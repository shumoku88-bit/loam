# LOAM Interaction Atlas — What Makes a Good UI?

Date: 2026-09-06
Status: **broad HCI research shard; not a LOAM UI specification**
Parent: `LOAM_INTERACTION_ATLAS.md`

---

## 0. Why this shard exists

The interaction research so far found a useful but deliberately narrow result:

- HRA had a flatter human-visible interaction graph,
- h-kernel added more presentation-focus state,
- current LOAM CLI has stronger semantic/publication safety but more repeated context entry,
- a flat + palette shell looks promising on paper.

The first structural scorecard measured one thing well:

> how much work the UI adds that is not part of the household meaning itself.

That is useful, but it is **not a definition of a good UI**.

A household system can have very few keystrokes and still be bad if it:

- makes wrong actions easy,
- hides important state,
- encourages premature decisions,
- makes the user uncertain whether the right thing happened,
- is difficult to learn,
- is stressful enough that the user avoids recording,
- exposes so much complexity that useful capabilities go unused,
- is fast for experts but opaque to occasional use,
- interrupts the user's mental model after every action,
- silently converts uncertainty into false certainty,
- requires a separate conceptual vocabulary merely to operate the software.

Conversely, additional interaction can be beneficial when it:

- prevents a costly mistake,
- helps the user understand a consequential transition,
- makes an uncertain or exceptional state visible,
- supports recovery,
- teaches an unfamiliar operation at the moment it is needed,
- compares alternatives before commitment.

This shard therefore asks a broader question:

> What is a good UI, when we stop equating “good” with “few interactions”?

The research deliberately leaves personal finance and accounting and samples ideas from:

- general HCI/usability,
- government transactional services,
- accessibility,
- safety-critical aerospace interfaces,
- IDEs and expert tools,
- games/onboarding,
- mobile interaction,
- performance/latency research.

---

# 1. The first correction: usability is not efficiency

ISO 9241-11 defines usability in terms of three outcomes in a **specified context of use**:

1. **effectiveness** — accuracy and completeness in achieving goals,
2. **efficiency** — resources used in relation to results achieved,
3. **satisfaction** — physical, cognitive, and emotional responses meeting needs and expectations.

The context matters: users, goals, tasks, resources, and environment all change what “good” means.

This immediately invalidates a one-dimensional optimization such as:

```text
fewer clicks = better UI
```

A better starting point is:

```text
Good UI
  = correct outcomes
  + reasonable effort
  + sustainable willingness to use it
  + appropriate safety
  + appropriate understanding
  + fit to the actual context
```

Sources:

- ISO 9241-11:2018: https://www.iso.org/standard/63500.html
- ISO 9241 interaction principles: https://www.iso.org/obp/ui/#iso:std:iso:9241:-110:dis:ed-2:v1:en

---

# 2. Friction is not one thing

The previous scorecard used `UI Tax` to capture unnecessary presentation burden.

Broad HCI research suggests that the word **friction** needs to be split.

## 2.1 Semantic work

Work the person genuinely must do because reality is not already known.

Examples:

- which payment happened,
- how much actually moved,
- which future expectation is being changed,
- whether two records describe the same real-world event.

This cannot safely be optimized to zero unless the information can be obtained from reliable evidence.

## 2.2 UI tax

Work caused only by the interface.

Examples:

- retyping a visible internal ID,
- re-entering an already selected date,
- moving focus through an unrelated shell hierarchy,
- remembering which pane owns a shortcut,
- navigating back to the same object after every operation.

This is the friction we should aggressively remove.

## 2.3 Protective friction

Extra interaction intentionally inserted because acting too quickly can be harmful.

GOV.UK explicitly notes that good services should minimize steps **except when speed increases the risk of failure**, in which case the service may deliberately slow the user down with a warning or review step.

Examples for LOAM:

- showing Current/After before a Capacity movement,
- showing source and replacement before a historical correction,
- refusing a stale Scheduled completion after canonical state changed,
- requiring explicit approval for a ChatGPT-proposed write.

