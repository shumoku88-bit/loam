# LOAM Interaction Atlas — Sustained Use, Interruption, Trust, and Recovery

Date: 2026-09-06  
Status: **cross-domain HCI research; no LOAM UI selected**  
Parent: `LOAM_INTERACTION_ATLAS.md`

---

## 0. Question

A household system is not used in one uninterrupted laboratory session.

People:

- get interrupted,
- forget what they intended to do,
- postpone entry,
- return after days or weeks,
- ignore repetitive alerts,
- accept or reject automation,
- discover mistakes later,
- learn shortcuts gradually,
- stop using features that feel costly,
- and sometimes stop using the system entirely.

Therefore the next UI question is not only:

> How many actions does this task take?

It is:

> Can the person maintain a reliable relationship with the system over time, despite interruption, forgetting, uncertainty, mistakes, automation, and changing attention?

This shard studies that question beyond finance software.

---

# 1. Interaction has a time dimension

The previous scorecard measured local interaction cost:

- presentation focus,
- redundant recall/re-entry,
- context displacement.

That remains useful, but it measures a **single trace**.

Sustained use requires additional temporal questions:

1. Can the person resume after an interruption?
2. Can the system preserve an unfinished intention without pretending it is completed evidence?
3. Can a rare task be rediscovered after the shortcut is forgotten?
4. Can attention demands remain quiet enough that important items still stand out?
5. Can automation remain understandable after weeks of adaptation?
6. Can a mistake be repaired without reconstructing the whole workflow from memory?
7. Does the UI help the person remember future work at the right moment?

Candidate distinction:

```text
interaction quality
  = local task quality
  + resumption quality
  + prospective-memory support
  + attention discipline
  + trust calibration
  + recovery quality
  + long-term learnability
```

Do not collapse this into one scalar prematurely.

---

# 2. Interruption and resumption

Microsoft Research studied interruption of programming tasks and found that people rely heavily on external notes and contextual cues when returning to suspended work. In a controlled study, automated resumption cues substantially improved successful task resumption; participants preferred chronological, concrete cues over more abstract summaries.

Research implication:

> A good interface should not merely preserve state. It should preserve enough **meaningful resumption context** for the person to know what they were doing and why.

This is stronger than `KEEP-DAY` or `KEEP-OBJ`.

## 2.1 Candidate LOAM resumption packet

If an operation is safely interruptible before publication, a future surface could retain a non-authoritative draft/resumption packet containing presentation state such as:

- selected day,
- selected object,
- operation intent,
- fields already entered,
- fields still unresolved,
- last canonical observation used to construct the draft,
- plain-language next step.

Example:

```text
Unfinished
  Replace Sep 10 rent schedule

  Date     changed to Sep 12
  Amount   unchanged: 50,000 JPY
  Routing  not decided

  Canonical data has not been changed.
  [Continue] [Discard]
```

This must remain distinct from retained household authority.

## 2.2 Resumption quality metrics

Add:

- `ResumeTime`: time from reopening to productive action,
- `ResumeErrors`: wrong-target/wrong-operation starts after return,
- `ReconstructionQuestions`: facts the person must rediscover manually,
- `DraftAuthorityClarity`: can the person tell unfinished draft from published fact?,
- `ResumeConfidence`: “I know where I am and what remains.”

### Candidate principle SU-RESUME-01

> Preserve semantic breadcrumbs, not merely cursor position.

A cursor on row 7 is weak resumption state. “Replacing Sep 10 rent; amount unchanged; not published” is strong resumption state.

Primary source:
- Microsoft Research, *Evaluating Cues for Resuming Interrupted Programming Tasks*
- Microsoft Research, *Disruption and Recovery of Computing Tasks: Field Study, Analysis, and Directions*

---

# 3. Prospective memory: remembering to do something later

Household management is full of **prospective memory**:

- submit reimbursement later,
- verify a refund arrived,
- record cash purchase when home,
- review a bill when amount becomes known,
- realize a Scheduled item when payment actually occurs,
- revisit an unresolved discrepancy.

Research on prospective memory shows that external reminders can improve performance. Critically, reminder quality depends on whether the cue retrieves not only that *something* must happen, but **what action is intended and under what trigger/context**.

A weak reminder:

```text
Rent
```

A stronger reminder:

```text
When the Sep 10 rent payment appears in the bank,
record what actually happened against this Scheduled item.
```

## 3.1 LOAM implication

Do not equate an Issue/attention/reminder with a transaction or Scheduled fact.

A UI may need a presentation or retained attention mechanism that supports future action without manufacturing financial evidence.

This reopens the earlier HRA Issue question from a stronger foundation:

