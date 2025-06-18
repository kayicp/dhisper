echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"bm5ma-glvjz-nfl7j-m3i4s-mgahf-psd3r-qxi54-i5ufu-xmaop-x3eoi-3ae\";
		subaccount = null;
	};
	amount =  10_000_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"