Protective friction is not UI tax when it prevents a realistic class of harmful errors.

## 2.4 Learning friction

Temporary effort that helps the user understand a new operation.

Good onboarding research does not suggest front-loading a manual. Apple recommends teaching through interaction and providing contextual tips, with onboarding fast and optional.

Learning friction is justified when it decreases later uncertainty and can disappear as competence grows.

## 2.5 Recovery friction

Work required after something went wrong or changed.

A good UI minimizes recovery distance even if the original operation was necessarily complex.

Examples:

- correction available directly from the object where the mistake is noticed,
- interrupted publication produces a clear resumable state,
- Esc reliably returns to the previous place,
- the user can see why an action is unavailable.

### Working law UI-FR-01

> Minimize UI tax. Preserve necessary semantic work. Add protective friction only where it buys meaningful safety. Reduce recovery friction. Let learning friction decay with experience.

Source:

- GOV.UK good services: https://www.gov.uk/service-manual/design/introduction-designing-government-services
- Apple onboarding: https://developer.apple.com/design/human-interface-guidelines/onboarding

---

# 3. Good UI is task- and context-relative

One of the strongest findings from non-financial UI guidance is that apparently contradictory interface patterns can both be correct.

## 3.1 “One thing per page” can be excellent

GOV.UK recommends starting unfamiliar public forms with one decision/question per page because it:

- focuses attention,
- works well on mobile,
- improves error recovery,
- supports branches and loops,
- helps lower-confidence users.

## 3.2 Dense single-screen interfaces can also be excellent

The same GOV.UK guidance explicitly says internal/expert services may need a different balance when users:

- repeat tasks quickly,
- switch between tasks,
- need all relevant information in one place for a decision.

Nielsen Norman Group makes a similar point in progressive disclosure research: staged screens help when phases are separable, but when values are interdependent and the user repeatedly compares alternatives, forcing them across several screens can make the task worse.

### Implication for LOAM

There should probably be no universal rule such as:

```text
all operations must be one screen
```

or:

```text
all operations must be staged
```

Instead classify the task.

| Task shape | Likely UI bias |
|---|---|
| frequent + familiar + reversible | compact, direct |
| infrequent + unfamiliar | guided/staged |
| interdependent comparison | one workspace with visible alternatives |
| consequential + hard to reverse | explicit review/protective friction |
| exploratory/investigative | dense overview + drill-down |

Sources:

- GOV.UK form structure: https://www.gov.uk/service-manual/design/form-structure
- GOV.UK internal services: https://www.gov.uk/service-manual/design/services-for-government-users
- Progressive disclosure: https://www.nngroup.com/articles/progressive-disclosure/

---

# 4. A broader model of good UI

This shard proposes nine evaluation dimensions. None is sufficient alone.

## G1. Outcome effectiveness

Can the person actually achieve the intended real-world goal correctly and completely?

Questions:

- Did the intended task complete?
- Did the user believe it completed when it did not?
- Did the interface lead to a semantically wrong result?
- Can exceptional states still reach a clear outcome?

This is more important than raw speed.

## G2. Interaction efficiency

How much time, attention, memory, movement, and input does correct completion require?

This contains the previous UI Tax work but extends beyond keystrokes.

Questions:

- Is known information asked twice?
- Must internal identifiers be recalled?
- Is navigation disproportionate to the task?
- Are repeated expert tasks accelerated?

## G3. Sustainable use / satisfaction

Will the person willingly keep using the capability?

For LOAM this is crucial because a theoretically perfect accounting operation is useless if the interaction is irritating enough that the user postpones or avoids recording.

Questions:

- Does the task feel burdensome?
- Would the user willingly do this again tomorrow?
- Does a feature become avoided despite being useful?
- Does the interface create anxiety about making a mistake?
- Does the user trust that they understood what happened?

This dimension operationalizes the ISO satisfaction component for long-lived household software.

## G4. Learnability and discoverability

