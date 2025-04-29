import Nat "mo:base/Nat";
import Buffer "mo:base/Buffer";
import Option "Option";
module {
	public func cleanTake(query_size : Nat, max : ?Nat) : Nat = Nat.min(query_size, Option.fallback(max, query_size));

	public func buffer<T>(query_size : Nat, max : ?Nat) : {
		results : Buffer.Buffer<T>;
		take : Nat;
		isFull : () -> Bool;
		finalize : () -> [T];
		add : (T) -> ();
	} {
		let take = cleanTake(query_size, max);
		let results = Buffer.Buffer<T>(take);
		func isFull() : Bool = results.size() >= take;
		func add(t : T) = results.add(t);
		func finalize() : [T] = Buffer.toArray(results);
		{ results; take; isFull; finalize; add };
	};
};
