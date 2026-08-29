namespace Loam.Observation008

set_option autoImplicit false

universe uH uS uV uA uB

/-- A retained state is sufficient for a future-visible vocabulary when the
visible information can always be decoded from that state. -/
structure Sufficient
    (History : Type uH)
    (Summary : Type uS)
    (Visible : Type uV)
    (observe : History → Visible) where
  encode : History → Summary
  decode : Summary → Visible
  decode_encode : ∀ h, decode (encode h) = observe h

namespace Sufficient

/-- If two histories collapse to the same sufficient summary, then the chosen
future vocabulary cannot distinguish them. -/
theorem equalSummaryInvisible
    {History : Type uH}
    {Summary : Type uS}
    {Visible : Type uV}
    {observe : History → Visible}
    (s : Sufficient History Summary Visible observe)
    {h₁ h₂ : History}
    (hEq : s.encode h₁ = s.encode h₂) :
    observe h₁ = observe h₂ := by
  calc
    observe h₁ = s.decode (s.encode h₁) := (s.decode_encode h₁).symm
    _ = s.decode (s.encode h₂) := congrArg s.decode hEq
    _ = observe h₂ := s.decode_encode h₂

/-- A new representation is sufficient whenever it can recover an already
sufficient representation on every encoded history. -/
def reencode
    {History : Type uH}
    {Visible : Type uV}
    {A : Type uA}
    {B : Type uB}
    {observe : History → Visible}
    (source : Sufficient History A Visible observe)
    (encodeB : History → B)
    (recoverA : B → A)
    (recover_encode : ∀ h, recoverA (encodeB h) = source.encode h) :
    Sufficient History B Visible observe where
  encode := encodeB
  decode := fun b => source.decode (recoverA b)
  decode_encode := by
    intro h
    rw [recover_encode h]
    exact source.decode_encode h

/-- If two encodings can recover each other on the image of histories, they
induce exactly the same collision classes on histories. -/
theorem sameCollisionClasses
    {History : Type uH}
    {A : Type uA}
    {B : Type uB}
    (encodeA : History → A)
    (encodeB : History → B)
    (toB : A → B)
    (toA : B → A)
    (toB_encode : ∀ h, toB (encodeA h) = encodeB h)
    (toA_encode : ∀ h, toA (encodeB h) = encodeA h)
    (h₁ h₂ : History) :
    encodeA h₁ = encodeA h₂ ↔ encodeB h₁ = encodeB h₂ := by
  constructor
  · intro hEq
    calc
      encodeB h₁ = toB (encodeA h₁) := (toB_encode h₁).symm
      _ = toB (encodeA h₂) := congrArg toB hEq
      _ = encodeB h₂ := toB_encode h₂
  · intro hEq
    calc
      encodeA h₁ = toA (encodeB h₁) := (toA_encode h₁).symm
      _ = toA (encodeB h₂) := congrArg toA hEq
      _ = encodeA h₂ := toA_encode h₂

end Sufficient

abbrev History := Bool × Bool

def visible : History → History := id

def pairSummary : Sufficient History History History visible where
  encode := id
  decode := id
  decode_encode := by
    intro h
    rfl

inductive Count where
  | zero
  | one
  | two
  deriving DecidableEq, Repr

def count : History → Count
  | (false, false) => .zero
  | (false, true) => .one
  | (true, false) => .one
  | (true, true) => .two

/-- Observation 007's `u0 + count` coordinate system. -/
def u0CountEncode (h : History) : Bool × Count :=
  (h.1, count h)

def recoverFromU0Count : Bool × Count → History
  | (false, .zero) => (false, false)
  | (false, .one) => (false, true)
  | (false, .two) => (false, true)
  | (true, .zero) => (true, false)
  | (true, .one) => (true, false)
  | (true, .two) => (true, true)

theorem recoverU0Count (h : History) :
    recoverFromU0Count (u0CountEncode h) = h := by
  cases h with
  | mk u0 u1 =>
      cases u0 <;> cases u1 <;> rfl

def u0CountSummary :
    Sufficient History (Bool × Count) History visible :=
  Sufficient.reencode pairSummary u0CountEncode recoverFromU0Count recoverU0Count

/-- Observation 007's symmetric `u1 + count` coordinate system. -/
def u1CountEncode (h : History) : Bool × Count :=
  (h.2, count h)

def recoverFromU1Count : Bool × Count → History
  | (false, .zero) => (false, false)
  | (false, .one) => (true, false)
  | (false, .two) => (true, false)
  | (true, .zero) => (false, true)
  | (true, .one) => (false, true)
  | (true, .two) => (true, true)

theorem recoverU1Count (h : History) :
    recoverFromU1Count (u1CountEncode h) = h := by
  cases h with
  | mk u0 u1 =>
      cases u0 <;> cases u1 <;> rfl

def u1CountSummary :
    Sufficient History (Bool × Count) History visible :=
  Sufficient.reencode pairSummary u1CountEncode recoverFromU1Count recoverU1Count

/-- The direct pair and `u0 + count` are different coordinates with exactly
    the same history-collision classes in the Observation 005 universe. -/
theorem pairAndU0CountSameCollisionClasses (h₁ h₂ : History) :
    h₁ = h₂ ↔ u0CountEncode h₁ = u0CountEncode h₂ := by
  exact Sufficient.sameCollisionClasses
    (fun h : History => h)
    u0CountEncode
    u0CountEncode
    recoverFromU0Count
    (by intro h; rfl)
    recoverU0Count
    h₁ h₂

/-- The same holds for `u1 + count`. -/
theorem pairAndU1CountSameCollisionClasses (h₁ h₂ : History) :
    h₁ = h₂ ↔ u1CountEncode h₁ = u1CountEncode h₂ := by
  exact Sufficient.sameCollisionClasses
    (fun h : History => h)
    u1CountEncode
    u1CountEncode
    recoverFromU1Count
    (by intro h; rfl)
    recoverU1Count
    h₁ h₂

end Loam.Observation008