Can an unfamiliar capability be found and learned without a manual?

Nielsen's recognition-rather-than-recall heuristic is directly relevant. VS Code's Command Palette is an instructive expert-tool pattern: all commands remain searchable while common commands can also have shortcuts.

Questions:

- Can I find a capability if I forgot the shortcut?
- Are names written in language that matches the user's goal?
- Can shortcuts accelerate use without becoming the only path?
- Does advanced functionality appear only when relevant?

## G5. Orientation and situation awareness

Does the user know where they are, what is selected, what the system currently knows, and what will happen next?

This connects the HRA selected-day finding with safety-critical interface research.

NASA cockpit research explicitly measures information acquisition, attentional allocation, latency, errors, subjective workload, and situation awareness. NASA guidance also favors an overview “big picture” with direct access to subsystem details.

For LOAM:

- selected day visible,
- selected object visible,
- known-through boundary visible,
- open/complete/replaced/unknown visible,
- after a write, fresh state returned to the same human place.

## G6. Error prevention and recovery

Good error messages are secondary to preventing avoidable errors.

Nielsen's heuristics emphasize constraints and warning before high-risk commitment. WCAG 2.2 adds explicit guidance against redundant entry and requires predictable help and input assistance.

Questions:

- Can invalid combinations be impossible rather than merely rejected later?
- Is an error detected close to where it occurs?
- Can the user safely cancel?
- Is correction available from the context where the mistake is noticed?
- Does interruption leave a comprehensible recovery state?

## G7. Appropriate information density

A good UI neither hides needed information nor dumps everything at once.

Apple's feedback guidance says information severity should control presentation intensity:

- ordinary status can remain quiet and inspectable,
- important failure should be noticeable,
- possible data loss may justify interruption.

Nielsen's progressive disclosure similarly argues that frequent essentials belong up front and rare options belong behind a clear secondary path.

For LOAM this suggests **risk-adjusted explanation density**:

- ordinary purchase: compact,
- Scheduled replacement: target/replacement explanation,
- Capacity movement: Current/After,
- invalid canonical state: loud fail-closed presentation.

## G8. Accessibility and input adaptability

Accessibility is not a decorative final pass.

Apple describes accessible interfaces as intuitive, perceivable, and adaptable. WCAG 2.2 adds requirements around focus visibility, dragging alternatives, target size, predictable help, and redundant entry.

For LOAM surface research:

- keyboard-first must not mean keyboard-only,
- color cannot be the only status signal,
- focus must remain visible,
- pointer targets must be comfortably sized on mobile/GUI,
- drag must never be the only way to move allocation,
- text alternatives must exist for icons/status,
- time-limited prompts should be avoided.

## G9. Responsiveness and flow

Latency changes the feel of an interface even when task structure is unchanged.

Classic HCI response-time thresholds remain useful qualitative landmarks:

- around 0.1 s feels immediate,
- around 1 s generally preserves the user's flow of thought,
- around 10 s risks losing attention.

LOAM's TUI should therefore preserve the low-latency feel that made HRA pleasant, while long verification/publication steps need explicit progress/result feedback rather than unexplained pauses.

Sources:

- Nielsen heuristics: https://www.nngroup.com/articles/ten-usability-heuristics/
- Apple feedback: https://developer.apple.com/design/human-interface-guidelines/feedback
- Apple accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- WCAG 2.2: https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/
- NASA cockpit research: https://www.nasa.gov/human-systems-integration-division/cockpit-display-design-intelligent-spacecraft-interface-systems/
- NASA HSI testing: https://www.nasa.gov/reference/3-0-systems-engineering-processes-vol-2/
- Response times: https://www.nngroup.com/articles/response-times-3-important-limits/

---

# 5. Lessons from different interface domains

## 5.1 Government services: optimize the whole outcome, not the screen

GOV.UK repeatedly frames a service as something that helps a person accomplish a real goal from start to finish, across channels.

Useful lessons for LOAM:

- model the user's goal, not the software's module structure,
- avoid exposing backend/internal organizational structure unnecessarily,
- avoid dead ends,
- minimize repeated data entry,
- use the person's language,
- slow down where speed creates risk,
- research and iterate with actual use.

Potential LOAM translation:

The user may think:

> “I moved 3,000 yen from SMBC to PayPay.”

They should not need to first decide which internal persistence family or relation stream owns that fact.

Internal structure should remain inspectable for provenance, but not become the mandatory navigation model.

Source:

- https://www.gov.uk/service-manual/design/introduction-designing-government-services
- https://www.gov.uk/service-manual/design/scoping-your-service

## 5.2 Safety-critical systems: situation awareness beats decorative simplicity

A cockpit can never be judged by few clicks alone.

NASA human-systems work evaluates:

- error rates,
- latencies,
- switch/key actions,
- eye movement,
- attentional allocation,
- subjective workload,
- situation awareness.

NASA standards require iterative human-in-the-loop testing during development because workload and display problems must be found before final verification.

Useful LOAM lesson:

> Do not merely count actions. Observe attention, uncertainty, workload, and whether the user understands current state.

LOAM is not safety-critical aerospace software, but the methodological lesson is valuable.

Source:

- https://www.nasa.gov/human-systems-integration-division/cockpit-display-design-intelligent-spacecraft-interface-systems/
- https://www.nasa.gov/reference/3-0-systems-engineering-processes-vol-2/

## 5.3 IDEs: discoverability and expert speed can coexist

VS Code keeps a searchable Command Palette containing commands while also exposing keyboard shortcuts where appropriate. JetBrains' Search Everywhere similarly provides a universal discovery path alongside many direct shortcuts and navigation history commands.

This strongly supports the flat + palette candidate for LOAM:

```text
frequent action       -> direct mnemonic / local action
forgotten/rare action -> searchable palette
```

The two are complements, not competitors.

Useful additional IDE lesson:

- Back / Forward,
- recent locations,
- last edit location,
- current focus visibility,

all treat **place continuity** as a first-class interaction problem.

That reinforces the HRA finding that preserving the selected day/object after a write may matter more than shaving a single keystroke inside the form.

Sources:

- VS Code Command Palette: https://code.visualstudio.com/api/ux-guidelines/command-palette
- VS Code accessibility/keyboard navigation: https://code.visualstudio.com/docs/configure/accessibility/accessibility
- JetBrains Search Everywhere: https://www.jetbrains.com/help/idea/searching-everywhere.html

## 5.4 Games: teach the core loop by doing

Apple's game onboarding guidance emphasizes:

- teach essential activities through interaction,
- introduce complexity gradually,
- teach one step at a time,
- let users demonstrate competence,
- allow experienced users to skip tutorials,
- defer non-essential concepts until later.

Potential LOAM lesson:

Do not teach “EventCorrection”, “RelationDischarge”, or “CapacityEffectiveMemory” up front.

Teach the person's operation:

```text
record purchase
change a scheduled payment
correct this record
move spending capacity
```

and reveal deeper semantics contextually when the operation actually needs them.

Source:

- https://developer.apple.com/app-store/onboarding-for-games/
- https://developer.apple.com/design/human-interface-guidelines/onboarding

## 5.5 Accessibility: redundancy is a usability defect, not only an accessibility defect

WCAG 2.2's `Redundant Entry` criterion explicitly warns against making a person enter the same information twice within a process.

This makes the current LOAM Scheduled pattern especially notable:

```text
show scheduled-7
ask user to type scheduled-7
```

The problem is broader than convenience. It consumes memory and creates an unnecessary error opportunity.

Source:

- https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/

## 5.6 Performance: responsiveness is part of meaning

A low-latency interface feels causally connected to the user's action. Slow unexplained transitions weaken direct manipulation and interrupt thought.

Potential LOAM rule:

- navigation, selection, filtering, calendar movement: effectively immediate,
- local projections: fast enough to preserve flow,
- expensive verification/write: explicit visible progress and final fresh-state result.

