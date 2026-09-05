namespace Loam.Observation189

set_option autoImplicit false

/-!
# Observation 189 — choice, commitment, and funding are different questions

Observation 188 separated spending description from a human-facing decision role.
A practical fixed-cost example exposes a second seam: the candidate words
`need / want / prepare / committed` do not all live on one axis.

For example, a subscription can be something a household still wants while also
being already committed for the next payment. Groceries can be needed without a
specific future purchase already being committed. Preparing money is different
again: it is a funding posture toward a possible or expected use, not a judgment
that the use is needed or wanted.

This observation keeps three tiny axes separate:

- choice: `need | want`
- commitment: `open | committed`
- funding posture: `current | prepare`

The names are observation-local. They do not become LOAM Core primitives,
a complete household ontology, or a recommendation policy.
-/

inductive DescriptionClass where
  | subscription
  | groceries
  | rent
  | book
  deriving DecidableEq, Repr

inductive ChoiceRole where
  | need
  | want
  deriving DecidableEq, Repr

inductive CommitmentState where
  | open
  | committed
  deriving DecidableEq, Repr

inductive FundingPosture where
  | current
  | prepare
  deriving DecidableEq, Repr

structure ConsideredUse where
  description : DescriptionClass
  choice : ChoiceRole
  commitment : CommitmentState
  deriving DecidableEq, Repr

structure FundingDecision where
  use : ConsideredUse
  posture : FundingPosture
  deriving DecidableEq, Repr

private def wantedCommittedSubscription : ConsideredUse :=
  { description := .subscription, choice := .want, commitment := .committed }

private def neededOpenGroceries : ConsideredUse :=
  { description := .groceries, choice := .need, commitment := .open }

private def neededCommittedRent : ConsideredUse :=
  { description := .rent, choice := .need, commitment := .committed }

/-- A committed use need not be a `need`; commitment does not answer the choice question. -/
theorem committed_does_not_imply_need :
    wantedCommittedSubscription.commitment = .committed ∧
    wantedCommittedSubscription.choice = .want := by
  decide

/-- A needed use need not already be committed to a concrete future outlay. -/
theorem need_does_not_imply_committed :
    neededOpenGroceries.choice = .need ∧
    neededOpenGroceries.commitment = .open := by
  decide

/-- Need and commitment may also coincide; separating axes does not forbid that combination. -/
theorem need_and_committed_can_coexist :
    neededCommittedRent.choice = .need ∧
    neededCommittedRent.commitment = .committed := by
  decide

private def fund (use : ConsideredUse) (posture : FundingPosture) : FundingDecision :=
  { use := use, posture := posture }

/-- Changing how money is prepared need not rewrite the spending description. -/
theorem funding_posture_preserves_description
    (use : ConsideredUse) (posture : FundingPosture) :
    (fund use posture).use.description = use.description := by
  rfl

/-- Changing how money is prepared need not rewrite need/want judgment. -/
theorem funding_posture_preserves_choice
    (use : ConsideredUse) (posture : FundingPosture) :
    (fund use posture).use.choice = use.choice := by
  rfl

/-- Changing how money is prepared need not rewrite commitment state. -/
theorem funding_posture_preserves_commitment
    (use : ConsideredUse) (posture : FundingPosture) :
    (fund use posture).use.commitment = use.commitment := by
  rfl

/-!
## Finding

The four friendly words from Observation 188 are not best treated as four mutually
exclusive buckets. The smaller observed shape is closer to:

```text
spending description
× choice (need / want)
× commitment state
× funding posture
```

This explains why "fixed cost" is a poor proxy for `need`: a recurring or scheduled
outlay can be committed while still belonging on either side of the household's
need/want judgment. Likewise `prepare` describes what the household does with money
before an outlay, not what kind of thing the outlay morally is.

This observation does not require every use to receive a binary need/want label,
does not define legal necessity, does not say `want` should be cut first, and does
not migrate any current Capacity Purpose or household data.
-/

end Loam.Observation189
