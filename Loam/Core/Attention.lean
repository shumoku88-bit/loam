import Loam.Core.Event

namespace Loam.Core

set_option autoImplicit false

/-!
# Attention evidence

`Attention` is the neutral Practical Core family behind a household-facing
"Issue" surface. It records a matter that may need action even when no
financial occurrence exists yet.

Observation 109 established three boundaries that this type preserves:

* due meaning is not an optional date;
* closure meaning is not a boolean;
* relation provenance does not itself close Attention.

The first practical slice deliberately does not copy HRA's category, amount,
mutable status, details record, or account vocabulary.
-/

/-- Stable identity for one retained household attention item. -/
structure AttentionId where
  token : String
deriving Repr, DecidableEq

/-- Explicit due meaning. `none` and `unknown` are intentionally distinct. -/
inductive AttentionDue (Time : Type) where
  | dueOn (time : Time)
  | noDueDate
  | dueUndetermined
deriving Repr, DecidableEq

/--
One household matter currently retained for attention.

`context` is intentionally opaque human context. The Core does not yet split it
into category, title, details, or amount fields.
-/
structure Attention (Time : Type) where
  id : AttentionId
  context : String
  due : AttentionDue Time
deriving Repr, DecidableEq

/-- Why one Attention item stopped being open. -/
inductive AttentionClosureKind where
  | resolved
  | dropped
deriving Repr, DecidableEq

/--
Explicit lifecycle evidence for one Attention item.

`knownOn` is a knowledge coordinate, not the item's due coordinate. Current
inspection may observe all retained closure evidence; historical as-of
visibility remains a later Application question.
-/
structure AttentionClosure (Time : Type) where
  attention : AttentionId
  knownOn : Time
  kind : AttentionClosureKind
deriving Repr, DecidableEq

/--
The first qualified provenance targets from Observation 109.

A relation to an Actual Event or a later Attention identity is evidence about
what the item became or relates to. It is not closure evidence.
-/
inductive AttentionRelationTarget where
  | event (event : EventId)
  | attention (attention : AttentionId)
deriving Repr, DecidableEq

/-- Append-oriented provenance relation whose existence does not close source. -/
structure AttentionRelation (Time : Type) where
  source : AttentionId
  target : AttentionRelationTarget
  knownOn : Time
deriving Repr, DecidableEq

end Loam.Core