Source:

- https://www.nngroup.com/articles/response-times-3-important-limits/

---

# 6. Frequency × consequence: one promising LOAM classifier

The research suggests that interaction design should differ according to both **frequency** and **consequence**.

| | Lower consequence / easy recovery | Higher consequence / harder recovery |
|---|---|---|
| **Frequent** | direct, fast, defaults, shortcuts | fast target selection + clear compact preview |
| **Infrequent** | discoverable palette / contextual guidance | staged flow + explicit before/after + strong recovery |

Possible LOAM mapping:

## Frequent + recoverable

Examples:

- ordinary Actual recording,
- viewing selected day,
- searching recent history.

Bias:

- selected-day defaults,
- recognition-first account/locus selection,
- minimal explanation,
- direct shortcut,
- easy correction afterward.

## Frequent + consequential

Examples:

- completing a Scheduled item when actual details differ,
- recording shared-cost settlement when relationships matter.

Bias:

- object-local action,
- editable defaults,
- compact semantic preview,
- do not infer independent relations.

## Infrequent + recoverable

Examples:

- unusual report query,
- privacy/scramble option,
- advanced export.

Bias:

- palette / More actions,
- good labels,
- contextual help,
- no permanent Home clutter.

## Infrequent + consequential

Examples:

- historical correction,
- Capacity movement,
- authority migration/recovery,
- resolving ambiguous evidence.

Bias:

- explicit target,
- staged explanation,
- Current/After when useful,
- fail-closed,
- clear cancel path,
- provenance visible.

### Candidate law UI-FREQ-01

> Frequency decides how directly an action should be reachable. Consequence decides how much protective explanation/confirmation it earns.

---

# 7. Expertise changes what “good” means

A UI can be excellent on first use and irritating after the hundredth repetition.
A UI can also be extremely efficient for experts and almost undiscoverable at first use.

Therefore synthetic evaluation should distinguish at least:

1. **cold use** — user does not remember the action,
2. **warm use** — user recognizes the operation but not all shortcuts,
3. **habitual use** — repeated daily action,
4. **rare return** — feature last used weeks/months ago.

This is particularly important for LOAM because the same person is both:

- expert at daily recording,
- novice again at rarely used recovery/migration operations.

### Candidate law UI-EXP-01

> Do not design one global “novice mode” and one global “expert mode”. Expertise is per operation.

The flat + palette model fits this well:

- direct shortcut for habitual action,
- visible local actions for warm use,
- palette for rare return,
- contextual guided flow for unfamiliar/high-risk operations.

---

# 8. Information should appear when it changes a decision

A useful synthesis across progressive disclosure, government transaction design, and safety-critical overview/detail interfaces is:

> Show information when it helps the person choose, understand, or recover. Do not show it merely because the system has it.

This is more precise than “minimalism”.

Examples:

### Ordinary purchase

Likely useful now:

- selected day,
- From,
- To/use,
- amount,
- description if helpful,
- compact preview.

Probably not useful now unless exceptional:

- correction-chain structure,
- publication stream order,
- every retained evidence identifier.

### Scheduled replacement

Useful now:

- existing expectation,
- replacement draft,
- date/amount differences,
- routing status if independent,
- fact that replacement does not imply continuation.

### Capacity movement

Useful now:

- current balance/entitlement,
- source/destination,
- amount,
- after-state.

### Failure/recovery

Useful now:

- what is incomplete/ambiguous,
- why normal action is blocked,
- what safe next action exists.

### Candidate law UI-INFO-01

> Minimalism means minimizing irrelevant decision load, not minimizing visible information.

---

# 9. Calm home vs useful attention

A household UI can become exhausting if Home acts like an alarm dashboard for every calculable condition.

Apple's feedback guidance distinguishes presentation intensity by severity. NASA's overview guidance similarly values a useful “big picture” rather than every subsystem detail at once.

Potential LOAM Home rule:

