echo "$(dfx identity use default)"
dfx canister call icp_token icrc1_transfer "record {
	to = record {
		owner = principal \"gppvg-bhnva-byqgy-ccrv5-a4clj-gvlxk-k3354-gdr2v-trdtm-zmyrk-bqe\";
		subaccount = null;
	};
	amount =  10_000_000;
	memo = null;
	fee = null;
	created_at_time = null;
	from_subaccount = null;
}"