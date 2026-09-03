/-
Copyright (c) 2026 LOAM contributors. All rights reserved.
Released under Apache 2.0 license.
-/

/-!
# Minimal pure SHA-256

A self-contained SHA-256 implementation used by the historical-admission
prepare/verify qualification boundary. It exists so that source snapshot
fingerprints, destination base-state fingerprints, and candidate image
fingerprints can be bound inside the same process that reads the exact bytes,
without a second source read or an external process dependency.

The implementation follows FIPS 180-4. It carries no IO and no admission
semantics; admission decisions are made by callers.
-/

namespace Loam.Sha256

set_option autoImplicit false

private def kConstants : Array UInt32 :=
  #[0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]

private def initialHash : Array UInt32 :=
  #[0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]

private def rotr (x : UInt32) (n : UInt32) : UInt32 :=
  (x >>> n) ||| (x <<< (32 - n))

/-- Pad the message length (in bytes) to a whole number of 64-byte blocks. -/
private def paddedSize (byteCount : Nat) : Nat :=
  let base := byteCount + 1 + 8
  let blocks := (base + 63) / 64
  blocks * 64

/--
Build the 64-word message schedule for one block, given the padded virtual byte
view (zeros and the 0x80 marker are synthesized by `getByte`).
-/
private def scheduleFor (getByte : Nat → UInt8) (blockStart : Nat) : Array UInt32 :=
  let initial := ((List.range 16).map fun i =>
    let b0 := getByte (blockStart + i * 4)
    let b1 := getByte (blockStart + i * 4 + 1)
    let b2 := getByte (blockStart + i * 4 + 2)
    let b3 := getByte (blockStart + i * 4 + 3)
    (b0.toUInt32 <<< 24) ||| (b1.toUInt32 <<< 16) |||
      (b2.toUInt32 <<< 8) ||| b3.toUInt32).toArray
  (List.range 48).foldl (fun w j =>
    let i := j + 16
    let s0 := rotr (w[i - 15]!) 7 ^^^ rotr (w[i - 15]!) 18 ^^^ ((w[i - 15]!) >>> 3)
    let s1 := rotr (w[i - 2]!) 17 ^^^ rotr (w[i - 2]!) 19 ^^^ ((w[i - 2]!) >>> 10)
    w.push (w[i - 16]! + s0 + w[i - 7]! + s1)) initial

/-- Compress one block into the running hash state. -/
private def compress (hash : Array UInt32) (schedule : Array UInt32) : Array UInt32 :=
  let state := (List.range 64).foldl (fun state i =>
    let a := state[0]!
    let b := state[1]!
    let c := state[2]!
    let d := state[3]!
    let e := state[4]!
    let f := state[5]!
    let g := state[6]!
    let h := state[7]!
    let s1 := rotr e 6 ^^^ rotr e 11 ^^^ rotr e 25
    let ch := (e &&& f) ^^^ (~~~e &&& g)
    let temp1 := h + s1 + ch + kConstants[i]! + schedule[i]!
    let s0 := rotr a 2 ^^^ rotr a 13 ^^^ rotr a 22
    let maj := (a &&& b) ^^^ (a &&& c) ^^^ (b &&& c)
    let temp2 := s0 + maj
    #[temp1 + temp2, a, b, c, d + temp1, e, f, g]) hash
  #[hash[0]! + state[0]!, hash[1]! + state[1]!, hash[2]! + state[2]!,
    hash[3]! + state[3]!, hash[4]! + state[4]!, hash[5]! + state[5]!,
    hash[6]! + state[6]!, hash[7]! + state[7]!]

private def hexNibble (n : UInt32) : Char :=
  if n < 10 then Char.ofNat (48 + n.toNat) else Char.ofNat (87 + n.toNat)

private def wordToHex (w : UInt32) : String :=
  (List.range 8).foldl (fun out i =>
    let shift := (7 - i).toUInt32 * 4
    out.push (hexNibble ((w >>> shift) &&& 0xf))) ""

/--
Compute the SHA-256 digest of the exact bytes and render it as lowercase hex.
-/
def hash (data : ByteArray) : String :=
  let total := data.size
  let padded := paddedSize total
  let bitLen : UInt64 := (total.toUInt64) * 8
  let getByte (index : Nat) : UInt8 :=
    if index < total then
      data[index]!
    else if index == total then
      0x80
    else if index >= padded - 8 then
      -- Big-endian 64-bit bit length in the final eight bytes.
      let shift := ((padded - 1 - index).toUInt64) * 8
      (bitLen >>> shift).toUInt8
    else
      0
  let blockCount := padded / 64
  let finalHash := (List.range blockCount).foldl (fun h block =>
    compress h (scheduleFor getByte (block * 64))) initialHash
  finalHash.foldl (fun acc word => acc ++ wordToHex word) ""

end Loam.Sha256
