# LOAM UI Evaluation Framework v0.1

Date: 2026-09-06  
Status: **evaluation framework; not a UI specification and not an implementation decision**  
Parent research: `LOAM_INTERACTION_ATLAS*.md`

---

## 0. Purpose

The Interaction Atlas has accumulated several kinds of evidence:

- household-finance product archaeology,
- HRA and h-kernel interaction archaeology,
- code-derived interaction traces,
- the first synthetic `UI Tax` scorecard,
- broad usability/HCI research,
- sustained-use research,
- information-shape and learning research.

The research now needs a smaller instrument that can be used repeatedly when comparing a CLI, TUI, GUI/Web, ChatGPT surface, or mobile flow.

This document is that instrument.

It answers:

> What must be true before a LOAM interaction can be called good enough to implement or keep?

It deliberately does **not** answer:

- what LOAM Home must look like,
- which TUI shell is selected,
- which widget toolkit should be used,
- how many clicks a good task must take,
- whether HRA should be copied,
- whether one aggregate usability score exists.

The framework is intended to keep future UI work falsifiable.

---

# 1. Working definition

A good LOAM UI is one that:

> helps the person reach the correct household meaning, with appropriate effort and appropriate safety, while keeping current state understandable, recovery nearby, attention demands disciplined, and repeated use sustainable over time.

The definition has five consequences.

1. **Correctness comes before convenience.**
2. **Efficiency is only one dimension.**
3. **Not all friction is bad.**
4. **A task does not end when publication succeeds; return, comprehension, and recovery matter.**
5. **A feature that is technically usable but consistently avoided has failed as an interaction design.**

---

# 2. Evaluation architecture

Do not begin with a total score.

Evaluate in this order:

```text
0. Context declaration
        ↓
1. Safety / semantic eligibility gate
        ↓
2. Raw trace observations
        ↓
3. Friction decomposition
        ↓
4. Usability profile
        ↓
5. Time / learning profile
        ↓
6. Avoidance and sustained-use signals
        ↓
7. Compare candidates
        ↓
8. Decide: reject / continue dogfood / earned
```

A candidate that fails the safety gate is ineligible regardless of speed or preference.

A candidate that passes the gate is **not automatically good**. It must survive human-use evaluation.

---

# 3. Layer 0 — declare the context before judging the UI

Usability is context-dependent.

Every scenario record should declare at least:

| Field | Example |
|---|---|
| Human goal | Record a purchase |
| Surface | TUI |
| Starting place | Home, Sep 6 selected |
| Frequency | many/day |
| Consequence | low/moderate |
| Familiarity | repeated/expert |
| Reversibility | easy via Correction |
| Interruption likelihood | medium |
| Input environment | keyboard + mouse available |
| Information already visible | selected day, PayPay locus |
| Canonical state | fresh / stale-sensitive / ambiguous |

Without this context, action counts and timing are not comparable.

### Context classifiers

Use these simple buckets unless a scenario needs more precision.

#### Frequency

- `F0` first/rare
- `F1` occasional
- `F2` repeated
- `F3` high-frequency daily

#### Consequence

- `C0` observational only
- `C1` easy to repair
- `C2` meaningful correction cost
- `C3` high consequence / ambiguous authority / destructive-looking effect

#### Familiarity

- `N` novice/cold start
- `R` returning after a gap
- `E` experienced

#### Interruption

- `I0` uninterrupted
- `I1` interrupted before preview
- `I2` interrupted after draft/preview but before publication
- `I3` interrupted during or around qualified publication/recovery

---

# 4. Layer 1 — Safety and semantic eligibility gate

Safety is not a weighted score.

For every relevant operation, mark `PASS / FAIL / N/A`.

## SG-01 Semantic honesty

The UI must not present an assumption, default, projection, AI suggestion, or unfinished draft as retained household fact.

## SG-02 Provenance preservation

The interaction must preserve the qualified provenance/history semantics of the underlying LOAM action.

## SG-03 Fail-closed behavior

Ambiguous, stale, invalid, or unavailable authority must not be flattened into success, empty, zero, or a guessed answer.

## SG-04 Qualified publication protocol

WriterOwnership, fresh re-read, relation-first/Event-last rules, idempotent recovery, and other operation-specific publication constraints must remain intact.

## SG-05 No hidden semantic manufacture

Convenient UI defaults must not create independent relations or meanings that were not justified.

Examples:

