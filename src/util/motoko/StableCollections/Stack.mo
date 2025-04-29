import Buffer "mo:base/Buffer";
import Deque "mo:base/Deque";
import Iter "mo:base/Iter";
import List "mo:base/List";

module {
  public type Stack<V> = (d : Deque.Deque<V>, size : Nat);

  public func empty<V>() : Stack<V> = (Deque.empty(), 0);

  public func insertTop<V>((d, d_size) : Stack<V>, value : V) : Stack<V> = (Deque.pushBack(d, value), d_size + 1);

  public func deleteTop<V>((d, d_size) : Stack<V>) : Stack<V> = switch (Deque.popBack(d)) {
    case (?(stack, _)) (stack, d_size - 1);
    case _ (d, d_size);
  };

  public func seeTop<V>((d, _) : Stack<V>) : ?V = Deque.peekBack(d);

  func combineRecurse<V>(btm : List.List<V>, top : List.List<V>) : List.List<V> = switch btm {
    case (?(value, null)) ?(value, top);
    case (?(value, list)) ?(value, combineRecurse(list, top));
    case _ top;
  };

  public func iterBottom<V>(((tail, head), _) : Stack<V>) : Iter.Iter<V> {
    let combined = combineRecurse(tail, List.reverse(head));
    List.toIter(combined);
  };

  public func arrayBottom<V>((d, d_size) : Stack<V>) : [V] {
    let buffer = Buffer.Buffer<V>(d_size);
    for (v in iterBottom((d, d_size))) buffer.add(v);
    Buffer.toArray(buffer);
  };
};
