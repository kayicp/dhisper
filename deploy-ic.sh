# echo "$(dfx identity use grant)"
# export GRANT_PRINCIPAL=$(dfx identity get-principal)
# export TOKEN_ID="ryjl3-tyaaa-aaaaa-aaaba-cai"

# dfx deploy dhisper_backend --network ic --no-wallet --argument "(
#   variant {
#     Init = record {
#       kay1 = record {
#         available = null;
#         custodians = vec {};
#         max_logs_size = opt (100 : nat);
#       };
#       kay2 = record {
#         default_take_value = opt (1000 : nat);
#         max_take_value = opt (2000 : nat);
#       };
#       kay4 = record {
#         fee_collectors = vec {
#           principal \"$GRANT_PRINCIPAL\";
#         };
#         delete_fee_rates = vec {
#           record {
#             assets = vec {
#               record {
#                 canister_id = principal \"$TOKEN_ID\";
#                 minimum_amount = opt (100_000 : nat);
#               };
#             };
#             standard = \"ICRC-2\";
#           };
#         };
#         default_take_value = opt (100 : nat);
#         max_threads_size = null;
#         max_replies_size = null;
#         create_fee_rates = vec {
#           record {
#             assets = vec {
#               record {
#                 canister_id = principal \"$TOKEN_ID\";
#                 minimum_amount = opt (100_000 : nat);
#                 additional = opt record {
#                   byte_denominator = 1 : nat;
#                   amount_numerator = 1 : nat;
#                 };
#               };
#             };
#             standard = \"ICRC-2\";
#           };
#         };
#         max_take_value = opt (200 : nat);
#         max_query_batch_size = opt (100 : nat);
#         max_content_size = opt (256 : nat);
#       };
#     }
#   },
# )"

# dfx deploy dhisper_frontend --network ic --no-wallet