- replacement must not silently imply continuation,
- replacement must not silently inherit routing,
- reimbursement must not silently become income,
- external duplicate suppression must not silently become physical movement.

## SG-06 Authority/mode legibility

The user must be able to distinguish relevant modes such as:

- draft,
- proposed,
- admitted/published,
- raw retained fact,
- effective projection,
- Scheduled expectation,
- Actual evidence,
- stale observation,
- unavailable state.

## SG-07 Consequence-appropriate confirmation

A candidate must not remove a confirmation/review step merely to improve a speed metric when that step buys meaningful safety.

### Eligibility rule

```text
Any relevant SG failure => candidate is ineligible for selection.
```

Do not compensate for a safety failure with high usability scores.

---

# 5. Layer 2 — Raw trace observations

Record raw observations before interpretation.

## 5.1 Semantic work

These are not automatically defects.

- `SD`: genuine semantic decisions
- `TS`: target-selection operations
- `DE`: genuinely new data entry
- `PR`: necessary preview/publication/recovery boundaries

Examples:

- choosing the changed Scheduled date is `SD/DE`, not tax,
- selecting which visible transaction is wrong is `TS`, not presentation tax,
- entering a purchase amount unknown to the system is `DE`, not redundant entry.

## 5.2 Interaction activity

Record:

- key presses / clicks / gestures,
- surface changes,
- focus-mode transitions,
- text fields entered,
- selectable candidates used,
- help lookups,
- command/palette searches,
- previews viewed,
- cancellations,
- retries.

Do not treat total action count as the score. It is evidence.

## 5.3 Timing

When actual dogfood exists, record:

- `T_start_preview`: start → first correct semantic preview,
- `T_preview_result`: preview → fresh result,
- `T_total`: complete task,
- `T_resume`: reopen after interruption → productive continuation.

Paper traces should leave timing blank rather than invent numbers.

## 5.4 Errors

Record actual error classes separately:

- wrong target,
- wrong date,
- wrong amount,
- wrong endpoint,
- wrong action/command,
- focus-mode mistake,
- mistaken belief that publication happened,
- mistaken belief that a draft is canonical,
- ignored/overlooked warning,
- stale-state conflict,
- failed recovery attempt.

---

# 6. Layer 3 — Friction decomposition

The word `friction` is too broad unless decomposed.

## 6.1 UI Tax

Work that exists only because of the presentation.

```text
UI Tax = PF + R + CD
```

### PF — presentation-focus tax

Count focus/mode transitions that do not select a real semantic target.

Examples:

- Calendar focus → Section focus,
- Section focus → Surface focus,
- unrelated pane switching required merely to reach the action.

### R — recall/re-entry tax

Count avoidable recall/re-entry.

Suggested units:

- `+2`: retype a visible internal identity,
- `+1`: re-enter a visible/inheritable human datum,
- `+1`: type an exact known token when safe recognition selection is available in principle.

### CD — context displacement

After completion/cancel/recovery:

- `0` same useful human place retained,
- `1` same domain but local place lost,
- `2` Home only; domain must be re-entered,
- `3` top menu/command shell; task context reconstructed,
- `4` effective restart.

UI Tax should generally be minimized.

## 6.2 Protective friction

Extra work that prevents a realistic harmful error.

Examples:

- Current/After before Capacity movement,
- explicit source/replacement before Correction,
- explicit approval for an ambiguous AI-proposed write.

Record:

- what risk the friction protects against,
- whether that risk actually occurs in dogfood,
- whether the protection can become lighter with familiarity without losing safety.

Protective friction is not a defect merely because it adds steps.

## 6.3 Learning friction

Temporary cost of understanding an unfamiliar task.

Record:

- help required,
- concepts introduced,
- whether guidance is contextual,
- whether the burden decays after repetitions.

## 6.4 Recovery friction

Cost after detecting an error or failed operation.

Record:

- `D_cancel`: distance to safe cancel,
- `D_correct`: distance from discovering error to a correction draft,
- number of facts re-entered,
- whether previous input is preserved,
- whether the next safe action is obvious.

## 6.5 Resumption friction

Cost after an interruption or time gap.

Record:

- `ResumeTime`,
- `ResumeErrors`,
- `ReconstructionQuestions`,
- whether the unfinished intent is described semantically,
- whether draft vs canonical authority is obvious.

A good resumption cue says something like:

```text
Replacing Sep 10 rent with Sep 12.
Amount unchanged.
Routing unresolved.
Nothing has been published yet.
```

