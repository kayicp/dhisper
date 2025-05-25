import Prim "mo:⛔";
import Debug "mo:base/Debug";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";

import Error "../Error";
import Result "../Result";
import Queue "../StableCollections/Queue";
import Time64 "../Time64";
import Value "../Value";
import Square "../Square";
import RBTree "../StableCollections/RedBlackTree/RBTree";

module {
  public let AVAILABLE = "kay1:available";
  public let MAX_LOGS = "kay1:max_logs_size";
  public let CUSTODIANS = "kay1:custodians";

  public type Init = {
    available : ?Bool;
    max_logs_size : ?Nat;
    custodians : [Principal];
  };

  public func init(metadata : Value.Metadata, i : Init) : Value.Metadata {
    var m = metadata;
    m := Value.setBool(m, AVAILABLE, i.available);
    m := Value.setNat(m, MAX_LOGS, i.max_logs_size);
    m := Value.setPrincipals(m, CUSTODIANS, i.custodians);
    m;
  };

  public type KeyValue = { key : Text; value : ?Value.Type };
  public type MetadataArg = {
    child_canister_id : ?Principal;
    pairs : [KeyValue];
  };

  public func isAvailable(meta : Value.Metadata) : Bool = Value.getBool(meta, AVAILABLE, true);
  public func getMaxLogs(meta : Value.Metadata) : ?Nat = Value.metaNat(meta, MAX_LOGS);
  public func getCustodians(meta : Value.Metadata) : RBTree.RBTree<Principal, ()> = Value.getUniquePrincipals(meta, CUSTODIANS, RBTree.empty());

  public type Logs = Queue.Queue<Text>;
  public func log(_logs : Logs, t : Text) : Logs {
    Debug.print(t);
    Queue.insertHead(_logs, t);
  };
  public func trimLogs(_logs : Logs, meta : Value.Metadata) : Logs {
    let init_size = Queue.size(_logs);
    let max_logs = switch (getMaxLogs(meta)) {
      case (?defined) if (defined > 0) defined else return Queue.empty();
      case _ if (init_size > 100) init_size - Square.root(init_size) else return _logs;
    };
    var logs = _logs;
    while (Queue.size(logs) > max_logs) {
      logs := Queue.deleteTail(logs);
    };
    logs;
  };

  public func getMetrics(
    _metrics : Value.Metadata,
    caller : Principal,
    logs : Logs,
    custodians : RBTree.RBTree<Principal, ()>,
  ) : Value.Metadata {
    var metrics = _metrics;
    if (
      Principal.isController(caller) or
      RBTree.has(custodians, Principal.compare, caller)
    ) {
      metrics := Value.insert(metrics, "kay1:cycles_balance", #Nat(ExperimentalCycles.balance()));
      metrics := Value.insert(metrics, "kay1:canister_version", #Nat(Nat64.toNat(Prim.canisterVersion())));
      metrics := Value.insert(metrics, "kay1:rts_callback_table_count", #Nat(Prim.rts_callback_table_count()));
      metrics := Value.insert(metrics, "kay1:rts_callback_table_size", #Nat(Prim.rts_callback_table_size()));
      metrics := Value.insert(metrics, "kay1:rts_collector_instructions", #Nat(Prim.rts_collector_instructions()));
      metrics := Value.insert(metrics, "kay1:rts_heap_size", #Nat(Prim.rts_heap_size())); // the actual size of the current Motoko heap
      metrics := Value.insert(metrics, "kay1:rts_logical_stable_memory_size", #Nat(Prim.rts_logical_stable_memory_size()));
      metrics := Value.insert(metrics, "kay1:rts_max_live_size", #Nat(Prim.rts_max_live_size())); // largest heap size that has remained so far after a GC
      metrics := Value.insert(metrics, "kay1:rts_max_stack_size", #Nat(Prim.rts_max_stack_size()));
      metrics := Value.insert(metrics, "kay1:rts_memory_size", #Nat(Prim.rts_memory_size()));
      metrics := Value.insert(metrics, "kay1:rts_mutator_instructions", #Nat(Prim.rts_mutator_instructions()));
      metrics := Value.insert(metrics, "kay1:rts_reclaimed", #Nat(Prim.rts_reclaimed()));
      metrics := Value.insert(metrics, "kay1:rts_stable_memory_size", #Nat(Prim.rts_stable_memory_size()));
      metrics := Value.insert(metrics, "kay1:rts_total_allocation", #Nat(Prim.rts_total_allocation()));
      metrics := Value.insert(metrics, "kay1:rts_version", #Text(Prim.rts_version()));
      // metrics := Value.insert(metrics, "kay1:stable_memory_size", #Nat(Nat64.toNat(Prim.stableMemorySize())));
    };
    metrics := Value.insert(metrics, "kay1:time", #Nat(Nat64.toNat(Time64.nanos())));
    Value.insert(metrics, "kay1:logs_size", #Nat(Queue.size(logs)));
  };

  public func callerNotCustodianErr(caller : Principal, current : Principal) : Error.Result = Error.text("Caller (" # debug_show caller # ") is not a controller nor a custodian of this canister (" # debug_show current # ")");

  public func setMetadata(child_id : ?Principal, _meta : Value.Metadata, pairs : [KeyValue]) : async* Result.Type<Value.Metadata, Error.Generic> {
    if (pairs.size() == 0) return Error.text("Pairs are empty");
    switch child_id {
      case (?child) try switch (await interface(child).kay1_set_metadata({ child_canister_id = null; pairs })) {
        case (#Err err) #Err err;
        case _ #Ok _meta;
      } catch e Error.error(e);
      case _ {
        var meta = _meta;
        for ({ key; value } in pairs.vals()) meta := switch value {
          case (?defined) Value.insert(meta, key, defined);
          case _ Value.delete(meta, key);
        };
        #Ok meta;
      };
    };
  };

  public func interface(p : Principal) : actor {
    kay1_set_metadata : shared MetadataArg -> async Result.Type<(), Error.Generic>;
  } = actor (Principal.toText(p));
};