- ordinary healthy state stays quiet,
- upcoming facts are visible but not alarming,
- user action required gets stronger emphasis,
- blocked/invalid canonical state interrupts normal interpretation,
- detailed provenance remains one action away.

This supports the earlier Home/Attention Atlas idea that **quiet is a feature**.

---

# 10. Evaluation should measure abandonment and confidence

GOV.UK usability benchmarking does not only measure task time. It also measures:

- task completion,
- abandonment,
- false belief that a task completed,
- perceived difficulty,
- confidence in the answer,
- whether completion took longer than expected.

This maps unusually well to the user's concern that a technically capable household system can fail if interaction stress causes avoidance.

For LOAM synthetic/dogfood evaluation, add:

| Metric | Question |
|---|---|
| `Success` | Did the intended semantic outcome occur? |
| `FalseSuccess` | Did the user think it succeeded when it did not? |
| `Time` | How long did correct completion take? |
| `UI Tax` | How much presentation/recall/context overhead occurred? |
| `Confidence` | How sure is the user that the result is correct? |
| `FeltEffort` | How effortful/stressful did it feel? |
| `RepeatWillingness` | Would I willingly do this again tomorrow? |
| `Avoidance` | Would I postpone/skip this because the UI is annoying? |
| `RecoveryDistance` | From discovering a mistake, how far to a safe correction? |
| `ContextReturn` | Did I return to the same useful place after completion? |
| `SafetyGate` | Were LOAM semantic/provenance/fail-closed guarantees preserved? |

Source:

- GOV.UK usability benchmarking: https://www.gov.uk/service-manual/measuring-success/usability-benchmarking-a-website-or-whole-service

---

# 11. Replace “overall usability score” with an evaluation profile

A single 100-point score is tempting but can hide tradeoffs.

For the next phase, keep a profile:

```text
Effectiveness        █████
Efficiency           ████░
Sustainable use      █████
Discoverability      ███░░
Orientation          █████
Error/recovery       ████░
Information fit      ████░
Accessibility        ████░
Responsiveness       █████
Safety               PASS
```

Only later, after repeated dogfood shows which dimensions predict real preference and avoidance, consider weighting.

### Why this is preferable

Two candidate interfaces can have the same UI Tax but differ dramatically:

- one may be faster but opaque,
- another slower but confidence-building,
- one may be excellent daily but impossible to rediscover after a month,
- one may be safe but stressful,
- one may be delightful but silently wrong.

The profile preserves these distinctions.

---

# 12. Revised interpretation of the HRA result

Earlier structural result:

- HRA mean UI Tax: `0.0`
- h-kernel mean UI Tax: `1.5`
- current LOAM CLI mean UI Tax: `3.3`

This remains useful, but its correct interpretation is now narrower:

> HRA appears to have imposed less presentation/recall/context overhead in the sampled tasks.

It does **not** yet show that HRA is universally better on:

- discoverability,
- accessibility,
- unusual tasks,
- first use,
- mouse/touch,
- error prevention,
- long-term capability growth,
- semantic honesty,
- safety under concurrent writes,
- recovery from partial publication.

The user's real-world preference is nevertheless strong evidence that the low-tax interaction topology deserves high weight.

The next research phase should test whether that topology can retain its advantage while improving the other dimensions.

---

# 13. Revised flat + palette hypothesis

The broader research strengthens, but also constrains, the hybrid candidate.

Candidate shell:

```text
stable selected time/context
        |
        +--> direct high-frequency actions
        |
        +--> object-local actions
        |
        +--> searchable palette for long tail
        |
        +--> guided/staged flows for rare consequential operations
        |
        +--> provenance/explanation on demand
```

Why it remains promising:

- HRA-like low presentation tax,
- IDE-like discoverability + expert acceleration,
- progressive disclosure for long-tail complexity,
- risk-adjusted protective friction,
- reusable across TUI/GUI/ChatGPT/mobile without forcing identical layouts.

But this is still a hypothesis, not a selected UI.