not merely `cursor = row 7`.

## 6.6 Attention friction

Cost imposed by alerts, warnings, badges, suggestions, and repeated attention requests.

Record:

- alerts/day,
- repeated alerts,
- dismiss-without-reading,
- action-after-alert,
- missed important state,
- user desire to disable the alert,
- false urgency.

## 6.7 Visual-search burden

Cost of locating relevant information or control.

Record:

- search pauses,
- wrong-region moves,
- approximate-location recall,
- visual scanning before action,
- layout instability that forces relearning.

### Working rule

> Minimize UI tax, recovery friction, resumption friction, attention friction, and unnecessary visual search. Preserve semantic work. Use protective friction only when its safety benefit is real. Let learning friction decay.

---

# 7. Layer 4 — Usability profile

Do not collapse the following dimensions into one number during early research.

Use a profile such as `1–5 + note`, or qualitative `poor / weak / acceptable / strong / excellent`.

The note is mandatory when a rating is surprising or decisive.

## U1 Outcome effectiveness

Can the person correctly and completely accomplish the real household goal?

Measure:

- success/failure,
- semantic correctness,
- false-success belief,
- exceptional-state completion.

## U2 Interaction efficiency

Is the effort proportionate to the task?

Consider:

- UI Tax,
- total actions,
- time,
- repeated data entry,
- memory burden.

## U3 Orientation / situation awareness

Does the person know:

- where they are,
- what day/object is selected,
- what the system currently knows,
- whether state is fresh,
- what will happen next,
- whether the last action actually published?

## U4 Learnability / discoverability

Can a cold or returning user find and understand the action?

Consider:

- visible affordance,
- command/palette discoverability,
- labels in human language,
- contextual help,
- shortcut discoverability.

## U5 Error prevention / recovery

Does the UI prevent common errors and provide a short, comprehensible repair path?

## U6 Information fit

Does the surface show the right amount and kind of information for the decision?

Consider:

- visual hierarchy,
- risk-adjusted explanation density,
- exact vs overview representation,
- empty/unknown/unavailable distinctions,
- provenance drill-down.

## U7 Accessibility / input adaptability

Can the operation be used through appropriate input modalities without hiding status in color, pointer-only gestures, or fragile focus behavior?

## U8 Responsiveness / causal flow

Does the interface feel connected to the person's action?

Consider:

- latency,
- local immediate feedback,
- progress during long work,
- fresh result shown in place.

## U9 Trust / authority clarity

Does the interface encourage calibrated trust?

Consider:

- automation authority level visible,
- suggestion vs admitted fact clear,
- uncertainty explicit,
- explanation available,
- correction/dismissal easy.

## U10 Continuity / sustained use

Does the interaction survive interruption, time gaps, correction, and repeated household use?

## U11 Satisfaction / repeat willingness

Would the person willingly use this flow again?

Record separately:

- felt effort,
- confidence,
- stress/anxiety,
- preference,
- `RepeatWillingness`.

### Important

A high U2 efficiency rating cannot cancel a low U1 correctness rating or an SG failure.

---

# 8. Layer 5 — Information-shape tests

Some UI failures are not captured by action traces.

## IS-T1 Visual hierarchy

Can the user identify in a glance:

1. blocking/safety state,
2. action requiring attention,
3. current orientation,
4. ordinary facts,
5. secondary explanation/provenance?

### Rule

> Visual weight must be earned by decision importance.

## IS-T2 Spatial stability

Does repeated use create useful spatial memory, or does the interface continuously move landmarks?

### Rule

> Stable place before adaptive cleverness.

Do not casually reorder Home based on inferred usage.

## IS-T3 Navigation vs search

Can the person:

- navigate by recognition when they know the place,
- search/palette by intent when they know the goal but forgot the place?

### Rule

> Recognition for place, search for intent.

## IS-T4 Exactness vs overview

Choose representation by question.

```text
pattern / trend / outlier -> chart
exact value / search / selection / action -> table or list
need both -> linked overview + exact detail
```

### Rule

> Chart for shape, table for exactness.

## IS-T5 Epistemic empty states

Verify that these do not look identical:

- none,
- none at selected coordinate,
- unknown,
- unavailable/failure,
- filtered out,
- future/not yet observed,
- not configured.

### Rule

> Empty must preserve epistemic meaning.

## IS-T6 Human error layer

Primary error text should explain:

- what happened in human terms,
- what did **not** happen,
- the next safe action.

