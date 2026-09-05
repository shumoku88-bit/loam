namespace Loam.Observation188

set_option autoImplicit false

/-!
# Observation 188 — spending description is not a spending permission

Household language can quietly mix two different questions:

1. what was / would be bought?;
2. what kind of decision is this use of finite capacity?

A label such as `learning` or `books` can describe an outlay while also sounding
like a reason the outlay deserves funding. This observation keeps those axes
separate and asks only whether one can determine the other.

The candidate human-facing decision vocabulary used here is deliberately small:

- `need`      — 必要
- `want`      — 欲しい
- `prepare`   — 備える
- `committed` — 決まっている

These names are observation-local. They do not become LOAM Core primitives,
Capacity Purpose identities, a moral ordering, or an automatic recommendation.
-/

inductive DescriptionClass where
  | book
  | learning
  | coffee
  | groceries
  | transport
  | subscription
  deriving DecidableEq, Repr

inductive DecisionRole where
  | need
  | want
  | prepare
  | committed
  deriving DecidableEq, Repr

structure ConsideredUse where
  description : DescriptionClass
  role : DecisionRole
  deriving DecidableEq, Repr

private def wantedBook : ConsideredUse :=
  { description := .book, role := .want }

private def neededBook : ConsideredUse :=
  { description := .book, role := .need }

private def wantedCoffee : ConsideredUse :=
  { description := .coffee, role := .want }

private def wantedLearning : ConsideredUse :=
  { description := .learning, role := .want }

/--
A descriptive class does not determine the decision role. The same `book`
description can appear under different decision frames.
-/
theorem description_does_not_determine_role :
    ∃ a b : ConsideredUse,
      a.description = b.description ∧ a.role ≠ b.role := by
  exact ⟨wantedBook, neededBook, rfl, by decide⟩

/--
A decision role does not determine what was bought. `want` can contain different
descriptive classes without collapsing them into one spending category.
-/
theorem role_does_not_determine_description :
    ∃ a b : ConsideredUse,
      a.role = b.role ∧ a.description ≠ b.description := by
  exact ⟨wantedBook, wantedCoffee, rfl, by decide⟩

/--
Even a positively coloured description such as `learning` does not imply `need`.
The observation permits it to be framed simply as something wanted.
-/
theorem learning_label_is_not_need_authority :
    wantedLearning.description = .learning ∧ wantedLearning.role = .want := by
  decide

private def reconsider (use : ConsideredUse) (role : DecisionRole) : ConsideredUse :=
  { use with role := role }

/--
Reconsidering the decision frame need not rewrite the descriptive evidence.
-/
theorem changing_role_preserves_description
    (use : ConsideredUse) (role : DecisionRole) :
    (reconsider use role).description = use.description := by
  rfl

/-!
## Finding

For this deliberately tiny model:

```text
spending description × decision role
```

is a better shape than either direction being an implicit function.

A later household policy may choose friendly presentation words such as
`必要 / 欲しい / 備える / 決まっている`, while retained descriptions such as
`book`, `transport`, or `subscription` remain independently queryable.

This observation does not decide that those four Japanese labels are universal,
that every outlay must receive exactly one role, or that `need` is more worthy than
`want`. It also does not rename any current household Capacity Purpose or routing
entry. A real-data migration needs its own explicit mapping and effective boundary.
-/

end Loam.Observation188
