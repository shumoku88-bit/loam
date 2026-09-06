# LOAM UI Evaluation Experiment 01

Date: 2026-09-06  
Status: **E1 paper-trace experiment; no production UI selected**  
Framework: `LOAM_UI_EVALUATION_FRAMEWORK.md`

---

## 0. Goal

Apply the evaluation framework to the four current shell candidates over the first eight high-value scenarios.

Candidates:

1. current LOAM practical CLI,
2. HRA-derived flat shell,
3. h-kernel-derived focus shell,
4. flat + palette hybrid.

Scenarios:

1. ordinary Actual entry,
2. past Actual entry,
3. Scheduled realization,
4. Scheduled replacement,
5. discovered Correction,
6. Capacity movement,
7. interrupted unfinished operation,
8. rare operation after a simulated time gap.

This experiment deliberately does **not** invent human-use ratings for paper candidates.

The first six scenarios reuse code-derived structural evidence from the existing interaction traces and scorecards. Scenarios 7 and 8 are added specifically to challenge the current leading hypothesis.

---

# 1. Evidence discipline

## Current LOAM CLI

Evidence:

- code-derived current interaction structure,
- existing practical CLI behavior,
- current LOAM semantic/publication machinery.

Grade for structural claims: `E1 code-derived`.

No new timing, satisfaction, or avoidance measurements are invented here.

## HRA-derived flat shell

Evidence:

- historical HRA code archaeology,
- the user's report that HRA has been the easiest household UI they have used so far,
- paper adaptation that assumes current LOAM publishers underneath.

The historical preference is a real experiential anchor, but this experiment does not convert that preference into per-scenario numeric usability scores.

## h-kernel-derived focus shell

Evidence:

- historical h-kernel code archaeology,
- code-derived focus topology,
- paper adaptation that assumes current LOAM publishers underneath.

## Flat + palette hybrid

Evidence:

- paper/state-machine prediction only,
- current leading candidate from prior interaction research.

Grade: `E1 paper trace`.

### Rule

Unknown human-use dimensions remain `?`.

---

# 2. Safety gate stance

All three imagined TUI shells are evaluated under the same constraint:

```text
surface draft
  -> existing LOAM semantic proposal/admission
  -> WriterOwnership / fresh re-read where required
  -> qualified publication protocol
  -> fresh observation
```

Therefore the shell may improve target selection, orientation, prefill, and explanation, but may not bypass qualified LOAM semantics.

## Safety eligibility table

| Gate | Current CLI | HRA-derived flat | h-kernel focus | Flat + palette |
|---|---|---|---|---|
| SG01 semantic honesty | PASS | modeled PASS | modeled PASS | modeled PASS |
| SG02 provenance | PASS | modeled PASS | modeled PASS | modeled PASS |
| SG03 fail-closed | PASS | modeled PASS | modeled PASS | modeled PASS |
| SG04 publication protocol | PASS | modeled PASS | modeled PASS | modeled PASS |
| SG05 no hidden manufacture | PASS | modeled PASS | modeled PASS | modeled PASS |
| SG06 authority/mode legibility | PASS/operation-dependent presentation | must be tested | must be tested | must be tested |
| SG07 protective review | PASS where currently qualified | must preserve | must preserve | must preserve |

No paper candidate receives a safety advantage merely for being visually simpler.

---

# 3. Scenario 01 — ordinary Actual entry today

Context:

- Human goal: record an ordinary purchase,
- Frequency: `F3`,
- Consequence: `C1`,
- Familiarity target: `E`,
- Starting place for TUI candidates: Home with today selected.

## Current LOAM CLI

Representative trace:

```text
top/menu
  -> Record movement
  -> date
  -> movement fields
  -> qualified preview/admission/publication
  -> command/menu orientation
```

Structural observations:

- date is re-entered even when the human is conceptually acting "today",
- no persistent selected-day orientation,
- publication safety is strong,
- command return loses the temporal/object place.

Provisional UI Tax: `4`.

## HRA-derived flat

```text
Home(today)
  -> r
  -> draft(today)
  -> preview
  -> LOAM publisher
  -> Home(today)
```

