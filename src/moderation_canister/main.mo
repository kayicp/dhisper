import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import Kay5 "../util/motoko/Kay5_Moderation";

shared (install) actor class Canister(
	// deploy : {}
) = Self {
	stable var reports = RBTree.empty<Nat, Kay5.Report>();

};
