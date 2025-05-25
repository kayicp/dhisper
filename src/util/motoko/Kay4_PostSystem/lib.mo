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

	public type Init = {
		max_threads_size : ?Nat;
		max_replies_size : ?Nat;
		max_content_size : ?Nat;

		fee_collectors : [Principal];
		create_fee_rates : [{
			standard : Text;
			assets : [{
				canister_id : Principal;
				minimum_amount : ?Nat;
				additional : ?{ amount_numerator : Nat; byte_denominator : Nat };
			}];
		}];
		delete_fee_rates : [{
			standard : Text;
			assets : [{
				canister_id : Principal;
				minimum_amount : ?Nat;
			}];
		}];

		default_take_value : ?Nat;
		max_take_value : ?Nat;
		max_query_batch_size : ?Nat;
	};

	public func init(metadata : Value.Metadata, i : Init) : Value.Metadata {
		var m = metadata;
		m := Value.setNat(m, MAX_THREADS, i.max_threads_size);
		m := Value.setNat(m, MAX_REPLIES, i.max_replies_size);
		m := Value.setNat(m, MAX_CONTENT, i.max_content_size);

		let fee_collectors = Buffer.Buffer<Value.Type>(i.fee_collectors.size());
		for (p in i.fee_collectors.vals()) fee_collectors.add(#Principal p);
		m := Value.setArray(m, FEE_COLLECTORS, Buffer.toArray(fee_collectors));

		var create_fee_rates_standards : Value.Metadata = RBTree.empty();
		for (fee_rate in i.create_fee_rates.vals()) {
			var token_map = RBTree.empty<Value.Type, Value.Type>();
			for (token in fee_rate.assets.vals()) {
				var fee_map : Value.Metadata = RBTree.empty();
				fee_map := Value.setNat(fee_map, MIN_AMOUNT, token.minimum_amount);
				switch (token.additional) {
					case (?defined) {
						fee_map := Value.setNat(fee_map, ADDITIONAL_AMOUNT, ?defined.amount_numerator);
						fee_map := Value.setNat(fee_map, ADDITIONAL_BYTE, ?defined.byte_denominator);
					};
					case _ ();
				};
				token_map := RBTree.insert(token_map, Value.compare, #Principal(token.canister_id), #Map(RBTree.array(fee_map)));
			};
			create_fee_rates_standards := Value.setValueMap(create_fee_rates_standards, fee_rate.standard, token_map);
		};
		m := Value.setMap(m, CREATE_FEE_RATES, create_fee_rates_standards);

		var delete_fee_rates_standards : Value.Metadata = RBTree.empty();
		for (fee_rate in i.delete_fee_rates.vals()) {
			var token_map = RBTree.empty<Value.Type, Value.Type>();
			for (token in fee_rate.assets.vals()) {
				var fee_map : Value.Metadata = RBTree.empty();
				fee_map := Value.setNat(fee_map, MIN_AMOUNT, token.minimum_amount);
				token_map := RBTree.insert(token_map, Value.compare, #Principal(token.canister_id), #Map(RBTree.array(fee_map)));
			};
			delete_fee_rates_standards := Value.setValueMap(delete_fee_rates_standards, fee_rate.standard, token_map);
		};
		m := Value.setMap(m, DELETE_FEE_RATES, delete_fee_rates_standards);

		m := Value.setNat(m, DEFAULT_TAKE, i.default_take_value);
		m := Value.setNat(m, MAX_TAKE, i.max_take_value);
		m := Value.setNat(m, MAX_QUERY_BATCH, i.max_query_batch_size);

		m;
	};

	public let LOCKER = "kay4:locker";

	type Must = {
		authorization : Kay2.Authorized;
		timestamp : Nat64;
		phash : ?Blob; // hash of previous version, 1st version is null
	};
	public type Post = {
		thread : ?Nat; // todo: remove this
		versions : RBTree.RBTree<Nat, Must>;
		content_versions : RBTree.RBTree<Nat, Text>;
		files_versions : RBTree.RBTree<Nat, RBTree.RBTree<Text, ()>>;
		owners_versions : RBTree.RBTree<Nat, RBTree.RBTree<Kay2.Identity, ()>>;
		metadata_versions : RBTree.RBTree<Nat, Value.Metadata>;
		hash : Blob;
	};
	public type CreatePostArg = {
		thread : ?Nat;
		content : Text;
		files : [Kay3.CreateArg];
		owners : [Kay2.Identity];
		metadata : [(Text, Value.Type)];
		authorization : Kay2.Authorization;
	};
	public type CreatePostError = {
		#GenericError : Error.Type;
		#ContentTooLarge : { current_size : Nat; maximum_size : Nat };
		#UnknownThread;
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
		let replacements = [
			("  ", " "),
			("\n\n", "\n"),
			("\r\r", "\r"),
			("\t\t", "\t"),
		];
		var t = _t;
		for ((search, replacement) in replacements.vals()) {
			t := Text.replace(t, #text search, replacement);
		};
		Text.trim(
			t,
			#predicate(
				func(c) {
					c == ' ' or c == '\n' or c == '\r' or c == '\t';
				}
			),
		);
	};
	public func createPost({
		thread : ?Nat;
		content : Text;
		authorization : Kay2.Authorized;

		timestamp : Nat64;
		owner : Kay2.Identity;
	}) : Post {
		var hashes = RBTree.empty<Blob, Blob>();
		func register(k : Text, v : Value.Type) {
			let keyHash = Hasher.sha256([Text.encodeUtf8(k).vals()].vals());
			let valueHash = Value.hash(v);
			hashes := RBTree.insert(hashes, Blob.compare, keyHash, valueHash);
		};
		switch thread {
			case (?defined) register("thread", #Nat defined);
			case _ ();
		};
		var new_post : Post = {
			thread;
			versions = RBTree.empty();
			content_versions = RBTree.empty();
			files_versions = RBTree.empty();
			owners_versions = RBTree.empty();
			metadata_versions = RBTree.empty();
			hash = "" : Blob;
		};
		let must : Must = { authorization; timestamp; phash = null };
		new_post := newMust(new_post, must, func(b : Blob) = register("versions", #Blob b));

		new_post := newContent(new_post, content, func(b : Blob) = register("content_versions", #Blob b));

		// todo: later
		// new_post := newFiles(new_post, RBTree.empty(), func(b: Blob) = register("files_versions", #Blob b));

		new_post := newOwners(new_post, RBTree.insert(RBTree.empty(), Kay2.compareIdentity, owner, ()), func(b : Blob) = register("owners_versions", #Blob b));

		// todo: later
		// new_post := newMetadata(new_post, RBTree.empty(), func(b: Blob) = register("metadata_versions", #Blob b));

		{ new_post with hash = Hasher.sha256blobMap(RBTree.entries(hashes)) };
	};
	func newMust(p : Post, must : Must, hashed : Blob -> ()) : Post {
		var hashes = RBTree.empty<Blob, Blob>();
		func register(k : Text, v : Value.Type) {
			let keyHash = Hasher.sha256([Text.encodeUtf8(k).vals()].vals());
			let valueHash = Value.hash(v);
			hashes := RBTree.insert(hashes, Blob.compare, keyHash, valueHash);
		};
		register("authorization", #Blob(Kay2.hashAuth(must.authorization)));
		register("timestamp", #Nat(Nat64.toNat(must.timestamp)));
		switch (must.phash) {
			case (?found) register("phash", #Blob found);
			case _ ();
		};
		hashed(Hasher.sha256blobMap(RBTree.entries(hashes)));
		{
			p with versions = RBTree.insert(p.versions, Nat.compare, RBTree.size(p.versions) + 1, must)
		};
	};
	func newContent(p : Post, content : Text, hashed : Blob -> ()) : Post {
		var hashes = RBTree.empty<Blob, Blob>();
		func register(k : Text, v : Value.Type) {
			let keyHash = Hasher.sha256([Text.encodeUtf8(k).vals()].vals());
			let valueHash = Value.hash(v);
			hashes := RBTree.insert(hashes, Blob.compare, keyHash, valueHash);
		};
		register("content", #Text content);
		hashed(Hasher.sha256blobMap(RBTree.entries(hashes)));
		{
			p with content_versions = RBTree.insert(p.content_versions, Nat.compare, RBTree.size(p.versions), content)
		};
	};
	func newOwners(p : Post, owners : RBTree.RBTree<Kay2.Identity, ()>, hashed : Blob -> ()) : Post {
		var hashes = RBTree.empty<Blob, Blob>();
		func register(k : Text, v : Value.Type) {
			let keyHash = Hasher.sha256([Text.encodeUtf8(k).vals()].vals());
			let valueHash = Value.hash(v);
			hashes := RBTree.insert(hashes, Blob.compare, keyHash, valueHash);
		};
		let buff = Buffer.Buffer<Value.Type>(RBTree.size(owners));
		for ((owner, _) in RBTree.entries(owners)) {
			buff.add(#Blob(Kay2.hashIdentity(owner)));
		};
		register("owners", #Array(Buffer.toArray(buff)));
		hashed(Hasher.sha256blobMap(RBTree.entries(hashes)));
		{
			p with owners_versions = RBTree.insert(p.owners_versions, Nat.compare, RBTree.size(p.versions), owners)
		};
	};

	public func deletePost(
		_p : Post,
		{
			authorization : Kay2.Authorized;
			timestamp : Nat64;
		},
	) : Post {
		var hashes = RBTree.empty<Blob, Blob>();
		func register(k : Text, v : Value.Type) {
			let keyHash = Hasher.sha256([Text.encodeUtf8(k).vals()].vals());
			let valueHash = Value.hash(v);
			hashes := RBTree.insert(hashes, Blob.compare, keyHash, valueHash);
		};
		var p = _p;
		switch (p.thread) {
			case (?defined) register("thread", #Nat defined);
			case _ ();
		};
		let must : Must = { authorization; timestamp; phash = ?p.hash };
		p := newMust(p, must, func(b) = register("versions", #Blob b));
		p := newContent(p, "", func(b) = register("content_versions", #Blob b));
		p := newOwners(p, RBTree.empty(), func(b) = register("owners_versions", #Blob b));
		// todo later: files n metadata
		{ p with hash = Hasher.sha256blobMap(RBTree.entries(hashes)) };
	};

	// track not used because because we only wanna know the last value
	public func trackAuthorization(p : Post, version : Nat, track : Track) : ?Kay2.Authorized = switch (RBTree.get(p.versions, Nat.compare, version)) {
		case (?v) ?v.authorization;
		case _ null;
	};
	public func getAuthorization(p : Post) : ?Kay2.Authorized {
		for ((_, latest) in RBTree.entriesReverse(p.versions)) return ?latest.authorization;
		null;
	};

	public func trackTimestamp(p : Post, version : Nat, _ : Track) : ?Nat64 = switch (RBTree.get(p.versions, Nat.compare, version)) {
		case (?v) ?v.timestamp;
		case _ null;
	};
	public func getTimestamp(p : Post) : ?Nat64 {
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

	public func getContent(p : Post) : ?Text {
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

	public func pageOwners(p : Post, prev : ?Kay2.Identity, take : ?Nat, meta : Value.Metadata) : [Kay2.Identity] {
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
		posts : Posts,
		meta : Value.Metadata,
		f : Post -> ?T,
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

	public func getOwners(p : Post) : RBTree.RBTree<Kay2.Identity, ()> {
		for ((_, version) in RBTree.entriesReverse(p.owners_versions)) return version;
		RBTree.empty();
	};

	public type Threads = RBTree.RBTree<Nat, RBTree.RBTree<Nat, ()>>;
	public func getMetrics(metrics : Value.Metadata, threads : Threads, posts : Posts) : Value.Metadata {
		let m = Value.insert(metrics, "kay4:threads_size", #Nat(RBTree.size(threads)));
		Value.insert(m, "kay4:posts_size", #Nat(RBTree.size(posts)));
	};
};