Paper UI Tax: `0`.

Risk not captured by tax:

- a general editor can still have unnecessary field volume.

## h-kernel focus

Use the direct Home `r` path.

Paper/code-derived UI Tax: `0`.

Important counterpoint:

- the generalized focus shell does not hurt this high-frequency path if a direct Home action exists.

## Flat + palette

Use direct `r` because frequency earns a permanent shortcut.

Paper UI Tax: `0`.

### S01 outcome

The scenario does **not** distinguish HRA-flat, h-kernel-direct, and hybrid.

It mainly demonstrates that current CLI orientation/context is the avoidable cost.

Decision relevance: low by itself.

---

# 4. Scenario 02 — record a purchase three days ago

Context:

- Frequency: `F2`,
- Consequence: `C1`,
- recognition-first date selection is useful,
- expert direct date jump should remain possible.

## Current CLI

```text
Record movement
  -> type ISO date
  -> movement
  -> publish
  -> command shell
```

UI Tax: `4` under the existing score definition.

Strength:

- exact ISO date can be extremely efficient when already known.

Weakness:

- date must be recalled rather than reused from visible temporal context.

## HRA-derived flat

```text
Home
  -> select past day
  -> r
  -> draft(selected day)
  -> publish
  -> same day
```

UI Tax: `0`.

## h-kernel focus

Direct calendar selection + `r`.

UI Tax: `0`.

## Flat + palette

Same recognition-first path as HRA, plus optional direct date jump.

UI Tax: `0`.

### S02 outcome

The useful law is not "calendar instead of typing".

It is:

> preserve a visible selected-day coordinate, while allowing an expert direct jump.

All serious TUI candidates can satisfy this.

---

# 5. Scenario 03 — realize a Scheduled item as Actual

Context:

- Frequency: `F2`,
- Consequence: `C2`,
- object is already visible in open Scheduled state,
- expected movement may seed an editable Actual draft,
- completion must not imply unrelated semantics.

## Current CLI

Representative path:

```text
Scheduled workbench
  -> visible open list
  -> r
  -> type visible Scheduled ID
  -> editable Actual draft
  -> acquire ownership / fresh re-read
  -> completion publication
  -> re-render open set
```

UI Tax: `3` in the existing structural scorecard.

Strong safety:

- stale completion draft cannot beat concurrent terminal evidence,
- Actual remains independent evidence,
- no silent continuation.

Main UI defect:

> visible object is not the action target until its internal identity is retyped.

## HRA-derived flat

```text
Home -> s
  -> select visible Scheduled
  -> r Record actual
  -> editable defaults
  -> compact semantic preview
  -> LOAM completion publisher
  -> same Scheduled context
```

Paper UI Tax: `0`.

## h-kernel focus

Representative cold keyboard path:

```text
Calendar focus
  -> Section focus
  -> Plans/Scheduled
  -> Surface focus
  -> select object
  -> complete
```

UI Tax: `2`.

## Flat + palette

Because the object is visible, completion is object-local.

```text
select Scheduled row
  -> r
  -> editable defaults
  -> preview
  -> LOAM publisher
  -> same list
```

Paper UI Tax: `0`.

### S03 outcome

Strongest current finding:

> Scheduled target re-identification is pure UI tax and can be removed without weakening LOAM completion semantics.

HRA-flat and hybrid remain strongest paper structures here.

---

# 6. Scenario 04 — replace/reschedule one Scheduled item

Context:

- Frequency: `F1/F2`,
- Consequence: `C2`,
- source identity is visible,
- replacement date/movement are semantic changes,
- replacement must remain independent from continuation and routing.

## Current CLI

```text
Scheduled list
  -> e
  -> type visible Scheduled ID
  -> source shown
  -> date/movement defaults
  -> fresh re-read
  -> replacement relation first
  -> replacement occurrence
  -> open set re-rendered
```

UI Tax: `2`.

The semantic implementation is already the strongest part of the path.

## HRA-derived flat

```text
select Scheduled
  -> e
  -> edit replacement draft
  -> preview
  -> existing LOAM replacement publisher
  -> replacement remains selected
```