---

# 14. Cross-surface consequences

A shared semantic application action does not imply identical interaction.

## CLI

Optimize for:

- explicitness,
- scripting,
- reproducibility,
- composability,
- machine-readable errors/results.

Low discoverability is acceptable if a `help`/command discovery path is strong.

## TUI

Optimize for:

- continuity,
- low-latency keyboard flow,
- visible context,
- object-local actions,
- searchable long-tail commands,
- optional pointer/mouse support.

## GUI/Web

Optimize for:

- overview,
- direct selection,
- comparisons,
- drill-down,
- provenance exploration,
- accessible pointer + keyboard operation.

## ChatGPT

Optimize for:

- natural-language intent,
- ambiguity exposure,
- structured proposal,
- explicit approval for writes,
- explanation in ordinary language,
- link/jump to deeper UI when inspection is easier visually.

## Mobile

Optimize for:

- point-of-event capture,
- touch targets,
- minimal redundant typing,
- notifications as contextual entrances,
- camera/receipt evidence where earned,
- brief interactions with deeper details available later.

The same action can therefore have different **interaction cost shapes** while retaining one semantic contract.

---

# 15. New research hypotheses

## GU-01 — Sustainable use dominates theoretical completeness

A feature that is semantically correct but habitually avoided due to interaction burden is not practically successful.

Measure actual avoidance, not just completion speed.

## GU-02 — Context preservation may predict satisfaction better than raw keystrokes

Returning to the same day/object after a write may matter more than reducing one field in the editor.

## GU-03 — Protective friction should scale with consequence

Uniform confirmation dialogs are likely inferior to risk-specific preview.

## GU-04 — Rare actions need rediscoverability more than shortcuts

Palette/search/contextual help may beat permanent mnemonic allocation for the long tail.

## GU-05 — Frequent actions need muscle-memory paths

Daily recording should not require repeated browsing through a generalized hierarchy.

## GU-06 — Good minimalism preserves decision-relevant density

A dense Capacity before/after view may be more usable than a visually simpler multi-page wizard if the values must be compared together.

## GU-07 — Internal semantics should be inspectable, not mandatory vocabulary

LOAM can keep provenance and formal meaning without making persistence concepts the navigation model.

## GU-08 — Good UI must support interruption

Household recording often occurs around real life. Draft/cancel/resume and stable return location matter.

## GU-09 — Good UI is operation-specific

The same user can need an expert UI for daily recording and a novice-friendly guided UI for a recovery operation used twice a year.

## GU-10 — Trust requires visible boundaries

The UI should make clear what is:

- retained evidence,
- editable draft/default,
- derived projection,
- inferred suggestion,
- blocked/unknown state.

---

# 16. Proposed next experiment

Before production TUI implementation, revise synthetic dogfood to test **good-UI profiles**, not just UI Tax.

Use the same six core scenarios plus several rare/exceptional scenarios:

1. ordinary purchase today,
2. purchase three days ago,
3. correct discovered Actual,
4. complete Scheduled as Actual,
5. replace Scheduled,
6. move Capacity,
7. ambiguous/blocked Scheduled state,
8. external balance mismatch,
9. first-time use of an unfamiliar action,
10. return to a rare action after simulated forgetting.

Compare at least:

- current LOAM CLI,
- HRA-derived flat topology,
- h-kernel focus topology,
- palette topology,
- flat + palette hybrid.

For each scenario capture:

### Objective

- task success,
- semantic correctness,
- elapsed time,
- UI Tax,
- number of wrong turns,
- number of corrections,
- recovery distance,
- context displacement.

### Subjective

After the trace ask:

- How certain am I that the result is right? `1..5`
- How tiring/annoying was this? `1..5`
- Would I willingly use this flow tomorrow? `1..5`
- Could I rediscover it next month? `1..5`
- Did I understand why the system asked each nontrivial question? `1..5`

### Safety gate

