import Value "../Value";
import Kay2 "../Kay2_Authorization";
import RBTree "../StableCollections/RedBlackTree/RBTree";

module {
	public type CreateReportArg = {
		subaccount : ?Blob;
		subject : Value.Type; // for many types of key, eg: { post: { id: 5; version: 2 } }
		reason : Text;
	};
	public type ModerateArg = {
		subaccount : ?Blob;
		report_id : Nat;
		report_agreement : Bool;
		comment : Text;
	};
	public type AppealArg = {
		subaccount : ?Blob;
		report_id : Nat;
		reason : Text;
	};
	public type Moderation = {
		moderator : Kay2.Identity;
		report_agreement : Bool;
		comment : Text;
	};
	public type Appeal = {
		author : Kay2.Identity;
		reason : Text;
	};
	public type Status = {
		#Moderated : Moderation;
		#Appealed : Appeal;
	};
	public type Report = {
		author : Kay2.Identity;
		subject : Value.Type;
		reason : Text;
		timestamp : Nat64;
		statuses : RBTree.RBTree<Nat64, Status>;
	};
};