Paper UI Tax: `0`.

## h-kernel focus

Reach Plans surface through generalized focus, then object-local Replace.

UI Tax: `2`.

## Flat + palette

Visible target gets an object-local Edit/Reschedule action.

Paper UI Tax: `0`.

For a non-visible source, palette fallback can be:

```text
/ -> Change a scheduled payment -> recognition-first target picker
```

### S04 outcome

The shell experiment should not touch replacement semantics.

The earned UI opportunity is smaller:

> selectable object + editable defaults + qualified preview + fresh return.

---

# 7. Scenario 05 — correct a mistake discovered while reviewing history

Context:

- Frequency: `F0/F1`,
- Consequence: `C2/C3`,
- operation is usually a cold start,
- target is already visible at the moment the error is discovered.

## Current CLI

```text
More actions
  -> correct
  -> global numbered correctable list
  -> select target
  -> re-enter corrected balanced movement
  -> relation-first correction publication
  -> result
```

Existing UI Tax estimate: `3`.

Strength:

- no raw Event-ID recall,
- history/provenance semantics are strong.

Weakness:

- correction is not initiated where the mistake is discovered,
- correction draft is not necessarily seeded from the selected object.

## HRA-derived flat

```text
History/Actual
  -> select mistaken object
  -> local Correct/Reverse
  -> seeded draft / explicit before-after
  -> LOAM correction publisher
  -> same history context
```

Paper UI Tax: `0`.

But discoverability after a long gap is not proven.

## h-kernel focus

Representative cold path adds region/pane focus before the selected transaction action.

UI Tax: about `3` from prior code-derived trace.

Potential advantage:

- visible rich workspace may make the rare task easier to rediscover than a mnemonic-only shell.

## Flat + palette

Two complementary routes:

```text
visible mistaken object -> local Correct
```

or cold start:

```text
/ More actions -> "correct a record" -> target picker
```

Paper UI Tax when object already selected: `0`.

### S05 outcome

This is the first scenario where the hybrid has a plausible advantage over a literal HRA restoration:

- object-local speed when context is present,
- palette rediscovery when the shortcut is forgotten.

That is still a prediction, not human-use evidence.

---

# 8. Scenario 06 — move Capacity

Context:

- Frequency: `F1`,
- Consequence: `C2`,
- current balances matter to the decision,
- Current/After is useful protective friction.

## Current CLI

```text
capacity command
  -> date
  -> type From purpose/token
  -> type To purpose/token
  -> amount
  -> sufficient-entitlement validation
  -> publish
  -> command shell
```

Existing UI Tax estimate: `4` for the common unallocated-to-known-purpose path.

Interaction gap:

- no rich Current/After preview,
- endpoints are typed rather than selected from visible current state.

## HRA-derived flat

```text
Home -> Capacity
  -> visible balances
  -> choose From / To
  -> amount
  -> Current/After
  -> publish
  -> Capacity context
```

Paper UI Tax: `0`.

Protective friction intentionally remains.

## h-kernel focus

Generalized section path + richer workspace.

UI Tax: `2`.

## Flat + palette

Capacity is not frequent enough to earn a permanent global key initially.

```text
/ More actions
  -> Move capacity
  -> visible balances/endpoints
  -> amount
  -> Current/After
  -> publish
  -> same capacity/result context
```

Paper UI Tax: `1`.

### S06 outcome

A one-point palette cost may be desirable because the operation is less frequent and more consequential.

This is a useful example where minimum UI Tax is **not automatically the design target**.

HRA-flat is structurally shorter, while hybrid may be better disciplined about permanent Home vocabulary.

---

# 9. First-six structural matrix

| Scenario | Current CLI | HRA-flat | h-kernel focus | Flat + palette |
|---|---:|---:|---:|---:|
| S01 ordinary Actual | 4 | 0 | 0 | 0 |
| S02 past Actual | 4 | 0 | 0 | 0 |
| S03 Scheduled realization | 3 | 0 | 2 | 0 |
| S04 Scheduled replacement | 2 | 0 | 2 | 0 |
| S05 discovered Correction | 3 | 0 | 3 | 0 |
| S06 Capacity move | 4 | 0 | 2 | 1 |
| **mean UI Tax** | **3.33** | **0.00** | **1.50** | **0.17** |

