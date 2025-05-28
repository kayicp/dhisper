import Value "../util/motoko/Value";
import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
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

// todo: for dhisper, replace the post completely when deleting
// todo: rename modifications
// todo: combat sybil spam

shared (install) actor class Canister(
  deploy : {
    #Init : {
      kay1 : Kay1.Init;
      kay2 : Kay2.Init;
      kay4 : Kay4.Init;
    };
    #Upgrade;
  }
) = Self {
  func self() : Principal = Principal.fromActor(Self);
  stable var metadata : Value.Metadata = RBTree.empty();
  stable var logs = Queue.empty<Text>();
  stable var threads = RBTree.empty<Nat, RBTree.RBTree<Nat, ()>>();
  stable var owners = RBTree.empty<Kay2.Identity, RBTree.RBTree<Nat, ()>>();
  stable var posts : Kay4.Posts = RBTree.empty();
  stable var bumps = RBTree.empty<Nat, Nat>(); // PostId, ThreadId
  stable var post_id = 0;

  switch deploy {
    case (#Init init) {
      metadata := RBTree.empty();
      logs := Queue.empty(); // todo: redesign this to use tree
      threads := RBTree.empty();
      owners := RBTree.empty();
      posts := RBTree.empty();
      bumps := RBTree.empty();
      post_id := 0;

      metadata := Kay1.init(metadata, init.kay1);
      metadata := Kay2.init(metadata, init.kay2);
      metadata := Kay4.init(metadata, init.kay4);
    };
    case _ ();
  };

  func log(t : Text) = logs := Kay1.log(logs, t);
  public shared query func kay1_logs() : async [Text] = async Queue.arrayTail(logs);

  public shared query ({ caller }) func kay1_metrics() : async [(Text, Value.Type)] {
    var custodians = Kay1.getCustodians(metadata);

    var metrics : Value.Metadata = RBTree.empty();
    metrics := Kay1.getMetrics(metrics, caller, logs, custodians);
    metrics := Kay2.getMetrics(metrics, RBTree.size(owners));
    // metrics := Kay3.getMetrics(metrics, files); // todo: uncomment this
    metrics := Kay4.getMetrics(metrics, threads, posts);
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

  public shared query func kay2_owners(prev : ?Kay2.Identity, take : ?Nat) : async [Kay2.Identity] {
    let _take = Pager.cleanTake(take, Value.metaNat(metadata, Kay2.MAX_TAKE), Value.metaNat(metadata, Kay2.DEFAULT_TAKE), RBTree.size(owners));
    RBTree.pageKey(owners, Kay2.compareIdentity, prev, _take);
  };

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

  // todo: separate metadata by standards
  public shared query func kay4_metadata() : async [(Text, Value.Type)] = async RBTree.array(metadata);

  public shared query func kay4_max_threads() : async ?Nat = async null;
  public shared query func kay4_max_posts_per_thread() : async ?Nat = async null;
  public shared query func kay4_max_content_size_per_post() : async ?Nat = async null;

  public shared query func kay4_fee_collectors() : async [Principal] = async [];
  public shared query func kay4_create_fee_rates() : async [(Text, Value.Type)] = async RBTree.array(Value.getMap(metadata, Kay4.CREATE_FEE_RATES, RBTree.empty()));
  public shared query func kay4_delete_fee_rates() : async [(Text, Value.Type)] = async RBTree.array(Value.getMap(metadata, Kay4.DELETE_FEE_RATES, RBTree.empty()));

  public shared query func kay4_default_take_value() : async ?Nat = async Value.metaNat(metadata, Kay4.DEFAULT_TAKE);
  public shared query func kay4_max_take_value() : async ?Nat = async Value.metaNat(metadata, Kay4.MAX_TAKE);
  public shared query func kay4_max_query_batch_size() : async ?Nat = async Value.metaNat(metadata, Kay4.MAX_QUERY_BATCH);

  // public shared query func kay4_locker

  // todo later: delete all files within each posts/thread
  func delete(postid : Nat) {
    let post = switch (RBTree.get(posts, Nat.compare, postid)) {
      case (?found) found;
      case _ return;
    };
    let post_owners = Kay4.getOwners(post);
    label each_owner for ((him, _) in RBTree.entries(post_owners)) {
      var his_posts = switch (RBTree.get(owners, Kay2.compareIdentity, him)) {
        case (?found) found;
        case _ continue each_owner;
      };
      his_posts := RBTree.delete(his_posts, Nat.compare, postid);
      owners := RBTree.insert(owners, Kay2.compareIdentity, him, his_posts);
    };
    posts := RBTree.delete(posts, Nat.compare, postid);
  };
  func trim() {
    let max_threads = switch (Value.metaNat(metadata, Kay4.MAX_THREADS)) {
      case (?found) found;
      case _ return;
    };
    if (RBTree.size(threads) <= max_threads) return;
    for ((bump_id, thread_id) in RBTree.entries(bumps)) {
      // only delete 1 oldest thread + posts within
      let replies = switch (RBTree.get(threads, Nat.compare, thread_id)) {
        case (?found) found;
        case _ RBTree.empty();
      };

      for ((reply_id, _) in RBTree.entries(replies)) {
        delete(reply_id);
      };
      delete(thread_id);
      threads := RBTree.delete(threads, Nat.compare, thread_id);
      return;
    };
  };
  func lock(locker : ?Kay2.Locker) = metadata := switch locker {
    case (?found) Value.insert(metadata, Kay4.LOCKER, Kay2.identityValue(Kay2.lockerIdentity(found)));
    case _ Value.delete(metadata, Kay4.LOCKER);
  };
  func getFee({
    canister_id : Principal;
    fee : ?Nat;
    content_size : Nat;
    content_max : Nat;
    fee_key : Text;
  }) : Result.Type<Nat, { #Unauthorized : Kay2.Unauthorized; #GenericError : Error.Type }> {
    let fee_rates_standards = Value.getMap(metadata, fee_key, RBTree.empty());
    let ICRC_2_KEY = "ICRC-2";
    let icrc2_fee_rates = Value.getPrincipalMap(fee_rates_standards, ICRC_2_KEY, RBTree.empty());
    let fee_tree = switch (RBTree.get(icrc2_fee_rates, Principal.compare, canister_id)) {
      case (?#Map found) RBTree.fromArray(found, Text.compare);
      case _ return #Err(#Unauthorized(#ICRC_2(#BadCanister { expected_canister_ids = RBTree.arrayKey(icrc2_fee_rates) })));
    };
    let minimum_amount = switch (Value.metaNat(fee_tree, Kay4.MIN_AMOUNT)) {
      case (?found) found;
      case _ return Error.text("Metadata `" # fee_key # "." # ICRC_2_KEY # "." # Kay4.MIN_AMOUNT # "` is missing");
    };
    let additional_amount = if (content_max > 0 and content_size > content_max) switch (Value.metaNat(fee_tree, Kay4.ADDITIONAL_AMOUNT), Value.metaNat(fee_tree, Kay4.ADDITIONAL_BYTE)) {
      case (?amount_numer, ?byte_denom) if (amount_numer > 0 and byte_denom > 0) (content_size - content_max) * amount_numer / byte_denom else 0;
      case _ 0;
    } else 0;
    let expected_fee = minimum_amount + additional_amount;
    switch fee {
      case (?defined_fee) if (defined_fee != expected_fee) return #Err(#Unauthorized(#ICRC_2(#BadFee { expected_fee })));
      case _ ();
    };
    #Ok expected_fee;
  };

  // todo: error when replies reached max replies per thread
  public shared ({ caller }) func kay4_create(arg : Kay4.CreatePostArg) : async Result.Type<Nat, Kay4.CreatePostError> {
    var is_locker = false;
    try {
      if (not Kay1.isAvailable(metadata)) return Error.text("Unavailable");
      if (arg.owners.size() > 0) return Error.text("Owners must be empty");
      if (arg.metadata.size() > 0) return Error.text("Metadata must be empty");

      switch (arg.thread) {
        case (?op_id) if (not RBTree.has(posts, Nat.compare, op_id)) return #Err(#UnknownThread);
        case _ ();
      };
      let content = Kay4.cleanText(arg.content);
      let content_size = Text.size(content);
      if (content_size == 0) return Error.text("Content cannot be empty");
      let content_max = Value.getNat(metadata, Kay4.MAX_CONTENT, 0);

      if (arg.files.size() > 0) return Error.text("File system not implemented yet.");
      // todo later: implement file storing
      // todo: check locker
      let (authorization, owner) = switch (arg.authorization) {
        case (#None auth) (#None { auth with owner = caller }, #ICRC_1 { auth with owner = caller });
        // todo: redo icrc-1 authorization
        // case (#ICRC_1 auth) {
        //   let user = { owner = caller; subaccount = auth.subaccount };
        //   if (Account.validate(user)) return Error.text("Invalid caller account");

        //   let token_minimums = Value.getPrincipalMap(metadata, Kay2.TOKEN_MINIMUMS, RBTree.empty());
        //   let minimum_balance = switch (RBTree.get(token_minimums, Principal.compare, auth.canister_id)) {
        //     case (?#Nat minimum) minimum;
        //     case _ return #Err(#Unauthorized(#ICRC_1(#BadCanister { expected_canister_ids = RBTree.arrayKey(token_minimums) })));
        //   };
        //   let token = ICRC_1_Types.genActor(auth.canister_id);
        //   lock(?{ arg with caller });
        //   is_locker := true;
        //   let current_balance = await token.icrc1_balance_of(user);
        //   if (current_balance < minimum_balance) {
        //     lock(null);
        //     return #Err(#Unauthorized(#ICRC_1(#BalanceTooSmall { current_balance; minimum_balance })));
        //   };
        //   (#ICRC_1 { auth with owner = caller; minimum_balance }, #ICRC_1 user);
        // };
        case (#ICRC_2 auth) {
          let user = { owner = caller; subaccount = auth.subaccount };
          if (Account.validate(user)) return Error.text("Invalid caller account");
          let expected_fee = switch (getFee({ auth with content_size; content_max; fee_key = Kay4.CREATE_FEE_RATES })) {
            case (#Ok ok) ok;
            case (#Err err) return #Err err;
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
          lock(?{ arg with caller });
          is_locker := true;
          let transfer_from_id = switch (await token.icrc2_transfer_from(transfer_from_args)) {
            case (#Err err) {
              lock(null);
              return #Err(#Unauthorized(#ICRC_2(#TransferFromFailed err)));
            };
            case (#Ok ok) ok;
          };
          (#ICRC_2 { auth with owner = caller; xfer = transfer_from_id }, #ICRC_1 user);
        };
        case _ return Error.text("ICRC-1 & ICRC-7 authorizations are not implemented yet");
      };
      lock(null);

      let new_post_id = post_id;
      let (thread_id, replies) = switch (arg.thread) {
        case (?op_id) switch (RBTree.get(threads, Nat.compare, op_id)) {
          case (?replies) (op_id, RBTree.insert(replies, Nat.compare, new_post_id, ()));
          case _ (new_post_id, RBTree.empty()); // if thread is gone after user paid, make this a new thread
        };
        case _ (new_post_id, RBTree.empty());
      };
      threads := RBTree.insert(threads, Nat.compare, thread_id, replies);
      let new_post = Kay4.createPost({
        thread = arg.thread;
        content;
        authorization;

        timestamp = Time64.nanos();
        owner;
      });
      posts := RBTree.insert(posts, Nat.compare, new_post_id, new_post);
      post_id += 1;
      trim();
      #Ok new_post_id;
    } catch e {
      if (is_locker) lock(null);
      Error.error(e);
    };
  };

  // public shared ({ caller }) func kay4_modify(arg : Kay4.ModifyPostArg) : async Result.Type<(), Kay4.ModifyPostError> = async Error.text("'kay4_modify' is not implemented yet");

  public shared ({ caller }) func kay4_delete(arg : Kay4.DeletePostArg) : async Result.Type<(), Kay4.DeletePostError> {
    var is_locker = false;
    try {
      if (not Kay1.isAvailable(metadata)) return Error.text("Unavailable");
      let the_post = switch (RBTree.get(posts, Nat.compare, arg.id)) {
        case (?found) found;
        case _ return #Err(#UnknownPost);
      };
      let post_owners = Kay4.getOwners(the_post);
      let authorization = switch (arg.authorization) {
        case (#None auth) (#None { auth with owner = caller });
        // todo: rethink icrc1 delete
        // case (#ICRC_1 auth) {
        //   let user = { owner = caller; subaccount = auth.subaccount };
        //   if (Account.validate(user)) return Error.text("Invalid caller account");

        //   let token_minimums = Value.getPrincipalMap(metadata, Kay2.TOKEN_MINIMUMS, RBTree.empty());
        //   let minimum_balance = switch (RBTree.get(token_minimums, Principal.compare, auth.canister_id)) {
        //     case (?#Nat minimum) minimum;
        //     case _ return #Err(#Unauthorized(#ICRC_1(#BadCanister { expected_canister_ids = RBTree.arrayKey(token_minimums) })));
        //   };
        //   let token = ICRC_1_Types.genActor(auth.canister_id);
        //   lock(?{ arg with caller });
        //   is_locker := true;
        //   let current_balance = await token.icrc1_balance_of(user);
        //   if (current_balance < minimum_balance) {
        //     lock(null);
        //     return #Err(#Unauthorized(#ICRC_1(#BalanceTooSmall { current_balance; minimum_balance })));
        //   };
        //   #ICRC_1 { auth with owner = caller; minimum_balance };
        // };
        case (#ICRC_2 auth) {
          let user = { owner = caller; subaccount = auth.subaccount };
          if (not RBTree.has(post_owners, Kay2.compareIdentity, #ICRC_1 user)) return Error.text("Caller is not the owner of the post");

          let expected_fee = switch (getFee({ auth with content_size = 0; content_max = 0; fee_key = Kay4.DELETE_FEE_RATES })) {
            case (#Ok ok) ok;
            case (#Err err) return #Err err;
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
          lock(?{ arg with caller });
          is_locker := true;
          let transfer_from_id = switch (await token.icrc2_transfer_from(transfer_from_args)) {
            case (#Err err) {
              lock(null);
              return #Err(#Unauthorized(#ICRC_2(#TransferFromFailed err)));
            };
            case (#Ok ok) ok;
          };
          #ICRC_2 { auth with owner = caller; xfer = transfer_from_id };
        };
        case _ return Error.text("ICRC-7 authorizations not implemented yet");
      };
      lock(null);
      let deleted = Kay4.deletePost(the_post, { authorization; timestamp = Time64.nanos() });
      posts := RBTree.insert(posts, Nat.compare, arg.id, deleted);
      trim();
      #Ok;
    } catch e {
      if (is_locker) lock(null);
      Error.error(e);
    };
  };

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
  public shared query func kay4_posts(by_owner : ?Kay2.Identity, prev : ?Nat, take : ?Nat) : async [Nat] = async switch by_owner {
    case (?owned_by) switch (RBTree.get(owners, Kay2.compareIdentity, owned_by)) {
      case (?found) {
        let _take = Pager.cleanTake(take, Value.metaNat(metadata, Kay4.MAX_TAKE), Value.metaNat(metadata, Kay4.DEFAULT_TAKE), RBTree.size(found));
        RBTree.pageKey(found, Nat.compare, prev, _take);
      };
      case _ [];
    };
    case _ {
      let _take = Pager.cleanTake(take, Value.metaNat(metadata, Kay4.MAX_TAKE), Value.metaNat(metadata, Kay4.DEFAULT_TAKE), RBTree.size(posts));
      RBTree.pageKey(posts, Nat.compare, prev, _take);
    };
  };
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

  public shared query func kay4_authorizations_of(post_ids : [Nat]) : async [?Kay2.Authorized] = async Kay4.batchPostId(post_ids, posts, metadata, Kay4.getAuthorization);
  public shared query func kay4_authorizations_at(postvers : [Kay4.PostVersion]) : async [?Kay2.Authorized] = async Kay4.batchPostVersion(postvers, posts, metadata, #LastValue, Kay4.trackAuthorization);

  public shared query func kay4_timestamps_of(post_ids : [Nat]) : async [?Nat64] = async Kay4.batchPostId(post_ids, posts, metadata, Kay4.getTimestamp);
  public shared query func kay4_timestamps_at(postvers : [Kay4.PostVersion]) : async [?Nat64] = async Kay4.batchPostVersion(postvers, posts, metadata, #LastValue, Kay4.trackTimestamp);

  // public shared query func kay4_parent_hashes_of(post_ids : [Nat]) : async [?Blob] = async Kay4.batchPostId(post_ids, posts, metadata, Kay4.getPhash);
  // public shared query func kay4_parent_hashes_at(postvers : [Kay4.PostVersion]) : async [?Blob] = async Kay4.batchPostVersion(postvers, posts, metadata, #LastValue, Kay4.trackPhash);

  // public shared query func kay4_contents_modifications(postvers : [Kay4.PostVersion]) : async [?Text] = async Kay4.batchPostVersion(postvers, posts, metadata, #Modification, Kay4.trackContent);
  // public shared query func kay4_contents_at(postvers : [Kay4.PostVersion]) : async [?Text] = async Kay4.batchPostVersion(postvers, posts, metadata, #LastValue, Kay4.trackContent);
  public shared query func kay4_contents_of(post_ids : [Nat]) : async [?Text] = async Kay4.batchPostId(post_ids, posts, metadata, Kay4.getContent);

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
  public shared query func kay4_owners_at(post_id : Nat, version_id : Nat, prev : ?Kay2.Identity, take : ?Nat) : async [Kay2.Identity] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
    case (?found) Kay4.trackOwners(found, version_id, #LastValue, prev, take, metadata);
    case _ [];
  };
  public shared query func kay4_owners_of(post_id : Nat, prev : ?Kay2.Identity, take : ?Nat) : async [Kay2.Identity] = async switch (RBTree.get(posts, Nat.compare, post_id)) {
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
