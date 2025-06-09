echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"jjlsl-d7rm2-6oykh-qca54-l6hrt-lp5jj-sez5a-jhubr-24hri-v4zvo-tae\";
		subaccount = null;
	};
	amount =  1_000_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"