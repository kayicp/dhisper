echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"6fj6t-pkyen-emgix-f5ff5-ej35g-uakq4-nfbah-nnzwt-sj5kt-7siqx-wqe\";
		subaccount = null;
	};
	amount = 10_000_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"