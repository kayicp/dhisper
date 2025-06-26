import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import O "mo:base/Order";

import Rb "Tree";

/// this is a wrapper for my tree
module {
	type Size = Nat;
	public type RBTree<K, V> = (rb3 : Rb.Tree<K, V>, rb3_size : Size);

	public func empty<K, V>() : RBTree<K, V> = (Rb.empty(), 0);

	public func fromArray<K, V>(arr : [(K, V)], comparer : (K, K) -> O.Order) : RBTree<K, V> = insertArray(empty(), arr, comparer);

	public func insertArray<K, V>(t : RBTree<K, V>, arr : [(K, V)], comparer : (K, K) -> O.Order) : RBTree<K, V> {
		var fast = t;
		for ((k, v) in arr.vals()) fast := insert(fast, comparer, k, v);
		fast;
	};

	public func fromSet<K>(arr : [K], comparer : (K, K) -> O.Order) : RBTree<K, ()> {
		var fast = empty<K, ()>();
		for (k in arr.vals()) fast := insert(fast, comparer, k, ());
		fast;
	};

	public func size<K, V>((_, rb3_size) : RBTree<K, V>) : Size = rb3_size;
	public func tree<K, V>((rb3, _) : RBTree<K, V>) : Rb.Tree<K, V> = rb3;

	public func insert<K, V>((rb3, rb3_size) : RBTree<K, V>, comparer : (K, K) -> O.Order, key : K, value : V) : RBTree<K, V> {
		let (is_new, new_tree) = Rb.insert(rb3, comparer, key, value);
		(
			new_tree,
			if (is_new) rb3_size + 1 else rb3_size,
		);
	};

	public func max<K, V>((rb3, _) : RBTree<K, V>) : ?(K, V) = Rb.max(rb3);

	public func maxKey<K, V>(t : RBTree<K, V>) : ?K = switch (max(t)) {
		case (?(k, _)) ?k;
		case _ null;
	};

	func afterDelete<K, V>(fast_size : Nat, after_delete : (?(K, V), Rb.Tree<K, V>)) : RBTree<K, V> {
		let (deleted, new_tree) = after_delete;
		(
			new_tree,
			switch deleted {
				case (?_value) fast_size - 1;
				case _ fast_size;
			},
		);
	};

	public func deleteMax<K, V>((rb3, rb3_size) : RBTree<K, V>) : RBTree<K, V> = afterDelete(rb3_size, Rb.deleteMax(rb3));

	public func min<K, V>((rb3, _) : RBTree<K, V>) : ?(K, V) = Rb.min(rb3);

	public func minKey<K, V>(t : RBTree<K, V>) : ?K = switch (min(t)) {
		case (?(k, _)) ?k;
		case _ null;
	};

	public func deleteMin<K, V>((rb3, rb3_size) : RBTree<K, V>) : RBTree<K, V> = afterDelete(rb3_size, Rb.deleteMin(rb3));

	public func delete<K, V>((rb3, rb3_size) : RBTree<K, V>, comparer : (K, K) -> O.Order, key : K) : RBTree<K, V> = afterDelete(rb3_size, Rb.delete(rb3, comparer, key));

	public func get<K, V>((rb3, _) : RBTree<K, V>, comparer : (K, K) -> O.Order, key : K) : ?V = Rb.get(rb3, comparer, key);

	public func right<K, V>((rb3, _) : RBTree<K, V>, comparer : (K, K) -> O.Order, key : K) : ?(K, V) = Rb.near(rb3, comparer, #Right, key);

	public func left<K, V>((rb3, _) : RBTree<K, V>, comparer : (K, K) -> O.Order, key : K) : ?(K, V) = Rb.near(rb3, comparer, #Left, key);

	public func has<K, V>((rb3, _) : RBTree<K, V>, comparer : (K, K) -> O.Order, key : K) : Bool = Rb.has(rb3, comparer, key);

	// public type ScanResult<K, V> = Rb.ScanResult<K, V>;

	// public func scan<K, V>(fast : RBTree<K, V>, comparer : (K, K) -> O.Order, limit : Nat, from_key : ?K) : ScanResult<K, V> {
	//   return Rb.scan(fast.tree, limit, #Fwd, comparer, from_key);
	// };

	// public func scanReverse<K, V>(fast : RBTree<K, V>, comparer : (K, K) -> O.Order, limit : Nat, from_key : ?K) : ScanResult<K, V> {
	//   return Rb.scan(fast.tree, limit, #Bwd, comparer, from_key);
	// };

	public func entries<K, V>((rb3, _) : RBTree<K, V>) : Iter.Iter<(K, V)> = Rb.iter(rb3, #Fwd);

	public func entriesReverse<K, V>((rb3, _) : RBTree<K, V>) : Iter.Iter<(K, V)> = Rb.iter(rb3, #Bwd);

	public func array<K, V>((rb3, rb3_size) : RBTree<K, V>) : [(K, V)] {
		let buffer = Buffer.Buffer<(K, V)>(rb3_size);
		for (node in entries((rb3, rb3_size))) buffer.add(node);
		Buffer.toArray(buffer);
	};

	// public func arrayReverse<K, V>((rb3, rb3_size) : RBTree<K, V>) : [(K, V)] {
	//   let buffer = Buffer.Buffer<(K, V)>(rb3_size);
	//   for (kv in entriesReverse((rb3, rb3_size))) buffer.add(kv);
	//   Buffer.toArray(buffer);
	// };

	public func arrayValue<K, V>((rb3, rb3_size) : RBTree<K, V>) : [V] {
		let buffer = Buffer.Buffer<V>(rb3_size);
		for ((_, v) in entries((rb3, rb3_size))) buffer.add(v);
		Buffer.toArray(buffer);
	};

	public func arrayKey<K, V>((rb3, rb3_size) : RBTree<K, V>) : [K] {
		let buffer = Buffer.Buffer<K>(rb3_size);
		for ((k, _) in entries((rb3, rb3_size))) buffer.add(k);
		Buffer.toArray(buffer);
	};

	// public func arrayValueReverse<K, V>((rb3, rb3_size) : RBTree<K, V>) : [V] {
	//   let buffer = Buffer.Buffer<V>(rb3_size);
	//   for ((_, v) in entriesReverse((rb3, rb3_size))) buffer.add(v);
	//   Buffer.toArray(buffer);
	// };

	// public func arrayKeyReverse<K, V>((rb3, rb3_size) : RBTree<K, V>) : [K] {
	//   let buffer = Buffer.Buffer<K>(rb3_size);
	//   for ((k, _) in entriesReverse((rb3, rb3_size))) buffer.add(k);
	//   Buffer.toArray(buffer);
	// };

	public func void<K, V>((rb3, rb3_size) : RBTree<K, V>, comparer : (K, K) -> O.Order, prev : ?K, take : Nat, fn : (K, V) -> ()) {
		Rb.void(rb3, Nat.min(take, rb3_size), #Fwd, comparer, prev, fn);
	};

	public func page<K, V>((rb3, rb3_size) : RBTree<K, V>, comparer : (K, K) -> O.Order, prev : ?K, take : Nat) : [(K, V)] {
		let real_take = Nat.min(take, rb3_size);
		let buffer = Buffer.Buffer<(K, V)>(real_take);
		void((rb3, rb3_size), comparer, prev, real_take, func(k : K, v : V) = buffer.add(k, v));
		Buffer.toArray(buffer);
	};

	public func pageKey<K, V>((rb3, rb3_size) : RBTree<K, V>, comparer : (K, K) -> O.Order, prev : ?K, take : Nat) : [K] {
		let real_take = Nat.min(take, rb3_size);
		let buffer = Buffer.Buffer<K>(real_take);
		void((rb3, rb3_size), comparer, prev, real_take, func(k : K, _ : V) = buffer.add(k));
		Buffer.toArray(buffer);
	};

	public func pageValue<K, V>((rb3, rb3_size) : RBTree<K, V>, comparer : (K, K) -> O.Order, prev : ?K, take : Nat) : [V] {
		let real_take = Nat.min(take, rb3_size);
		let buffer = Buffer.Buffer<V>(real_take);
		void((rb3, rb3_size), comparer, prev, real_take, func(_ : K, v : V) = buffer.add(v));
		Buffer.toArray(buffer);
	};

	public func voidReverse<K, V>((rb3, rb3_size) : RBTree<K, V>, comparer : (K, K) -> O.Order, prev : ?K, take : Nat, fn : (K, V) -> ()) {
		Rb.void(rb3, Nat.min(take, rb3_size), #Bwd, comparer, prev, fn);
	};
	// todo: remove all real_take
	public func pageKeyReverse<K, V>((rb3, rb3_size) : RBTree<K, V>, comparer : (K, K) -> O.Order, prev : ?K, take : Nat) : [K] {
		let real_take = Nat.min(take, rb3_size);
		let buffer = Buffer.Buffer<K>(real_take);
		voidReverse((rb3, rb3_size), comparer, prev, real_take, func(k : K, _ : V) = buffer.add(k));
		Buffer.toArray(buffer);
	};

	public func pageValueReverse<K, V>((rb3, rb3_size) : RBTree<K, V>, comparer : (K, K) -> O.Order, prev : ?K, take : Nat) : [V] {
		let real_take = Nat.min(take, rb3_size);
		let buffer = Buffer.Buffer<V>(real_take);
		voidReverse((rb3, rb3_size), comparer, prev, real_take, func(_ : K, v : V) = buffer.add(v));
		Buffer.toArray(buffer);
	};

	// public func pageReverse<K, V>(fast : RBTree<K, V>, comparer : (K, K) -> O.Order, prev : ?K, take : ?Nat) : [(K, V)] {
	//   let real_take = switch take {
	//     case (?take) take;
	//     case _ fast.size;
	//   };
	//   let buffer = Buffer.Buffer<(K, V)>(real_take);
	//   let fn = func(k : K, v : V) = buffer.add(k, v);
	//   Rb.void(fast.tree, real_take, #Bwd, comparer, prev, fn);
	//   Buffer.toArray(buffer);
	// };

	// public func pageKeyReverse<K, V>(fast : RBTree<K, V>, comparer : (K, K) -> O.Order, prev : ?K, take : ?Nat) : [K] {
	//   let real_take = switch take {
	//     case (?take) take;
	//     case _ fast.size;
	//   };
	//   let buffer = Buffer.Buffer<K>(real_take);
	//   let fn = func(k : K, v : V) = buffer.add(k);
	//   Rb.void(fast.tree, real_take, #Bwd, comparer, prev, fn);
	//   Buffer.toArray(buffer);
	// };

	// public func pageValueReverse<K, V>(fast : RBTree<K, V>, comparer : (K, K) -> O.Order, prev : ?K, take : ?Nat) : [V] {
	//   let real_take = switch take {
	//     case (?take) take;
	//     case _ fast.size;
	//   };
	//   let buffer = Buffer.Buffer<V>(real_take);
	//   let fn = func(k : K, v : V) = buffer.add(v);
	//   Rb.void(fast.tree, real_take, #Bwd, comparer, prev, fn);
	//   Buffer.toArray(buffer);
	// };

	public func family<K, V>((rb3, _) : RBTree<K, V>, comparer : (K, K) -> O.Order, k : K) : ?Rb.Family<K> {
		Rb.family(rb3, comparer, k);
	};
};
