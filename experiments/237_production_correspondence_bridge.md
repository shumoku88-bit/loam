# Observation 237 — Can a small trusted bridge connect independent semantics to production LOAM?

Status: **ACTIVE — correspondence-boundary probe**

Research baseline: LOAM `0251d1a4357cb3f107b55fa2a27db13e50f7dc08`

## Question

Can an independently reviewed semantic statement constrain current production
Scheduled behavior without either becoming a vacuous concrete theorem or sharing
enough LOAM implementation vocabulary to reopen coupled semantic drift?

## Pressure

Observations 161–168 qualified statement contracts, an implementation-independent
Challenge surface, Comparator statement equality, axiom policy, Lean kernel replay,
and Nanoda checker diversity. The remaining verification checkpoint explicitly
reserved a future production-relevant claim.

The current production Scheduled read boundary is a suitable pressure point:

```text
explicit current-open evidence on day -> Due
no explicit current-open evidence      -> Unknown
malformed lifecycle/replacement         -> fail-closed refusal
```

There is deliberately no current production `NotDue` constructor because no
production completeness authority currently justifies turning absence into a
negative household claim.

## Three candidate boundaries

### A — concrete-only statement

A concrete statement can be made fully independent of LOAM vocabulary. The probe
includes a trivially true reviewed claim to make the weakness explicit: it can be
proved without touching production at all.

Result sought: **reject as sufficient production correspondence**.

### B — direct production statement

A theorem can mention `CurrentScheduledDayEvidenceResult` and
`currentScheduledDayEvidenceWithReplacement` directly. That genuinely exercises
production, but the trusted statement shares implementation vocabulary and can
therefore drift with it.

Result sought: **useful test, insufficient independent statement boundary**.

### C — neutral judgement + explicit bridge

The experiment defines only four review outcomes:

```text
positive | negative | unknown | refused
```

An experiment-local bridge maps the current production result into that vocabulary.
The bridge is intentionally visible and reviewable. It does not enter Core or
Application.

The production empty-Scheduled fixture must evaluate through the real
`currentScheduledDayEvidenceWithReplacement` reader and then project to `unknown`.
The bridge also proves that no current production result can manufacture
`negative`, while malformed replacement evidence remains `refused` rather than
being collapsed into ordinary absence.

Result sought: **survive if the correspondence edge stays small and explicit**.

## Stop condition

Do not introduce a generic verification ontology, generic production adapter
framework, Comparator workflow, or Nanoda workflow from this observation alone.
First establish whether the small bridge is mechanically useful and whether it
exposes rather than hides the remaining human-review boundary.

If C survives, a later observation may ask whether the independently reviewed
judgement and the production-backed Solution are worth placing behind Comparator.
