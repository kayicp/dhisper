import Order "mo:base/Order";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";

module {
  public func compare<T>(a : ?T, b : ?T, comparer : (T, T) -> Order.Order) : Order.Order = switch (a, b) {
    case (?A, ?B) comparer(A, B);
    case (null, ?_) #less;
    case (?_, null) #greater;
    case _ #equal;
  };

  public func select<T>(a : ?T, b : ?T, fn : (T, T) -> T) : ?T = switch (a, b) {
    case (?A, ?B) ?fn(A, B);
    case (null, ?N) ?N;
    case (?N, null) ?N;
    case _ null;
  };

  public func minOrDefault(opt : ?Nat, default : Nat) : Nat = switch opt {
    case (?defined) Nat.min(defined, default);
    case _ default;
  };

  public func equalPrincipal(guess : Principal, question : ?Principal) : Bool = equal(guess, question, Principal.equal);

  public func equal<T>(guess : T, question : ?T, fn : (T, T) -> Bool) : Bool = switch question {
    case (?answer) fn(guess, answer);
    case _ false;
  };

  public func fallback<T>(guess : ?T, final : T) : T = switch guess {
    case (?found) found;
    case _ final;
  };
};