This repeats the earlier structural result with the corrected scenario ordering used by the new framework.

It does **not** establish a usability winner.

---

# 10. Scenario 07 — interrupt an unfinished operation and return hours later

This scenario is deliberately chosen to attack the leading flat-shell hypothesis.

Context:

- operation: use a split or Scheduled replacement draft,
- interruption point: `I2`, after meaningful draft work but before publication,
- return: hours later,
- requirement: user must distinguish unfinished draft from canonical authority.

## Current CLI

If the terminal process/input flow is abandoned before publication, the practical safe behavior is generally:

- canonical data remains unchanged,
- the human may need to restart the command,
- draft field work can be lost,
- semantic resumption cues are not a first-class shell feature.

Safety: good in the important sense that an abandoned pre-publication draft does not silently become authority.

Resumption quality: weak.

Provisional classification:

- UI Tax: not the useful primary metric,
- Resumption friction: **high**,
- `ResumeTime`: unknown until dogfood,
- `ReconstructionQuestions`: likely multiple,
- persistent semantic breadcrumb: not established.

## HRA-derived flat

The flat shell gives excellent location continuity while the application remains alive.

But flat topology by itself does **not** guarantee:

- persisted unfinished draft,
- semantic resumption packet,
- hours-later/process-restart recovery.

Therefore:

- Resumption friction: **unknown/high risk**,
- human-use rating: `?`,
- no advantage awarded merely because Home is flat.

## h-kernel focus

Likewise, a richer focus shell can preserve in-process state but does not automatically solve durable semantic resumption.

Potential advantage:

- typed sub-flow state can make the current in-process mode explicit.

But after a full gap/restart, durable resumption is not earned by shell topology alone.

Resumption friction: **unknown/high risk**.

## Flat + palette

The previous research proposed a possible semantic resumption packet, but that is **not part of the candidate shell yet**.

Therefore this experiment refuses to award the hybrid an imagined resumption advantage.

Resumption friction: **unknown/high risk**.

### S07 outcome

This scenario breaks the temptation to treat shell topology as the whole UI problem.

> Flatness solves orientation during ordinary navigation. It does not automatically solve unfinished-intent persistence.

New research boundary:

```text
shell topology
    !=
resumption model
```

Any future prototype that tests interruption should explicitly decide whether unfinished drafts are:

1. intentionally ephemeral,
2. recoverable only while the process remains alive,
3. retained as non-authoritative resumption packets.

Do not add persistent draft semantics merely to improve a score. The need must be dogfooded.

---

# 11. Scenario 08 — perform a rare Correction after a simulated one-week gap

This scenario attacks expert-shortcut bias.

Context:

- operation: historical Correction,
- frequency: `F0`,
- consequence: `C3`,
- familiarity: `R`, returning after gap,
- assumption: shortcut/action name is not reliably remembered.

The main metric is **cold-start rediscovery**, not speed after the action is found.

## Current CLI

Potential cold path:

```text
top-level menu
  -> More actions
  -> correct
  -> displayed candidate list
```

Structural strengths:

- visible menus can be rediscovered,
- target selection is recognition-first once inside the correction flow.

Weaknesses:

- correction starts globally rather than from the record where the mistake may have been noticed,
- command shell loses richer temporal/object orientation,
- seeded replacement convenience is limited.

Cold-start discoverability: **structurally plausible, human rating unknown**.

## HRA-derived flat

If the user remembers `a` and the local correction/reversal action, the path is extremely short.

After a gap, however, pure mnemonics can become a recall problem.

A visible persistent footer can reduce this, but object-local rare commands may still require help.

Cold-start discoverability: **open question**.

This is a direct falsification condition for "HRA-flat is always best".

## h-kernel focus

The section/focus shell is more verbose, but it makes major domains persistently visible.

For a rare task, that visible structure may partially repay its presentation tax.

Potential cold path:

```text
visible Actual section
  -> visible transaction workspace
  -> select record
  -> discover local action/help
```

