echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"o222n-qbhzl-6u2sf-cn3j6-kzmfa-nwwbi-pvuey-jn4u2-4gzcv-c4knx-kae\";
		subaccount = null;
	};
	amount =  10_000_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"