> Is there a genuine household need for retained prospective intention/evidence, distinct from Actual and Scheduled economic facts?

This should be falsified with real cases before adding a Core concept.

## 3.2 Reminder design candidate

A useful reminder should make at least these retrievable:

- trigger: when/where/what observation makes it relevant,
- intended action,
- target object if already known,
- why it matters,
- dismiss/snooze/resolve semantics.

### Candidate principle SU-PM-01

> A reminder should retrieve the intended action, not merely name the topic.

Sources:
- PubMed, *Prospective memory: when reminders fail*
- PMC, research on prospective-memory offloading/reminders

---

# 4. Notifications and alert fatigue

Apple distinguishes multiple interruption levels and explicitly warns that overstating urgency damages trust. Human-factors research in clinical systems shows a stronger failure mode: repeated low-value alerts train people to stop processing alerts at all.

This is especially important for a household Home surface.

If Home constantly says:

```text
3 planned payments
2 budget warnings
1 account changed
4 suggestions
5 reminders
```

then “attention” becomes wallpaper.

## 4.1 Attention is a budget

Candidate model:

```text
A0 background
  information available on inspection

A1 ambient
  useful state visible without demanding action

A2 review
  action is useful but can wait

A3 due
  action is time-relevant

A4 blocking
  reliable continuation is impossible without resolution
```

The earlier Home/Attention shard introduced a similar hierarchy. This research strengthens the rule that **higher levels must be rare**.

## 4.2 Notification legitimacy test

Before producing an interruption, ask:

1. Is the information new?
2. Is it actionable now?
3. Does delaying it materially matter?
4. Is this the right channel/time?
5. Is the urgency honestly represented?
6. Will repeating it teach the user to ignore us?

If several answers are no, prefer passive Home state or later review.

## 4.3 LOAM notification hypothesis

LOAM may need fewer notifications than commercial finance products because it does not need engagement metrics.

Candidate default:

> Prefer a quiet, information-rich Home that the user chooses to inspect. Interrupt only for genuinely time-sensitive or blocking household obligations.

### Candidate metrics

- alerts/day,
- dismiss-without-reading rate,
- repeated-alert rate,
- action-after-alert rate,
- false-urgency count,
- “I would disable this alert” response,
- missed-important-item rate.

Sources:
- Apple HIG, *Managing notifications*
- recent clinical alert-fatigue research (PMC/PubMed)

---

# 5. Automation and trust calibration

A good automation UI should not maximize trust.

It should help the user place **appropriate trust** in the system.

NASA human-factors work identifies both over-reliance (misuse) and under-reliance (disuse) as automation failures. NIST similarly emphasizes that human roles, oversight, context, transparency, and recourse need to be explicit in human-AI systems.

Microsoft's Human-AI Interaction guidelines add a practical lifecycle:

- make clear what the system can do,
- make clear how well it can do it,
- act/intervene at appropriate times,
- make dismissal easy,
- make correction easy,
- scope behavior when uncertain,
- explain why it acted,
- remember recent interaction,
- adapt cautiously,
- expose controls and consequences.

## 5.1 LOAM / ChatGPT implication

The dangerous design is:

```text
User: “本を2470円で買った”
AI: “記帳しました”
```

when the system actually inferred several unresolved meanings.

A calibrated design is:

```text
I can confidently identify:
  total: 2,470 JPY
  paid from: PayPay

I am less certain whether shipping should be a separate purpose.

Proposed record:
  PayPay -> books      1,750
  PayPay -> shipping     720

[Record] [Combine] [Edit]
```

The user need not see numeric confidence unless it is meaningful and calibrated. Coarse semantic uncertainty can be better:

- known,
- proposed,
- ambiguous,
- unavailable.

## 5.2 Automation authority ladder

Candidate ladder:

```text
L0 observe only
L1 suggest
L2 prefill draft
L3 act after explicit approval
L4 act automatically with immediate visible audit/reversal
L5 autonomous policy action
```

LOAM should earn each higher level per operation family. Do not give “AI” one global autonomy setting and assume all actions have equal consequence.

## 5.3 Mode awareness

NASA mode-awareness research highlights a recurring automation hazard: an input produces no visible effect because the system is in a different mode than the human expects.

LOAM equivalent risks include:

- editing a draft while believing canonical data changed,
- looking at raw retained quantities while believing they are effective corrected quantities,
- viewing an old snapshot while believing it is fresh,
- seeing Scheduled expectation while believing it is an Actual,
- treating an AI suggestion as admitted authority.

### Candidate principle SU-MODE-01