Cold-start discoverability: **plausible strength, human rating unknown**.

## Flat + palette

Candidate path:

```text
/ More actions
  -> type "correct" / "fix" / "wrong amount"
  -> Correct a record
  -> recognition-first target picker or selected-object action
```

This is the hybrid's strongest paper argument:

- frequent operations can become muscle memory,
- rare operations do not require mnemonic recall.

But it depends on:

- `/ More actions` being visible enough to discover,
- human-language aliases being good,
- search results not becoming a junk drawer.

Cold-start discoverability: **strong paper hypothesis, not measured evidence**.

### S08 outcome

The focus shell should not be rejected merely for higher repeated-use UI Tax.

Rare operations expose a different tradeoff:

```text
stable visible hierarchy
  vs
flat local shortcuts
  vs
searchable intent retrieval
```

The hybrid remains the most promising paper synthesis, but only a real cold-start test can confirm it.

---

# 12. Cross-scenario profile

Legend:

- `strong structural` = supported by code/paper topology for that dimension,
- `weak structural` = clear structural burden,
- `?` = requires actual human-use evidence,
- `gap` = capability/model not presently established.

| Dimension | Current CLI | HRA-flat | h-kernel focus | Flat + palette |
|---|---|---|---|---|
| Safety eligibility | PASS | modeled PASS | modeled PASS | modeled PASS |
| Repeated daily UI Tax | weak | strong | medium/strong | strong |
| Selected-day continuity | weak | strong | strong | strong |
| Visible-object local action | mixed | strong | strong | strong |
| Rare-action rediscovery | plausible menus | ? | plausible visible hierarchy | strong paper hypothesis |
| Consequential preview | strong semantics | modeled risk-adjusted | modeled rich flow | modeled risk-adjusted |
| Resumption after hours | gap/high friction | gap/unknown | gap/unknown | gap/unknown |
| Spatial stability | command shell stable but low context | strong hypothesis | strong but deeper | strong hypothesis |
| Mouse/pointer fit | weak | can be added | historical strength | can be added |
| Human satisfaction | ? | positive historical anchor, no per-scenario score | ? | ? |
| Avoidance | ? | ? | ? | ? |

No candidate has enough evidence for `EARNED`.

---

# 13. What survived and what was weakened

## Hypothesis H1 — stable selected-day orientation matters

Status: **SURVIVES E1**.

Evidence:

- helps S01/S02,
- supports object/time continuity,
- does not conflict with LOAM publication semantics.

Needs:

- wrong-date/default oversight test.

## Hypothesis H2 — object-local action beats retyping identity

Status: **SURVIVES strongly at E1**.

Evidence:

- Scheduled realization/replacement,
- discovered Correction.

This appears to remove pure UI tax without semantic loss.

## Hypothesis H3 — generalized focus shell is inferior

Status: **NOT PROVEN; weakened as a universal claim**.

Reason:

- higher repeated-use UI Tax remains visible,
- but stable visible hierarchy may help rare/cold-start operations,
- pointer use may reduce focus tax,
- richer workspace visibility may improve consequence comprehension.

Keep as comparison candidate.

## Hypothesis H4 — flat + palette is the likely synthesis

Status: **SURVIVES E1, ready for synthetic dogfood**.

Why:

- retains low daily UI Tax,
- gives rare actions an intent-search route,
- avoids permanent global shortcuts for every domain,
- permits object-local actions,
- maps cleanly to shared LOAM application actions.

But two major unknowns remain:

1. interruption/resumption is not solved by the shell,
2. actual discoverability/satisfaction/avoidance are unmeasured.

## Hypothesis H5 — fewer steps means better UI

Status: **REJECTED as a general rule**.

Capacity is the clean counterexample:

- Current/After protective friction adds interaction,
- but can improve decision quality.

Rare Correction is another:

- a visible/searchable path can be slightly longer but better after forgetting.

---

# 14. Decision states after Experiment 01

## Current LOAM CLI

State: **BASELINE / SURVIVES**.

Reason:

- semantically strong and safe,
- usable as canonical practical baseline,
- clear orientation/target-selection friction remains.

