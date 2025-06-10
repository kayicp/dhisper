echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"eonfl-fmim6-efxhz-qoahn-zs6ut-azxwa-2abpr-m6r54-bhpus-refim-xae\";
		subaccount = null;
	};
	amount =  1_000_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"