> Every consequential interaction must make the current authority/mode legible through behavior and nearby status, not only documentation.

Sources:
- NASA mode-awareness/formal-methods research
- NIST AI RMF Human-AI Interaction appendix/playbook
- Microsoft Human-AI Interaction Guidelines

---

# 6. Undo, history, and reversible action

Apple's Undo/Redo guidance emphasizes two things especially relevant to LOAM:

1. people expect recent actions to be reversible,
2. they need to predict **which action** will be undone and see **what changed** afterward.

LOAM cannot honestly implement every recovery as destructive state rollback because its history/provenance semantics intentionally retain correction/replacement/reversal evidence.

That does not mean the human interface must force accounting jargon on the user.

## 6.1 Human action vs retained mechanism

Possible surface language:

```text
Undo “change Sep 10 rent to Sep 12”
```

Possible retained semantics beneath it:

- append another Scheduled replacement,
- restore previous effective meaning through qualified relation,
- retain both history steps.

The UI promise must be about the resulting meaning, not about erasing history.

## 6.2 Predictive undo preview

For consequential historical actions:

```text
Undo schedule change?

Current
  Sep 12  rent  50,000

After
  Sep 10  rent  50,000

History remains available.
```

This is stronger than a generic “Are you sure?”

## 6.3 Recovery distance

Keep measuring `D_correct`, but add:

- `UndoPredictability`: can user state the resulting household meaning before confirming?,
- `UndoTargetVisibility`: is the affected object visible?,
- `UndoResultVisibility`: is the changed effective state shown immediately?,
- `HistoryExplainability`: can the user later understand why current state differs from original record?

### Candidate principle SU-UNDO-01

> Surface-level undo may be implemented by append-only semantic repair, as long as the predicted and resulting meaning is explicit.

Source:
- Apple HIG, *Undo and redo*

---

# 7. Direct manipulation: strong, but not universal

Direct manipulation has important advantages:

- object remains visible,
- action is attached to the selected object,
- effect is immediately visible,
- recognition replaces identifier recall.

This strongly supports several HRA-derived ideas:

```text
select Scheduled row -> e
select Actual -> c
select Capacity coordinate -> move
```

But direct manipulation has known costs:

- only visible objects are easy to manipulate,
- repeated/bulk operations become tedious,
- pointer precision can be worse than language/commands,
- automation and conditional behavior are awkward,
- complex systems cannot expose every object at once.

Therefore “make everything clickable” is not a complete UI strategy.

## 7.1 Three complementary interaction modes

A promising LOAM family is:

### Object-local
When the object is already visible:

```text
select -> action
```

### Intent/search
When the operation is known but the path is not:

```text
/ -> “correct transaction”
```

### Explicit command
When precision, scripting, repeatability, or AI integration matters:

```text
loam ...
```

These can share application semantics without sharing interaction shape.

### Candidate principle SU-DM-01

> Prefer direct manipulation for visible local objects; prefer language/commands for long-tail, bulk, precise, or non-visible operations.

Sources:
- Nielsen Norman Group, direct manipulation research
- historical “Anti-Mac” analysis of direct-manipulation limits

---

# 8. Feedback, latency, and perceived continuity

A UI can be semantically correct and still feel unreliable if feedback is late or vague.

Apple's current guidance emphasizes:

- show status near the object it describes,
- match feedback intensity to consequence,
- explain when an action cannot proceed and why,
- show meaningful progress for longer operations,
- allow cancellation when safe.

Classic response-time guidance distinguishes roughly:

- near-instant response: feels directly caused by the action,
- around a second: flow remains largely intact,
- long waits: attention can drift and progress/status becomes necessary.

LOAM writes may be fast today, but future ChatGPT/MCP/sync/large reconstruction surfaces may not be.

## 8.1 LOAM feedback candidates

For a normal local write:

```text
Recorded ✓
```

then refresh the affected visible object in place.

For a fail-closed refusal:

```text
Not recorded
The selected Scheduled item changed while this draft was open.

Current state:
  Sep 10 item is now cancelled.

[Return to Scheduled]
```

For an interrupted relation-first recovery:

```text
Incomplete publication detected
The replacement relation is retained, but the new Scheduled object is missing.

[Resume safely]
```

This converts internal safety machinery into actionable human feedback.

### Candidate principle SU-FEEDBACK-01

> Show the result where the user was looking, and explain refusals in terms of the object and next safe action.

Sources:
- Apple HIG, *Feedback*, *Progress indicators*, *Loading*
- NN/g response-time research

---

# 9. Decision-support displays and uncertainty

A finance UI often tempts designers to present a single clean number:

```text
Safe to spend: 3,421 JPY
```

