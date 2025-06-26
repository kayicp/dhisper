import I "mo:base/Iter";
import List "mo:base/List";
import Nat "mo:base/Nat";
import O "mo:base/Order";
import Counter "../../Counter";

module {
	public type Color = {
		#Wyt; // -1 black node
		#Red; //  0 black node
		#Blk; //  1 black node
		#Ngr; // +2 black node
	};

	public type Tree<K, V> = {
		#Empty; // 0 node
		#Negro; // 1 black node
		#Node : (
			Tree<K, V>, // left child
			(Color, K, V), // self: null deleted, take max of left child
			Tree<K, V>, // right child
		);
	};

	public func empty<K, V>() : Tree<K, V> = #Empty;

	func chrisOkasaki<K, V>(tree : Tree<K, V>) : Tree<K, V> {
		switch tree {
			case (#Node(#Node(#Node(a, (#Red, xk, xv), b), (#Red, yk, yv), c), (#Blk, zk, zv), d)) {
				// Debug.print(debug_show "oksk1: red < red < blk --------- blk < red > blk");
				return #Node(#Node(a, (#Blk, xk, xv), b), (#Red, yk, yv), #Node(c, (#Blk, zk, zv), d));
			};
			case (#Node(#Node(a, (#Red, xk, xv), #Node(b, (#Red, yk, yv), c)), (#Blk, zk, zv), d)) {
				// Debug.print(debug_show "oksk2: red(red) < blk --------- blk < red > blk");
				return #Node(#Node(a, (#Blk, xk, xv), b), (#Red, yk, yv), #Node(c, (#Blk, zk, zv), d));
			};
			case (#Node(a, (#Blk, xk, xv), #Node(#Node(b, (#Red, yk, yv), c), (#Red, zk, zv), d))) {
				// Debug.print(debug_show "oksk3: blk > (red)red --------- blk < red > blk");
				return #Node(#Node(a, (#Blk, xk, xv), b), (#Red, yk, yv), #Node(c, (#Blk, zk, zv), d));
			};
			case (#Node(a, (#Blk, xk, xv), #Node(b, (#Red, yk, yv), #Node(c, (#Red, zk, zv), d)))) {
				// Debug.print(debug_show "oksk4: blk > red > red --------- blk < red > blk");
				return #Node(#Node(a, (#Blk, xk, xv), b), (#Red, yk, yv), #Node(c, (#Blk, zk, zv), d));
			};
			case _ return tree;
		};
	};

	func mattMight<K, V>(tree : Tree<K, V>) : Tree<K, V> {
		switch tree {
			case (#Node(#Node(#Node(a, (#Red, xk, xv), b), (#Red, yk, yv), c), (#Ngr, zk, zv), d)) {
				// Debug.print(debug_show "might1: red < red < ngr --------- blk < blk > blk");
				return #Node(#Node(a, (#Blk, xk, xv), b), (#Blk, yk, yv), #Node(c, (#Blk, zk, zv), d));
			};
			case (#Node(#Node(a, (#Red, xk, xv), #Node(b, (#Red, yk, yv), c)), (#Ngr, zk, zv), d)) {
				// Debug.print(debug_show "might2: red(red) < ngr --------- blk < blk > blk");
				return #Node(#Node(a, (#Blk, xk, xv), b), (#Blk, yk, yv), #Node(c, (#Blk, zk, zv), d));
			};
			case (#Node(a, (#Ngr, xk, xv), #Node(#Node(b, (#Red, yk, yv), c), (#Red, zk, zv), d))) {
				// Debug.print(debug_show "might3: ngr > (red)red --------- blk < blk > blk");
				return #Node(#Node(a, (#Blk, xk, xv), b), (#Blk, yk, yv), #Node(c, (#Blk, zk, zv), d));
			};
			case (#Node(a, (#Ngr, xk, xv), #Node(b, (#Red, yk, yv), #Node(c, (#Red, zk, zv), d)))) {
				// Debug.print(debug_show "might4: ngr > red > red --------- blk < blk > blk");
				return #Node(#Node(a, (#Blk, xk, xv), b), (#Blk, yk, yv), #Node(c, (#Blk, zk, zv), d));
			};
			case (#Node(#Node(#Node(a, (#Blk, wk, wv), b), (#Wyt, xk, xv), #Node(c, (#Blk, yk, yv), d)), (#Ngr, zk, zv), e)) {
				// Debug.print("mightA: (blk < wyt > blk) < ngr --------- oksk(red < blk) < blk > blk");
				return #Node(chrisOkasaki(#Node(#Node(a, (#Red, wk, wv), b), (#Blk, xk, xv), c)), (#Blk, yk, yv), #Node(d, (#Blk, zk, zv), e));
			};
			case (#Node(a, (#Ngr, wk, wv), #Node(#Node(b, (#Blk, xk, xv), c), (#Wyt, yk, yv), #Node(d, (#Blk, zk, zv), e)))) {
				// Debug.print("mightB: ngr > (blk < wyt > blk) --------- blk < blk > oksk(blk > red)");
				return #Node(#Node(a, (#Blk, wk, wv), b), (#Blk, xk, xv), chrisOkasaki(#Node(c, (#Blk, yk, yv), #Node(d, (#Red, zk, zv), e))));
			};
			case _ return tree;
		};
	};

	func bubble<K, V>(tree : Tree<K, V>) : Tree<K, V> {
		switch tree {
			case (#Node(#Node(a, (#Blk, xk, xv), b), (#Red, yk, yv), #Negro)) {
				// Debug.print(debug_show "bubble1a: blk < red > negro --------- red < blk > empty");
				return #Node(#Node(a, (#Red, xk, xv), b), (#Blk, yk, yv), #Empty);
			};
			case (#Node(#Node(a, (#Blk, xk, xv), b), (#Blk, yk, yv), #Negro)) {
				// Debug.print(debug_show "bubble2a: blk < blk > negro --------- red < ngr > empty");
				return #Node(#Node(a, (#Red, xk, xv), b), (#Ngr, yk, yv), #Empty);
			};
			case (#Node(#Node(a, (#Red, xk, xv), b), (#Blk, yk, yv), #Negro)) {
				// Debug.print(debug_show "bubble3a: red < blk > negro --------- wyt < ngr > empty");
				return #Node(#Node(a, (#Wyt, xk, xv), b), (#Ngr, yk, yv), #Empty);
			};
			case (#Node(#Negro, (#Red, yk, yv), #Node(c, (#Blk, zk, zv), d))) {
				// Debug.print(debug_show "bubble1b: negro < red > blk --------- empty < blk > red");
				return #Node(#Empty, (#Blk, yk, yv), #Node(c, (#Red, zk, zv), d));
			};
			case (#Node(#Negro, (#Blk, yk, yv), #Node(c, (#Blk, zk, zv), d))) {
				// Debug.print(debug_show "bubble2b: negro < blk > blk --------- empty < ngr > red");
				return #Node(#Empty, (#Ngr, yk, yv), #Node(c, (#Red, zk, zv), d));
			};
			case (#Node(#Negro, (#Blk, yk, yv), #Node(c, (#Red, zk, zv), d))) {
				// Debug.print(debug_show "bubble3b: negro < blk > red --------- empty < ngr > wyt");
				return #Node(#Empty, (#Ngr, yk, yv), #Node(c, (#Wyt, zk, zv), d));
			};
			case (#Node(#Node(a, (#Blk, xk, xv), b), (#Red, yk, yv), #Node(c, (#Ngr, zk, zv), d))) {
				// Debug.print(debug_show "bubble1a!: blk < red > ngr --------- red < blk > blk");
				return #Node(#Node(a, (#Red, xk, xv), b), (#Blk, yk, yv), #Node(c, (#Blk, zk, zv), d));
			};
			case (#Node(#Node(a, (#Ngr, xk, xv), b), (#Red, yk, yv), #Node(c, (#Blk, zk, zv), d))) {
				// Debug.print(debug_show "bubble1b!: ngr < red > blk --------- blk < blk > red");
				return #Node(#Node(a, (#Blk, xk, xv), b), (#Blk, yk, yv), #Node(c, (#Red, zk, zv), d));
			};
			case (#Node(#Node(a, (#Blk, xk, xv), b), (#Blk, yk, yv), #Node(c, (#Ngr, zk, zv), d))) {
				// Debug.print(debug_show "bubble2a!: blk < blk > ngr --------- red < ngr > blk");
				return #Node(#Node(a, (#Red, xk, xv), b), (#Ngr, yk, yv), #Node(c, (#Blk, zk, zv), d));
			};
			case (#Node(#Node(a, (#Ngr, xk, xv), b), (#Blk, yk, yv), #Node(c, (#Blk, zk, zv), d))) {
				// Debug.print(debug_show "bubble2b!: ngr < blk > blk --------- blk < ngr > red");
				return #Node(#Node(a, (#Blk, xk, xv), b), (#Ngr, yk, yv), #Node(c, (#Red, zk, zv), d));
			};
			case (#Node(#Node(a, (#Red, xk, xv), b), (#Blk, yk, yv), #Node(c, (#Ngr, zk, zv), d))) {
				// Debug.print(debug_show "bubble3a!: red < blk > ngr --------- wyt < ngr > blk");
				return #Node(#Node(a, (#Wyt, xk, xv), b), (#Ngr, yk, yv), #Node(c, (#Blk, zk, zv), d));
			};
			case (#Node(#Node(a, (#Ngr, xk, xv), b), (#Blk, yk, yv), #Node(c, (#Red, zk, zv), d))) {
				// Debug.print(debug_show "bubble3b!: ngr < blk > red --------- blk < ngr > wyt");
				return #Node(#Node(a, (#Blk, xk, xv), b), (#Ngr, yk, yv), #Node(c, (#Wyt, zk, zv), d));
			};
			case _ return tree;
		};
	};

	func insertRecursive<K, V>(new_key : K, comparer : (K, K) -> O.Order, new_value : V, old_tree : Tree<K, V>) : (Bool, Tree<K, V>) {
		switch old_tree {
			case (#Node(old_left, (color, old_key, old_value), old_right)) {
				let node = (color, old_key, old_value);
				switch (comparer(new_key, old_key)) {
					case (#less) {
						let (is_new, new_left) = insertRecursive(new_key, comparer, new_value, old_left);
						return (is_new, chrisOkasaki(#Node(new_left, node, old_right)));
					};
					case (#equal) return (false, #Node(old_left, (color, old_key, new_value), old_right)); // update
					case (#greater) {
						let (is_new, new_right) = insertRecursive(new_key, comparer, new_value, old_right);
						return (is_new, chrisOkasaki(#Node(old_left, node, new_right)));
					};
				};
			};
			case _ return (true, #Node(#Empty, (#Red, new_key, new_value), #Empty));
		};
	};

	public func insert<K, V>(old_tree : Tree<K, V>, comparer : (K, K) -> O.Order, new_key : K, new_value : V) : (Bool, Tree<K, V>) {
		switch (insertRecursive(new_key, comparer, new_value, old_tree)) {
			case (is_new, #Node(left, (_, key, value), right)) return (is_new, #Node(left, (#Blk, key, value), right));
			case _ return (false, old_tree);
		};
	};

	public func max<K, V>(tree : Tree<K, V>) : ?(K, V) {
		switch tree {
			case (#Node(_, (_, k, v), #Empty)) ?(k, v);
			case (#Node(_, _, right)) max(right);
			case _ null;
		};
	};

	public func deleteMax<K, V>(tree : Tree<K, V>) : (?(K, V), Tree<K, V>) {
		switch tree {
			case (#Node(#Empty, (#Red, k, v), #Empty)) {
				// Debug.print(debug_show "deleteMax red");
				return (?(k, v), #Empty);
			};
			case (#Node(#Empty, (#Blk, k, v), #Empty)) {
				// Debug.print(debug_show "deleteMax blk");
				return (?(k, v), #Negro);
			};
			case (#Node(#Node(l, (#Red, wk, wv), #Empty), (#Blk, xk, xv), #Empty)) {
				// Debug.print(debug_show "deleteMax red < blk");
				return (?(xk, xv), #Node(l, (#Blk, wk, wv), #Empty));
			};
			case (#Node(l, kv, r)) {
				// Debug.print(debug_show "deleteMax -->");
				let (max_kv, max_r) = deleteMax(r);
				return (max_kv, mattMight(chrisOkasaki(bubble(#Node(l, kv, max_r)))));
			};
			case _ return (null, tree);
		};
	};

	public func min<K, V>(tree : Tree<K, V>) : ?(K, V) {
		switch tree {
			case (#Node(#Empty, (_, k, v), _)) ?(k, v);
			case (#Node(left, _, _)) min(left);
			case _ null;
		};
	};

	public func deleteMin<K, V>(tree : Tree<K, V>) : (?(K, V), Tree<K, V>) {
		switch tree {
			case (#Node(#Empty, (#Red, k, v), #Empty)) {
				// Debug.print(debug_show "deleteMin red");
				return (?(k, v), #Empty);
			};
			case (#Node(#Empty, (#Blk, k, v), #Empty)) {
				// Debug.print(debug_show "deleteMin blk");
				return (?(k, v), #Negro);
			};
			case (#Node(#Empty, (#Blk, xk, xv), #Node(#Empty, (#Red, yk, yv), r))) {
				// Debug.print(debug_show "deleteMin blk > red");
				return (?(xk, xv), #Node(#Empty, (#Blk, yk, yv), r));
			};
			case (#Node(l, kv, r)) {
				// Debug.print(debug_show "<-- deleteMin");
				let (min_kv, min_l) = deleteMin(l);
				return (min_kv, mattMight(chrisOkasaki(bubble(#Node(min_l, kv, r)))));
			};
			case _ return (null, tree);
		};
	};

	func deleteRecursive<K, V>(key : K, comparer : (K, K) -> O.Order, old_tree : Tree<K, V>) : (?(K, V), Tree<K, V>) {
		switch old_tree {
			case (#Node(old_left, (color, old_key, old_value), old_right)) {
				let node = (color, old_key, old_value);
				switch (comparer(key, old_key)) {
					case (#less) {
						// Debug.print(debug_show "<--");
						let (deleted, new_left) = deleteRecursive(key, comparer, old_left);
						return (deleted, mattMight(chrisOkasaki(bubble(#Node(new_left, node, old_right)))));
					};
					case (#equal) {
						// Debug.print(debug_show "found!");
						let new_tree = switch (old_left, color, old_right) {
							// no children
							case (#Empty, #Red, #Empty) {
								// Debug.print(debug_show "empty");
								#Empty;
							};
							case (#Empty, #Blk, #Empty) {
								// Debug.print(debug_show "negro");
								#Negro;
							};
							// 1 children
							case (#Node(l, (#Red, k, v), r), #Blk, #Empty) {
								// Debug.print(debug_show "1 child left");
								#Node(l, (#Blk, k, v), r);
							};
							case (#Empty, #Blk, #Node(l, (#Red, k, v), r)) {
								// Debug.print(debug_show "1 child right");
								#Node(l, (#Blk, k, v), r);
							};
							// 2 children
							case (#Node l, #Red, #Node r) {
								// Debug.print(debug_show "red 2 children");
								let (maxkv, maxl) = deleteMax(#Node l);
								switch (maxkv) {
									case (?(maxk, maxv)) mattMight(chrisOkasaki(bubble(#Node(maxl, (#Red, maxk, maxv), #Node r))));
									case _ old_tree;
								};
							};
							case (#Node l, #Blk, #Node r) {
								// Debug.print(debug_show "blk 2 children");
								let (maxkv, maxl) = deleteMax(#Node l);
								switch (maxkv) {
									case (?(maxk, maxv)) mattMight(chrisOkasaki(bubble(#Node(maxl, (#Blk, maxk, maxv), #Node r))));
									case _ old_tree;
								};
							};
							case _ {
								// Debug.print("unhandled cases");
								old_tree;
							};
						};

						return (?(old_key, old_value), new_tree);
					};
					case (#greater) {
						// Debug.print(debug_show "-->");
						let (deleted, new_right) = deleteRecursive(key, comparer, old_right);
						return (deleted, mattMight(chrisOkasaki(bubble(#Node(old_left, node, new_right)))));
					};
				};
			};
			case _ {
				// Debug.print("not found!");
				return (null, old_tree);
			};
		};
	};

	public func delete<K, V>(tree : Tree<K, V>, comparer : (K, K) -> O.Order, del_key : K) : (?(K, V), Tree<K, V>) {
		let (deleted, new_tree) = deleteRecursive(del_key, comparer, tree);
		switch (mattMight(chrisOkasaki(bubble(new_tree)))) {
			case (#Node(left, (_, key, value), right)) return (deleted, #Node(left, (#Blk, key, value), right));
			case _ return (deleted, #Empty);
		};
	};

	func getRecursive<K, V>(get_key : K, comparer : (K, K) -> O.Order, tree : Tree<K, V>) : Tree<K, V> {
		switch tree {
			case (#Node(left, (_color, key, _value), right)) {
				switch (comparer(get_key, key)) {
					case (#less) return getRecursive(get_key, comparer, left);
					case (#equal) return tree;
					case (#greater) return getRecursive(get_key, comparer, right);
				};
			};
			case _ tree;
		};
	};

	public func get<K, V>(tree : Tree<K, V>, comparer : (K, K) -> O.Order, get_key : K) : ?V {
		switch (getRecursive(get_key, comparer, tree)) {
			case (#Node(_, (_, _, value), _)) return ?value;
			case _ return null;
		};
	};

	public type Prefer = { #Left; #Right };

	func isOrdered<K, V>(min : K, test : K, max : K, comparer : (K, K) -> O.Order, prefer : Prefer) : Bool {
		let mintest = comparer(min, test);
		let maxtest = comparer(test, max);
		if (prefer == #Left) {
			(mintest == #less or mintest == #equal) and maxtest == #less;
		} else mintest == #less and (maxtest == #less or maxtest == #equal);
	};

	func nearRecursive<K, V>(get_key : K, comparer : (K, K) -> O.Order, prefer : Prefer, tree : Tree<K, V>) : Tree<K, V> {
		switch tree {
			case (#Node(left, (_, key, _value), right)) {
				switch (comparer(get_key, key)) {
					case (#less) switch (max(left)) {
						case (?(lmaxk, lmaxv)) if (isOrdered(lmaxk, get_key, key, comparer, prefer)) {
							if (prefer == #Left) #Node(#Empty, (#Blk, lmaxk, lmaxv), #Empty) else tree;
						} else nearRecursive(get_key, comparer, prefer, left);
						case _ if (prefer == #Left) left else tree;
					};
					case (#equal) tree;
					case (#greater) switch (min(right)) {
						case (?(rmink, rminv)) if (isOrdered(key, get_key, rmink, comparer, prefer)) {
							if (prefer == #Right) #Node(#Empty, (#Blk, rmink, rminv), #Empty) else tree;
						} else nearRecursive(get_key, comparer, prefer, right);
						case _ if (prefer == #Right) right else tree;
					};
				};
			};
			case _ tree;
		};
	};

	public func near<K, V>(tree : Tree<K, V>, comparer : (K, K) -> O.Order, prefer : Prefer, key : K) : ?(K, V) {
		switch (nearRecursive(key, comparer, prefer, tree)) {
			case (#Node(_, (_, near_key, value), _)) return ?(near_key, value);
			case _ return null;
		};
	};

	public type ColorKey<K> = (Color, K);

	public func root<K, V>(tree : Tree<K, V>) : ?ColorKey<K> {
		switch tree {
			case (#Node(_, (col, k, _), _)) return ?(col, k);
			case _ return null;
		};
	};

	public type Family<K> = {
		parent : ?ColorKey<K>;
		self : ColorKey<K>;
		children : (?ColorKey<K>, ?ColorKey<K>);
	};
	func familyRecursive<K, V>(child : K, comparer : (K, K) -> O.Order, tree : Tree<K, V>, link : ?Family<K>) : ?Family<K> {
		switch tree {
			case (#Node(left, (color, key, _value), right)) {
				let reslink = switch (comparer(child, key)) {
					case (#less) familyRecursive(child, comparer, left, link);
					case (#equal) return ?{
						parent = null;
						self = (color, key);
						children = (root(left), root(right));
					};
					case (#greater) familyRecursive(child, comparer, right, link);
				};

				return switch reslink {
					case (?res) switch (res.parent) {
						case (?_) ?res;
						case _ ?{ res with parent = ?(color, key) };
					};
					case _ null;
				};
			};
			case _ null;
		};
	};

	public func family<K, V>(tree : Tree<K, V>, comparer : (K, K) -> O.Order, key : K) : ?Family<K> {
		familyRecursive(key, comparer, tree, null);
	};

	public func height<K, V>(tree : Tree<K, V>) : Nat {
		switch tree {
			case (#Node(left, _, right)) return Nat.max(height(left), height(right)) + 1;
			case _ return 0;
		};
	};

	public func size<K, V>(tree : Tree<K, V>) : Nat {
		switch tree {
			case (#Node(left, _, right)) return size(left) + size(right) + 1;
			case _ return 0;
		};
	};

	public func has<K, V>(tree : Tree<K, V>, comparer : (K, K) -> O.Order, has_key : K) : Bool {
		switch (get(tree, comparer, has_key)) {
			case (?_found) return true;
			case _ return false;
		};
	};

	public func colorIssue<K, V>(tree : Tree<K, V>) : ?(K, K) {
		switch tree {
			case (#Node(_, (#Red, pk, _), #Node(_, (#Red, ck, _), _))) return ?(pk, ck); // red > red
			case (#Node(#Node(_, (#Red, ck, _), _), (#Red, pk, _), _)) return ?(pk, ck); // red < red
			case (#Node(_, (#Wyt or #Ngr, pk, _), _)) return ?(pk, pk); // illegal color
			case (#Node(_, (_, pk, _), #Node(_, (#Wyt or #Ngr, ck, _), _))) return ?(pk, ck); // illegal color
			case (#Node(#Node(_, (#Wyt or #Ngr, ck, _), _), (_, pk, _), _)) return ?(pk, ck); // illegal color
			case (#Node(l, _, r)) {
				switch (colorIssue(l)) {
					case (?found) return ?found;
					case _ return colorIssue(r);
				};
			};
			case _ return null;
		};
	};

	public type BlackHeight<K> = {
		#Black : Nat;
		#ExtraBlack : (Nat, K, Nat);
	};
	func blackHeightRecursive<K, V>(tree : Tree<K, V>, count : Nat) : BlackHeight<K> {
		switch tree {
			case (#Node(l, (#Blk, k, _), r)) {
				switch (blackHeightRecursive(l, count + 1)) {
					case (#Black(left_black)) {
						switch (blackHeightRecursive(r, count + 1)) {
							case (#Black(right_black)) {
								if (left_black == right_black) return #Black right_black;
								return #ExtraBlack(left_black, k, right_black);
							};
							case (#ExtraBlack(key)) return #ExtraBlack key;
						};
					};
					case (#ExtraBlack(key)) return #ExtraBlack key;
				};
			};
			case (#Node(l, (_, k, _), r)) {
				switch (blackHeightRecursive(l, count)) {
					case (#Black(left_black)) {
						switch (blackHeightRecursive(r, count)) {
							case (#Black(right_black)) {
								if (left_black == right_black) return #Black right_black;
								return #ExtraBlack(left_black, k, right_black);
							};
							case (#ExtraBlack(key)) return #ExtraBlack key;
						};
					};
					case (#ExtraBlack(key)) return #ExtraBlack key;
				};
			};
			case _ {
				return #Black count;
			};
		};
	};

	public func blackHeight<K, V>(tree : Tree<K, V>) : BlackHeight<K> {
		switch tree {
			case (#Node(l, (_, k, _), r)) {
				switch (blackHeightRecursive(l, 1)) {
					case (#Black(left_black)) {
						switch (blackHeightRecursive(r, 1)) {
							case (#Black(right_black)) {
								if (left_black == right_black) return #Black right_black;
								return #ExtraBlack(left_black, k, right_black);
							};
							case (#ExtraBlack(key)) return #ExtraBlack key;
						};
					};
					case (#ExtraBlack(key)) return #ExtraBlack key;
				};
			};
			case _ return #Black 1;
		};
	};

	public type Validity<K> = {
		#Valid;
		#Unsorted : (K, K);
		#ColorIssue : (K, K);
		#ExtraBlack : (Nat, K, Nat);
	};
	public func validity<K, V>(tree : Tree<K, V>, comparer : (K, K) -> O.Order) : Validity<K> {
		switch (min(tree)) {
			case (?(min_key, _)) {
				var previous = min_key;
				for ((current, _) in iter(tree, #Fwd)) {
					switch (comparer(previous, current)) {
						case (#greater) return #Unsorted(previous, current);
						case _ previous := current; // correct
					};
				};
			};
			case _ return #Valid;
		};

		switch (colorIssue(tree)) {
			case (?found) return #ColorIssue found;
			case _ {};
		};

		switch (blackHeight(tree)) {
			case (#Black(_)) {};
			case (#ExtraBlack k) return #ExtraBlack k;
		};

		return #Valid;
	};

	func voidRun<K, V>(step : Counter.Class, limit : Nat, k : K, v : V, brother : Tree<K, V>, direction : Direction, comparer : (K, K) -> O.Order, fn : (K, V) -> (), prev : ?K) : Bool {
		if (step.get() < limit) {
			fn(k, v);
			step.plus(1);
			if (step.get() < limit) {
				return voidRecursive(brother, step, limit, direction, comparer, fn, prev, true);
			};
		};
		return false;
	};

	func voidFirst<K, V>(child : Tree<K, V>, step : Counter.Class, limit : Nat, direction : Direction, comparer : (K, K) -> O.Order, fn : (K, V) -> (), prev : ?K, found : Bool, k : K, v : V, brother : Tree<K, V>) : Bool {
		if (voidRecursive(child, step, limit, direction, comparer, fn, prev, found)) {
			return voidRun(step, limit, k, v, brother, direction, comparer, fn, prev);
		};
		return false;
	};

	func voidRecursive<K, V>(tree : Tree<K, V>, step : Counter.Class, limit : Nat, direction : Direction, comparer : (K, K) -> O.Order, fn : (K, V) -> (), prev : ?K, found : Bool) : Bool {
		switch (tree, direction, found) {
			case (#Node(l, (_, k, v), r), #Fwd, false) {
				switch (
					switch prev {
						case (?key) comparer(key, k);
						case _ #less;
					}
				) {
					case (#less) return voidFirst(l, step, limit, direction, comparer, fn, prev, found, k, v, r);
					case (#equal) return voidRecursive(r, step, limit, direction, comparer, fn, prev, true);
					case (#greater) return voidRecursive(r, step, limit, direction, comparer, fn, prev, found);
				};
			};
			case (#Node(l, (_, k, v), r), #Bwd, false) {
				switch (
					switch prev {
						case (?key) comparer(key, k);
						case _ #greater;
					}
				) {
					case (#less) return voidRecursive(l, step, limit, direction, comparer, fn, prev, found);
					case (#equal) return voidRecursive(l, step, limit, direction, comparer, fn, prev, true);
					case (#greater) return voidFirst(r, step, limit, direction, comparer, fn, prev, found, k, v, l);
				};
			};
			case (#Node(l, (_, k, v), r), #Fwd, true) return voidFirst(l, step, limit, direction, comparer, fn, prev, found, k, v, r);
			case (#Node(l, (_, k, v), r), #Bwd, true) return voidFirst(r, step, limit, direction, comparer, fn, prev, found, k, v, l);
			case _ return true;
		};
	};

	public func void<K, V>(tree : Tree<K, V>, limit : Nat, direction : Direction, comparer : (K, K) -> O.Order, prev : ?K, fn : (K, V) -> ()) {
		ignore voidRecursive(tree, Counter.Class(), limit, direction, comparer, fn, prev, false);
	};

	public type Direction = { #Fwd; #Bwd };

	type IterRep<K, V> = List.List<{ #Tree : Tree<K, V>; #KV : (K, V) }>;

	public func iter<K, V>(tree : Tree<K, V>, direction : Direction) : I.Iter<(K, V)> {
		object {
			var trees : IterRep<K, V> = ?(#Tree(tree), null);
			public func next() : ?(K, V) {
				switch (direction, trees) {
					case (_, null) { null };
					case (_, ?(#Tree(#Empty or #Negro), ts)) {
						trees := ts;
						next();
					};
					case (_, ?(#KV(kv), ts)) {
						trees := ts;
						return ?kv;
					};
					case (#Fwd, ?(#Tree(#Node(l, (_, k, v), r)), ts)) {
						trees := ?(#Tree(l), ?(#KV(k, v), ?(#Tree(r), ts)));
						next();
					};
					case (#Bwd, ?(#Tree(#Node(l, (_, k, v), r)), ts)) {
						trees := ?(#Tree(r), ?(#KV(k, v), ?(#Tree(l), ts)));
						next();
					};
				};
			};
		};
	};
};
