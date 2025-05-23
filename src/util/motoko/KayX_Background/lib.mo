import Value "../Value";
import RBTree "../StableCollections/RedBlackTree/RBTree";

module {
	type Status = {
		#Processing;
		#Processed;
	};
	public type Operation = {
		caller : Principal;
		name : Text;
		timestamp : Nat64;
		metadata : RBTree.RBTree<Text, Value.Type>;

	};
};
