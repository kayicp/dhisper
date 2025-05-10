import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import Kay5 "../util/motoko/Kay5_Moderation";
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

	stable var reports = RBTree.empty<Nat, Kay5.Report>();
	stable var subjects = RBTree.empty<Value.Type, Nat>();

	public shared query func kay5_reports(prev : ?Nat, take : ?Nat) : async [Nat] {
		[];
	};
	public shared query func kay5_authors_of(report_ids : [Nat]) : async [Kay2.Identity] {
		[];
	};
	public shared query func kay5_subjects_of(report_ids : [Nat]) : async [Value.Type] {
		[];
	};
	public shared query func kay5_comments_of(report_ids : [Nat]) : async [Text] {
		[];
	};
	public shared query func kay5_timestamps_of(report_ids : [Nat]) : async [Nat64] {
		[];
	};
	public shared query func kay5_statuses_of(report_id : Nat) : async [Kay5.Status] {
		[];
	};
	public shared query func kay5_subjects(prev : ?Value.Type, take : ?Nat) : async [Value.Type] {
		[];
	};
	public shared query func kay5_report_ids_of(subjects : [Value.Type]) : async [Nat] {
		[];
	};
	public shared ({ caller }) func kay5_create(report : Kay5.CreateReportArg) : async Result.Type<Nat, Kay5.CreateReportError> {
		#Ok 1;
	};
	public shared ({ caller }) func kay5_moderate(arg : Kay5.ModerateArg) : async Result.Type<(), Kay5.ModerateError> {
		#Ok;
	};
	public shared ({ caller }) func kay5_appeal(arg : Kay5.AppealArg) : async Result.Type<(), Kay5.AppearError> {
		#Ok;
	};

};
