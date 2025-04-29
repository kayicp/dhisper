import Error "../Error";
import Account "Account";
import Result "../Result";
import Principal "mo:base/Principal";
import Value "../Value";
module {
	public type TransferError = {
		#GenericError : Error.Type;
		#TemporarilyUnavailable;
		#BadBurn : { min_burn_amount : Nat };
		#Duplicate : { duplicate_of : Nat };
		#BadFee : { expected_fee : Nat };
		#CreatedInFuture : { ledger_time : Nat64 };
		#TooOld;
		#InsufficientFunds : { balance : Nat };
	};

	public type TransferArg = {
		to : Account.Pair;
		fee : ?Nat;
		memo : ?Blob;
		from_subaccount : ?Blob;
		created_at_time : ?Nat64;
		amount : Nat;
	};

	public type TransferFromArgs = {
		to : Account.Pair;
		fee : ?Nat;
		spender_subaccount : ?Blob;
		from : Account.Pair;
		memo : ?Blob;
		created_at_time : ?Nat64;
		amount : Nat;
	};

	public type TransferFromError = {
		#GenericError : Error.Type;
		#TemporarilyUnavailable;
		#InsufficientAllowance : { allowance : Nat };
		#BadBurn : { min_burn_amount : Nat };
		#Duplicate : { duplicate_of : Nat };
		#BadFee : { expected_fee : Nat };
		#CreatedInFuture : { ledger_time : Nat64 };
		#TooOld;
		#InsufficientFunds : { balance : Nat };
	};

	public type ApproveArgs = {
		fee : ?Nat;
		memo : ?Blob;
		from_subaccount : ?Blob;
		created_at_time : ?Nat64;
		amount : Nat;
		expected_allowance : ?Nat;
		expires_at : ?Nat64;
		spender : Account.Pair;
	};

	public type ApproveError = {
		#GenericError : Error.Type;
		#TemporarilyUnavailable;
		#Duplicate : { duplicate_of : Nat };
		#BadFee : { expected_fee : Nat };
		#AllowanceChanged : { current_allowance : Nat };
		#CreatedInFuture : { ledger_time : Nat64 };
		#TooOld;
		#Expired : { ledger_time : Nat64 };
		#InsufficientFunds : { balance : Nat };
	};

	public type AllowanceArgs = { account : Account.Pair; spender : Account.Pair };
	public type Allowance = { allowance : Nat; expires_at : ?Nat64 };
	public type GetBlocksRequest = { start : Nat; length : Nat };
	public type GetBlocksResult = {
		log_length : Nat;
		blocks : [BlockWithId];
		archived_blocks : [ArchivedBlocks];
	};
	public type BlockWithId = { id : Nat; block : Value.Type };
	public type ArchivedBlocks = {
		args : [GetBlocksRequest];
		callback : shared query [GetBlocksRequest] -> async GetBlocksResult;
	};

	public type Actor = actor {
		icrc1_fee : shared query () -> async Nat;
		icrc1_balance_of : shared query Account.Pair -> async Nat;
		icrc1_transfer : shared TransferArg -> async Result.Type<Nat, TransferError>;
		icrc2_allowance : shared query AllowanceArgs -> async Allowance;
		icrc2_approve : shared ApproveArgs -> async Result.Type<Nat, ApproveError>;
		icrc2_transfer_from : shared TransferFromArgs -> async Result.Type<Nat, TransferFromError>;
		icrc3_get_blocks : shared query [GetBlocksRequest] -> async GetBlocksResult;
	};

	public func genActor(p : Principal) : Actor = actor (Principal.toText(p));
};
