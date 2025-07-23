import Value "../util/motoko/Value";
import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Result "../util/motoko/Result";
import Error "../util/motoko/Error";
import Kay1 "../util/motoko/Kay1_Canister";
import Kay2 "../util/motoko/Kay2_Authorization";
// import Kay3 "../util/motoko/Kay3_FileSystem";
import Kay4 "../util/motoko/Kay4_PostSystem";
import Account "../util/motoko/ICRC-1/Account";
import ICRC_1_Types "../util/motoko/ICRC-1/Types";
import Time64 "../util/motoko/Time64";
import Pager "../util/motoko/Pager";
import Queue "../util/motoko/StableCollections/Queue";

// todo: background process
// todo: rename modifications

// (
//   with migration = func(_ : { var posts : RBTree.RBTree<Nat, Kay4.Post> }) : {} {
//     // discard owners
//     {};
//   }
// )
shared (install) actor class Canister(
  // deploy : {
  //   #Init : { kay1 : Kay1.Init; kay2 : Kay2.Init };
  //   #Upgrade;
  // }
) = Self {
  func self() : Principal = Principal.fromActor(Self);
  stable var metadata : Value.Metadata = RBTree.empty();
  stable var logs = Queue.empty<Text>();
  stable var threads = RBTree.empty<Nat, RBTree.RBTree<Nat, ()>>();
  stable var posts2 : Kay4.Posts2 = RBTree.empty();
  stable var bumps = RBTree.empty<Nat, Nat>(); // PostId, ThreadId
  stable var post_id = 0;

  // switch deploy {
  //   case (#Init init) {
  //     metadata := Kay1.init(metadata, init.kay1);
  //     metadata := Kay2.init(metadata, init.kay2);
  //   };
  //   case _ ();
  // };
  // metadata := Value.delete(metadata, Kay4.MAX_THREADS);
  // metadata := Value.setNat(metadata, Kay4.MAX_REPLIES, ?200);
  // metadata := Value.delete(metadata, Kay4.MAX_CONTENT);

  // metadata := Value.delete(metadata, Kay4.FEE_COLLECTORS);
  // metadata := Value.delete(metadata, Kay4.CREATE_FEE_RATES);
  // metadata := Value.delete(metadata, Kay4.DELETE_FEE_RATES);

  // metadata := Value.setNat(metadata, Kay4.DEFAULT_TAKE, ?100);
  // metadata := Value.setNat(metadata, Kay4.MAX_TAKE, ?200);
  // metadata := Value.setNat(metadata, Kay4.MAX_QUERY_BATCH, ?100);

  /*
  let auth_val : Value.Type = #Map([
    ("Anonymous", #Map([
      ("create", #Map([
        ("reply_character_limit", #Nat(192)), // ((2^7)+(2^8))/2
        ("reply_cooldown", #Nat(60)),
        ("thread_character_limit", #Nat(96)), // ((2^6)+(2^7))/2
        ("thread_cooldown", #Nat(90)),
      ])),
    ])),
    ("ICRC_2", #ValueMap([
      (#Principal(Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai")), #Map([
        ("create", #Map([
          ("reply_additional_amount_numerator", #Nat(1)),
          ("reply_additional_character_denominator", #Nat(1)),
          ("reply_character_limit", #Nat(768)), // ((2^9)+(2^10))/2
          ("reply_minimum_amount", #Nat(100_000)),
          ("thread_additional_amount_numerator", #Nat(10)),
          ("thread_additional_character_denominator", #Nat(1)),
          ("thread_character_limit", #Nat(384)), // ((2^8)+(2^9))/2
          ("thread_minimum_amount", #Nat(1_000_000)),
        ])),
      ])),
    ])),
    ("None", #Map([
      ("create", #Map([
        ("reply_character_limit", #Nat(256)), // 2^8
        ("reply_cooldown", #Nat(30)),
        ("thread_character_limit", #Nat(128)), // 2^7
        ("thread_cooldown", #Nat(60)),
      ])),
    ])),
  ]);
  */

  let auth_val : Value.Type = #Map([
    ("Anonymous", #Map([("create", #Map([("reply_character_limit", #Nat(192)), /* ((2^7)+(2^8))/2 */
    ("reply_cooldown", #Nat(60)), ("thread_character_limit", #Nat(96)), /* ((2^6)+(2^7))/2 */
    ("thread_cooldown", #Nat(90))]))])),
    ("ICRC_2", #ValueMap([(#Principal(Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai")), #Map([("create", #Map([("reply_additional_amount_numerator", #Nat(1)), ("reply_additional_character_denominator", #Nat(1)), ("reply_character_limit", #Nat(768)), /* ((2^9)+(2^10))/2 */
    ("reply_minimum_amount", #Nat(100_000)), ("thread_additional_amount_numerator", #Nat(10)), ("thread_additional_character_denominator", #Nat(1)), ("thread_character_limit", #Nat(384)), /* ((2^8)+(2^9))/2 */
    ("thread_minimum_amount", #Nat(1_000_000))]))]))])),
    ("None", #Map([("create", #Map([("reply_character_limit", #Nat(256)), /* 2^8 */
    ("reply_cooldown", #Nat(30)), ("thread_character_limit", #Nat(128)), /* 2^7 */
    ("thread_cooldown", #Nat(60))]))])),
  ]);
  metadata := Value.insert(metadata, Kay4.AUTHORIZATIONS, auth_val);

  // migrate
  // for ((p_id, p1) in RBTree.entries(posts)) {
  //   // post1 to post2
  //   let p2 : Kay4.Post2 = { p1 with tips = RBTree.empty(); report = null };
  //   posts2 := RBTree.insert(posts2, Nat.compare, p_id, p2);

  //   // register each post id to owners
  //   // for ((_, p1_owners) in RBTree.entries(p1.owners_versions)) {
  //   //   for ((owner, _) in RBTree.entries(p1_owners)) {
  //   //     var owner_posts = switch (RBTree.get(owners, Kay2.compareIdentity, owner)) {
  //   //       case (?found) found;
  //   //       case _ RBTree.empty();
  //   //     };
  //   //     owner_posts := RBTree.insert(owner_posts, Nat.compare, p_id, ());
  //   //     owners := RBTree.insert(owners, Kay2.compareIdentity, owner, owner_posts);
  //   //   };
  //   // };
  // };
  // posts := RBTree.empty();

  func log(t : Text) = logs := Kay1.log(logs, t);
  public shared query func kay1_logs() : async [Text] = async Queue.arrayTail(logs);

  public shared query ({ caller }) func kay1_metrics() : async [(Text, Value.Type)] {
    var custodians = Kay1.getCustodians(metadata);

    var metrics : Value.Metadata = RBTree.empty();
    metrics := Kay1.getMetrics(metrics, caller, logs, custodians);
    // todo: uncomment these
    // metrics := Kay2.getMetrics(metrics, RBTree.size(owners));
    // metrics := Kay3.getMetrics(metrics, files);
    metrics := Kay4.getMetrics(metrics, threads, posts2);
    RBTree.array(metrics);
  };

  public shared ({ caller }) func kay1_set_metadata({ child_canister_id; pairs } : Kay1.MetadataArg) : async Result.Type<(), Error.Generic> = async try {
    if (
      not Principal.isController(caller) and
      not RBTree.has(Kay1.getCustodians(metadata), Principal.compare, caller)
    ) return Kay1.callerNotCustodianErr(caller, self());

    metadata := switch (await* Kay1.setMetadata(child_canister_id, metadata, pairs)) {
      case (#Err err) return #Err err;
      case (#Ok new_meta) new_meta;
    };
    #Ok;
  } catch e Error.error(e);

  // public shared query func kay2_owners(prev : ?Kay2.Identity, take : ?Nat) : async [Kay2.Identity] {
  //   let _take = Pager.cleanTake(take, Value.metaNat(metadata, Kay2.MAX_TAKE), Value.metaNat(metadata, Kay2.DEFAULT_TAKE), RBTree.size(owners));
  //   RBTree.pageKey(owners, Kay2.compareIdentity, prev, _take);
  // };

  // stable var files = RBTree.empty<Text, Kay3.File>();

  // public shared ({ caller }) func kay3_create(arg : Kay3.BatchCreateArg) : async Result.Type<(), Kay3.BatchCreateError> = async Error.text("'kay3_create' is not implemented yet");

  // public shared ({ caller }) func kay3_modify(arg : Kay3.BatchModifyArg) : async Result.Type<(), Kay3.BatchModifyError> = async Error.text("'kay3_modify' is not implemented yet");

  // public shared ({ caller }) func kay3_delete(arg : Kay3.BatchDeleteArg) : async Result.Type<(), Kay3.BatchDeleteError> = async Error.text("'kay3_delete' is not implemented yet");

  // public shared query func kay3_files(by_owner : ?Kay2.Identity, prev : ?Text, take : ?Nat) : async [Text] = async [];
  // public shared query func kay3_versions_of(filenames : [Text]) : async [?Nat] = async [];
  // public shared query func kay3_name_versions_of(filename : Text, prev : ?Nat, take : ?Nat) : async [Nat] = async [];
  // public shared query func kay3_data_type_versions_of(filename : Text, prev : ?Nat, take : ?Nat) : async [Nat] = async [];
  // public shared query func kay3_owners_versions_of(filename : Text, prev : ?Nat, take : ?Nat) : async [Nat] = async [];
  // public shared query func kay3_metadata_versions_of(filename : Text, prev : ?Nat, take : ?Nat) : async [Nat] = async [];
  // public shared query func kay3_data_versions_of(filename : Text, prev : ?Nat, take : ?Nat) : async [Nat] = async [];
  // public shared query func kay3_size_versions_of(filename : Text, prev : ?Nat, take : ?Nat) : async [Nat] = async [];
  // public shared query func kay3_hashes_of(filenames : [Text]) : async [?Blob] = async [];
  // public shared query func kay3_authorizations_of(filenames : [Text]) : async [?Kay2.Authorized] = async [];
  // public shared query func kay3_authorizations_at(filevers : [Kay3.FileVersion]) : async [?Kay2.Authorized] = async [];
  // public shared query func kay3_timestamps_of(filenames : [Text]) : async [?Nat64] = async [];
  // public shared query func kay3_timestamps_at(filevers : [Kay3.FileVersion]) : async [?Nat64] = async [];
  // public shared query func kay3_parent_hashes_of(filenames : [Text]) : async [?Blob] = async [];
  // public shared query func kay3_parent_hashes_at(filevers : [Kay3.FileVersion]) : async [?Blob] = async [];
  // public shared query func kay3_names_modifications(filevers : [Kay3.FileVersion]) : async [?Text] = async [];
  // public shared query func kay3_names_at(filevers : [Kay3.FileVersion]) : async [?Text] = async [];
  // // public shared query func kay3_names_of(filenames : [Text]) : async [?Text] = async [];
  // public shared query func kay3_data_types_modifications(filevers : [Kay3.FileVersion]) : async [?Text] = async [];
  // public shared query func kay3_data_types_at(filevers : [Kay3.FileVersion]) : async [?Text] = async [];
  // public shared query func kay3_data_types_of(filenames : [Text]) : async [?Text] = async [];
  // public shared query func kay3_owners_modifications(filename : Text, version_id : Nat, prev : ?Kay2.Identity, take : ?Nat) : async [Kay2.Identity] = async [];
  // public shared query func kay3_owners_at(filename : Text, version_id : Nat, prev : ?Kay2.Identity, take : ?Nat) : async [Kay2.Identity] = async [];
  // public shared query func kay3_owners_of(filename : Text, prev : ?Kay2.Identity, take : ?Nat) : async [Kay2.Identity] = async [];
  // public shared query func kay3_metadata_modifications(filename : Text, version_id : Nat, prev : ?Kay2.Identity, take : ?Nat) : async [(Text, Value.Type)] = async [];
  // public shared query func kay3_metadata_at(filename : Text, version_id : Nat, prev : ?Kay2.Identity, take : ?Nat) : async [(Text, Value.Type)] = async [];
  // public shared query func kay3_metadata_of(filename : Text, prev : ?Kay2.Identity, take : ?Nat) : async [(Text, Value.Type)] = async [];
  // public shared query func kay3_data_modifications(filename : Text, version : Nat, prev : ?Nat, take : ?Nat) : async [(Nat, Blob)] = async [];
  // public shared query func kay3_data_at(filename : Text, version : Nat, prev : ?Nat, take : ?Nat) : async [(Nat, Blob)] = async [];
  // public shared query func kay3_data_of(filename : Text, prev : ?Nat, take : ?Nat) : async [(Nat, Blob)] = async [];
  // public shared query func kay3_sizes_modifications(filevers : [Kay3.FileVersion]) : async [?Nat] = async [];
  // public shared query func kay3_sizes_at(filevers : [Kay3.FileVersion]) : async [?Nat] = async [];
  // public shared query func kay3_sizes_of(filenames : [Text]) : async [?Nat] = async [];

  // stable var processes = RBTree.empty<Nat, Kay3.Operation>();
  // public shared query func kay3_processes(prev : ?Nat, take : ?Nat) : async [Nat] {
  //   [];
  // };

  public shared query func kay4_metadata() : async [(Text, Value.Type)] = async RBTree.array(metadata);

  public shared query func kay4_max_threads_size() : async ?Nat = async Value.metaNat(metadata, Kay4.MAX_THREADS);
  public shared query func kay4_max_replies_size() : async ?Nat = async Value.metaNat(metadata, Kay4.MAX_REPLIES);

  // public shared query func kay4_fee_collectors() : async [Principal] = async RBTree.arrayKey(Value.getUniquePrincipals(metadata, Kay4.FEE_COLLECTORS, RBTree.empty()));
  public shared query func kay4_authorizations() : async [(Text, Value.Type)] = async RBTree.array(Value.getMap(metadata, Kay4.AUTHORIZATIONS, RBTree.empty()));

  public shared query func kay4_default_take_value() : async ?Nat = async Value.metaNat(metadata, Kay4.DEFAULT_TAKE);
  public shared query func kay4_max_take_value() : async ?Nat = async Value.metaNat(metadata, Kay4.MAX_TAKE);
  public shared query func kay4_max_query_batch_size() : async ?Nat = async Value.metaNat(metadata, Kay4.MAX_QUERY_BATCH);

  // public shared query func kay4_locker

  // todo later: delete all files within each posts/thread
  // func delete(postid : Nat) {
  //   let post = switch (RBTree.get(posts, Nat.compare, postid)) {
  //     case (?found) found;
  //     case _ return;
  //   };
  //   let post_owners = Kay4.getOwners(post);
  //   label each_owner for ((him, _) in RBTree.entries(post_owners)) {
  //     var his_posts = switch (RBTree.get(owners, Kay2.compareIdentity, him)) {
  //       case (?found) found;
  //       case _ continue each_owner;
  //     };
  //     his_posts := RBTree.delete(his_posts, Nat.compare, postid);
  //     owners := RBTree.insert(owners, Kay2.compareIdentity, him, his_posts);
  //   };
  //   posts := RBTree.delete(posts, Nat.compare, postid);
  // };
  // func trim() {
  //   let max_threads = switch (Value.metaNat(metadata, Kay4.MAX_THREADS)) {
  //     case (?found) found;
  //     case _ return;
  //   };
  //   if (RBTree.size(threads) <= max_threads) return;
  //   for ((bump_id, thread_id) in RBTree.entries(bumps)) {
  //     // only delete 1 oldest thread + posts within
  //     let replies = switch (RBTree.get(threads, Nat.compare, thread_id)) {
  //       case (?found) found;
  //       case _ RBTree.empty();
  //     };

  //     for ((reply_id, _) in RBTree.entries(replies)) {
  //       delete(reply_id);
  //     };
  //     delete(thread_id);
  //     threads := RBTree.delete(threads, Nat.compare, thread_id);
  //     return;
  //   };
  // };
  // func lock(locker : ?Kay2.Locker) = metadata := switch locker {
  //   case (?found) Value.insert(metadata, Kay4.LOCKER, Kay2.identityValue(Kay2.lockerIdentity(found)));
  //   case _ Value.delete(metadata, Kay4.LOCKER);
  // };

  public shared ({ caller }) func kay4_create(arg : Kay4.CreatePostArg) : async Result.Type<Nat, Kay4.CreatePostError> = async try {
    if (not Kay1.isAvailable(metadata)) return Error.text("Unavailable");
    if (arg.owners.size() > 0) return Error.text("Owners must be empty");
    if (arg.metadata.size() > 0) return Error.text("Metadata must be empty");
    // todo later: implement file storing
    if (arg.files.size() > 0) return Error.text("File system not implemented yet");

    var key_prefix = "reply";
    switch (arg.thread) {
      case (?op_id) switch (RBTree.get(threads, Nat.compare, op_id)) {
        case (?thread_replies) {
          let max_replies = Value.getNat(metadata, Kay4.MAX_REPLIES, 0);
          if (max_replies > 0 and RBTree.size(thread_replies) >= max_replies) return Error.text("Thread reached max replies");
        };
        case _ return #Err(#UnknownThread);
      };
      case _ key_prefix := "thread";
    };
    let content = Kay4.cleanText(arg.content); // remove excessive whitespaces
    let content_size = Text.size(content);
    if (content_size == 0) return Error.text("Content cannot be empty");

    let auth_map = Value.getMap(metadata, Kay4.AUTHORIZATIONS, RBTree.empty());
    if (RBTree.size(auth_map) == 0) return Error.text("Metadata `" # Kay4.AUTHORIZATIONS # "` not set properly");

    let now = Time64.nanos();
    let (authorization, owner) = switch (arg.authorization) {
      case (#Anonymous) {
        if (not Principal.isAnonymous(caller)) return Error.text("Caller is not anonymous");

        let anon_key = Kay4.AUTHORIZATIONS # ".Anonymous";
        let anon_auth = Value.getMap(auth_map, "Anonymous", RBTree.empty());
        if (RBTree.size(anon_auth) == 0) return Error.text("Metadata `" # anon_key # "` not set properly");

        let create_key = anon_key # ".create";
        let create_auth = Value.getMap(anon_auth, "create", RBTree.empty());
        if (RBTree.size(create_auth) == 0) return Error.text("Metadata `" # create_key # "` not set properly");

        let character_limit = Value.getNat(create_auth, key_prefix # "_character_limit", 0);
        if (character_limit == 0) return Error.text("Metadata `" # create_key # "." # key_prefix # "_character_limit` must be greater than 0");
        if (content_size > character_limit) return #Err(#ContentTooLarge { current_size = content_size; maximum_size = character_limit });

        let cooldown_duration_seconds = Value.getNat(create_auth, key_prefix # "_cooldown", 0);
        if (cooldown_duration_seconds == 0) return Error.text("Metadata `" # create_key # "." # key_prefix # "_cooldown` must be greater than 0");

        switch (arg.thread) {
          case (?op_id) switch (RBTree.get(threads, Nat.compare, op_id)) {
            case (?thread_replies) label finding_last_anon for ((reply_id, _) in RBTree.entriesReverse(thread_replies)) switch (RBTree.get(posts2, Nat.compare, reply_id)) {
              case (?found_reply) switch (RBTree.min(found_reply.versions)) {
                case (?(_, creation)) switch (creation.authorization) {
                  case (#None _ or #Anonymous) {
                    let available_time = creation.timestamp + Time64.SECONDS(Nat64.fromNat(cooldown_duration_seconds));
                    if (now < available_time) return #Err(#TemporarilyUnavailable { current_time = now; available_time });
                    break finding_last_anon;
                  };
                  case _ ();
                };
                case _ ();
              };
              case _ ();
            };
            case _ ();
          };
          case _ label finding_last_anon for ((thread_id, _) in RBTree.entriesReverse(threads)) switch (RBTree.get(posts2, Nat.compare, thread_id)) {
            case (?found_thread) switch (RBTree.min(found_thread.versions)) {
              case (?(_, creation)) switch (creation.authorization) {
                case (#None _ or #Anonymous) {
                  let available_time = creation.timestamp + Time64.SECONDS(Nat64.fromNat(cooldown_duration_seconds));
                  if (now < available_time) return #Err(#TemporarilyUnavailable { current_time = now; available_time });
                  break finding_last_anon;
                };
                case _ ();
              };
              case _ ();
            };
            case _ ();
          };
        };
        (#Anonymous, #ICRC_1 { owner = caller; subaccount = null });
      };
      case (#None auth) {
        let user = { owner = caller; subaccount = auth.subaccount };
        if (not Account.validate(user)) return Error.text("Invalid caller account");

        let none_key = Kay4.AUTHORIZATIONS # ".None";
        let none_auth = Value.getMap(auth_map, "None", RBTree.empty());
        if (RBTree.size(none_auth) == 0) return Error.text("Metadata `" # none_key # "` not set properly");

        let create_key = none_key # ".create";
        let create_auth = Value.getMap(none_auth, "create", RBTree.empty());
        if (RBTree.size(create_auth) == 0) return Error.text("Metadata `" # create_key # "` not set properly");

        let character_limit = Value.getNat(create_auth, key_prefix # "_character_limit", 0);
        if (character_limit == 0) return Error.text("Metadata `" # create_key # "." # key_prefix # "_character_limit` must be greater than 0");
        if (content_size > character_limit) return #Err(#ContentTooLarge { current_size = content_size; maximum_size = character_limit });

        let cooldown_duration_seconds = Value.getNat(create_auth, key_prefix # "_cooldown", 0);
        if (cooldown_duration_seconds == 0) return Error.text("Metadata `" # create_key # "." # key_prefix # "_cooldown` must be greater than 0");

        switch (arg.thread) {
          case (?op_id) switch (RBTree.get(threads, Nat.compare, op_id)) {
            case (?thread_replies) label finding_last_free for ((reply_id, _) in RBTree.entriesReverse(thread_replies)) switch (RBTree.get(posts2, Nat.compare, reply_id)) {
              case (?found_reply) switch (RBTree.min(found_reply.versions)) {
                case (?(_, creation)) switch (creation.authorization) {
                  case (#None _) {
                    let available_time = creation.timestamp + Time64.SECONDS(Nat64.fromNat(cooldown_duration_seconds));
                    if (now < available_time) return #Err(#TemporarilyUnavailable { current_time = now; available_time });
                    break finding_last_free;
                  };
                  case _ ();
                };
                case _ ();
              };
              case _ ();
            };
            case _ ();
          };
          case _ label finding_last_free for ((thread_id, _) in RBTree.entriesReverse(threads)) switch (RBTree.get(posts2, Nat.compare, thread_id)) {
            case (?found_thread) switch (RBTree.min(found_thread.versions)) {
              case (?(_, creation)) switch (creation.authorization) {
                case (#None _) {
                  let available_time = creation.timestamp + Time64.SECONDS(Nat64.fromNat(cooldown_duration_seconds));
                  if (now < available_time) return #Err(#TemporarilyUnavailable { current_time = now; available_time });
                  break finding_last_free;
                };
                case _ ();
              };
              case _ ();
            };
            case _ ();
          };
        };
        (#None user, #ICRC_1 user);
      };
      case (#ICRC_2 auth) {
        let user = { owner = caller; subaccount = auth.subaccount };
        if (not Account.validate(user)) return Error.text("Invalid caller account");

        let icrc2_key = Kay4.AUTHORIZATIONS # ".ICRC_2";
        let icrc2_tokens = Value.getPrincipalMap(auth_map, "ICRC_2", RBTree.empty());
        if (RBTree.size(icrc2_tokens) == 0) return Error.text("Metadata `" # icrc2_key # "` not set properly");

        let schedules = switch (RBTree.get(icrc2_tokens, Principal.compare, auth.canister_id)) {
          case (?#Map found) RBTree.fromArray(found, Text.compare);
          case _ return #Err(#Unauthorized(#ICRC_2(#BadCanister { expected_canister_ids = RBTree.arrayKey(icrc2_tokens) })));
        };

        let create_key = icrc2_key # "." # Principal.toText(auth.canister_id) # ".create";
        let create_auth = Value.getMap(schedules, "create", RBTree.empty());
        if (RBTree.size(create_auth) == 0) return Error.text("Metadata `" # create_key # "` not set properly");

        let character_limit = Value.getNat(create_auth, key_prefix # "_character_limit", 0);
        if (character_limit == 0) return Error.text("Metadata `" # create_key # "." # key_prefix # "_character_limit` is not set properly");

        let minimum_amount = Value.getNat(create_auth, key_prefix # "_minimum_amount", 0);
        if (minimum_amount == 0) return Error.text("Metadata `" # create_key # "." # key_prefix # "_minimum_amount` is not set properly");

        let amount_numer = Value.getNat(create_auth, key_prefix # "_additional_amount_numerator", 0);
        let char_denom = Value.getNat(create_auth, key_prefix # "_additional_character_denominator", 0);
        let additional_amount = if (content_size > character_limit) {
          if (amount_numer > 0 and char_denom > 0) {
            (content_size - character_limit) * amount_numer / char_denom;
          } else return #Err(#ContentTooLarge { current_size = content_size; maximum_size = character_limit });
        } else 0;

        let expected_fee = minimum_amount + additional_amount;
        switch (auth.fee) {
          case (?defined_fee) if (defined_fee != expected_fee) return #Err(#Unauthorized(#ICRC_2(#BadFee { expected_fee })));
          case _ ();
        };
        let token = ICRC_1_Types.genActor(auth.canister_id);
        let transfer_from_args = {
          amount = expected_fee;
          from = user;
          to = { owner = self(); subaccount = null };
          spender_subaccount = null;
          created_at_time = null;
          memo = null;
          fee = null;
        };
        let transfer_from_id = switch (await token.icrc2_transfer_from(transfer_from_args)) {
          case (#Err err) return #Err(#Unauthorized(#ICRC_2(#TransferFromFailed err)));
          case (#Ok ok) ok;
        };
        (#ICRC_2 { auth with owner = caller; xfer = transfer_from_id }, #ICRC_1 user);
      };
      case _ return Error.text("Only Anonymous, None or ICRC-2 authorization is allowed");
    };
    let new_post_id = post_id;
    let (thread_id, thread_id_opt, thread_replies, bumpable) = switch (arg.thread) {
      case (?op_id) switch (RBTree.get(threads, Nat.compare, op_id)) {
        case (?replies) {
          let should_bump = switch authorization {
            case (#ICRC_2 _) {
              let is_paid_thread = switch (RBTree.get(posts2, Nat.compare, op_id)) {
                case (?found_thread) switch (RBTree.max(found_thread.versions)) {
                  case (?(_, max_version)) switch (max_version.authorization) {
                    case (#ICRC_2 _) true; // only bump paid thread
                    case _ false;
                  };
                  case _ false;
                };
                case _ false;
              };
              if (is_paid_thread) {
                var last_paid_reply = op_id;
                label finding_last_paid_reply for ((reply_id, _) in RBTree.entriesReverse(replies)) switch (RBTree.get(posts2, Nat.compare, reply_id)) {
                  case (?found_reply) switch (RBTree.min(found_reply.versions)) {
                    case (?(_, reply_must)) switch (reply_must.authorization) {
                      case (#ICRC_2 _) {
                        last_paid_reply := reply_id;
                        break finding_last_paid_reply;
                      };
                      case _ ();
                    };
                    case _ ();
                  };
                  case _ ();
                };
                bumps := RBTree.delete(bumps, Nat.compare, last_paid_reply);
              };
              is_paid_thread;
            };
            case _ false; // anon or free dont bump
          };
          (op_id, ?op_id, RBTree.insert(replies, Nat.compare, new_post_id, ()), should_bump);
        };
        case _ (new_post_id, null, RBTree.empty(), true); // if thread is gone after user paid, make this a new thread
      };
      case _ (new_post_id, null, RBTree.empty(), true);
    };
    if (bumpable) bumps := RBTree.insert(bumps, Nat.compare, new_post_id, thread_id);
    threads := RBTree.insert(threads, Nat.compare, thread_id, thread_replies);
    let new_post = Kay4.createPost({
      thread_id_opt;
      authorization;
      timestamp = now;
      content;
      owner;
    });
    posts2 := RBTree.insert(posts2, Nat.compare, new_post_id, new_post);
    post_id += 1;
    // trim();
    #Ok new_post_id;
  } catch e Error.error(e);

  // public shared ({ caller }) func kay4_modify(arg : Kay4.ModifyPostArg) : async Result.Type<(), Kay4.ModifyPostError> = async Error.text("'kay4_modify' is not implemented yet");

  public shared ({ caller }) func kay4_delete(arg : Kay4.DeletePostArg) : async Result.Type<(), Kay4.DeletePostError> = async try {
    if (not Kay1.isAvailable(metadata)) return Error.text("Unavailable");
    let the_post = switch (RBTree.get(posts2, Nat.compare, arg.id)) {
      case (?found) found;
      case _ return #Err(#UnknownPost);
    };
    let authorization = switch (arg.authorization) {
      case (#None auth) {
        let user = { owner = caller; subaccount = auth.subaccount };
        if (not Account.validate(user)) return Error.text("Invalid caller account");

        let mods = Value.getUniquePrincipals(metadata, Kay4.MODERATORS, RBTree.empty());
        if (RBTree.has(mods, Principal.compare, caller)) {
          // caller is a mod
        } else if (RBTree.has(Kay4.getOwners(the_post), Kay2.compareIdentity, #ICRC_1 user)) {
          // caller is the owner of the post
        } else switch (the_post.thread) {
          // caller is not mod nor owner of post
          case (?reply_to) switch (RBTree.get(posts2, Nat.compare, reply_to)) {
            case (?found_thread) if (RBTree.has(Kay4.getOwners(found_thread), Kay2.compareIdentity, #ICRC_1 user)) {
              // caller is owner of thread
              switch (Kay4.getAuthorization(found_thread), Kay4.getAuthorization(the_post)) {
                case (?(#ICRC_2 _), (?(#None _) or ?#Anonymous)) (); // paid thread owners can delete free & anon posts
                case (?(#None _), ?#Anonymous) (); // free thread owners can delete anon posts
                case _ return Error.text("Thread owner does not have the authorization to delete this post");
              };
            } else return Error.text("Caller is not the thread owner");
            case _ return Error.text("Caller is not the post owner");
          };
          case _ return Error.text("Caller is not the post owner");
        };
        let post_content = switch (Kay4.getContent(the_post)) {
          case (?found) found;
          case _ "";
        };
        if (Text.size(post_content) == 0) return Error.text("This post is already deleted");
        (#None { auth with owner = caller });
      };
      case _ return Error.text("Only None authorization is allowed");
    };
    let deleted = Kay4.deletePost(the_post, { authorization; timestamp = Time64.nanos() });
    posts2 := RBTree.insert(posts2, Nat.compare, arg.id, deleted);
    // trim();
    #Ok;
  } catch e Error.error(e);

  public shared query func kay4_threads(prev : ?Nat, take : ?Nat) : async [Nat] {
    let _take = Pager.cleanTake(take, Value.metaNat(metadata, Kay4.MAX_TAKE), Value.metaNat(metadata, Kay4.DEFAULT_TAKE), RBTree.size(threads));
    RBTree.pageKeyReverse(threads, Nat.compare, prev, _take);
  };
  public shared query func kay4_replies_of(thread_id : Nat, prev : ?Nat, take : ?Nat) : async [Nat] {
    let replies = switch (RBTree.get(threads, Nat.compare, thread_id)) {
      case (?found) found;
      case _ return [];
    };
    let _take = Pager.cleanTake(take, Value.metaNat(metadata, Kay4.MAX_TAKE), Value.metaNat(metadata, Kay4.DEFAULT_TAKE), RBTree.size(replies));
    RBTree.pageKey(replies, Nat.compare, prev, _take);
  };
  public shared query func kay4_bumps(prev : ?Nat, take : ?Nat) : async [Nat] {
    let _take = Pager.cleanTake(take, Value.metaNat(metadata, Kay4.MAX_TAKE), Value.metaNat(metadata, Kay4.DEFAULT_TAKE), RBTree.size(bumps));
    RBTree.pageValueReverse(bumps, Nat.compare, prev, _take);
  };
  // public shared query func kay4_posts(by_owner : ?Kay2.Identity, prev : ?Nat, take : ?Nat) : async [Nat] = async switch by_owner {
  //   case (?owned_by) switch (RBTree.get(owners, Kay2.compareIdentity, owned_by)) {
  //     case (?found) {
  //       let _take = Pager.cleanTake(take, Value.metaNat(metadata, Kay4.MAX_TAKE), Value.metaNat(metadata, Kay4.DEFAULT_TAKE), RBTree.size(found));
  //       RBTree.pageKey(found, Nat.compare, prev, _take);
  //     };
  //     case _ [];
  //   };
  //   case _ {
  //     let _take = Pager.cleanTake(take, Value.metaNat(metadata, Kay4.MAX_TAKE), Value.metaNat(metadata, Kay4.DEFAULT_TAKE), RBTree.size(posts));
  //     RBTree.pageKey(posts, Nat.compare, prev, _take);
  //   };
  // };
  // public shared query func kay4_threads_of(post_ids : [Nat]) : async [?Nat] {
  //   let batcher = Batcher.buffer<?Nat>(post_ids.size(), Value.metaNat(metadata, Kay4.MAX_QUERY_BATCH));
  //   label looping for (id in post_ids.vals()) {
  //     let result = switch (RBTree.get(posts, Nat.compare, id)) {
  //       case (?found) found.thread;
  //       case _ null;
  //     };
  //     batcher.add(result);
  //     if (batcher.isFull()) break looping;
  //   };
  //   batcher.finalize();
  // };
  // public shared query func kay4_versions_of(post_ids : [Nat]) : async [?Nat] {
  //   let batcher = Batcher.buffer<?Nat>(post_ids.size(), Value.metaNat(metadata, Kay4.MAX_QUERY_BATCH));
  //   label looping for (id in post_ids.vals()) {
  //     let result = switch (RBTree.get(posts, Nat.compare, id)) {
  //       case (?found) ?RBTree.size(found.versions);
  //       case _ null;
  //     };
  //     batcher.add(result);
  //     if (batcher.isFull()) break looping;
  //   };
  //   batcher.finalize();
  // };
  // public shared query func kay4_content_versions_of(post_id : Nat, prev : ?Nat, take : ?Nat) : async [Nat] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
  //   case (?{ content_versions }) {
  //     let _take = Pager.cleanTake(take, Value.metaNat(metadata, Kay4.MAX_TAKE), Value.metaNat(metadata, Kay4.DEFAULT_TAKE), RBTree.size(content_versions));
  //     RBTree.pageKey(content_versions, Nat.compare, prev, _take);
  //   };
  //   case _ [];
  // };
  // public shared query func kay4_files_versions_of(post_id : Nat, prev : ?Nat, take : ?Nat) : async [Nat] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
  //   case (?{ files_versions }) {
  //     let _take = Pager.cleanTake(take, Value.metaNat(metadata, Kay4.MAX_TAKE), Value.metaNat(metadata, Kay4.DEFAULT_TAKE), RBTree.size(files_versions));
  //     RBTree.pageKey(files_versions, Nat.compare, prev, _take);
  //   };
  //   case _ [];
  // };
  // public shared query func kay4_owners_versions_of(post_id : Nat, prev : ?Nat, take : ?Nat) : async [Nat] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
  //   case (?{ owners_versions }) {
  //     let _take = Pager.cleanTake(take, Value.metaNat(metadata, Kay4.MAX_TAKE), Value.metaNat(metadata, Kay4.DEFAULT_TAKE), RBTree.size(owners_versions));
  //     RBTree.pageKey(owners_versions, Nat.compare, prev, _take);
  //   };
  //   case _ [];
  // };
  // public shared query func kay4_metadata_versions_of(post_id : Nat, prev : ?Nat, take : ?Nat) : async [Nat] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
  //   case (?{ metadata_versions }) {
  //     let _take = Pager.cleanTake(take, Value.metaNat(metadata, Kay4.MAX_TAKE), Value.metaNat(metadata, Kay4.DEFAULT_TAKE), RBTree.size(metadata_versions));
  //     RBTree.pageKey(metadata_versions, Nat.compare, prev, _take);
  //   };
  //   case _ [];
  // };
  // public shared query func kay4_hashes_of(post_ids : [Nat]) : async [?Blob] {
  //   let batcher = Batcher.buffer<?Blob>(post_ids.size(), Value.metaNat(metadata, Kay4.MAX_QUERY_BATCH));
  //   label looping for (id in post_ids.vals()) {
  //     let result = switch (RBTree.get(posts, Nat.compare, id)) {
  //       case (?found) ?found.hash;
  //       case _ null;
  //     };
  //     batcher.add(result);
  //     if (batcher.isFull()) break looping;
  //   };
  //   batcher.finalize();
  // };

  public shared query func kay4_authorizations_of(post_ids : [Nat]) : async [?Kay2.Authorized] = async Kay4.batchPostId(post_ids, posts2, metadata, Kay4.getAuthorization);
  // public shared query func kay4_authorizations_at(postvers : [Kay4.PostVersion]) : async [?Kay2.Authorized] = async Kay4.batchPostVersion(postvers, posts, metadata, #LastValue, Kay4.trackAuthorization);

  public shared query func kay4_timestamps_of(post_ids : [Nat]) : async [?Nat64] = async Kay4.batchPostId(post_ids, posts2, metadata, Kay4.getTimestamp);
  // public shared query func kay4_timestamps_at(postvers : [Kay4.PostVersion]) : async [?Nat64] = async Kay4.batchPostVersion(postvers, posts, metadata, #LastValue, Kay4.trackTimestamp);

  // public shared query func kay4_parent_hashes_of(post_ids : [Nat]) : async [?Blob] = async Kay4.batchPostId(post_ids, posts, metadata, Kay4.getPhash);
  // public shared query func kay4_parent_hashes_at(postvers : [Kay4.PostVersion]) : async [?Blob] = async Kay4.batchPostVersion(postvers, posts, metadata, #LastValue, Kay4.trackPhash);

  // public shared query func kay4_contents_modifications(postvers : [Kay4.PostVersion]) : async [?Text] = async Kay4.batchPostVersion(postvers, posts, metadata, #Modification, Kay4.trackContent);
  // public shared query func kay4_contents_at(postvers : [Kay4.PostVersion]) : async [?Text] = async Kay4.batchPostVersion(postvers, posts, metadata, #LastValue, Kay4.trackContent);
  public shared query func kay4_contents_of(post_ids : [Nat]) : async [?Text] = async Kay4.batchPostId(post_ids, posts2, metadata, Kay4.getContent);

  // public shared query func kay4_files_modifications(post_id : Nat, version_id : Nat, prev : ?Text, take : ?Nat) : async [Text] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
  //   case (?found) Kay4.trackFiles(found, version_id, #Modification, prev, take, metadata);
  //   case _ [];
  // };
  // public shared query func kay4_files_at(post_id : Nat, version_id : Nat, prev : ?Text, take : ?Nat) : async [Text] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
  //   case (?found) Kay4.trackFiles(found, version_id, #LastValue, prev, take, metadata);
  //   case _ [];
  // };
  // public shared query func kay4_files_of(post_id : Nat, prev : ?Text, take : ?Nat) : async [Text] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
  //   case (?found) Kay4.getFiles(found, prev, take, metadata);
  //   case _ [];
  // };

  // public shared query func kay4_owners_modifications(post_id : Nat, version_id : Nat, prev : ?Kay2.Identity, take : ?Nat) : async [Kay2.Identity] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
  //   case (?found) Kay4.trackOwners(found, version_id, #Modification, prev, take, metadata);
  //   case _ [];
  // };
  // public shared query func kay4_owners_at(post_id : Nat, version_id : Nat, prev : ?Kay2.Identity, take : ?Nat) : async [Kay2.Identity] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
  //   case (?found) Kay4.trackOwners(found, version_id, #LastValue, prev, take, metadata);
  //   case _ [];
  // };
  public shared query func kay4_owners_of(post_id : Nat, prev : ?Kay2.Identity, take : ?Nat) : async [Kay2.Identity] = async switch (RBTree.get(posts2, Nat.compare, post_id)) {
    case (?found) Kay4.pageOwners(found, prev, take, metadata);
    case _ [];
  };

  // public shared query func kay4_metadata_modifications(post_id : Nat, version_id : Nat, prev : ?Text, take : ?Nat) : async [(Text, Value.Type)] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
  //   case (?found) Kay4.trackPostMeta(found, version_id, #Modification, prev, take, metadata);
  //   case _ [];
  // };
  // public shared query func kay4_metadata_at(post_id : Nat, version_id : Nat, prev : ?Text, take : ?Nat) : async [(Text, Value.Type)] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
  //   case (?found) Kay4.trackPostMeta(found, version_id, #LastValue, prev, take, metadata);
  //   case _ [];
  // };
  // public shared query func kay4_metadata_of(post_id : Nat, prev : ?Text, take : ?Nat) : async [(Text, Value.Type)] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
  //   case (?found) Kay4.pagePostMeta(found, prev, take, metadata);
  //   case _ [];
  // };
};
