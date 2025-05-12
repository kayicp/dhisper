import Kay2 "../Kay2_Authorization";
import Error "../Error";
import RBTree "../StableCollections/RedBlackTree/RBTree";
module {
	public let TRUSTED_CALLERS = "kay6:trusted_callers";
	public let MAX_INCREMENTS = "kay6:max_increments_per_batch";
	public type Reputation = {
		positives : RBTree.RBTree<Nat, ()>; // point ids
		negatives : RBTree.RBTree<Nat, ()>;
	};
	public type Score = {
		positives : Nat; // size of tree
		negatives : Nat;
	};
	type Increment = {
		to : Kay2.Identity;
		positive : Bool;
		points : Nat;
		comment : Text;
	};
	public type BatchIncrementArg = {
		authorization : Kay2.Authorization;
		increments : [Increment];
	};
	public type BatchIncrementError = {
		#GenericError : Error.Type;
		#IncrementsTooMany : { maximum_increments_per_batch : Nat };
		#Unauthorized : Kay2.Unauthorized;
	};
	public type StableIncrement = {
		to : Kay2.Identity;
		positive : Bool;
		points : [Nat];
		comment : Text;
	};
	public type Commit = {
		from : Kay2.Authorized;
		timestamp : Nat64;
		increments : [StableIncrement];
	};
};
