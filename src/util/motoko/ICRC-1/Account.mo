import Blob "mo:base/Blob";
import Hash "mo:base/Hash";
import Nat8 "mo:base/Nat8";
import Order "mo:base/Order";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

import Management "../Management";
import SHA2 "../SHA2";

module {
	public type Pair = { owner : Principal; subaccount : ?Blob };

	/// Account Identitier type.
	public type Identifier = { hash : Blob };

	/// Return the [motoko-base's Hash.Hash](https://github.com/dfinity/motoko-base/blob/master/src/Hash.mo#L9) of `Identifier`.
	/// To be used in HashMap.
	public func hash(a : Identifier) : Hash.Hash = Blob.hash(a.hash);

	/// Test if two account identifier are equal.
	// public func equal(a : Identifier, b : Identifier) : Bool = a.hash == b.hash;

	public let default_subaccount : [Nat8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

	/// Return the account identifier of the Principal.
	public func fromPrincipal({ owner; subaccount } : Pair) : Identifier {
		let sa : [Nat8] = switch subaccount {
			case (?found) Blob.toArray(found);
			case _ default_subaccount;
		};
		let tag : [Nat8] = [10, 97, 99, 99, 111, 117, 110, 116, 45, 105, 100]; // b"\x0Aaccount-id"
		let digest = SHA2.SHA224();
		digest.writeIter(tag.vals());
		digest.writeIter(Principal.toBlob(owner).vals());
		digest.writeIter(sa.vals()); // sub account
		{ hash = digest.sum() };
	};

	public func default() : Pair = {
		owner = Management.principal();
		subaccount = null;
	};

	public func validate(pair : Pair) : Bool = if (Principal.isAnonymous(pair.owner) or Principal.equal(pair.owner, Management.principal()) or Principal.toBlob(pair.owner).size() > 29) false else validateSubaccount(pair.subaccount);

	public func validateSubaccount(blob : ?Blob) : Bool = switch (blob) {
		case (?bytes) bytes.size() == 32;
		case _ true;
	};

	public func denull(blob : ?Blob) : Blob = switch blob {
		case (?found) found;
		case _ Blob.fromArray(default_subaccount);
	};

	public func compare(a : Pair, b : Pair) : Order.Order {
		switch (Principal.compare(a.owner, b.owner)) {
			case (#equal) Blob.compare(denull(a.subaccount), denull(b.subaccount));
			case other other;
		};
	};

	public func equal(a : Pair, b : Pair) : Bool = compare(a, b) == #equal;

	public func print(a : Pair) : Text = debug_show a;
};
