echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"vqtgd-5s2oj-l3etw-fnyad-2hop3-5az4o-rka3m-idfzs-5i725-afemt-bae\";
		subaccount = null;
	};
	amount =  1_000_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"