module {
	public class Class() {
		var count = 0;
		public func plus(n : Nat) = count += n;
		public func get() : Nat = count;
	};
};
