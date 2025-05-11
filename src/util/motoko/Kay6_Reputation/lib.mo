import Kay2 "../Kay2_Authorization";
import Error "../Error";
import RBTree "../StableCollections/RedBlackTree/RBTree";
module {
	public type Reputation = {
		positives : RBTree.RBTree<Nat, ()>; // point ids
		negatives : RBTree.RBTree<Nat, ()>;
	};
	public type Score = {
		positives : Nat; // size of tree
		negatives : Nat;
	};
	type Increment = {
		account : Kay2.Identity;
		positives : Nat; // how many points
		negatives : Nat;
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
};
