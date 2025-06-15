echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"s3zk6-vqwsb-7lo5n-v75hj-uppw6-cghdf-d3yt3-v6va5-t6dkc-r4xkw-dqe\";
		subaccount = null;
	};
	amount =  10_000_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"