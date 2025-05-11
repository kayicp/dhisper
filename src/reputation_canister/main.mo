import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import Kay6 "../util/motoko/Kay6_Reputation";
import Value "../util/motoko/Value";
import Kay1 "../util/motoko/Kay1_Canister";
import Queue "../util/motoko/StableCollections/Queue";

import Result "../util/motoko/Result";
import Error "../util/motoko/Error";
import Principal "mo:base/Principal";
import Kay2 "../util/motoko/Kay2_Authorization";

shared (install) actor class Canister(
	// deploy : {}
) = Self {
	func self() : Principal = Principal.fromActor(Self);
	stable var metadata : Value.Metadata = RBTree.empty();
	stable var logs = Queue.empty<Text>();

	func log(t : Text) = logs := Kay1.log(logs, t);
	public shared query func kay1_logs() : async [Text] = async Queue.arrayTail(logs);

	public shared query ({ caller }) func kay1_metrics() : async [(Text, Value.Type)] {
		var custodians = Kay1.getCustodians(metadata);

		var metrics : Value.Metadata = RBTree.empty();
		metrics := Kay1.getMetrics(metrics, caller, logs, custodians);
		// todo: kay5

		RBTree.array(metrics);
	};

	public shared ({ caller }) func kay1_set_metadata({ child_canister_id; pairs } : Kay1.MetadataArg) : async Result.Type<(), Error.Generic> = async try {
		if (
			not Principal.isController(caller) and
			not RBTree.has(Kay1.getCustodians(metadata), Principal.compare, caller)
		) return Kay1.callerNotCustodianErr(caller, self());

		metadata := switch (await* Kay1.setMetadata(child_canister_id, metadata, pairs)) {
			case (#Err err) return #Err err;
			case (#Ok new_meta) new_meta;
		};
		#Ok;
	} catch e Error.error(e);

	stable var points = Queue.empty<(Nat, { to : Kay2.Identity; timestamp : Nat64 })>(); // for trimming expired points
	stable var accounts = RBTree.empty<Kay2.Identity, Kay6.Reputation>();
	stable var ranks = RBTree.empty<Kay6.Score, Kay2.Identity>();

	public shared query func kay6_accounts(prev : ?Kay2.Identity, take : Nat) : async [Kay2.Identity] {
		[];
	};
	public shared query func kay6_positives_of(accounts : [Kay2.Identity]) : async [Nat] {
		[];
	};
	public shared query func kay6_negatives_of(accounts : [Kay2.Identity]) : async [Nat] {
		[];
	};
	public shared query func kay6_top(take : Nat) : async [Kay2.Identity] { [] };

	public shared func kay6_increment(scores : Kay6.BatchIncrementArg) : async Result.Type<(), Kay6.BatchIncrementError> {
		#Ok;
	};

};
