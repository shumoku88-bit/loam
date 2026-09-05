# LOAM Falsification Selection — September 2026

Status: **first near-queue extraction after full F001-F200 review**

Baseline review checkpoint: `LOAM_FALSIFICATION_PROGRESS.md` at main `cd5a5a1c15ac86ef15aa38772e4882bfc93d8ec9`.

The corpus now contains 200 reviewed specimens, of which 146 remain `REVIEWED / UNTESTED`.
This document does not create product requirements. It ranks unresolved pressure and extracts only a small formal near queue.

## Selection rule

Each unresolved specimen was judged on four axes, each from 0 to 3:

```text
H  household contact
   0 remote domain
   3 ordinary or already-adjacent household use

B  boundary attack
   0 mostly operational detail
   3 directly attacks a current minimum-evidence distinction

W  witness smallness
   0 requires a large domain model
   3 admits a very small two-world or bounded witness

N  novelty after review
   0 nearly answered by existing composition
   3 clearly outside direct qualified evidence
```

The score is only a selection aid. It is not a theorem and does not replace the Atlas two-world criterion.

A second rule prevents near-queue monoculture:

> Prefer one representative specimen per independent attack seam before selecting several variants from the same family.

## READY near queue

| Order | ID | Pressure | H | B | W | N | Total | Why selected now | Likely first tool |
|---|---|---|---:|---:|---:|---:|---:|---|---|
| 1 | F051 | obligation is certain but amount is unknown | 3 | 3 | 3 | 3 | 12 | Current Scheduled evidence is quantity-bearing; this asks whether existence can be independently known before quantity. Very small information-independence test. | Alloy |
| 2 | F033 | same numeric wallet quantity has different movement rights | 3 | 3 | 3 | 3 | 12 | Directly household-adjacent and attacks whether `Locus × Measure × Quantity` plus current eligibility is enough to answer future transfer/withdrawal questions. | Alloy |
| 3 | F001 | card authorization hold exists without capture | 3 | 3 | 3 | 2 | 11 | Observation 050 explicitly stopped before reservation/hold rights. Tests temporary reservation without pretending it is settled Actual. | TLA+ or Alloy first, depending selected query |
| 4 | F076 | shared expense is later fully refunded | 3 | 3 | 2 | 3 | 11 | Existing burden/discharge work handles ordinary reimbursement, but not refund provenance through an already shared burden graph. This is direct household pressure. | Alloy |
| 5 | F055 | day-31 recurrence meets a shorter month | 3 | 2 | 3 | 3 | 11 | Series membership and Scheduled replacement exist, but recurrence generation policy remains deliberately unearned. Small calendar-boundary witness. | Lean or Alloy |
| 6 | F086 | physical cash/quantity assertion conflicts with reconstructed balance | 2 | 3 | 3 | 3 | 11 | Tests external truth/observation versus reconstructed history and epistemic conflict without importing reconciliation or adjustment nouns. | Alloy |

`READY` means only that these are the best current candidates for near formal work.
It does not mean six observations should be opened at once.
Normally only the first unresolved READY specimen should become `OBSERVING`.

## WATCHLIST

The following remain `REVIEWED / UNTESTED`, not `READY`, but are the first alternates if dogfood or the first observations change the ranking.

| ID | Pressure | Why not READY yet |
|---|---|---|
| F025 | one transfer has side-local dates | Strong household pressure, but temporal-coordinate work may compose further than the current review can safely claim; prefer a more orthogonal seam first. |
| F011 | refund requested but not received | Strong claim-vs-Actual pressure, but F076 gives a sharper extension of already-real shared-cost dogfood. |
| F037 | limited-time points expire | Strong rights-over-time pressure, but F033 is the smaller representative of the rights family. |
| F052 | amount known but due date unknown | Symmetric and useful, but F051 is the sharper first uncertainty test because it challenges quantity-bearing Scheduled existence directly. |
| F067 | interest accrues daily but is paid monthly | Strong accounting distinction, but less immediate household pressure than the READY set and overlaps recognition-time machinery. |
| F088 | missing history may be padded or left unknown | Important for migration and epistemic state, but F086 is the smaller assertion-conflict entrance. |
| F113 | one Event is corrected into two replacement Events | Structurally sharp, but correction topology is less immediate than current Scheduled/wallet/shared-cost pressure. |
| F125 | offline device syncs after newer facts exist | Important concurrency frontier, but the current two-user/single-household operation does not yet make distributed merge a near requirement. |

## Families deliberately not promoted yet

### Inventory / COGS

F105-F112 remain a coherent unresolved island and are valuable external pressure. They are not in the first near queue because the household distance is larger than the selected six. The family should remain intact rather than being marked low-value.

### Insurance / tax / payroll / marketplace

These Wave 2 families contain real unresolved distinctions, but most require more domain scaffolding than the first READY set. They remain useful later adversarial pressure.

### BNPL / subscription / securities settlement

These contain attractive lifecycle examples, but the first queue already covers obligation uncertainty, reservation, rights, provenance, and generation policy with smaller household-adjacent witnesses.

## First-observation recommendation

Start with **F051** unless fresh dogfood changes the order.

The first two-world question should be deliberately narrow:

```text
World A
  the household knows that obligation O exists
  amount is not yet known

World B
  no obligation O is known

Hold fixed every currently representable exact Scheduled fact.

Question
  must the household be able to distinguish
  "known obligation, unknown amount"
  from
  "no known obligation"?
```

If current exact quantity-bearing Scheduled evidence cannot distinguish those worlds, that is a genuine information loss.

Do not begin by adding `UnknownAmount`, nullable quantity, Invoice, Bill, or Commitment state.
First establish whether the distinction is independently observable and what the smallest information-equivalent evidence is.

## Runtime gate

All six READY specimens remain:

```text
Runtime = RESEARCH_ONLY
```

A formal counterexample does not trigger implementation.
Production work still waits for concrete household dogfood pressure.

## Re-ranking triggers

Re-rank this queue when any of the following happens:

- one READY observation finishes;
- real dogfood directly exercises an unresolved specimen;
- a newly merged Observation absorbs or subsumes a READY specimen;
- one candidate requires much larger scaffolding than expected;
- an external pressure produces a strictly smaller or stronger two-world witness.
