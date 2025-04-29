import Prim "mo:⛔";

module {
	public let MICRO : Nat64 = 1000;
	public func MILLI(t : Nat64) : Nat64 = t * 1000 * MICRO;
	public func SECONDS(t : Nat64) : Nat64 = t * MILLI(1000);
	public func MINUTES(t : Nat64) : Nat64 = t * SECONDS(60);
	public func HOURS(t : Nat64) : Nat64 = t * MINUTES(60);
	public func DAYS(t : Nat64) : Nat64 = t * HOURS(24);

	public func nanos() : Nat64 {
		// return Nat64.fromNat(Int.abs(Time.now()));
		Prim.time();
	};
};
