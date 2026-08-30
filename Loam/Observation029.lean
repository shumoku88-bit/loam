namespace Loam.Observation029

set_option autoImplicit false

universe uH uQ uA uS

/-- A future vocabulary is the set of questions that future observers are
allowed to ask. -/
abbrev Vocabulary (Question : Type uQ) := Question → Prop

/-- `small` asks no question that `large` cannot also ask. -/
def Included {Question : Type uQ}
    (small large : Vocabulary Question) : Prop :=
  ∀ q, small q → large q

/-- Two histories are observationally equivalent for a vocabulary when every
question in that vocabulary receives the same answer. -/
def Equivalent
    {History : Type uH}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : History → Question → Answer)
    (vocabulary : Vocabulary Question)
    (h₁ h₂ : History) : Prop :=
  ∀ q, vocabulary q → answer h₁ q = answer h₂ q

/-- Enlarging the future vocabulary can preserve an observational quotient or
refine it, but it cannot merge histories that the smaller vocabulary already
distinguished. -/
theorem richerEquivalenceRefines
    {History : Type uH}
    {Question : Type uQ}
    {Answer : Type uA}
    (answer : History → Question → Answer)
    {small large : Vocabulary Question}
    (hIncluded : Included small large)
    {h₁ h₂ : History}
    (hEquivalent : Equivalent answer large h₁ h₂) :
    Equivalent answer small h₁ h₂ := by
  intro q hSmall
  exact hEquivalent q (hIncluded q hSmall)

/-- A summary is sufficient for a vocabulary when one decoder can recover the
answer to every future-visible question from that summary. -/
def SufficientFor
    {History : Type uH}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uS}
    (answer : History → Question → Answer)
    (vocabulary : Vocabulary Question)
    (encode : History → Summary) : Prop :=
  ∃ decode : Summary → Question → Answer,
    ∀ h q, vocabulary q → decode (encode h) q = answer h q

/-- The same retained summary remains sufficient when the future vocabulary is
restricted. No new memory is required by forgetting questions. -/
theorem sufficiencyDescends
    {History : Type uH}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uS}
    (answer : History → Question → Answer)
    {small large : Vocabulary Question}
    (hIncluded : Included small large)
    (encode : History → Summary)
    (hSufficient : SufficientFor answer large encode) :
    SufficientFor answer small encode := by
  rcases hSufficient with ⟨decode, hDecode⟩
  refine ⟨decode, ?_⟩
  intro h q hSmall
  exact hDecode h q (hIncluded q hSmall)

/-- Equal sufficient summaries make histories indistinguishable to every
question in the vocabulary. -/
theorem equalSummaryInvisible
    {History : Type uH}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uS}
    (answer : History → Question → Answer)
    {vocabulary : Vocabulary Question}
    {encode : History → Summary}
    (hSufficient : SufficientFor answer vocabulary encode)
    {h₁ h₂ : History}
    (hEncode : encode h₁ = encode h₂) :
    Equivalent answer vocabulary h₁ h₂ := by
  rcases hSufficient with ⟨decode, hDecode⟩
  intro q hVisible
  calc
    answer h₁ q = decode (encode h₁) q := (hDecode h₁ q hVisible).symm
    _ = decode (encode h₂) q := congrArg (fun s => decode s q) hEncode
    _ = answer h₂ q := hDecode h₂ q hVisible

structure Origin where
  a : Bool
  b : Bool
  hidden : Bool
  deriving DecidableEq, Repr

inductive Question where
  | either
  | a
  | b
  | both
  | hidden
  deriving DecidableEq, Repr

/-- The five concrete future questions from Observation 028. -/
def answer (o : Origin) : Question → Bool
  | .either => o.a || o.b
  | .a => o.a
  | .b => o.b
  | .both => o.a && o.b
  | .hidden => o.hidden

/-- `V3` can see Either(A,B), A, and B. -/
def V3 : Vocabulary Question
  | .either => True
  | .a => True
  | .b => True
  | .both => False
  | .hidden => False

/-- `V4` additionally asks Both(A,B), which is derivable from A and B. -/
def V4 : Vocabulary Question
  | .either => True
  | .a => True
  | .b => True
  | .both => True
  | .hidden => False

/-- `V5` additionally makes Hidden observable. -/
def V5 : Vocabulary Question
  | .either => True
  | .a => True
  | .b => True
  | .both => True
  | .hidden => True

theorem v3IncludedV4 : Included V3 V4 := by
  intro q hVisible
  cases q <;> simp [V3, V4] at hVisible ⊢

theorem v4IncludedV5 : Included V4 V5 := by
  intro q hVisible
  cases q <;> simp [V4, V5] at hVisible ⊢

/-- Adding the derivable `Both(A,B)` question does not refine the quotient at
all: equality of A and B answers already forces equality of Both. -/
theorem redundantBothNoRefinement (x y : Origin) :
    Equivalent answer V3 x y ↔ Equivalent answer V4 x y := by
  constructor
  · intro hEquivalent
    intro q hVisible
    cases q with
    | either => exact hEquivalent .either (by simp [V3])
    | a => exact hEquivalent .a (by simp [V3])
    | b => exact hEquivalent .b (by simp [V3])
    | both =>
        have hA : x.a = y.a := hEquivalent .a (by simp [V3])
        have hB : x.b = y.b := hEquivalent .b (by simp [V3])
        simp [answer, hA, hB]
    | hidden =>
        simp [V4] at hVisible
  · intro hEquivalent
    exact richerEquivalenceRefines answer v3IncludedV4 hEquivalent

def originHiddenFalse : Origin :=
  { a := false, b := false, hidden := false }

def originHiddenTrue : Origin :=
  { a := false, b := false, hidden := true }

/-- Once Hidden joins the vocabulary, two origins that were previously
indistinguishable can become distinguishable. -/
theorem hiddenCanStrictlyRefine :
    Equivalent answer V4 originHiddenFalse originHiddenTrue ∧
    ¬ Equivalent answer V5 originHiddenFalse originHiddenTrue := by
  constructor
  · intro q hVisible
    cases q <;> simp [V4, answer, originHiddenFalse, originHiddenTrue] at hVisible ⊢
  · intro hEquivalent
    have hHidden := hEquivalent .hidden (by simp [V5])
    simpa [answer, originHiddenFalse, originHiddenTrue] using hHidden

abbrev ABSummary := Bool × Bool

def encodeAB (o : Origin) : ABSummary :=
  (o.a, o.b)

def decodeAB (summary : ABSummary) : Question → Bool
  | .either => summary.1 || summary.2
  | .a => summary.1
  | .b => summary.2
  | .both => summary.1 && summary.2
  | .hidden => false

/-- Remembering only A and B is sufficient through V4, including the redundant
Both question. -/
theorem abSummarySufficientV4 : SufficientFor answer V4 encodeAB := by
  refine ⟨decodeAB, ?_⟩
  intro h q hVisible
  cases q <;> simp [V4, answer, encodeAB, decodeAB] at hVisible ⊢

/-- The same A/B summary ceases to be sufficient once Hidden becomes a
future-visible distinction. -/
theorem abSummaryNotSufficientV5 : ¬ SufficientFor answer V5 encodeAB := by
  intro hSufficient
  have hEquivalent :
      Equivalent answer V5 originHiddenFalse originHiddenTrue :=
    equalSummaryInvisible answer hSufficient (by rfl)
  have hHidden := hEquivalent .hidden (by simp [V5])
  simpa [answer, originHiddenFalse, originHiddenTrue] using hHidden

end Loam.Observation029
