import Array "mo:base/Array";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";

import Queue "StableCollections/Queue";
// reference:
// https://github.com/edjCase/motoko_numbers/blob/main/src/NatX.mo

module {
  func natToLeastSignificantBits(value : Nat, byteLength : Nat, hasSign : Bool) : [Bool] {
    // let buffer = Buffer.Buffer<Bool>(64);
    var queue = Queue.empty<Bool>();
    var remainingValue : Nat = value;
    while (remainingValue > 0) {
      let bit : Bool = remainingValue % 2 == 1;
      // buffer.add(bit);
      queue := Queue.insertHead(queue, bit);
      remainingValue /= 2;
    };
    while (Queue.size(queue) % byteLength != 0) {
      // buffer.add(false); // Pad 0's for full byte
      queue := Queue.insertHead(queue, false);
    };
    if (hasSign) {
      let mostSignificantBit : Bool = // buffer.get(buffer.size() - 1);
      switch (Queue.seeHead(queue)) {
        case (?found) found;
        case _ false;
      };

      if (mostSignificantBit) {
        // If most significant bit is a 1, overflow to another byte
        for (i in Iter.range(1, byteLength)) {
          // buffer.add(false);
          queue := Queue.insertHead(queue, false);
        };
      };

    };
    // Least Sigficant Bit first
    // Buffer.toArray(buffer);
    Queue.arrayTail(queue);
  };

  func invariableLengthBytesEncode(queue : Queue.Queue<Nat8>, bits : [Bool]) : Queue.Queue<Nat8> {
    let byteCount : Nat = (bits.size() / 7) + (if (bits.size() % 7 != 0) 1 else 0); // 7, not 8, the 8th bit is to indicate end of number

    var q = queue;
    label f for (byteIndex in Iter.range(0, byteCount - 1)) {
      var byte : Nat8 = 0;
      for (bitOffset in Iter.range(0, 6)) {
        let bit : Bool = bits[byteIndex * 7 + bitOffset];
        if (bit) {
          // Set bit
          byte := Nat8.bitset(byte, bitOffset);
        };
      };
      let hasMoreBits = bits.size() > (byteIndex + 1) * 7;
      if (hasMoreBits) {
        // Have most left of byte be 1 if there is another byte
        byte := Nat8.bitset(byte, 7);
      };
      // buffer.add(byte);
      q := Queue.insertHead(q, byte);
    };
    q;
  };

  public func twosCompliment(bits : [Bool]) : [Bool] {
    // Ones compliment, flip all bits
    let flippedBits = Array.map(bits, func(b : Bool) : Bool { not b });

    // Twos compliment, add 1
    let lastIndex : Nat = flippedBits.size() - 1;
    let varBits : [var Bool] = Array.thaw(flippedBits);

    // Loop through adding 1 to the LSB, and carry the 1 if neccessary
    label l for (n in Iter.range(0, lastIndex)) {
      varBits[n] := not varBits[n]; // flip
      if (varBits[n]) {
        // If flipped to 1, end
        break l;
      } else {
        // If flipped to 0, carry the one till the first 0
      };
    };
    Array.freeze(varBits);
  };

  public func encodeNat(queue : Queue.Queue<Nat8>, value : Nat) : Queue.Queue<Nat8> {
    if (value == 0) {
      // buffer.add(0);
      return Queue.insertHead(queue, 0 : Nat8);
    };
    // Unsigned LEB128 - https://en.wikipedia.org/wiki/LEB128#Unsigned_LEB128
    //       10011000011101100101  In raw binary
    //      010011000011101100101  Padded to a multiple of 7 bits
    //  0100110  0001110  1100101  Split into 7-bit groups
    // 00100110 10001110 11100101  Add high 1 bits on all but last (most significant) group to form bytes
    let bits : [Bool] = natToLeastSignificantBits(value, 7, false);

    invariableLengthBytesEncode(queue, bits);
  };

  public func encodeInt(queue : Queue.Queue<Nat8>, value : Int) : Queue.Queue<Nat8> {
    if (value == 0) {
      // buffer.add(0);
      return Queue.insertHead(queue, 0 : Nat8);
    };
    // Signed LEB128 - https://en.wikipedia.org/wiki/LEB128#Signed_LEB128
    //          11110001001000000  Binary encoding of 123456
    //    00001_11100010_01000000  As a 21-bit number (multiple of 7)
    //    11110_00011101_10111111  Negating all bits (one's complement)
    //    11110_00011101_11000000  Adding one (two's complement) (Binary encoding of signed -123456)
    //  1111000  0111011  1000000  Split into 7-bit groups
    // 01111000 10111011 11000000  Add high 1 bits on all but last (most significant) group to form bytes
    let positiveValue = Int.abs(value);
    var bits : [Bool] = natToLeastSignificantBits(positiveValue, 7, true);
    if (value < 0) {
      // If negative, then get twos compliment
      bits := twosCompliment(bits);
    };
    invariableLengthBytesEncode(queue, bits);
  };

  public func initNat(n : Nat) : Queue.Queue<Nat8> = encodeNat(Queue.empty<Nat8>(), n);
  public func iterNat(n : Nat) : Iter.Iter<Nat8> = Queue.iterTail(initNat(n));

  public func initInt(i : Int) : Queue.Queue<Nat8> = encodeInt(Queue.empty<Nat8>(), i);
  public func iterInt(i : Int) : Iter.Iter<Nat8> = Queue.iterTail(initInt(i));

  /// Decodes a Nat from a byte iterator using unsigned LEB128 encoding.
  ///
  /// ```motoko
  /// let bytes : [Nat8] = [0xE5, 0x8E, 0x26]; // 624485 in unsigned LEB128
  /// let result = NatX.decodeNat(bytes.vals(), #unsignedLEB128);
  /// switch (result) {
  ///   case (null) { /* Decoding error */ };
  ///   case (?value) { /* value is 624485 */ };
  /// };
  /// ```
  // public func decodeNat(bytes : Iter.Iter<Nat8>, _ : { #unsignedLEB128 }) : ?Nat {
  //   do ? {
  //     var v : Nat = 0;
  //     var i : Nat = 0;
  //     label l loop {
  //       let byte : Nat8 = bytes.next()!;
  //       v += Nat8.toNat(byte & 0x7f) * Nat.pow(2, 7 * i); // Shift over 7 * i bits to get value to add, ignore first bit
  //       i += 1;
  //       let hasNextByte = (byte & 0x80) == 0x80; // If starts with a 1, there is another byte
  //       if (not hasNextByte) {
  //         break l;
  //       };
  //     };
  //     v;
  //   };
  // };

  /// Decodes an Int from a byte iterator using signed LEB128 encoding.
  ///
  /// ```motoko
  /// let bytes : [Nat8] = [0xc6, 0xf5, 0x08]; // -123456 in signed LEB128
  /// let result = IntX.decodeInt(bytes.vals(), #signedLEB128);
  /// switch (result) {
  ///   case (null) { /* Decoding error */ };
  ///   case (?value) { /* value is -123456 */ };
  /// };
  /// ```
  // public func decodeInt(bytes : Iter.Iter<Nat8>, encoding : { #signedLEB128 }) : ?Int {
  //   do ? {
  //     switch (encoding) {
  //       case (#signedLEB128) {
  //         var bits : [Bool] = Util.invariableLengthBytesDecode(bytes);
  //         let isNegative = bits[bits.size() - 1];
  //         if (isNegative) {
  //           // Reverse twos compliment
  //           bits := Util.reverseTwosCompliment(bits);
  //         };
  //         var i = 0;
  //         let int = Array.foldLeft<Bool, Int>(
  //           bits,
  //           0,
  //           func(accum : Int, bit : Bool) {
  //             let newAccum = if (bit) {
  //               accum + Nat.pow(2, i); // Shift over 7 * i bits to get value to add, ignore first bit
  //             } else {
  //               accum;
  //             };
  //             i += 1;
  //             newAccum;
  //           },
  //         );
  //         if (isNegative) {
  //           int * -1;
  //         } else {
  //           int;
  //         };
  //       };
  //     };
  //   };
  // };
};
