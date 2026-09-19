# Plain Text Accounting export — obligation scaffold

Status: **focused audit — one production boundary gap repaired**

Date: 2026-09-19

Baseline:

```text
1b1038718f645693e8b0ee81b61fd998f23ec138
docs(method): adopt obligation scaffolding (#1082)
```

Target:

```text
Plain Text Accounting export (#1063)
```

Method: `docs/OBLIGATION_SCAFFOLD_METHOD.md`

## Root question

Can the one-way hledger/Ledger projection accidentally acquire authority over
LOAM sources, or claim more semantic fidelity than its narrow accounting view
actually preserves?

The root decomposes into:

```text
PTA export
    |
    +--> O1 source Actual is the admitted current image
    |
    +--> O2 correction/date selection is inherited rather than reimplemented
    |
    +--> O3 AccountingRole is explicit rather than inferred
    |
    +--> O4 only representable balanced Events are rendered
    |
    +--> O5 exported ordering and syntax are deterministic
    |
    +--> O6 output cannot replace either source authority
    |
    +--> O7 omitted LOAM evidence is not silently claimed to round-trip
```

## D — deterministic closure

### D1 — journal entry construction

`ActualJournalProjection.fromImage?` consumes
`ActualAuthority.Image.currentEvents` and `currentValidities`.

It does not independently choose the correction frontier or occurrence date.
Entries are deterministically sorted by current date and then EventId.

### D2 — AccountingRole rendering

`PlainTextAccountingExport.accountName` maps only explicit
`AccountingRoleMap` evidence to the conventional PTA prefixes.

An unresolved role remains visible under `unclassified:`; the exporter does not
guess one.

### D3 — representability gate

Each exported Event must:

- contain at least one Effect;
- balance independently for every Measure;
- use whitespace-safe Locus and Measure tokens.

The exporter refuses rather than inventing balancing postings, valuation, costs,
lots, or inferred quantities.

### D4 — narrow output vocabulary

The renderer emits ordinary transaction headings, one retained LOAM EventId
comment, and explicit postings.

It emits no:

- Scheduled evidence;
- Capacity evidence;
- recurrence;
- inferred amounts;
- virtual postings;
- lots or costs.

That loss is visible in the module contract rather than hidden behind a
round-trip claim.

## P — previously earned boundaries

### P1 — normalized Actual authority

Actual admission, correction selection, current validity selection, and the
canonical authority boundary are reused from `ActualAuthority`.

The PTA exporter does not earn or duplicate those semantics.

### P2 — AccountingRole authority

Role assignment is consumed from the existing persisted
`AccountingRoleMap`. The exporter only changes presentation prefixes.

### P3 — physical replacement primitive

`replaceTextViaSiblingStage` owns only complete sibling-stage replacement.
It does not make the output authoritative and it does not weaken the semantic
requirement that the output target remain distinct from source authorities.

## R — residuals

### R1 / production gap — aliased source path

The original CLI guarded source replacement with raw String equality:

```text
outputPath == actualPath || outputPath == rolePath
```

That does not establish file identity.

Concrete counterexample:

```text
ACTUAL_FILE = /tmp/x/actual.loam
OUTPUT_FILE = /tmp/x/./actual.loam
```

The strings differ, so the old guard accepted the request. Both paths designate
the same existing file. The final sibling-stage rename could therefore replace
the Actual authority with the generated PTA view.

A symbolic-link output can produce the same class of bypass for either source.

### Repair

The CLI now performs the conflict check on `System.FilePath` values and, when
the output already exists, compares all three paths after `IO.FS.realPath`.

This closes:

- `.` aliases;
- `..` aliases;
- symbolic-link aliases;
- relative/absolute aliases that resolve to the same existing source.

A non-existing output cannot already be either existing source authority, so no
identity comparison is required for that case.

CI pins both:

```text
output = <root>/./actual.loam
output = symlink -> accounting-role.loam
```

and requires refusal.

### R2 / policy — intentionally lossy accounting view

LOAM currently retains evidence that the PTA projection does not emit, including
families such as Merchant and Relation/Discharge provenance.

That is not a proof hole in the current feature because the exporter claims only
a conservative one-way current accounting view, not a lossless LOAM
serialization or round-trip interchange format.

The distinction is:

```text
PTA accounting view
    -> current dated balanced postings
    -> explicit role presentation
    -> EventId trace comment

LOAM semantic image
    -> richer retained evidence
    -> remains authoritative
```

Do not add Merchant, Relation, Discharge, routing, Scheduled, or Capacity fields
merely to make the export "complete".

If a future external consumer requires one of those facts, open a separate
interchange obligation and decide whether the target format has a faithful,
portable representation for it.

## Result

```text
D
├─ current journal construction
├─ explicit role rendering
├─ per-Measure representability
└─ narrow deterministic PTA syntax

P
├─ ActualAuthority
├─ AccountingRole authority
└─ sibling-stage physical replacement

R
├─ production: source-path alias bypass -> REPAIRED
└─ policy: intentionally lossy accounting view -> KEEP NARROW
```

The scaffold prevented two opposite overreactions:

1. reopening correction, validity, and AccountingRole semantics that were already
   earned; and
2. expanding the exporter into a general LOAM interchange format merely because
   it omits richer evidence.

## Stop point

Do not use this repair to justify:

- a bidirectional PTA importer;
- making exported journals authoritative;
- adding recurrence or Scheduled semantics;
- embedding every LOAM evidence family in comments or metadata;
- generic filesystem identity infrastructure across unrelated writers without a
  separate observed pressure.

Reopen only when another production output path can replace an authority through
path aliasing, or when an external interchange requirement needs richer
semantics.
