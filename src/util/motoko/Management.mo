import Principal "mo:base/Principal";
module {
	public let id = "aaaaa-aa";
	public func principal() : Principal = Principal.fromText(id);
	public func canister() : Self = actor (id) : Self;

	public type CanisterId = { canister_id : Principal };
	public type CanisterSettings = {
		freezing_threshold : ?Nat;
		controllers : ?[Principal];
		memory_allocation : ?Nat;
		compute_allocation : ?Nat;
	};
	public type DefiniteCanisterSettings = {
		freezing_threshold : Nat;
		controllers : [Principal];
		memory_allocation : Nat;
		compute_allocation : Nat;
	};

	public type StatusResult = {
		status : { #stopped; #stopping; #running };
		memory_size : Nat;
		cycles : Nat;
		settings : DefiniteCanisterSettings;
		module_hash : ?[Nat8];
	};

	public type Self = actor {
		canister_status : shared CanisterId -> async StatusResult;
		create_canister : shared { settings : ?CanisterSettings } -> async CanisterId;
		delete_canister : shared CanisterId -> async ();
		deposit_cycles : shared CanisterId -> async ();
		install_code : shared {
			arg : [Nat8];
			wasm_module : [Nat8];
			mode : { #reinstall; #upgrade; #install };
			canister_id : Principal;
		} -> async ();
		provisional_create_canister_with_cycles : shared {
			settings : ?CanisterSettings;
			amount : ?Nat;
		} -> async CanisterId;
		provisional_top_up_canister : shared {
			canister_id : Principal;
			amount : Nat;
		} -> async ();
		raw_rand : shared () -> async [Nat8];
		start_canister : shared CanisterId -> async ();
		stop_canister : shared CanisterId -> async ();
		uninstall_code : shared CanisterId -> async ();
		update_settings : shared {
			canister_id : Principal;
			settings : CanisterSettings;
		} -> async ();
	};
};
