echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"ybimv-qoqro-ki6cx-sgtpq-3kiic-7ziyv-fjvrh-n7asd-fvymi-5hh5h-fae\";
		subaccount = null;
	};
	amount = 10_000_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"