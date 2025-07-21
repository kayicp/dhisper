import Account "../ICRC-1/Account";
import ICRC_1_Types "../ICRC-1/Types";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Order "mo:base/Order";
import Nat "mo:base/Nat";
import RBTree "../StableCollections/RedBlackTree/RBTree";
import Value "../Value";

module {
	public let DEFAULT_TAKE = "kay2:default_take_value";
	public let MAX_TAKE = "kay2:max_take_value";

	public type Init = {
		default_take_value : ?Nat;
		max_take_value : ?Nat;
	};

	public func init(metadata : Value.Metadata, i : Init) : Value.Metadata {
		var m = metadata;
		m := Value.setNat(m, DEFAULT_TAKE, i.default_take_value);
		m := Value.setNat(m, MAX_TAKE, i.max_take_value);
		m;
	};

	type AnonProof = {
		canister_id : Principal;
		amount : Nat;
		root : Blob;
		nullifier : Blob;
		to : Account.Pair;
	};
	public type Identity = {
		#ICRC_1 : Account.Pair;
	};
	public type Authorization = {
		#ICRC_1 : { subaccount : ?Blob; canister_id : Principal }; // check if user holds enough token to create/modify/delete files with weaker limits
		#ICRC_7 : {
			subaccount : ?Blob;
			canister_id : Principal;
			preferred_token_id : ?Nat;
		}; // check if user holds any NFT in the collection to create/modify/delete files with weaker limits
		#ICRC_2 : { subaccount : ?Blob; canister_id : Principal; fee : ?Nat }; // else, user have to pay fee to create/modify/delete files to bypass limits
		#None : { subaccount : ?Blob }; // free tier
	};
	public type Authorized = {
		#ICRC_1 : {
			owner : Principal;
			subaccount : ?Blob;
			canister_id : Principal;
			minimum_balance : Nat;
		};
		#ICRC_7 : {
			owner : Principal;
			subaccount : ?Blob;
			canister_id : Principal;
			token_id : Nat;
		};
		#ICRC_2 : {
			owner : Principal;
			subaccount : ?Blob;
			canister_id : Principal;
			xfer : Nat;
		}; // xfer = paid fee transfer block id
		#None : Account.Pair;
	};
	public type Unauthorized = {
		#ICRC_1 : {
			#BadCanister : { expected_canister_ids : [Principal] };
			#BalanceTooSmall : { current_balance : Nat; minimum_balance : Nat }; // user dont have enough balance to meet the minimum
		};
		#ICRC_7 : {
			#BadCanister : { expected_canister_ids : [Principal] };
			#UnknownPreferredToken : { current_holdings : [Nat] }; // preferred token is not in the list of user's holding
			#EmptyHoldings; // user holds nothing from the collection
		};
		#ICRC_2 : {
			#BadCanister : { expected_canister_ids : [Principal] };
			#BadFee : { expected_fee : Nat };
			#TransferFromFailed : ICRC_1_Types.TransferFromError;
		};
	};
	public type Locker = { caller : Principal; authorization : Authorization };
	public func lockerIdentity({ caller; authorization } : Locker) : Identity = switch authorization {
		case (#ICRC_1 { subaccount } or #ICRC_2 { subaccount } or #ICRC_7 { subaccount } or #None { subaccount }) #ICRC_1 {
			owner = caller;
			subaccount;
		};
	};
	// func rankIdentity(o : Identity) : Nat = switch o {
	//   case (#ICRC_1 _) 0;
	// };
	public func compareIdentity(ao : Identity, bo : Identity) : Order.Order = switch (ao, bo) {
		case (#ICRC_1 a, #ICRC_1 b) Account.compare(a, b);
		// case _ Nat.compare(rankIdentity(ao), rankIdentity(bo));
	};
	public func equalIdentity(ao : Identity, bo : Identity) : Bool = compareIdentity(ao, bo) == #equal;

	public func identityValue(id : Identity) : Value.Type = switch id {
		case (#ICRC_1 { owner; subaccount }) {
			let x = switch subaccount {
				case (?found) [("owner", #Principal owner), ("subaccount", #Blob found)];
				case _ [("owner", #Principal owner)];
			};
			#Map x;
		};
	};

	public func getMetrics(metrics : Value.Metadata, owners_size : Nat) : Value.Metadata {
		Value.insert(metrics, "kay2:owners_size", #Nat owners_size);
	};
};
