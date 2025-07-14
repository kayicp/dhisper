import Error "../Error";
import Kay2 "../Kay2_Authorization";
import Kay3 "../Kay3_FileSystem";
import Value "../Value";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Hasher "../SHA2";
import RBTree "../StableCollections/RedBlackTree/RBTree";
import Batcher "../Batcher";
import Pager "../Pager";

module {
	public let MAX_THREADS = "kay4:max_threads_size";
	public let MAX_REPLIES = "kay4:max_replies_size";
	public let MAX_CONTENT = "kay4:max_content_size";
	// public let MAX_FILES = "kay4:max_files";
	// public let MAX_OWNERS = "kay4:max_owners_size";
	// public let MAX_META = "kay4:max_metadata_size";

	public let FEE_COLLECTORS = "kay4:fee_collectors";
	public let CREATE_FEE_RATES = "kay4:create_fee_rates";
	public let DELETE_FEE_RATES = "kay4:delete_fee_rates";
	public let MIN_AMOUNT = "minimum_amount";
	public let ADDITIONAL_AMOUNT = "additional_amount_numerator";
	public let ADDITIONAL_BYTE = "additional_byte_denominator";

	public let DEFAULT_TAKE = "kay4:default_take_value";
	public let MAX_TAKE = "kay4:max_take_value";
	public let MAX_QUERY_BATCH = "kay4:max_query_batch_size";

	public let AUTHORIZATIONS = "kay4:authorizations";

	public let LOCKER = "kay4:locker";

	type Must = {
		authorization : Kay2.Authorized;
		timestamp : Nat64;
		phash : ?Blob; // hash of previous version, 1st version is null
	};
	public type Post = {
		thread : ?Nat;
		versions : RBTree.RBTree<Nat, Must>;
		content_versions : RBTree.RBTree<Nat, Text>;
		files_versions : RBTree.RBTree<Nat, RBTree.RBTree<Text, ()>>;
		owners_versions : RBTree.RBTree<Nat, RBTree.RBTree<Kay2.Identity, ()>>;
		metadata_versions : RBTree.RBTree<Nat, Value.Metadata>;
		hash : Blob;
	};
	type Must2 = {
		authorization : Kay2.Authorized;
		timestamp : Nat64;
		// phash : ?Blob; remove
	};
	public type Post2 = {
		thread : ?Nat;
		versions : RBTree.RBTree<Nat, Must2>;
		content_versions : RBTree.RBTree<Nat, Text>;
		files_versions : RBTree.RBTree<Nat, RBTree.RBTree<Text, ()>>;
		owners_versions : RBTree.RBTree<Nat, RBTree.RBTree<Kay2.Identity, ()>>;
		metadata_versions : RBTree.RBTree<Nat, Value.Metadata>;
		// hash removed, then added below
		tips : RBTree.RBTree<Nat, ()>;
		report : ?Nat;
	};
	public type Posts2 = RBTree.RBTree<Nat, Post2>;

	public type CreatePostArg = {
		thread : ?Nat;
		content : Text;
		files : [Kay3.CreateArg];
		owners : [Kay2.Identity];
		metadata : [(Text, Value.Type)];
		authorization : Kay2.Authorization;
	};
	// todo: canister lock error
	public type CreatePostError = {
		#GenericError : Error.Type;
		#ContentTooLarge : { current_size : Nat; maximum_size : Nat };
		#UnknownThread;
		#TemporarilyUnavailable : { current_time : Nat64; available_time : Nat64 };
		#DuplicateFileName : { index : Nat };
		#UnsupportedFileType : { index : Nat; supported_file_types : [Text] };
		#FilesTooMany : { maximum_files_per_batch : Nat };
		#FileTooLarge : { index : Nat; current_size : Nat; maximum_size : Nat };
		#Unauthorized : Kay2.Unauthorized;
	};
	public type ModifyPostArg = {
		id : Nat;
		content : Text; // "" = no changes
		files : [Kay3.CreateArg]; // [] = no new files
		owners : [Kay2.Identity]; // [] = no changes
		metadata : [(Text, Value.Type)]; // [] = no changes
		authorization : Kay2.Authorization;
	};
	public type ModifyPostError = {
		#GenericError : Error.Type;
		#UnknownPost;
		#DuplicateFileName : { index : Nat };
		#UnsupportedFileType : { index : Nat; supported_file_types : [Text] };
		#FilesTooMany : { maximum_files_per_batch : Nat };
		#FileTooLarge : { index : Nat; current_size : Nat; maximum_size : Nat };
		#Unauthorized : Kay2.Unauthorized;
	};
	public type DeletePostArg = {
		id : Nat;
		authorization : Kay2.Authorization;
	};
	public type DeletePostError = {
		#GenericError : Error.Type;
		#UnknownPost;
		#Unauthorized : Kay2.Unauthorized;
	};
	public func cleanText(_t : Text) : Text {
		// Convert tabs and carriage returns to space
		var t = Text.map(
			_t,
			func(c) {
				if (c == '\t' or c == '\r') { ' ' } else { c };
			},
		);
		// Repeatedly collapse spaces and newlines until stable
		label loopy while (true) {
			let original = t;
			t := Text.replace(t, #text "  ", " ");
			t := Text.replace(t, #text "\n\n\n", "\n\n");
			t := Text.replace(t, #text " \n", "\n");
			t := Text.replace(t, #text "\n ", "\n");
			if (t == original) break loopy;
		};
		Text.trim(
			t,
			#predicate(
				func(c) {
					c == ' ' or c == '\n';
				}
			),
		);
	};
	public func createPost({
		thread_id_opt : ?Nat;
		authorization : Kay2.Authorized;
		timestamp : Nat64;
		content : Text;
		owner : Kay2.Identity;
	}) : Post2 {
		{
			thread = thread_id_opt;
			versions = RBTree.insert(RBTree.empty(), Nat.compare, 0, { authorization; timestamp });
			content_versions = RBTree.insert(RBTree.empty(), Nat.compare, 0, content);
			files_versions = RBTree.insert(RBTree.empty(), Nat.compare, 0, RBTree.empty());
			owners_versions = RBTree.insert(RBTree.empty(), Nat.compare, 0, RBTree.insert(RBTree.empty(), Kay2.compareIdentity, owner, ()));
			metadata_versions = RBTree.insert(RBTree.empty(), Nat.compare, 0, RBTree.empty());
			tips = RBTree.empty();
			report = null;
		};
	};

	public func deletePost(p : Post2, must2 : Must2) : Post2 {
		let new_v = RBTree.size(p.versions);
		{
			p with
			versions = RBTree.insert(p.versions, Nat.compare, new_v, must2);
			content_versions = RBTree.insert(p.content_versions, Nat.compare, new_v, "");
			owners_versions = RBTree.insert(p.owners_versions, Nat.compare, new_v, RBTree.empty());
		};
	};

	// track not used because because we only wanna know the last value
	public func trackAuthorization(p : Post, version : Nat, track : Track) : ?Kay2.Authorized = switch (RBTree.get(p.versions, Nat.compare, version)) {
		case (?v) ?v.authorization;
		case _ null;
	};
	public func getAuthorization(p : Post2) : ?Kay2.Authorized {
		for ((_, latest) in RBTree.entriesReverse(p.versions)) return ?latest.authorization;
		null;
	};

	public func trackTimestamp(p : Post, version : Nat, _ : Track) : ?Nat64 = switch (RBTree.get(p.versions, Nat.compare, version)) {
		case (?v) ?v.timestamp;
		case _ null;
	};
	public func getTimestamp(p : Post2) : ?Nat64 {
		for ((_, latest) in RBTree.entriesReverse(p.versions)) return ?latest.timestamp;
		null;
	};

	public func trackPhash(p : Post, version : Nat, _ : Track) : ?Blob = switch (RBTree.get(p.versions, Nat.compare, version)) {
		case (?v) v.phash;
		case _ null;
	};
	public func getPhash(p : Post) : ?Blob {
		for ((_, latest) in RBTree.entriesReverse(p.versions)) return latest.phash;
		null;
	};

	public func getContent(p : Post2) : ?Text {
		for ((_, latest) in RBTree.entriesReverse(p.content_versions)) return ?latest;
		null;
	};
	public func trackContent(p : Post, version : Nat, track : Track) : ?Text = if (track == #LastValue) switch (RBTree.left(p.content_versions, Nat.compare, version)) {
		case (?(v_id, v)) ?v;
		case _ null;
	} else RBTree.get(p.content_versions, Nat.compare, version);

	public func getFiles(p : Post, prev : ?Text, take : ?Nat, meta : Value.Metadata) : [Text] {
		for ((_, v) in RBTree.entriesReverse(p.files_versions)) {
			let _take = Pager.cleanTake(take, Value.metaNat(meta, MAX_TAKE), Value.metaNat(meta, DEFAULT_TAKE), RBTree.size(v));
			return RBTree.pageKey(v, Text.compare, prev, _take);
		};
		[];
	};

	public func trackFiles(p : Post, version : Nat, track : Track, prev : ?Text, take : ?Nat, meta : Value.Metadata) : [Text] {
		let v = if (track == #LastValue) switch (RBTree.left(p.files_versions, Nat.compare, version)) {
			case (?(v_id, v)) v;
			case _ return [];
		} else switch (RBTree.get(p.files_versions, Nat.compare, version)) {
			case (?v) v;
			case _ return [];
		};
		let _take = Pager.cleanTake(take, Value.metaNat(meta, MAX_TAKE), Value.metaNat(meta, DEFAULT_TAKE), RBTree.size(v));
		RBTree.pageKey(v, Text.compare, prev, _take);
	};

	public func pageOwners(p : Post2, prev : ?Kay2.Identity, take : ?Nat, meta : Value.Metadata) : [Kay2.Identity] {
		for ((_, v) in RBTree.entriesReverse(p.owners_versions)) {
			let _take = Pager.cleanTake(take, Value.metaNat(meta, MAX_TAKE), Value.metaNat(meta, DEFAULT_TAKE), RBTree.size(v));
			return RBTree.pageKey(v, Kay2.compareIdentity, prev, _take);
		};
		[];
	};
	public func trackOwners(p : Post, version : Nat, track : Track, prev : ?Kay2.Identity, take : ?Nat, meta : Value.Metadata) : [Kay2.Identity] {
		let v = if (track == #LastValue) switch (RBTree.left(p.owners_versions, Nat.compare, version)) {
			case (?(v_id, v)) v;
			case _ return [];
		} else switch (RBTree.get(p.owners_versions, Nat.compare, version)) {
			case (?v) v;
			case _ return [];
		};
		let _take = Pager.cleanTake(take, Value.metaNat(meta, MAX_TAKE), Value.metaNat(meta, DEFAULT_TAKE), RBTree.size(v));
		RBTree.pageKey(v, Kay2.compareIdentity, prev, _take);
	};

	public func pagePostMeta(p : Post, prev : ?Text, take : ?Nat, meta : Value.Metadata) : [(Text, Value.Type)] {
		for ((_, v) in RBTree.entriesReverse(p.metadata_versions)) {
			let _take = Pager.cleanTake(take, Value.metaNat(meta, MAX_TAKE), Value.metaNat(meta, DEFAULT_TAKE), RBTree.size(v));
			return RBTree.page(v, Text.compare, prev, _take);
		};
		[];
	};
	public func trackPostMeta(p : Post, version : Nat, track : Track, prev : ?Text, take : ?Nat, meta : Value.Metadata) : [(Text, Value.Type)] {
		let v = if (track == #LastValue) switch (RBTree.left(p.metadata_versions, Nat.compare, version)) {
			case (?(v_id, v)) v;
			case _ return [];
		} else switch (RBTree.get(p.metadata_versions, Nat.compare, version)) {
			case (?v) v;
			case _ return [];
		};
		let _take = Pager.cleanTake(take, Value.metaNat(meta, MAX_TAKE), Value.metaNat(meta, DEFAULT_TAKE), RBTree.size(v));
		RBTree.page(v, Text.compare, prev, _take);
	};

	public type Posts = RBTree.RBTree<Nat, Post>;
	public func batchPostId<T>(
		post_ids : [Nat],
		posts : Posts2,
		meta : Value.Metadata,
		f : Post2 -> ?T,
	) : [?T] {
		let max_limit = Value.metaNat(meta, MAX_QUERY_BATCH);
		let batcher = Batcher.buffer<?T>(post_ids.size(), max_limit);
		label looping for (id in post_ids.vals()) {
			let result = switch (RBTree.get(posts, Nat.compare, id)) {
				case (?found) f(found);
				case _ null;
			};
			batcher.add(result);
			if (batcher.isFull()) break looping;
		};
		batcher.finalize();
	};

	type Track = { #Modification; #LastValue };
	public type PostVersion = { id : Nat; version : Nat };
	public func batchPostVersion<T>(
		postqs : [PostVersion],
		posts : Posts,
		meta : Value.Metadata,
		track : Track,
		f : (Post, Nat, Track) -> ?T,
	) : [?T] {
		let max_limit = Value.metaNat(meta, MAX_QUERY_BATCH);
		let batcher = Batcher.buffer<?T>(postqs.size(), max_limit);
		label looping for (postq in postqs.vals()) {
			let result = switch (RBTree.get(posts, Nat.compare, postq.id)) {
				case (?found) f(found, postq.version, track);
				case _ null;
			};
			batcher.add(result);
			if (batcher.isFull()) break looping;
		};
		batcher.finalize();
	};

	public func getOwners(p : Post2) : RBTree.RBTree<Kay2.Identity, ()> {
		for ((_, version) in RBTree.entriesReverse(p.owners_versions)) return version;
		RBTree.empty();
	};

	public type Threads = RBTree.RBTree<Nat, RBTree.RBTree<Nat, ()>>;
	public func getMetrics(metrics : Value.Metadata, threads : Threads, posts : Posts, posts2 : Posts2) : Value.Metadata {
		var m = Value.insert(metrics, "kay4:threads_size", #Nat(RBTree.size(threads)));
		m := Value.insert(m, "kay4:old_posts_size", #Nat(RBTree.size(posts)));
		m := Value.insert(m, "kay4:posts_size", #Nat(RBTree.size(posts2)));
		m;
	};
};