Exact technical/provenance detail remains expandable.

### Rule

> Human situation first, exact diagnosis reachable.

## IS-T7 Defaults

For every default ask:

- is it visible?
- is it editable?
- is it only draft convenience?
- could accepting it manufacture independent evidence?

### Rule

> Default presentation, never default authority.

---

# 9. Layer 6 — Learning and time profile

A recurring-use UI must be measured over a curve.

At minimum evaluate:

| Phase | Why |
|---|---|
| first encounter | discoverability / cold-start cost |
| 5th repetition | early learning |
| 20th repetition | muscle memory / expert acceleration |
| after a one-week gap | relearnability / spatial memory |
| after interruption | resumption |
| after an error | recovery |
| after interface change | transition cost |

For rare operations such as historical correction, treat **every use as approximately a cold start** until evidence shows otherwise.

### Rule

> Measure the curve, not one point.

A candidate may be slower initially but excellent by repetition 20. That is acceptable only if the initial burden is not high enough to cause abandonment.

---

# 10. Layer 7 — Avoidance as a first-class failure signal

A household system can pass task-based usability tests while failing in life.

Record behaviors such as:

- “I will enter it later.”
- small purchases begin to go unrecorded,
- correction is postponed despite a known error,
- Capacity is never used because the workflow feels risky,
- repeated alerts are ignored automatically,
- a useful feature remains dormant because it is hard to rediscover.

Track:

- `AvoidanceIntent`: stated desire to postpone/avoid,
- `FeatureDormancy`: capability stops being used despite recurring need,
- `CleanupDebt`: unresolved corrections/tasks accumulate,
- `AlertDismissalHabit`: alerts dismissed without reading,
- `RepeatWillingness`: willingness to perform again,
- `FallbackBehavior`: user leaves LOAM for notes/manual workaround/ChatGPT-only memory.

### Rule

> Measure what the person stops doing.

### Strong rejection signal

If a task is semantically important and repeatedly avoided because of the interaction, the design should be treated as failing even when isolated completion is technically possible.

---

# 11. Frequency × consequence interaction policy

Use frequency to decide **reachability** and consequence to decide **protective explanation**.

| | Lower consequence / easy recovery | Higher consequence / harder recovery |
|---|---|---|
| Frequent | direct, compact, defaults, shortcut | fast target selection + compact semantic preview |
| Infrequent | searchable/palette, contextual help | staged flow, explicit before/after, strong recovery |

### Candidate examples

#### Frequent + low consequence

Ordinary Actual entry:

- selected-day default,
- recognition-first loci,
- minimal explanation,
- direct `r` or local action,
- easy correction afterward.

#### Frequent + meaningful consequence

Scheduled realization:

- select visible object,
- editable defaults,
- compact target/Actual preview,
- no silent independent routing/continuation inference.

#### Rare + low consequence

Advanced report/export:

- palette / More actions,
- descriptive label,
- no permanent Home clutter.

#### Rare + high consequence

Historical Correction / ambiguous recovery:

- selected target visible,
- staged explanation,
- before/after effective meaning,
- strong cancel/recovery,
- provenance available.

### Rule

> Frequency earns directness. Consequence earns explanation.

---

# 12. Expertise and multi-route policy

A good LOAM surface can expose several routes to one semantic action.

```text
visible local action
keyboard shortcut
command palette
CLI
ChatGPT proposal
GUI/menu
    ↓
shared application action / admission boundary
```

These routes may have different presentation shapes.

They must not become different accounting semantics.

### Rule 1

> Expertise changes access cost, not meaning.

### Rule 2

> Multiple routes, one meaning.

### Rule 3

> Personalize presentation and acceleration, not semantic authority.

Safe customization candidates:

- shortcut bindings,
- compact/roomy density,
- optional secondary Home blocks,
- chart/table preference.

Risky adaptation:

- silently reordering actions,
- hiding rarely used commands,
- changing Enter behavior by prediction,
- changing semantic defaults from inferred habits.

---

# 13. Automation / ChatGPT evaluation overlay

For AI or automation paths, additionally record:

## A1 Authority level

```text
L0 observe
L1 suggest
L2 prefill draft
L3 act after explicit approval
L4 automatic with immediate audit/reversal
L5 autonomous policy action
```

Authority is per operation family, not one global AI setting.

## A2 Uncertainty handling

Can the UI distinguish:

- known,
- proposed,
- ambiguous,
- unavailable?

