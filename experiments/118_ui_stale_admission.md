# Observation 118: Must UI activation re-admit after rendering?

## Question

Observations 116 and 117 separated three UI concerns:

```text
projection  -> what is visible
admission   -> what is operable
obligations -> what is still needed
```

Those observations are static. A real UI has time between rendering an affordance and the user activating it.

The question is:

> If an action was admitted when rendered, may activation trust that old result, or must it re-read and re-admit against the current world?

## Concrete Scheduled pressure

The current practical Scheduled lifecycle has a shared terminal boundary. A retained completion relation is a terminal claim even while the open-Scheduled projection still considers it semantically open until its Actual Event exists.

Cancellation therefore requires:

```text
no retirement
no retained completion relation
```

Completion / retry requires at least:

```text
no retirement
```

A fresh Scheduled occurrence can render both:

```text
[Complete] [Cancel]
```

But the world may change before activation.

### Stale Cancel

```text
render: Fresh
  Cancel admitted

other writer:
  publishes completion claim

user activates old Cancel affordance
```

At that point Cancel is no longer admitted. If the UI trusts the rendered result and writes retirement anyway, terminal evidence conflicts:

```text
completion claim + retirement
```

### Stale Complete

The symmetric pressure is:

```text
render: Fresh
  Complete admitted

other writer:
  publishes retirement

user activates old Complete affordance
```

Trusting the stale affordance would again create conflicting terminal claims.

## Candidate protocol

Rendering remains read-only and may become stale.

Activation is a new operation boundary:

```text
render snapshot
   ↓
show admitted affordance
   ↓
world may change
   ↓
activate
   ↓
acquire current terminal ownership
re-read current evidence
re-admit requested operation
   ↓
only then publish
```

The UI therefore treats an affordance as an invitation to request an operation, not as a durable authorization token.

This matches the current practical writer shape: terminal mutation already re-reads retained Scheduled completion / retirement evidence under writer ownership. A future TUI/GUI should call that boundary rather than mutate from a cached rendered state.

## Why SPIN

This is an interleaving question rather than a static information-sufficiency question.

The important shape is:

```text
UI read
concurrent writer mutation
UI activation
```

SPIN is a good fit because the state space is small and the counterexample is specifically an ordering between processes.

## Models

### Safe candidate

`118_ui_stale_admission_safe.pml` allows the UI to render from a fresh world, then allows a concurrent writer to publish either:

- a completion claim; or
- retirement.

The user then activates one of the old rendered actions.

The handler re-admits atomically against current terminal evidence before publishing. The safety invariant is:

```text
not (completion_claim and retirement)
```

### Unsafe stale Cancel

`118_ui_stale_admission_unsafe_cancel.pml` forces:

```text
render Cancel
publish completion claim
activate stale Cancel without re-admission
```

### Unsafe stale Complete

`118_ui_stale_admission_unsafe_complete.pml` forces:

```text
render Complete
publish retirement
activate stale Complete without re-admission
```

## SPIN result

Exact PR head after the Promela guard fix:

```text
37c976321701df9544eb1f6537750f742655883f
```

Observation 118 workflow run #4 completed successfully.

Safe activation-time re-admission:

```text
State-vector 28 byte, depth reached 12, errors: 0
20 states, stored
2 states, matched
22 transitions
```

Unsafe stale Cancel:

```text
assertion violated !(completion_claim && retirement)
depth reached 9, errors: 1
```

Unsafe stale Complete:

```text
assertion violated !(completion_claim && retirement)
depth reached 9, errors: 1
```

The first workflow attempt did not produce a semantic counterexample. SPIN rejected the initial safe Promela model because nested `else` guards were inherited into one selection. Replacing those `else` branches with explicit complementary guards allowed the intended state-space check to run. The protocol result above is therefore from the corrected model, not from the rejected syntax shape.

## Interpretation

The bounded result supports:

```text
render-time admission
    !=
activation-time authority
```

and:

```text
visible affordance
    -> request operation
    -> re-admit on current world
    -> publish or explain refusal
```

This is stronger than merely disabling buttons correctly at render time.

The UI does not need to hold writer ownership while a person thinks. The rendered surface may become stale. Mutation authority is recomputed only when activation begins, under the current operation's existing ownership / admission boundary.

## Relationship to Lean-shaped UI

The result gives a natural future interaction loop:

```text
World W0
  -> projection
  -> admitted actions
  -> outstanding obligations
  -> render

user chooses action

World W1
  -> re-admit chosen action
     | admitted -> continue / publish
     | changed  -> refresh obligations and explanation
```

No proof object from W0 should be treated as authority over W1 unless its premises are explicitly shown to remain valid.

That phrasing is intentionally proof-flavored, but Observation 118 does not introduce proof-carrying UI state.

## Deliberate non-results

This observation does not add:

- UI locks held across human think time;
- durable authorization tokens;
- optimistic version numbers;
- automatic retry of arbitrary mutations;
- a Core UI action type;
- a generic stale-state error taxonomy;
- a TUI/GUI framework;
- websocket/event refresh semantics;
- multi-user collaboration semantics;
- fairness or liveness guarantees.

The earned boundary is smaller: human-visible UI state may go stale, so mutation authority must be recomputed at activation time.