But the number may depend on:

- observation horizon,
- future known obligations,
- missing external evidence,
- policy choices,
- expected but uncertain amounts,
- stale data.

A visually clean single number can therefore be **less usable** if it conceals what the person needs to judge.

## 9.1 Decision support is not raw data density

The design target should be:

> enough information to make the current decision, with uncertainty and provenance visible when they can change that decision.

Candidate compact form:

```text
Available now      12,000
Committed           8,000
-------------------------
Uncommitted          4,000

Known through: Sep 6
2 future amounts are approximate
```

Drill-down can explain the 8,000.

## 9.2 Uncertainty vocabulary

Avoid one generic `?` state.

Candidate presentation distinctions:

- exact retained fact,
- exact derived projection,
- approximate expectation,
- incomplete evidence,
- outside observation horizon,
- ambiguous interpretation,
- unavailable because authority is invalid.

### Candidate principle SU-UNCERT-01

> Display uncertainty at the level where it can alter action; do not decorate every number with technical confidence metadata.

This aligns with human-AI research caution that numerical confidence can be hard to interpret unless calibrated and semantically meaningful.

Sources:
- Microsoft Research on calibrated/explained uncertainty in human-AI systems
- NIST AI RMF human-AI interaction guidance
- current uncertainty-visualization research

---

# 10. A stronger model of friction

The earlier Good UI shard split friction into:

- semantic work,
- UI tax,
- protective friction,
- learning friction,
- recovery friction.

Sustained-use research suggests adding two more.

## 10.1 Resumption friction

The cost of reconstructing context after interruption.

Examples:

- finding the Scheduled item again,
- remembering whether a draft was published,
- rediscovering which mismatch was under investigation.

## 10.2 Attention friction

The cost imposed by repeated demands to notice, classify, dismiss, or defer information.

Examples:

- noisy Home warnings,
- repetitive alerts,
- badges that never clear,
- suggestions that require constant review.

Revised friction taxonomy:

```text
necessary semantic work

avoidable costs
  UI tax
  resumption friction
  attention friction

conditional/beneficial costs
  protective friction
  learning friction
  recovery friction
```

Even beneficial friction should be tested. A confirmation dialog shown 100 times becomes attention tax.

---

# 11. Sustained-use evaluation profile

Do not replace the previous nine dimensions. Extend them with longitudinal measures.

## Immediate task

- success / failure,
- time,
- UI Tax,
- error opportunities,
- recovery distance,
- confidence.

## After interruption

- resume time,
- resume error,
- context reconstruction count,
- draft-vs-authority clarity.

## Over days/weeks

- feature avoidance,
- delayed-entry backlog,
- reminder dismissal rate,
- ignored-attention rate,
- shortcut retention,
- palette/search reliance,
- correction frequency caused by UI mistakes,
- trust in automation vs actual automation accuracy,
- manual override rate,
- repeat willingness,
- voluntary return rate.

## Subjective prompts

After a scenario, ask very small questions:

- “Was anything annoying?”
- “Were you sure it was recorded correctly?”
- “Would you do this the same way next time?”
- “Was anything shown that you did not need?”
- “Was anything missing when you needed it?”

For interruption tests:

- “What were you doing before interruption?”
- “What remains to be done?”
- “Has canonical data changed yet?”

---

# 12. Synthetic dogfood scenarios for sustained use

The next paper/dogfood batch should add temporal scenarios, not only isolated transactions.

## SU-01 Interrupted purchase entry

Start a split purchase, interrupt after first destination, return later.

Test:

- draft recovery,
- authority clarity,
- resumption cue quality.

## SU-02 Interrupted Scheduled replacement

Change date, interrupt before publication, then canonical Scheduled state changes elsewhere.

Test:

- stale-draft explanation,
- fresh re-read behavior,
- resumption without false success.

## SU-03 Refund reminder over 14 days

Create “refund expected”, receive no refund for several days, finally receive it.

Test:

- reminder/attention escalation,
- alert fatigue,
- resolution semantics.

## SU-04 Rare correction after 30 days

User has forgotten shortcut/navigation.

Test:

- command palette discoverability,
- object-local action discovery,
- terminology comprehension.

## SU-05 Automation suggestion becomes wrong

ChatGPT proposes a familiar routing based on history, but this purchase is exceptional.

Test:

- uncertainty visibility,
- correction ease,
- whether one correction changes future behavior transparently.

## SU-06 Repeated low-value alerts

Simulate a week of harmless warnings plus one genuinely urgent item.

Test:

- whether urgent item is still noticed,
- whether user wants alerts disabled.

## SU-07 Undo after context change