- fail-closed preserved?
- provenance preserved?
- no silent semantic inference?
- stale write protected?
- unknown distinct from zero/empty?

### Repeat at different expertise levels

For high-frequency actions, compare:

- first trace,
- fifth repetition,
- later habitual trace.

For rare actions, deliberately evaluate rediscovery after the shortcut/path is no longer fresh in memory.

---

# 17. Working definition for LOAM

A candidate definition, intentionally broader than “few clicks”:

> A good LOAM interface helps the user reach the correct household outcome with little unnecessary cognitive or interaction burden, preserves enough context and explanation to maintain confidence, adds friction only where it meaningfully improves safety or understanding, makes recovery close and obvious, remains rediscoverable when forgotten, adapts to the input surface, and is pleasant enough that useful actions are actually used rather than avoided.

Short form:

> **Correct, clear, calm, recoverable, rediscoverable, and worth using again.**

This is a research hypothesis, not a design slogan to enforce mechanically.

---

# 18. Sources / research queue

## Standards / accessibility

- ISO 9241-11 usability: https://www.iso.org/standard/63500.html
- ISO 9241-110 interaction principles: https://www.iso.org/obp/ui/#iso:std:iso:9241:-110:dis:ed-2:v1:en
- ISO 9241-115 UI/navigation design: https://www.iso.org/obp/ui/#iso:std:iso:9241:-115:ed-1:v1:en
- WCAG 2.2 changes: https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/
- WCAG at a glance: https://www.w3.org/WAI/standards-guidelines/wcag/glance/

## General HCI

- Nielsen heuristics: https://www.nngroup.com/articles/ten-usability-heuristics/
- Progressive disclosure: https://www.nngroup.com/articles/progressive-disclosure/
- Response time limits: https://www.nngroup.com/articles/response-times-3-important-limits/
- Interaction elasticity: https://www.nngroup.com/articles/interaction-elasticity/

## Government/service design

- Design principles: https://www.gov.uk/guidance/government-design-principles
- Good services: https://www.gov.uk/service-manual/design/introduction-designing-government-services
- Form structure: https://www.gov.uk/service-manual/design/form-structure
- Internal/expert services: https://www.gov.uk/service-manual/design/services-for-government-users
- Usability benchmarking: https://www.gov.uk/service-manual/measuring-success/usability-benchmarking-a-website-or-whole-service
- Transaction scoping: https://www.gov.uk/service-manual/design/scoping-your-service

## Apple / mobile / games

- Data entry: https://developer.apple.com/design/human-interface-guidelines/entering-data
- Feedback: https://developer.apple.com/design/human-interface-guidelines/feedback
- Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Onboarding: https://developer.apple.com/design/human-interface-guidelines/onboarding
- Game onboarding: https://developer.apple.com/app-store/onboarding-for-games/

## Safety-critical human factors

- NASA cockpit display research: https://www.nasa.gov/human-systems-integration-division/cockpit-display-design-intelligent-spacecraft-interface-systems/
- NASA iterative human-in-the-loop testing: https://www.nasa.gov/reference/3-0-systems-engineering-processes-vol-2/
- NASA flight cognition: https://www.nasa.gov/human-systems-integration-division/flight-cognition-laboratory/

## Expert tools

- VS Code Command Palette: https://code.visualstudio.com/api/ux-guidelines/command-palette
- VS Code accessibility: https://code.visualstudio.com/docs/configure/accessibility/accessibility
- JetBrains Search Everywhere: https://www.jetbrains.com/help/idea/searching-everywhere.html

## Next broad research topics

Still worth deeper research before final LOAM UI selection:

- cognitive dimensions of notation,
- interruption/resumption research,
- prospective memory and reminders,
- trust calibration in automation/AI,
- calm technology / notification burden,
- decision-support visualization,
- undo/recovery models in creative tools,
- spreadsheet direct manipulation,
- database/admin UI design,
- command-line discoverability,
- multimodal accessibility,
- mobile one-handed ergonomics,
- longitudinal habit/avoidance measurement.