## A3 Correction cost

Can the user easily:

- reject,
- edit,
- narrow scope,
- understand why the suggestion happened?

## A4 Automation trust failure

Look for both:

- **misuse / over-reliance**: accepting guesses as facts,
- **disuse / under-reliance**: ignoring reliable automation because past behavior was opaque or annoying.

### Rule

> Optimize for calibrated trust, not maximum trust.

---

# 14. Candidate score sheet

Use one sheet per `scenario × candidate × familiarity phase`.

```text
Scenario:
Candidate:
Surface:
Start context:
Frequency / consequence:
Familiarity phase:
Interruption condition:

SAFETY GATE
SG01 semantic honesty        PASS / FAIL / N/A
SG02 provenance             PASS / FAIL / N/A
SG03 fail-closed            PASS / FAIL / N/A
SG04 publication protocol   PASS / FAIL / N/A
SG05 no manufacture         PASS / FAIL / N/A
SG06 authority legibility   PASS / FAIL / N/A
SG07 protective review      PASS / FAIL / N/A
Eligible: YES / NO

RAW TRACE
SD:
TS:
DE:
PR:
Actions:
PF:
R:
CD:
UI Tax:
Help lookups:
Errors:
T_start_preview:
T_total:

FRICTION
Protective friction:
Learning friction:
Recovery friction:
Resumption friction:
Attention friction:
Visual-search burden:

PROFILE (1–5 + note)
U1 effectiveness:
U2 efficiency:
U3 orientation:
U4 discoverability:
U5 error/recovery:
U6 information fit:
U7 accessibility:
U8 responsiveness:
U9 trust/authority clarity:
U10 sustained continuity:
U11 satisfaction/repeat willingness:

SUSTAINED-USE SIGNALS
AvoidanceIntent:
FeatureDormancy:
CleanupDebt:
AlertDismissalHabit:
FallbackBehavior:

OBSERVATION
What felt good:
What caused hesitation:
What was forgotten:
What should remain unchanged:
What should be falsified next:
```

Do not average this sheet automatically.

---

# 15. Candidate comparison view

For a scenario, compare candidates using a profile rather than a winner number.

Example structure:

| Dimension | Current CLI | HRA-flat | Focus shell | Flat+palette |
|---|---:|---:|---:|---:|
| Safety eligible | PASS | modeled PASS | modeled PASS | modeled PASS |
| UI Tax | 4 | 0 | 0 | 0 |
| Effectiveness | ? | ? | ? | ? |
| Orientation | ? | ? | ? | ? |
| Discoverability | ? | ? | ? | ? |
| Recovery | ? | ? | ? | ? |
| Repeat willingness | ? | ? | ? | ? |
| Avoidance | ? | ? | ? | ? |

Paper candidates must keep unknown human-use dimensions as `?`.

Do not convert imagined usability into fake precision.

---

# 16. Minimal synthetic dogfood corpus v0.1

A candidate shell should not be selected from one easy transaction.

## Local daily tasks

1. ordinary purchase today,
2. purchase three days ago,
3. simple income,
4. PayPay/wallet charge,
5. split purchase.

## Object lifecycle

6. complete Scheduled as Actual,
7. Scheduled Actual differs in amount,
8. replace/reschedule Scheduled,
9. cancel/retire future item,
10. correction discovered from history.

## Capacity / planning

11. move Capacity from unallocated to purpose,
12. move Capacity between purposes,
13. inspect Current/After before committing.

## Difficult meaning

14. shared cost and later settlement,
15. refund,
16. points/discount case,
17. duplicate/import match,
18. external balance mismatch.

## Failure / recovery

19. stale Scheduled draft,
20. interrupted relation-first publication/retry,
21. invalid/ambiguous state,
22. user cancels halfway through entry.

## Sustained use

23. interrupt a split entry and return hours later,
24. return after one week and perform a rare Correction,
25. repeated low-value attention over 14 simulated days,
26. AI proposes an ambiguous routing,
27. user rejects an AI suggestion then sees another similar case,
28. interface location changes after familiarity develops.

Not every scenario needs every surface. Record `N/A` honestly.

---

# 17. Evidence grades

Keep evidence quality visible.

- `E0 speculation` — idea only
- `E1 paper trace` — state-machine or code-derived prediction
- `E2 synthetic dogfood` — user performs realistic scenario with scratch data
- `E3 repeated synthetic use` — learning/resumption curve observed
- `E4 household dogfood` — naturally occurring real need
- `E5 sustained household use` — repeated use over multiple cycles