Make a Scheduled replacement, navigate elsewhere, then invoke Undo.

Test:

- target prediction,
- result visibility,
- history explanation.

## SU-08 Long-running refresh/sync

Simulate a slow canonical refresh or ChatGPT adapter call.

Test:

- status clarity,
- cancel behavior,
- whether user repeats the action because feedback is missing.

---

# 13. Candidate LOAM interaction laws from this wave

These are research hypotheses, not design requirements.

### SU-L01 — Return is part of the operation
A workflow is not complete merely when data is written. It is complete when the user can understand the result and continue from a coherent place.

### SU-L02 — Unfinished is a first-class presentation state
An unfinished draft must be recoverable or discardable without masquerading as canonical household evidence.

### SU-L03 — Attention must remain scarce
If everything is highlighted, nothing is attention.

### SU-L04 — Trust should be calibrated, not maximized
Automation should expose enough capability, limitation, uncertainty, correction, and recourse for appropriate reliance.

### SU-L05 — Undo names the future state
A human recovery action should communicate what effective state will result, even when append-only historical evidence implements it.

### SU-L06 — Visible objects deserve local actions
Do not ask the human to identify again what the interface already knows is selected.

### SU-L07 — Not every object needs to be visible
Long-tail and bulk actions need search/commands; direct manipulation alone does not scale.

### SU-L08 — Feedback belongs near the consequence
Refresh the affected object and make failure/actionability visible where the user is already looking.

### SU-L09 — Reminders retrieve an action
A reminder should say what the user intended to do and why/when it becomes relevant.

### SU-L10 — Rare tasks are a cold-start problem every time
A task done twice per year should not be designed as though the shortcut is remembered.

### SU-L11 — Mode/authority must be legible
Draft, proposal, retained fact, effective projection, stale observation, and automation suggestion must not blur together.

### SU-L12 — Measure avoidance
A feature that is theoretically powerful but routinely postponed or avoided has failed its household purpose.

---

# 14. Implication for the current flat + palette candidate

This research neither confirms nor rejects the flat + palette shell.

It makes the candidate more specific.

A strong experiment would combine:

```text
persistent selected day
+ quiet Home
+ object-local actions
+ one-key shortcuts only for genuinely frequent actions
+ palette/search for rare actions
+ explicit draft/published distinction
+ resumption cues
+ risk-adjusted previews
+ contextual feedback
+ sparse interruption/notification policy
+ existing LOAM fail-closed publishers
```

The key test is no longer “does it minimize UI Tax?”

The stronger test is:

> Does it remain understandable, recoverable, quiet, trustworthy, and worth returning to after real life interrupts it?

---

# 15. Source trail

Key external sources for this pass:

- Microsoft Research — Evaluating Cues for Resuming Interrupted Programming Tasks
  https://www.microsoft.com/en-us/research/publication/evaluating-cues-for-resuming-interrupted-programming-tasks/
- Microsoft Research — Disruption and Recovery of Computing Tasks
  https://www.microsoft.com/en-us/research/publication/disruption-recovery-computing-tasks-field-study-analysis-directions/
- Apple HIG — Managing notifications
  https://developer.apple.com/design/human-interface-guidelines/managing-notifications
- Apple HIG — Undo and redo
  https://developer.apple.com/design/human-interface-guidelines/undo-and-redo
- Apple HIG — Feedback
  https://developer.apple.com/design/human-interface-guidelines/feedback
- Apple HIG — Progress indicators
  https://developer.apple.com/design/human-interface-guidelines/progress-indicators
- Microsoft Research / HAX — Guidelines for Human-AI Interaction
  https://www.microsoft.com/en-us/haxtoolkit/ai-guidelines/
- NIST AI RMF — Human-AI Interaction appendix / playbook
  https://airc.nist.gov/airmf-resources/airmf/appendices/app-c-ai-risk-management-and-human-ai-interaction/
- NASA — Mode Awareness research
  https://shemesh.larc.nasa.gov/fm/fm-collins-mode.html
- Nielsen Norman Group — Direct Manipulation
  https://www.nngroup.com/articles/direct-manipulation/
- PubMed — Prospective memory: when reminders fail
  https://pubmed.ncbi.nlm.nih.gov/9584436/
- PMC — Alert-fatigue human-factors research
  https://pmc.ncbi.nlm.nih.gov/articles/PMC12919987/

---

## Working rule after Wave 2

> Optimize not for the shortest isolated path, but for reliable return: the person should be able to act correctly, stop safely, resume clearly, recover cheaply, ignore noise, distrust uncertainty appropriately, and still want to use LOAM tomorrow.
