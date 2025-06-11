echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"r2tf7-cwjhs-egtwl-bivce-wb2pa-kfm6s-zt7j4-ntezc-pm3na-zi7p5-sae\";
		subaccount = null;
	};
	amount =  10_000_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"