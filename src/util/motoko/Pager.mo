import Nat "mo:base/Nat";
import Option "Option";
module {
	public func cleanTake(take : ?Nat, max_take : ?Nat, default_take : ?Nat, final_take : Nat) : Nat = switch take {
		case (?found) Nat.min(found, Option.fallback(max_take, final_take));
		case _ Option.fallback(default_take, Option.fallback(max_take, final_take));
	};
};
