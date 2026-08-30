import Loam.Core.Allocation

namespace Loam.Core

set_option autoImplicit false

/-!
# Recipient assignment

The numeric allocation kernel knows only how many parts exist and where the
remainder-bearing parts appear. This module introduces runtime recipient
identity and binds those exact parts to the caller's explicit recipient order.

Recipient order is data, not an intrinsic priority relation. `front` and `back`
therefore mean the front or back of the supplied order only. Fairness,
rotation, display names, and historical priority remain outside this module.
-/

/-- Stable runtime identity for an allocation recipient. -/
structure RecipientId where
  token : String
deriving Repr, DecidableEq

namespace RecipientAssignment

/--
A successful assignment carries the exact numeric laws needed by callers:
there is one quantity for every recipient and their sum is the original total.
-/
structure Assignment (recipients : List RecipientId) (total : Nat) where
  quanta : List Nat
  length_eq : quanta.length = recipients.length
  sum_eq : quanta.sum = total

/-- Pair the caller's recipient order with its proven same-length quantities. -/
def pairs {recipients : List RecipientId} {total : Nat}
    (assignment : Assignment recipients total) : List (RecipientId × Nat) :=
  recipients.zip assignment.quanta

/--
Assign a nonnegative exact total to an explicit ordered list of recipients.

An empty recipient list is rejected. A successful result packages the length
and conservation proofs from the numeric allocation kernel together with the
allocated quanta.
-/
def assign?
    (placement : Allocation.RemainderPlacement)
    (total : Nat)
    (recipients : List RecipientId) : Option (Assignment recipients total) :=
  match recipients with
  | [] => none
  | first :: rest =>
      let quanta := Allocation.parts placement total (first :: rest).length
      have hPositive : 0 < (first :: rest).length := by
        simp
      some {
        quanta := quanta
        length_eq := Allocation.length_parts
          placement total (first :: rest).length hPositive
        sum_eq := Allocation.sum_parts
          placement total (first :: rest).length hPositive
      }

private def alice : RecipientId := ⟨"alice"⟩
private def bob : RecipientId := ⟨"bob"⟩
private def carol : RecipientId := ⟨"carol"⟩

/-- No recipient means there is no assignment boundary to enter. -/
example : assign? .front 100 [] = none := by
  rfl

/-- Front placement binds the extra quantum to the first supplied recipient. -/
example :
    (assign? .front 100 [alice, bob, carol]).map pairs =
      some [(alice, 34), (bob, 33), (carol, 33)] := by
  decide

/-- Back placement binds the extra quantum to the last supplied recipient. -/
example :
    (assign? .back 100 [alice, bob, carol]).map pairs =
      some [(alice, 33), (bob, 33), (carol, 34)] := by
  decide

end RecipientAssignment

end Loam.Core
