module {
  public func root(n : Nat) : Nat {
    if (n < 2) return n;

    var left = 1;
    var right = n / 2;

    while (left <= right) {
      let mid = (left + right) / 2;
      let mid_sqr = mid * mid;
      if (mid_sqr < n) {
        left := mid + 1;
      } else if (mid_sqr > n) {
        right := mid - 1;
      } else return mid;
    };

    return right;
  };
};
