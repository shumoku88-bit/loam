# Observation 237 — Can a small trusted bridge connect independent semantics to production LOAM?

Status: **QUALIFIED — small explicit correspondence bridge survives; trust edge remains human-reviewed**

Research baseline: LOAM `0251d1a4357cb3f107b55fa2a27db13e50f7dc08`

Qualified Lean head: `834b1f6942c159914e480481e34f9ac74d9cf206`

Dedicated workflow: Observation 237 run `34369142952` — **SUCCESS**

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

Result: **rejected as sufficient production correspondence**.

### B — direct production statement

A theorem can mention `CurrentScheduledDayEvidenceResult` and
`currentScheduledDayEvidenceWithReplacement` directly. That genuinely exercises
production, but the trusted statement shares implementation vocabulary and can
therefore drift with it.

Result: **useful test, insufficient independent statement boundary**.

### C — neutral judgement + explicit bridge

The experiment defines only four review outcomes:

```text
positive | negative | unknown | refused
```

An experiment-local bridge maps the current production result into that vocabulary.
The bridge is intentionally visible and reviewable. It does not enter Core or
Application.

The production empty-Scheduled fixture evaluates through the real
`currentScheduledDayEvidenceWithReplacement` reader and then projects to `unknown`.
The bridge also proves that no current production result can manufacture
`negative`, while malformed replacement evidence remains `refused` rather than
being collapsed into ordinary absence.

Result: **survives in the selected Scheduled pressure case**.

## Qualified conclusion

The experiment did **not** eliminate the semantic trust boundary between an
independently reviewed meaning and a production implementation.

It reduced that boundary to one explicit, total, small, reviewable bridge:

```text
human-reviewed independent meaning
              |
              v
      explicit correspondence bridge
              |
              v
        production semantics
```

Lean can mechanically check that the selected production reader reaches the
expected independent judgement through that bridge, and can prove structural
properties of the bridge such as "no current production result maps to negative".
Lean does not establish that the bridge itself captures the human's intended
correspondence. That remaining edge is deliberately exposed for review rather than
hidden in shared definitions.

The selected fixture is deliberately narrow: the observation proves the empty valid
Scheduled world path and total result projection, not a universal theorem that every
possible valid Scheduled world with missing day evidence must project to `unknown`.
That broader semantic theorem is outside this observation's question.

## Stop condition reached

Do not introduce a generic verification ontology, generic production adapter
framework, Comparator workflow, Nanoda workflow, or a new Core/Application concept
from this observation alone.

Observation 237 has answered its boundary question. If later production pressure
justifies another step, a separate observation may ask whether an independent
Challenge plus production-backed conformance proof benefits from Comparator. The
correspondence bridge should remain explicit rather than being disguised as shared
implementation vocabulary.
