clear
# mops test

dfx stop
rm -rf .dfx
dfx start --clean --background

echo "$(dfx identity use default)"
export DEFAULT_ACCOUNT_ID=$(dfx ledger account-id)
echo "DEFAULT_ACCOUNT_ID: " $DEFAULT_ACCOUNT_ID
export DEFAULT_PRINCIPAL=$(dfx identity get-principal)

export TOKEN_ID="ryjl3-tyaaa-aaaaa-aaaba-cai"
export INTERNET_ID="rdmx6-jaaaa-aaaaa-aaadq-cai"

dfx deploy icp_token --no-wallet --specified-id $TOKEN_ID --argument "(
	variant { 
		Init = record {
			token_symbol = \"ICP\"; 
			token_name = \"Internet Computer\";
			minting_account = record {
				owner = principal \"$DEFAULT_PRINCIPAL\";
				subaccount = null;
			};
			transfer_fee = 10_000;
			metadata = vec {};
			feature_flags = opt record { icrc2 = true };
			initial_balances = vec {};
			archive_options = record {
				num_blocks_to_archive = 1000;
				trigger_threshold = 2000;
				controller_id = principal \"$DEFAULT_PRINCIPAL\";
				cycles_for_archive_creation = opt 10000000000000;
			};
		}
	}
)"

dfx deploy internet_identity --no-wallet --specified-id $INTERNET_ID

dfx deploy dhisper_backend --no-wallet --argument "(
  variant {
    Init = record {
      kay1 = record {
        available = null;
        custodians = vec {};
        max_logs_size = opt (100 : nat);
      };
      kay2 = record {
        default_take_value = opt (100 : nat);
        max_take_value = opt (200 : nat);
      };
      kay4 = record {
        fee_collectors = vec {
          principal \"$DEFAULT_PRINCIPAL\";
        };
        delete_fee_rates = vec {};
        default_take_value = opt (100 : nat);
        max_threads_size = opt (300 : nat);
        max_replies_size = opt (300 : nat);
        create_fee_rates = vec {
          record {
            assets = vec {
              record {
                canister_id = principal \"$TOKEN_ID\";
                minimum_amount = opt (100_000 : nat);
                additional = opt record {
                  byte_denominator = 1 : nat;
                  amount_numerator = 1 : nat;
                };
              };
            };
            standard = \"ICRC-2\";
          };
        };
        max_take_value = opt (200 : nat);
        max_query_batch_size = opt (100 : nat);
        max_content_size = opt (256 : nat);
      };
    }
  },
)"

dfx deploy dhisper_frontend --no-wallet