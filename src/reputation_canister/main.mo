import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import Kay6 "../util/motoko/Kay6_Reputation";
import Value "../util/motoko/Value";
import Kay1 "../util/motoko/Kay1_Canister";
import Queue "../util/motoko/StableCollections/Queue";

import Result "../util/motoko/Result";
import Error "../util/motoko/Error";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Kay2 "../util/motoko/Kay2_Authorization";
import Time64 "../util/motoko/Time64";

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
		// todo: kay6

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

	stable var point_id = 0;
	stable var commits = RBTree.empty<Nat, Kay6.Commit>(); // for trimming expired commits
	stable var accounts = RBTree.empty<Kay2.Identity, Kay6.Reputation>();
	stable var ranks = RBTree.empty<Kay6.Score, RBTree.RBTree<Kay2.Identity, ()>>();

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
	public shared query func kay6_bottom(take : Nat) : async [Kay2.Identity] {
		[];
	};

	public shared ({ caller }) func kay6_increment(arg : Kay6.BatchIncrementArg) : async Result.Type<(), Kay6.BatchIncrementError> {
		if (not Kay1.isAvailable(metadata)) return Error.text("Unavailable");

		let maximum_increments_per_batch = Value.getNat(metadata, Kay6.MAX_INCREMENTS, 0);
		if (maximum_increments_per_batch > 0 and arg.increments.size() > maximum_increments_per_batch) return #Err(#IncrementsTooMany { maximum_increments_per_batch });

		let from : Kay2.Authorized = switch (arg.authorization) {
			case (#None auth) {
				if (not RBTree.has(Value.getUniquePrincipals(metadata, Kay6.TRUSTED_CALLERS, RBTree.empty()), Principal.compare, caller)) return Error.text("Caller is not trusted");
				#None { auth with owner = caller };
			};
			case _ return Error.text("ICRC-1, ICRC-2, ICRC-7 authorizations are not supported");
		};
		let commit_id = point_id;
		let increment_buff = Buffer.Buffer<Kay6.StableIncrement>(arg.increments.size());
		label incrementing for (increment in arg.increments.vals()) {
			if (increment.points == 0) continue incrementing;
			let point_buff = Buffer.Buffer<Nat>(increment.points);
			var reputation = switch (RBTree.get(accounts, Kay2.compareIdentity, increment.to)) {
				case (?found) found;
				case _ ({ positives = RBTree.empty(); negatives = RBTree.empty() });
			};
			var score = Kay6.score(reputation);
			var polartives = if (increment.positive) reputation.positives else reputation.negatives;
			for (i in Iter.range(0, increment.points - 1)) {
				point_buff.add(point_id);
				polartives := RBTree.insert(polartives, Nat.compare, point_id, ());
				point_id += 1;
			};
			reputation := if (increment.positive) ({
				reputation with positives = polartives
			}) else ({ reputation with negatives = polartives });

			accounts := RBTree.insert(accounts, Kay2.compareIdentity, increment.to, reputation);
			increment_buff.add({ increment with points = Buffer.toArray(point_buff) });

			var rank_accounts = switch (RBTree.get(ranks, Kay6.compareScore, score)) {
				case (?found) found;
				case _ RBTree.empty();
			};
			rank_accounts := RBTree.delete(rank_accounts, Kay2.compareIdentity, increment.to);
			ranks := if (RBTree.size(rank_accounts) > 0) {
				RBTree.insert(ranks, Kay6.compareScore, score, rank_accounts);
			} else RBTree.delete(ranks, Kay6.compareScore, score);

			score := Kay6.score(reputation);
			rank_accounts := switch (RBTree.get(ranks, Kay6.compareScore, score)) {
				case (?found) found;
				case _ RBTree.empty();
			};
			rank_accounts := RBTree.insert(rank_accounts, Kay2.compareIdentity, increment.to, ());
			ranks := RBTree.insert(ranks, Kay6.compareScore, score, rank_accounts);
		};
		let commit = {
			from;
			timestamp = Time64.nanos();
			increments = Buffer.toArray(increment_buff);
		};
		commits := RBTree.insert(commits, Nat.compare, commit_id, commit);
		#Ok;
	};
};
