import Value "../Value";
import Kay2 "../Kay2_Authorization";
import RBTree "../StableCollections/RedBlackTree/RBTree";
import Error "../Error";

module {
	public type CreateReportArg = {
		subaccount : ?Blob;
		subject : Value.Type; // for many types of key, eg: { post: { id: 5; version: 2 } }
		comment : Text;
	};
	type TooLargeErr = { current_size : Nat; maximum_size : Nat };
	public type CreateReportError = {
		#GenericError : Error.Type;
		#DuplicateSubject : { id : Nat };
		#UnknownSubject;
		#CommentTooLarge : TooLargeErr;
	};
	public type ModerateArg = {
		subaccount : ?Blob;
		report_id : Nat;
		report_agreement : Bool;
		comment : Text;
	};
	public type ModerateError = {
		#GenericError : Error.Type;
		#UnknownReport;
		#CommentTooLarge : TooLargeErr;
	};
	public type AppealArg = {
		subaccount : ?Blob;
		report_id : Nat;
		comment : Text;
	};
	public type AppearError = ModerateError;
	public type Moderation = {
		moderator : Kay2.Identity;
		report_agreement : Bool;
		comment : Text;
	};
	public type Appeal = {
		author : Kay2.Identity;
		comment : Text;
	};
	public type Status = {
		#Moderated : Moderation;
		#Appealed : Appeal;
	};
	public type Report = {
		author : Kay2.Identity;
		subject : Value.Type;
		comment : Text;
		timestamp : Nat64;
		statuses : RBTree.RBTree<Nat64, Status>;
	};
};
