import Value "../Value";
import Kay2 "../Kay2_Authorization";
import RBTree "../StableCollections/RedBlackTree/RBTree";
import Error "../Error";
import Nat64 "mo:base/Nat64";

module {
	public let MASTER = "kay5:master_canister_id";
	public let MAX_COMMENT_LENGTH = "kay5:max_comment_length";
	public let COMMITMENT_FEES = "kay5:report_commitment_fees";
	public let MIN_AMOUNT = "minimum_amount";
	public let ADDITIONAL_AMOUNT = "additional_amount_numerator";
	public let ADDITIONAL_BYTE = "additional_byte_denominator";
	public let KAY_6_ID = "kay5:kay6_reputation_canister_id";
	public let MAX_MODERATORS_SIZE = "kay5:max_moderators_size";
	public let APPEAL_WINDOW = "kay5:appeal_window_after_moderation";
	public let MAX_APPEALS_PER_REPORT = "kay5:max_appeals_per_report";
	public type CreateReportArg = {
		subject : [(Text, Value.Type)]; // for many types of key, eg: { post: { id: 5; version: 2 } }
		commitment : Kay2.Authorization;
		comment : Text;
		verdict : ?Bool;
	};
	type TooLargeErr = { current_size : Nat; maximum_size : Nat };
	public type CreateReportError = {
		#GenericError : Error.Type;
		#DuplicateSubject : { report_id : Nat };
		#BadSubjectKey : { key : Text; expected_type : Text };
		#UnknownSubject;
		#CommentTooLarge : TooLargeErr;
		#Unauthorized : Kay2.Unauthorized;
	};
	public type ModerateArg = {
		authorization : Kay2.Authorization;
		report_id : Nat;
		verdict : Bool;
		comment : Text;
	};
	public type ModerateError = {
		#GenericError : Error.Type;
		#UnknownReport;
		#CommentTooLarge : TooLargeErr;
		#Unauthorized : Kay2.Unauthorized;
	};
	public type AppealArg = {
		authorization : Kay2.Authorization;
		report_id : Nat;
		comment : Text;
	};
	public type AppearError = ModerateError;
	public type Moderation = {
		moderator : Kay2.Authorized;
		verdict : Bool;
		comment : Text;
		phash : Blob;
	};
	public type Appeal = {
		author : Kay2.Authorized;
		comment : Text;
		phash : Blob;
	};
	public type Status = {
		#Moderated : Moderation;
		#Appealed : Appeal;
	};
	public type Report = {
		author : Kay2.Authorized;
		subject : [(Text, Value.Type)];
		comment : Text;
		timestamp : Nat64;
		statuses : RBTree.RBTree<Nat64, Status>;
		hash : Blob;
	};
	public func createReport(
		arg : {
			author : Kay2.Authorized;
			subject : [(Text, Value.Type)];
			comment : Text;
			timestamp : Nat64;
		}
	) : Report {
		let report : Report = {
			arg with statuses = RBTree.empty();
			hash = "" : Blob;
		};
		report; // todo: hash
	};
	public func moderate(
		report : Report,
		{
			moderator : Kay2.Authorized;
			verdict : Bool;
			comment : Text;
			timestamp : Nat64;
		},
	) : Report {
		let statuses = RBTree.insert(report.statuses, Nat64.compare, timestamp, #Moderated { moderator; verdict; comment; phash = report.hash });
		// todo: hash
		{ report with statuses };
	};
};