A high score at E1 must never be presented as equivalent to E4/E5 evidence.

The current HRA preference is valuable experiential evidence, while the flat+palette candidate remains primarily E1 until dogfooded.

---

# 18. Decision states

Use explicit states instead of vague enthusiasm.

## REJECTED

Candidate violates safety, creates repeated errors, or produces clear avoidance/overload.

## RESEARCH

Interesting but insufficient evidence.

## DOGFOOD

Ready for synthetic use.

## SURVIVES

Has survived the current falsification scenarios but is not yet implementation-worthy.

## EARNED

A practical need and repeated evidence justify implementation or retention.

### Candidate EARNED conditions

For a UI feature/pattern, require at least:

1. relevant Safety Gate passes,
2. solves a repeated or important human goal,
3. beats or complements the current path on at least one meaningful dimension,
4. does not cause a serious regression in another dimension,
5. does not show repeated avoidance,
6. survives at least the relevant interruption/error/cold-start tests,
7. can map to existing LOAM semantics without inventing a new concept unless that concept has separately been earned.

---

# 19. Consolidated LOAM UI laws v0.1

These are hypotheses to test, not commandments.

## L01 — Semantic honesty

Never make a guess look like evidence.

## L02 — Recognition-first identity

Visible identity is useful; recalled internal identity is usually unnecessary.

## L03 — Stable place

Stable spatial/temporal landmarks are assets. Do not move them casually.

## L04 — Return is part of the operation

A write is not interaction-complete until the person sees fresh state and remains oriented.

## L05 — Unfinished is first-class

An unfinished draft is neither nothing nor canonical fact.

## L06 — Risk-adjusted explanation density

Ordinary actions can be compact. Consequential/rare actions earn more explanation.

## L07 — Default presentation, never default authority

Defaults may prefill drafts but must not manufacture meaning.

## L08 — Attention is scarce

Quiet is a feature. High-severity signals must remain rare enough to matter.

## L09 — Empty preserves epistemic meaning

None, unknown, unavailable, filtered, future-unobserved, and not-applicable must not collapse together.

## L10 — Human error first, exact diagnosis reachable

Explain the human situation and next safe action before technical internals.

## L11 — Recognition for place, search for intent

Navigation and command search are complementary.

## L12 — Chart for shape, table for exactness

Use overview graphics for patterns and exact rows for inspection/action.

## L13 — Expertise changes access cost, not meaning

Shortcuts and direct manipulation must lead to the same semantic action as visible/guided routes.

## L14 — Multiple routes, one meaning

CLI, TUI, GUI, ChatGPT, and mobile may differ in interaction shape without semantic forks.

## L15 — Calibrated automation trust

Make suggestions, approvals, authority, uncertainty, and correction legible.

## L16 — Measure the curve

Recurring tasks must be evaluated across learning and time gaps, not one session.

## L17 — Rare tasks are repeated cold starts

Correction and unusual recovery must remain discoverable after forgetting.

## L18 — Measure what people stop doing

Avoidance is evidence.

## L19 — Visual weight must be earned

Prominence belongs to information that changes the next human decision.

## L20 — Implement only what LOAM earns

No UI pattern, widget, or new semantic concept is justified merely because it looks polished or exists in another product.

---

# 20. Immediate use of this framework

The next UI research should use this framework against the four current shell candidates:

1. current LOAM CLI,
2. HRA-derived flat shell,
3. h-kernel-derived focus shell,
4. flat + palette hybrid.

Do **not** build all four.

Start with paper traces where appropriate, then use the smallest possible interactive prototype only when a human-use dimension cannot be answered on paper.

Highest-value first scenarios:

1. ordinary Actual entry,
2. past Actual,
3. Scheduled realization,
4. Scheduled replacement,
5. discovered Correction,
6. Capacity movement,
7. interrupted unfinished operation,
8. rare operation after a simulated time gap.

The current research hypothesis remains:

> HRA's low presentation tax and stable orientation are valuable, while LOAM's stronger semantic/publication machinery should remain underneath. A flat + palette shell may combine those strengths, but it must now survive discoverability, resumption, attention, learning-curve, and avoidance tests before implementation is earned.

---

## Working rule

> Correct first. Remove needless burden. Add only useful friction. Preserve place. Make uncertainty visible. Measure continued use. Implement only what survives.