Do not replace until a candidate beats it without semantic regression.

## HRA-derived flat shell

State: **DOGFOOD comparator**.

Reason:

- strongest historical experiential anchor,
- strongest repeated-use structural simplicity,
- rare-action discoverability and durable resumption remain open.

Do not simply restore HRA.

## h-kernel-derived focus shell

State: **RESEARCH comparator**.

Reason:

- repeated keyboard presentation tax remains a concern,
- but cold-start visibility, rich workspaces, mouse, and scaling remain legitimate counter-hypotheses.

Do not reject yet.

## Flat + palette hybrid

State: **DOGFOOD candidate**.

Reason:

- best current E1 synthesis,
- survives all six local structural scenarios,
- has the strongest paper answer to rare-action rediscovery,
- did **not** receive an invented advantage on interruption/resumption.

Production implementation remains **NOT EARNED**.

---

# 15. Next smallest experiment

The framework says to use the smallest interactive prototype only when paper cannot answer a human-use question.

Paper has now reached that boundary.

The highest-value unknowns cannot be resolved by more topology diagrams:

1. Can a user rediscover a rare operation through the hybrid palette after forgetting it?
2. Does selected-day defaulting create wrong-date errors?
3. Does object-local action feel obvious without memorizing letters?
4. Does a visible `More actions` palette feel lighter than a section focus shell?
5. Does the user prefer the hybrid over HRA-flat when both are equally safe?
6. Does either flow create avoidance after several repetitions?

Therefore the next experiment should **not** build a full TUI.

Build or simulate only enough interaction to test:

```text
Home/calendar
  selected day
  one Actual row
  one Scheduled row
  r Record
  local Scheduled actions
  / More actions palette
  one rare Correct action
```

No new accounting semantics.

The prototype may use scratch/synthetic state and mock publication results at first **only if** the evaluation question is purely navigation/discoverability. When testing write/recovery comprehension, it should route through the real LOAM Application/CLI publisher boundary.

---

# 16. Synthetic dogfood protocol for the next phase

Run two shells first rather than four full implementations:

1. HRA-flat comparator,
2. flat + palette hybrid.

Keep current CLI as the real baseline and h-kernel as the documented counter-model.

### Round A — cold start

Without coaching:

- record today,
- go three days back and record,
- find how to correct an existing row,
- find how to change a Scheduled item.

Record:

- help lookups,
- wrong action attempts,
- hesitation points,
- orientation,
- `RepeatWillingness`.

### Round B — repetition

Repeat ordinary entry and Scheduled realization 5–20 times with varied synthetic data.

Look for:

- shortcut learning,
- visual-search reduction,
- annoyance,
- accidental wrong-date inheritance,
- desire for different direct keys.

### Round C — gap

After a simulated gap, ask for Correction and Capacity without giving the shortcut.

Look for:

- palette rediscovery,
- mnemonic failure,
- section-search behavior,
- whether human-language action labels are sufficient.

### Round D — interruption

Interrupt an unfinished draft.

Initially test both policies explicitly:

- ephemeral draft: return requires restart,
- non-authoritative resumable draft: return shows semantic breadcrumb.

Do not assume persistent drafts are automatically better. Measure whether the user actually values them enough to justify the concept/implementation cost.

---

# 17. Experiment 01 conclusion

The first framework run narrows the design space without selecting a production UI.

The strongest structural result remains:

> LOAM can probably preserve its current strict semantic/publication machinery while making the human shell much flatter and more recognition-first.

The first new falsification result is equally important:

> flat navigation and command palettes do not solve interruption/resumption by themselves.

The second new result is:

> h-kernel's extra visible structure may have value for cold/rare tasks even when it costs more focus transitions during repeated keyboard use.

The current best research move is therefore not "implement the winning shell".

It is:

> compare HRA-flat and flat + palette with the smallest interactive synthetic prototype, specifically targeting discoverability, wrong-date risk, repeated-use learning, rare-task cold starts, and avoidance.

---

## Working rule

> Keep the semantic engine strict. Test the human shell cheaply. Treat interruption and rare-task rediscovery as independent problems. Do not award imaginary human scores.