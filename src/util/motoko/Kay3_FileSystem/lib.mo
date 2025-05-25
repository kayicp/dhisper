import RBTree "../../motoko/StableCollections/RedBlackTree/RBTree";
import Value "../Value";
import Error "../Error";
import Kay2 "../Kay2_Authorization";

module {
	public let DEFAULT_TAKE = "kay3:default_take_value";
	public let MAX_TAKE = "kay3:max_take_value";
	public let MAX_QUERY_BATCH = "kay3:max_query_batch_size";
	public let FEE_COLLECTORS = "kay3:fee_collectors";

	public let MAX_FILES = "kay3:max_files_size";
	public let MAX_NAME = "kay3:max_filename_size";
	public let SUPPORTED_FILE_TYPES = "kay3:supported_file_types"; // = array of texts (image/jpeg, image/png, etc.)
	public let MAX_OWNERS = "kay3:max_owners_per_file";
	public let MAX_META = "kay3:max_metadata_size_per_file";
	public let MAX_CHUNKS_SIZE = "kay3:max_chunks_size";
	public let MAX_CHUNK_SIZE = "kay3:max_chunk_size";
	public let MAX_FILE_SIZE = "kay3:max_file_size"; // number in bytes
	public let MAX_FILES_BATCH_SIZE = "kay3:max_files_batch_size"; // number of max batch array size

	// todo: redo this, follow kay4
	public let CREATE_FEE = "kay3:create_file_icrc2_fee_rates"; // = map of (canister_id, amount_numerator, byte_denominator)
	public let MODIFY_FEE = "kay3:modify_file_icrc2_fee_rates"; // = map of (canister_id, amount_numerator, byte_denominator)
	public let DELETE_FEE = "kay3:delete_file_icrc2_fee_rates"; // = map of (canister_id, amount_numerator, byte_denominator)

	type Must = {
		authorization : Kay2.Authorized;
		timestamp : Nat64;
		phash : ?Blob; // hash of previous version, 1st version is null
	};
	public type File = {
		versions : RBTree.RBTree<Nat, Must>;
		name_versions : RBTree.RBTree<Nat, Text>;
		data_type_versions : RBTree.RBTree<Nat, Text>;
		owners_versions : RBTree.RBTree<Nat, RBTree.RBTree<Kay2.Identity, ()>>;
		metadata_versions : RBTree.RBTree<Nat, Value.Metadata>;
		data_versions : RBTree.RBTree<Nat, RBTree.RBTree<Nat, Blob>>;
		size_versions : RBTree.RBTree<Nat, Nat>;
		hash : Blob;
	};
	public type FileVersion = { name : Text; version : Nat };
	type Chunk = { index : Nat; chunk : Blob };
	public type CreateArg = {
		name : Text;
		data_type : Text;
		owners : [Kay2.Identity];
		metadata : [(Text, Value.Type)];
		data : [Chunk];
	};
	public type BatchCreateArg = {
		files : [CreateArg];
		authorization : Kay2.Authorization;
	};
	public type BatchCreateError = {
		#DuplicateName : { index : Nat };
		#UnsupportedFileType : { index : Nat; supported_file_types : [Text] };
		#FilesTooMany : { maximum_files_batch_size : Nat };
		#FileTooLarge : { index : Nat; current_size : Nat; maximum_size : Nat };
		#Unauthorized : Kay2.Unauthorized;
		#GenericError : Error.Type;
	};
	public type ModifyArg = {
		name : Text;
		new_name : Text; // "" = no changes
		new_data_type : Text; // "" = no changes
		new_owners : [Kay2.Identity]; // [] = no changes
		new_metadata : [(Text, Value.Type)]; // [] = no changes
		data : [Chunk]; // [] = no changes
	};
	public type BatchModifyArg = {
		files : [ModifyArg];
		authorization : Kay2.Authorization;
	};
	public type BatchModifyError = {
		#DuplicateNewName : { index : Nat };
		#UnsupportedNewFileType : { index : Nat; supported_file_types : [Text] };
		#FilesTooMany : { maximum_files_batch_size : Nat };
		#FileTooLarge : { index : Nat; current_size : Nat; maximum_size : Nat };
		#NotOwner : { index : Nat; owners : [Kay2.Identity] };
		#Unauthorized : Kay2.Unauthorized;
		#GenericError : Error.Type;
	};
	public type DeleteArg = { name : Text };
	public type BatchDeleteArg = {
		files : [DeleteArg];
		authorization : Kay2.Authorization;
	};
	public type BatchDeleteError = {
		#UnknownFilename : { index : Nat };
		#FilesTooMany : { maximum_files_batch_size : Nat };
		#NotOwner : { index : Nat; owners : [Kay2.Identity] };
		#Unauthorized : Kay2.Unauthorized;
		#GenericError : Error.Type;
	};

	public type Files = RBTree.RBTree<Text, File>;
	public func getMetrics(metrics : Value.Metadata, files : Files) : Value.Metadata = Value.insert(metrics, "kay3:files_size", #Nat(RBTree.size(files)));
};
