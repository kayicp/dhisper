echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"wfufo-lrmgz-cpmoq-y7z7o-suhlx-cuwj4-5nszf-hrcx4-xiuku-rryn6-aae\";
		subaccount = null;
	};
	amount =  10_000_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"