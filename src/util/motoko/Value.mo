import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Order "mo:base/Order";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Bool "mo:base/Bool";
import Iter "mo:base/Iter";
import Hasher "SHA2";

import Account "ICRC-1/Account";
import RBTree "StableCollections/RedBlackTree/RBTree";
import QueueLeb128 "QueueLEB128";
import Queue "StableCollections/Queue";

module {
  public type Type = {
    // ICRC-3: basic
    #Blob : Blob; // 0
    #Text : Text; // 1
    #Int : Int; // 2
    #Nat : Nat; // 3
    #Array : [Type]; // 4
    #Map : [(Text, Type)]; // 5

    // ICRC-16: enhanced
    #Principal : Principal; // 6
    #Bool : Bool; // 7
    #ValueMap : [(Type, Type)]; // 8
    // #Set : [Type];
  };

  func rank(t : Type) : Nat = switch t {
    case (#Blob _) 0;
    case (#Text _) 1;
    case (#Int _) 2;
    case (#Nat _) 3;
    case (#Array _) 4;
    case (#Map _) 5;
    case (#Principal _) 6;
    case (#Bool _) 7;
    case (#ValueMap _) 8;
  };

  func arrayCompare(a : [Type], b : [Type]) : Order.Order {
    let asize = a.size();
    let bsize = b.size();
    switch (Nat.compare(asize, bsize)) {
      case (#equal) ();
      case other return other;
    };
    for (i in Iter.range(0, asize - 1)) {
      switch (compare(a[i], b[i])) {
        case (#equal) ();
        case other return other;
      };
    };
    #equal;
  };

  func mapCompare(a : [(Text, Type)], b : [(Text, Type)]) : Order.Order {
    let asize = a.size();
    let bsize = b.size();
    switch (Nat.compare(asize, bsize)) {
      case (#equal) ();
      case other return other;
    };
    for (i in Iter.range(0, asize - 1)) {
      let (akey, aval) = a[i];
      let (bkey, bval) = b[i];
      switch (Text.compare(akey, bkey)) {
        case (#equal) ();
        case other return other;
      };
      switch (compare(aval, bval)) {
        case (#equal) ();
        case other return other;
      };
    };
    #equal;
  };

  func vmapCompare(a : [(Type, Type)], b : [(Type, Type)]) : Order.Order {
    let asize = a.size();
    let bsize = b.size();
    switch (Nat.compare(asize, bsize)) {
      case (#equal) ();
      case other return other;
    };
    for (i in Iter.range(0, asize - 1)) {
      let (akey, aval) = a[i];
      let (bkey, bval) = b[i];
      switch (compare(akey, bkey)) {
        case (#equal) ();
        case other return other;
      };
      switch (compare(aval, bval)) {
        case (#equal) ();
        case other return other;
      };
    };
    #equal;
  };

  public func compare(at : Type, bt : Type) : Order.Order = switch (at, bt) {
    case (#Blob a, #Blob b) Blob.compare(a, b);
    case (#Text a, #Text b) Text.compare(a, b);
    case (#Int a, #Int b) Int.compare(a, b);
    case (#Nat a, #Nat b) Nat.compare(a, b);
    case (#Array a, #Array b) arrayCompare(a, b);
    case (#Map a, #Map b) mapCompare(a, b);
    case (#Principal a, #Principal b) Principal.compare(a, b);
    case (#Bool a, #Bool b) Bool.compare(a, b);
    case (#ValueMap a, #ValueMap b) vmapCompare(a, b);
    case _ Nat.compare(rank(at), rank(bt));
  };

  public type Metadata = RBTree.RBTree<Text, Type>;
  public func metaMissingError(key : Text) : Text = "Metadata \"" # key # "\" is invalid or missing";

  public func delete(metadata : Metadata, key : Text) : Metadata = RBTree.delete(metadata, Text.compare, key);
  public func insert(metadata : Metadata, key : Text, val : Type) : Metadata = RBTree.insert(metadata, Text.compare, key, val);
  public func get(metadata : Metadata, key : Text) : ?Type = RBTree.get(metadata, Text.compare, key);
  public func equal(a : Type, b : Type) : Bool = a == b;
  public func print(t : Type) : Text = debug_show t;

  public func setText(metadata : Metadata, key : Text, text : ?Text) : Metadata = switch text {
    case (?defined) insert(metadata, key, #Text defined);
    case _ delete(metadata, key);
  };

  public func setMap(metadata : Metadata, key : Text, values : RBTree.RBTree<Text, Type>) : Metadata = switch (RBTree.size(values)) {
    case 0 delete(metadata, key);
    case _ insert(metadata, key, #Map(RBTree.array(values)));
  };

  public func setValueMap(metadata : Metadata, key : Text, values : RBTree.RBTree<Type, Type>) : Metadata = switch (RBTree.size(values)) {
    case 0 delete(metadata, key);
    case _ insert(metadata, key, #ValueMap(RBTree.array(values)));
  };

  public func setArray(metadata : Metadata, key : Text, values : [Type]) : Metadata = switch (values.size()) {
    case 0 delete(metadata, key);
    case _ insert(metadata, key, #Array values);
  };

  public func setPrincipals(metadata : Metadata, key : Text, principals : [Principal]) : Metadata {
    let buff = Buffer.Buffer<Type>(principals.size());
    for (p in principals.vals()) buff.add(#Principal p);
    setArray(metadata, key, Buffer.toArray(buff));
  };

  // public func setSet(metadata : Metadata, key : Text, values : RBTree.RBTree<Type, ()>) : Metadata = switch (RBTree.size(values)) {
  //   case 0 delete(metadata, key);
  //   case _ insert(metadata, key, #Set(RBTree.arrayKey(values)));
  // };

  public func setPrincipal(metadata : Metadata, key : Text, p : ?Principal) : Metadata = switch p {
    case (?defined) insert(metadata, key, #Principal defined);
    case _ delete(metadata, key);
  };

  public func setNat(metadata : Metadata, key : Text, nat : ?Nat) : Metadata = switch nat {
    case (?defined) insert(metadata, key, #Nat defined);
    case _ delete(metadata, key);
  };

  public func setNat8(metadata : Metadata, key : Text, nat : ?Nat8) : Metadata = switch nat {
    case (?defined) insert(metadata, key, #Nat(Nat8.toNat(defined)));
    case _ delete(metadata, key);
  };

  public func setBool(metadata : Metadata, key : Text, b : ?Bool) : Metadata = switch b {
    case (?defined) insert(metadata, key, #Bool defined); // #Blob(Blob.fromArray([if (defined) 255 else 0])));
    case _ delete(metadata, key);
  };

  public func setBlob(metadata : Metadata, key : Text, b : ?Blob) : Metadata = switch b {
    case (?defined) insert(metadata, key, #Blob defined);
    case _ delete(metadata, key);
  };

  public func setAccount(metadata : Metadata, key : Text, a : ?Account.Pair) : Metadata = switch a {
    case (?defined) insert(metadata, key, ofAccount(defined));
    case _ delete(metadata, key);
  };

  public func setAccountP(metadata : Metadata, key : Text, a : ?Account.Pair) : Metadata = switch a {
    case (?defined) insert(metadata, key, ofAccountP(defined));
    case _ delete(metadata, key);
  };

  public func accountFromArray(arr : [Type]) : ?Account.Pair {
    var pair : Account.Pair = if (arr.size() > 0) ({
      owner = switch (toPrincipal(arr[0])) {
        case (?p) p;
        case _ return null;
      };
      subaccount = null;
    }) else return null;
    ?{
      pair with subaccount = if (arr.size() > 1) switch (arr[1]) {
        case (#Blob b) ?b;
        case (#Text t) ?Text.encodeUtf8(t);
        case _ null;
      } else null;
    };
  };

  public func toPrincipal(value : Type) : ?Principal = switch value {
    case (#Text t) ?Principal.fromText(t);
    case (#Blob b) ?Principal.fromBlob(b);
    case (#Principal p) ?p;
    case (#Array arr) switch (accountFromArray(arr)) {
      case (?found) ?found.owner;
      case _ null;
    };
    case _ null;
  };

  public func metaPrincipal(metadata : Metadata, key : Text) : ?Principal = switch (RBTree.get(metadata, Text.compare, key)) {
    case (?value) toPrincipal(value);
    case _ null;
  };

  public func metaMap(metadata : Metadata, key : Text) : ?RBTree.RBTree<Text, Type> = switch (get(metadata, key)) {
    case (?v) switch v {
      case (#Map m) ?RBTree.fromArray(m, Text.compare);
      case _ null;
    };
    case _ null;
  };

  public func metaValueMap(metadata : Metadata, key : Text) : ?RBTree.RBTree<Type, Type> = switch (get(metadata, key)) {
    case (?v) switch v {
      case (#ValueMap m) ?RBTree.fromArray(m, compare);
      case _ null;
    };
    case _ null;
  };

  public func metaArray(metadata : Metadata, key : Text) : ?[Type] = switch (get(metadata, key)) {
    case (?v) switch v {
      case (#Array a) ?a;
      case _ null;
    };
    case _ null;
  };

  public func metaText(metadata : Metadata, key : Text) : ?Text = switch (get(metadata, key)) {
    case (?v) switch v {
      case (#Text t) ?t;
      case _ null;
    };
    case _ null;
  };

  public func metaNat(metadata : Metadata, key : Text) : ?Nat = switch (get(metadata, key)) {
    case (?v) switch v {
      case (#Nat n) ?n;
      case _ null;
    };
    case _ null;
  };

  public func metaNat8(metadata : Metadata, key : Text) : ?Nat8 = switch (get(metadata, key)) {
    case (?v) switch v {
      case (#Nat n) ?Nat8.fromNat(n);
      case _ null;
    };
    case _ null;
  };

  public func metaBool(metadata : Metadata, key : Text) : ?Bool = switch (get(metadata, key)) {
    case (?v) switch v {
      case (#Bool b) ?b;
      case (#Nat n) ?(n > 0);
      case (#Text t) ?(t == "true");
      case (#Blob b) ?(b > Blob.fromArray([]) or b > Blob.fromArray([0]));
      case _ null;
    };
    case _ null;
  };

  public func metaBlob(metadata : Metadata, key : Text) : ?Blob = switch (get(metadata, key)) {
    case (?v) switch v {
      case (#Blob b) ?b;
      case _ null;
    };
    case _ null;
  };

  public func metaNat64(metadata : Metadata, key : Text) : ?Nat64 = switch (get(metadata, key)) {
    case (?v) switch v {
      case (#Nat n) ?Nat64.fromNat(n);
      case _ null;
    };
    case _ null;
  };

  public func metaAccount(metadata : Metadata, key : Text) : ?Account.Pair = switch (get(metadata, key)) {
    case (?v) switch v {
      case (#Blob b) ?{ owner = Principal.fromBlob(b); subaccount = null };
      case (#Text t) ?{ owner = Principal.fromText(t); subaccount = null };
      case (#Principal p) ?{ owner = p; subaccount = null };
      case (#Array arr) accountFromArray(arr);
      case _ null;
    };
    case _ null;
  };

  public func getMap(metadata : Metadata, key : Text, default : RBTree.RBTree<Text, Type>) : RBTree.RBTree<Text, Type> = switch (metaMap(metadata, key)) {
    case (?n) n;
    case _ default;
  };

  public func getValueMap(metadata : Metadata, key : Text, default : RBTree.RBTree<Type, Type>) : RBTree.RBTree<Type, Type> = switch (metaValueMap(metadata, key)) {
    case (?n) n;
    case _ default;
  };

  public func getPrincipalMap(metadata : Metadata, key : Text, default : RBTree.RBTree<Principal, Type>) : RBTree.RBTree<Principal, Type> = switch (metaValueMap(metadata, key)) {
    case (?found) {
      var fast = RBTree.empty<Principal, Type>();
      for ((keytype, valtype) in RBTree.entries(found)) switch (toPrincipal(keytype)) {
        case (?p) fast := RBTree.insert(fast, Principal.compare, p, valtype);
        case _ ();
      };
      fast;
    };
    case _ default;
  };

  public func getUniquePrincipals(metadata : Metadata, key : Text, default : RBTree.RBTree<Principal, ()>) : RBTree.RBTree<Principal, ()> = switch (metaArray(metadata, key)) {
    case (?vs) {
      var fast = RBTree.empty<Principal, ()>();
      for (v in vs.vals()) switch (toPrincipal(v)) {
        case (?p) fast := RBTree.insert(fast, Principal.compare, p, ());
        case _ ();
      };
      fast;
    };
    case _ default;
  };

  public func getUniqueTexts(metadata : Metadata, key : Text, default : RBTree.RBTree<Text, ()>) : RBTree.RBTree<Text, ()> = switch (metaArray(metadata, key)) {
    case (?vs) {
      var rb3 = RBTree.empty<Text, ()>();
      for (v in vs.vals()) switch v {
        case (#Text t) rb3 := RBTree.insert(rb3, Text.compare, t, ());
        case _ ();
      };
      rb3;
    };
    case _ default;
  };

  public func getArray(metadata : Metadata, key : Text, default : [Type]) : [Type] = switch (metaArray(metadata, key)) {
    case (?n) n;
    case _ default;
  };

  public func getNat(metadata : Metadata, key : Text, default : Nat) : Nat = switch (metaNat(metadata, key)) {
    case (?n) n;
    case _ default;
  };

  public func getNat64(metadata : Metadata, key : Text, default : Nat64) : Nat64 = switch (metaNat(metadata, key)) {
    case (?n) Nat64.fromNat(n);
    case _ default;
  };

  public func getText(metadata : Metadata, key : Text, default : Text) : Text = switch (metaText(metadata, key)) {
    case (?t) t;
    case _ default;
  };

  public func getBlob(meta : Metadata, key : Text, default : Blob) : Blob = switch (metaBlob(meta, key)) {
    case (?b) b;
    case _ default;
  };

  public func getBool(metadata : Metadata, key : Text, default : Bool) : Bool = switch (metaBool(metadata, key)) {
    case (?b) b;
    case _ default;
  };

  public func getAccount(metadata : Metadata, key : Text, default : Account.Pair) : Account.Pair = switch (metaAccount(metadata, key)) {
    case (?a) a;
    case _ default;
  };

  public func ofAccount(a : Account.Pair) : Type {
    let owner = Principal.toBlob(a.owner);
    let owner_val = #Blob owner;
    #Array(
      switch (a.subaccount) {
        case (?found) [owner_val, #Blob found];
        case _ [owner_val];
      }
    );
  };

  public func ofAccountP(a : Account.Pair) : Type {
    let owner = #Principal(a.owner);
    #Array(
      switch (a.subaccount) {
        case (?found) [owner, #Blob found];
        case _ [owner];
      }
    );
  };

  // todo: revert to use digest
  public func hash(val : Type) : Blob {
    var q = Queue.empty<Iter.Iter<Nat8>>();
    switch val {
      case (#Nat n) q := Queue.insertHead(q, QueueLeb128.iterNat(n));
      case (#Int i) q := Queue.insertHead(q, QueueLeb128.iterInt(i));
      case (#Text t) q := Queue.insertHead(q, Text.encodeUtf8(t).vals());
      case (#Blob b) q := Queue.insertHead(q, b.vals());
      case (#Array arr) for (v in arr.vals()) q := Queue.insertHead(q, hash(v).vals());
      case (#Map map) {
        var hashes = RBTree.empty<Blob, Blob>();
        for ((k, v) in map.vals()) {
          let keyHash = Hasher.sha256([Text.encodeUtf8(k).vals()].vals());
          let valueHash = hash(v);
          hashes := RBTree.insert(hashes, Blob.compare, keyHash, valueHash);
        };
        // hashes are already sorted thru Blob.compare
        for ((kh, vh) in RBTree.entries(hashes)) {
          q := Queue.insertHead(q, kh.vals());
          q := Queue.insertHead(q, vh.vals());
        };
      };
      case (#Bool b) q := Queue.insertHead(q, QueueLeb128.iterNat(if (b) 1 else 0));
      case (#Principal p) q := Queue.insertHead(q, Principal.toBlob(p).vals());
      case (#ValueMap map) {
        var hashes = RBTree.empty<Blob, Blob>();
        for ((k, v) in map.vals()) {
          let keyHash = hash(k);
          let valueHash = hash(v);
          hashes := RBTree.insert(hashes, Blob.compare, keyHash, valueHash);
        };
        // hashes are already sorted thru Blob.compare
        for ((kh, vh) in RBTree.entries(hashes)) {
          q := Queue.insertHead(q, kh.vals());
          q := Queue.insertHead(q, vh.vals());
        };
      };
    };
    Hasher.sha256(Queue.iterTail(q));
  };

  // todo: revert to use digest
  public func hashMeta(meta_iter : { next() : ?(Text, Type) }) : Blob {
    var hashes = RBTree.empty<Blob, Blob>();
    for ((k, v) in meta_iter) {
      let keyHash = Hasher.sha256([Text.encodeUtf8(k).vals()].vals());
      let valueHash = hash(v);
      hashes := RBTree.insert(hashes, Blob.compare, keyHash, valueHash);
    };
    // hashes are already sorted thru Blob.compare
    var q = Queue.empty<Iter.Iter<Nat8>>();
    for ((kh, vh) in RBTree.entries(hashes)) {
      q := Queue.insertHead(q, kh.vals());
      q := Queue.insertHead(q, vh.vals());
    };
    Hasher.sha256(Queue.iterTail(q));
  };
};
