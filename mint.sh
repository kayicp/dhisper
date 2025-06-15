echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"p6xro-ihyns-qoymq-xl3su-sbgiz-v54ho-nxbfg-4dqbe-mvk65-veylh-oqe\";
		subaccount = null;
	};
	amount =  10_000_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"