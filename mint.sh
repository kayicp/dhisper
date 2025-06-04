echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"5qkli-nzn7o-gh7dc-xiwhd-znv2v-csvn7-kqdul-7sweb-of6ft-gxttl-yae\";
		subaccount = null;
	};
	amount =  100_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"