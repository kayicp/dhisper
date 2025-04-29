import Buffer "mo:base/Buffer";
import Deque "mo:base/Deque";
import Iter "mo:base/Iter";
import List "mo:base/List";

module {
	public type Queue<V> = (d : Deque.Deque<V>, size : Nat);

	public func empty<V>() : Queue<V> = (Deque.empty(), 0);

	public func size<V>((_, d_size) : Queue<V>) : Nat = d_size;

	public func insertHead<V>((d, d_size) : Queue<V>, value : V) : Queue<V> = (Deque.pushBack(d, value), d_size + 1);

	public func deleteTail<V>((d, d_size) : Queue<V>) : Queue<V> = switch (Deque.popFront(d)) {
		case (?(_, queue)) (queue, d_size - 1);
		case _ (d, d_size);
	};

	public func seeHead<V>((d, _) : Queue<V>) : ?V = Deque.peekBack(d);

	public func seeTail<V>((d, _) : Queue<V>) : ?V = Deque.peekFront(d);

	func combineRecurse<V>(tail : List.List<V>, head : List.List<V>) : List.List<V> = switch tail {
		case (?(value, null)) ?(value, head);
		case (?(value, list)) ?(value, combineRecurse(list, head));
		case _ head;
	};

	public func iterTail<V>(((tail, head), _) : Queue<V>) : Iter.Iter<V> {
		let combined = combineRecurse(tail, List.reverse(head));
		List.toIter(combined);
	};

	public func arrayTail<V>((d, d_size) : Queue<V>) : [V] {
		let buffer = Buffer.Buffer<V>(d_size);
		for (v in iterTail((d, d_size))) buffer.add(v);
		Buffer.toArray(buffer);
	};
};
