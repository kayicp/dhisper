import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import Kay5 "../util/motoko/Kay5_Moderation";
import Value "../util/motoko/Value";
import Kay1 "../util/motoko/Kay1_Canister";
import Queue "../util/motoko/StableCollections/Queue";

import Result "../util/motoko/Result";
import Error "../util/motoko/Error";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Kay2 "../util/motoko/Kay2_Authorization";
import Dhisper_Main "../dhisper_backend/main";
import Reputation_Main "../reputation_canister/main";
import ICRC_1_Types "../util/motoko/ICRC-1/Types";
import Time64 "../util/motoko/Time64";

// todo: trim
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

	stable var report_id = 0;
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
	public shared query func kay5_statuses_of(rpt_id : Nat) : async [Kay5.Status] {
		[];
	};
	public shared query func kay5_subjects(prev : ?Value.Type, take : ?Nat) : async [Value.Type] {
		[];
	};
	public shared query func kay5_report_ids_of(subjects : [Value.Type]) : async [Nat] {
		[];
	};

	private func canReport(master_can : Dhisper_Main.Canister, post : Nat, version : Nat, reporter : Kay2.Identity) : async* Result.Type<(), Error.Generic> {
		var owners = await master_can.kay4_owners_at(post, version, null, null);
		if (owners.size() == 0) return Error.text("Post does not exist");
		while (owners.size() > 0) {
			for (owner in owners.vals()) if (Kay2.equalIdentity(owner, reporter)) return Error.text("Caller cannot report their own post");
			owners := await master_can.kay4_owners_at(post, version, ?owners[owners.size() - 1], null);
		};
		#Ok;
	};

	private func getFee({
		canister_id : Principal;
		fee : ?Nat;
		comment_len : Nat;
		max_comment_len : Nat;
	}) : async* Result.Type<(ICRC_1_Types.Actor, Nat), { #Unauthorized : Kay2.Unauthorized; #GenericError : Error.Type }> {
		let commitment_standards = Value.getMap(metadata, Kay5.COMMITMENT_FEES, RBTree.empty());
		let ICRC_2_KEY = "ICRC-2";
		let icrc2_commitment_fee_rates = Value.getPrincipalMap(commitment_standards, ICRC_2_KEY, RBTree.empty());
		let fee_tree = switch (RBTree.get(icrc2_commitment_fee_rates, Principal.compare, canister_id)) {
			case (?#Map found) RBTree.fromArray(found, Text.compare);
			case _ return #Err(#Unauthorized(#ICRC_2(#BadCanister { expected_canister_ids = RBTree.arrayKey(icrc2_commitment_fee_rates) })));
		};
		let token = ICRC_1_Types.genActor(canister_id);
		let token_fee = await token.icrc1_fee();
		let minimum_amount = switch (Value.metaNat(fee_tree, Kay5.MIN_AMOUNT)) {
			case (?found) if (found > token_fee) found else return Error.text("Metadata `" # Kay5.COMMITMENT_FEES # "." # ICRC_2_KEY # "." # Kay5.MIN_AMOUNT # "` must be more than the token fee (" # Nat.toText(token_fee) # ") (current: " # Nat.toText(found) # ")");
			case _ return Error.text("Metadata `" # Kay5.COMMITMENT_FEES # "." # ICRC_2_KEY # "." # Kay5.MIN_AMOUNT # "` is missing");
		};
		let additional_amount = if (max_comment_len > 0 and comment_len > max_comment_len) switch (Value.metaNat(fee_tree, Kay5.ADDITIONAL_AMOUNT), Value.metaNat(fee_tree, Kay5.ADDITIONAL_BYTE)) {
			case (?amount_numer, ?byte_denom) if (amount_numer > 0 and byte_denom > 0) (comment_len - max_comment_len) * amount_numer / byte_denom else 0;
			case _ 0;
		} else 0;
		let expected_fee = minimum_amount + additional_amount;
		switch fee {
			case (?defined_fee) if (defined_fee != expected_fee) return #Err(#Unauthorized(#ICRC_2(#BadFee { expected_fee })));
			case _ ();
		};
		#Ok(token, expected_fee);
	};

	private func getMaster() : Result.Type<(Principal, Dhisper_Main.Canister), Error.Generic> {
		let master = switch (Value.metaPrincipal(metadata, Kay5.MASTER)) {
			case (?found) found;
			case _ return Error.text("Metadata `" # Kay5.MASTER # "` is missing");
		};
		#Ok(master, actor (Principal.toText(master)));
	};

	private func isMod(reputation_can : Reputation_Main.Canister, reporter : Kay2.Identity) : async* Bool {
		let max_mods = Value.getNat(metadata, Kay5.MAX_MODERATORS_SIZE, 0);
		let mods = if (max_mods == 0)[] else await reputation_can.kay6_top(max_mods);
		label check_mod for (mod in mods.vals()) {
			if (Kay2.equalIdentity(mod, reporter)) return true;
		};
		false;
	};

	public shared ({ caller }) func kay5_report(arg : Kay5.ReportArg) : async Result.Type<Nat, Kay5.ReportError> {
		if (not Kay1.isAvailable(metadata)) return Error.text("Unavailable");
		switch (RBTree.get(subjects, Value.compare, #Map(arg.subject))) {
			case (?id) return #Err(#DuplicateSubject { report_id = id });
			case _ ();
		};
		let subject = RBTree.fromArray(arg.subject, Text.compare);
		let post = switch (Value.metaNat(subject, "post")) {
			case (?found) found;
			case _ return #Err(#BadSubjectKey { key = "post"; expected_type = "Nat" });
		};
		let version = switch (Value.metaNat(subject, "version")) {
			case (?found) found;
			case _ return #Err(#BadSubjectKey { key = "version"; expected_type = "Nat" });
		};
		let (master, master_can) = switch (getMaster()) {
			case (#Err err) return #Err err;
			case (#Ok ok) ok;
		};
		let reputation_can = switch (Value.metaPrincipal(metadata, Kay5.KAY_6_ID)) {
			case (?found) actor (Principal.toText(found)) : Reputation_Main.Canister;
			case _ return Error.text("Metadata `" # Kay5.KAY_6_ID # "` is missing");
		};

		// todo: cleantrim comment
		let max_comment_len = Value.getNat(metadata, Kay5.MAX_COMMENT_SIZE, 0);
		let comment_len = Text.size(arg.comment);
		// todo: check locker
		let (reporter, identity, is_moderator) = switch (arg.commitment) {
			case (#ICRC_2 auth) {
				let account = { auth with owner = caller };
				if (await* isMod(reputation_can, #ICRC_1 account)) return Error.text("You are a moderator; you should not pay commitment fee");
				switch (arg.verdict) {
					case (?found) return Error.text("You cannot give a verdict because you are not a moderator");
					case _ ();
				};
				switch (await* canReport(master_can, post, version, #ICRC_1 account)) {
					case (#Err err) return #Err err;
					case _ ();
				};
				let (token, expected_fee) = switch (await* getFee({ auth with comment_len; max_comment_len })) {
					case (#Ok ok) ok;
					case (#Err err) return #Err err;
				};
				let transfer_from_args = {
					amount = expected_fee;
					from = account;
					to = { owner = master; subaccount = null };
					fee = null;
					spender_subaccount = null;
					memo = null;
					created_at_time = null;
				};
				// todo: lock(?{ arg with caller });
				//  is_locker := true;
				let transfer_from_id = switch (await token.icrc2_transfer_from(transfer_from_args)) {
					case (#Err err) {
						// todo: lock(null);
						return #Err(#Unauthorized(#ICRC_2(#TransferFromFailed err)));
					};
					case (#Ok ok) ok;
				};
				(#ICRC_2 { auth with owner = caller; xfer = transfer_from_id }, #ICRC_1 account, false);
			};
			case (#None auth) {
				let account = { auth with owner = caller };
				let is_mod = await* isMod(reputation_can, #ICRC_1 account);
				if (not is_mod) return Error.text("You are not a moderator; you must pay the commitment fee");
				switch (await* canReport(master_can, post, version, #ICRC_1 account)) {
					case (#Err err) return #Err err;
					case _ ();
				};
				if (max_comment_len > 0 and comment_len > max_comment_len) return #Err(#CommentTooLarge { current_size = comment_len; maximum_size = max_comment_len });
				(#None account, #ICRC_1 account, true);
			};
			case _ return Error.text("ICRC-1 & ICRC-7 authorizations are not available");
		};
		var new_report = Kay5.createReport({
			arg with reporter;
			timestamp = Time64.nanos();
		});
		let new_report_id = report_id;
		if (is_moderator) switch (arg.verdict) {
			case (?found) {
				new_report := Kay5.moderate(new_report, { moderator = reporter; verdict = found; comment = ""; timestamp = new_report.timestamp });
				// if (found) {
				//   let appeal_window = Time64.SECONDS(Nat64.fromNat(Value.getNat(metadata, Kay5.APPEAL_WINDOW, 0)));
				//   ignore if (appeal_window > 0) {
				//     deletion_timers := RBTree.insert(deletion_timers, Nat.compare, new_report_id, ());
				//     Timer.setTimer<system>(#nanoseconds(Nat64.toNat(appeal_window)), deletePost);
				//   } else master_can.kay4_delete({
				//     authorization = #None { subaccount = null };
				//     id = post;
				//   });
				// };
			};
			case _ ();
		};
		reports := RBTree.insert(reports, Nat.compare, new_report_id, new_report);
		subjects := RBTree.insert(subjects, Value.compare, #Map(new_report.subject), new_report_id);
		report_id += 1;
		#Ok new_report_id;
	};

	public shared ({ caller }) func kay5_moderate(arg : Kay5.ModerateArg) : async Result.Type<(), Kay5.ModerateError> {
		if (not Kay1.isAvailable(metadata)) return Error.text("Unavailable");
		let report = switch (RBTree.get(reports, Nat.compare, arg.report_id)) {
			case (?found) found;
			case _ return #Err(#UnknownReport);
		};
		// todo: cleantrim comment
		let max_comment_len = Value.getNat(metadata, Kay5.MAX_COMMENT_SIZE, 0);
		let comment_len = Text.size(arg.comment);
		if (max_comment_len > 0 and comment_len > max_comment_len) return #Err(#CommentTooLarge { current_size = comment_len; maximum_size = max_comment_len });

		let reputation_can = switch (Value.metaPrincipal(metadata, Kay5.KAY_6_ID)) {
			case (?found) actor (Principal.toText(found)) : Reputation_Main.Canister;
			case _ return Error.text("Metadata `" # Kay5.KAY_6_ID # "` is missing");
		};
		// todo: check locker
		let (moderator, identity) = switch (arg.authorization) {
			case (#None auth) {
				let account = { auth with owner = caller };
				// todo: make sure mod is not reporter nor appealer
				let is_mod = await* isMod(reputation_can, #ICRC_1 account);
				if (not is_mod) return Error.text("You are not a moderator");
				switch (RBTree.max(report.statuses)) {
					case (?(ts, #Resolved status)) return #Err(#Resolved { status with timestamp = ts });
					case (?(ts, #Moderated status)) return #Err(#Moderated { status with timestamp = ts });
					case _ ();
				};
				(#None account, #ICRC_1 account);
			};
			case _ return Error.text("ICRC-1, ICRC-2, ICRC-7 authorizations are not available");
		};
		// todo: put cleantrimmed comment
		let moderated = Kay5.moderate(report, { arg with moderator; timestamp = Time64.nanos() });
		reports := RBTree.insert(reports, Nat.compare, arg.report_id, moderated);
		#Ok;
	};

	private func canAppeal({
		master_can : Dhisper_Main.Canister;
		post : Nat;
		version : Nat;
		appealer : Kay2.Identity;
		now : Nat64;
		report : Kay5.Report;
	}) : async* Result.Type<(), Kay5.AppealError> {
		let appeal_window = Time64.SECONDS(Nat64.fromNat(Value.getNat(metadata, Kay5.APPEAL_WINDOW, 0)));
		switch (RBTree.max(report.statuses)) {
			case (?(ts, #Moderated _)) if (now < ts + appeal_window) return #Err(#AppealWindowClosed { moderated_at = ts; appeal_window });
			case (?(ts, #Appealed status)) return #Err(#Appealed { status with timestamp = ts });
			case (?(ts, #Resolved status)) return #Err(#Resolved { status with timestamp = ts });
			case (null) return Error.text("Report has no verdict yet");
		};
		// todo: change this based on moderator's verdict
		// - if verdict true (agree w report), poster can appeal
		// - if verdict false (agree w post), reporter can appeal
		// todo: count how many appeals hv been made
		var owners = await master_can.kay4_owners_at(post, version, null, null);
		if (owners.size() == 0) return Error.text("Post does not exist");
		while (owners.size() > 0) {
			for (owner in owners.vals()) if (Kay2.equalIdentity(owner, appealer)) return #Ok;
			owners := await master_can.kay4_owners_at(post, version, ?owners[owners.size() - 1], null);
		};
		Error.text("You are not the owner of this post");
	};
	public shared ({ caller }) func kay5_appeal(arg : Kay5.AppealArg) : async Result.Type<(), Kay5.AppealError> {
		if (not Kay1.isAvailable(metadata)) return Error.text("Unavailable");
		let report = switch (RBTree.get(reports, Nat.compare, arg.report_id)) {
			case (?found) found;
			case _ return #Err(#UnknownReport);
		};
		// todo: cleantrim comment
		let max_comment_len = Value.getNat(metadata, Kay5.MAX_COMMENT_SIZE, 0);
		let comment_len = Text.size(arg.comment);

		let (master, master_can) = switch (getMaster()) {
			case (#Err err) return #Err err;
			case (#Ok ok) ok;
		};
		let subject = RBTree.fromArray(report.subject, Text.compare);
		let post = switch (Value.metaNat(subject, "post")) {
			case (?found) found;
			case _ return Error.text("`post` is missing from report's subject");
		};
		let version = switch (Value.metaNat(subject, "version")) {
			case (?found) found;
			case _ return Error.text("`version` is missing from report's subject");
		};
		let now = Time64.nanos();
		let appealer = switch (arg.authorization) {
			case (#ICRC_2 auth) {
				let account = { auth with owner = caller };
				switch (await* canAppeal({ master_can; post; version; appealer = #ICRC_1 account; now; report })) {
					case (#Err err) return #Err err;
					case _ ();
				};
				let (token, expected_fee) = switch (await* getFee({ auth with comment_len; max_comment_len })) {
					case (#Ok ok) ok;
					case (#Err err) return #Err err;
				};
				let transfer_from_args = {
					amount = expected_fee;
					from = account;
					to = { owner = master; subaccount = null };
					fee = null;
					spender_subaccount = null;
					memo = null;
					created_at_time = null;
				};
				// todo: lock(?{ arg with caller });
				//  is_locker := true;
				let transfer_from_id = switch (await token.icrc2_transfer_from(transfer_from_args)) {
					case (#Err err) {
						// todo: lock(null);
						return #Err(#Unauthorized(#ICRC_2(#TransferFromFailed err)));
					};
					case (#Ok ok) ok;
				};
				#ICRC_2 { auth with owner = caller; xfer = transfer_from_id };
			};
			case (#None auth) {
				let account = { auth with owner = caller };
				switch (await* canAppeal({ master_can; post; version; appealer = #ICRC_1 account; now; report })) {
					case (#Err err) return #Err err;
					case _ ();
				};
				if (max_comment_len > 0 and comment_len > max_comment_len) return #Err(#CommentTooLarge { current_size = comment_len; maximum_size = max_comment_len });
				#None account;
			};
			case _ return Error.text("ICRC-1 & ICRC-7 authorizations are not available");
		};
		// todo: put cleantrimmed comment
		let appealed = Kay5.appeal(report, { arg with appealer; timestamp = Time64.nanos() });
		reports := RBTree.insert(reports, Nat.compare, arg.report_id, appealed);
		#Ok;
	};
	public shared ({ caller }) func kay5_resolve(arg : Kay5.ResolveArg) : async Result.Type<(), Kay5.ResolveError> {
		if (not Kay1.isAvailable(metadata)) return Error.text("Unavailable");
		let report = switch (RBTree.get(reports, Nat.compare, arg.report_id)) {
			case (?found) found;
			case _ return #Err(#UnknownReport);
		};
		let (master, _) = switch (getMaster()) {
			case (#Err err) return #Err err;
			case (#Ok ok) ok;
		};
		if (caller != master) return Error.text("Only master canister can resolve the report");

		let resolver = switch (arg.authorization) {
			case (#None auth) #None { auth with owner = caller };
			case _ return Error.text("ICRC-1, ICRC-2 & ICRC-7 authorizations are not available");
		};
		let resolved = Kay5.resolve(report, { arg with resolver; timestamp = Time64.nanos() });
		reports := RBTree.insert(reports, Nat.compare, arg.report_id, resolved);
		#Ok;
	};

	// stable var deletion_timers = RBTree.empty<Nat, ()>();

	// private func untime(rpt_id : Nat) = deletion_timers := RBTree.delete(deletion_timers, Nat.compare, rpt_id);

	// private func deletePost() : async () {
	//   let now = Time64.nanos();
	//   let appeal_window = Time64.SECONDS(Nat64.fromNat(Value.getNat(metadata, Kay5.APPEAL_WINDOW, 0)));
	//   label looping for ((timed_report_id, _) in RBTree.entries(deletion_timers)) {
	//     let report = switch (RBTree.get(reports, Nat.compare, timed_report_id)) {
	//       case (?found) found;
	//       case _ {
	//         untime(timed_report_id);
	//         continue looping;
	//       };
	//     };
	//     let (status_time, status) = switch (RBTree.max(report.statuses)) {
	//       case (?found) found;
	//       case _ {
	//         untime(timed_report_id);
	//         continue looping;
	//       };
	//     };
	//     let moderation = switch status {
	//       case (#Moderated m) m;
	//       case _ {
	//         untime(timed_report_id);
	//         continue looping;
	//       };
	//     };
	//     if (moderation.verdict) {
	//       let deleted_at = status_time + appeal_window;
	//       if (deleted_at < now) {

	//       } else
	//     } else untime(timed_report_id);
	//   };
	// };

};
