echo "$(dfx identity use default)"
dfx canister call dhisper_backend kay1_set_metadata "record {
	child_canister_id = null
	pairs = vec {
		record {
			key = \"kay4:moderators\";
			value = opt variant {
				Array = vec {
					variant {
						Principal = principal \"lhuc4-nqaaa-aaaan-qz3gq-cai\"
					}
				}
			}
		}
	}; 
}"