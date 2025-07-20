echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"t54cf-wox6i-y66xf-cj7x4-4z4hg-rcblp-ldtvi-3gzab-wqsny-n6jyf-kae\";
		subaccount = null;
	};
	amount = 1_000_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"