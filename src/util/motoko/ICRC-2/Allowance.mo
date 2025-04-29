import Order "mo:base/Order";

import RBTree "../StableCollections/RedBlackTree/RBTree";
import Account "../ICRC-1/Account";

module {
  type ExpiryTime = ?Nat64;
  type AllowanceAmount = Nat;
  public type Tuple = (AllowanceAmount, ExpiryTime);
  public type Object = { allowance : AllowanceAmount; expires_at : ExpiryTime };
  public let Empty : Object = { allowance = 0; expires_at = null };
  public type Pair = { account : Account.Pair; spender : Account.Pair };
  public type Pairs = RBTree.RBTree<Pair, ()>;

  public func isExpired((amount, expiry) : Tuple, now : Nat64) : Bool = switch (amount, expiry) {
    case (0, _) true;
    case (_, ?expiry_time) expiry_time < now;
    case _ false;
  };

  public func isActive(allowance : Tuple, now : Nat64) : Bool = not isExpired(allowance, now);

  public func pairCompare(a : Pair, b : Pair) : Order.Order = switch (Account.compare(a.account, b.account)) {
    case (#equal) Account.compare(a.spender, b.spender);
    case other other;
  };

  public func clean((allowance, expires_at) : Tuple, now : Nat64) : Object = if (isExpired((allowance, expires_at), now)) ({
    allowance = 0;
    expires_at = null;
  }) else ({
    allowance;
    expires_at;
  });
};
