echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"u2sio-c4ppe-gfhp6-crguy-ywdxd-pocqe-v27n5-siixd-xqum2-5rfe6-kqe\";
		subaccount = null;
	};
	amount =  200_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"