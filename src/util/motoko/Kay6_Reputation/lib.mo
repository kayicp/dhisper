import Kay2 "../Kay2_Authorization";
import Error "../Error";
import RBTree "../StableCollections/RedBlackTree/RBTree";
import Order "mo:base/Order";
import Nat "mo:base/Nat";
module {
	public let TRUSTED_CALLERS = "kay6:trusted_callers";
	public let MAX_INCREMENTS = "kay6:max_increments_per_batch";
	public type Reputation = {
		positives : RBTree.RBTree<Nat, ()>; // point ids
		negatives : RBTree.RBTree<Nat, ()>;
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
	public type Score = {
		positives : Nat; // size of tree
		negatives : Nat;
	};
	public func score(rep : Reputation) : Score = {
		positives = RBTree.size(rep.positives);
		negatives = RBTree.size(rep.negatives);
	};
	public func compareScore(a : Score, b : Score) : Order.Order {
		let a_total = a.positives + a.negatives;
		let b_total = b.positives + b.negatives;

		let a_polar = Nat.compare(a.positives, a.negatives);
		let b_polar = Nat.compare(b.positives, b.negatives);

		switch (a_polar, b_polar) {
			case (#greater, #greater) compareLaplace({ numer = a.positives; denom = a_total }, { numer = b.positives; denom = b_total });
			case (#greater, _) #greater;

			case (#less, #less) switch (compareLaplace({ numer = a.negatives; denom = a_total }, { numer = b.negatives; denom = b_total })) {
				case (#less) #greater; // weaker negative -> closer to max
				case (#greater) #less; // stronger negative votes -> closer to min
				case (#equal) #equal;
			};
			case (#less, _) #less;

			case (#equal, #equal) Nat.compare(a_total, b_total);
			case (#equal, #greater) #less;
			case (#equal, #less) #greater;
		};
	};

	type Fraction = { numer : Nat; denom : Nat };
	func compareLaplace(a : Fraction, b : Fraction) : Order.Order {
		// cross multiply to prevent division
		let a_num = (a.numer + 1) * (b.denom + 2);
		let b_num = (b.numer + 1) * (a.denom + 2);
		switch (Nat.compare(a_num, b_num)) {
			case (#equal) Nat.compare(a.denom, b.denom);
			case (other) other;
		};
	};
};
