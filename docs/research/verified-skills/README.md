# Verified development skills experiment

Status: **experimental / no production authority**

This experiment asks whether a small, explicit development skill can help an AI
agent choose better LOAM evidence and verification steps without growing a large
repository manual or changing the model.

The working loop is:

```text
concrete task
    -> candidate skill
    -> AI attempt
    -> repository / verifier feedback
    -> smallest skill revision, if needed
    -> held-out sibling task
    -> qualify or retire
```

This is inspired by recent skill-evolution work such as
[SkillEvoLean](https://arxiv.org/abs/2610.01799) and
[VeriSkill](https://arxiv.org/abs/2607.27733), but the experiment is deliberately
smaller. LOAM does not add a self-modifying agent runtime here.

## What a skill is

A skill is a small, reviewable procedure for a recurring development question.
It is **not**:

- semantic authority;
- a substitute for source inspection;
- a proof that a change is correct;
- a repository-wide prompt containing everything known about LOAM;
- a reason to run every available formal tool.

Each skill should state:

1. when it triggers;
2. which answer or boundary it protects;
3. a short procedure;
4. likely falsifiers or counterexamples;
5. what evidence can qualify the result;
6. when the skill should not be used.

The repository remains the source of evidence. A skill only helps route attention
through that evidence.

## Lifecycle

Skills use four states:

```text
Candidate
  -> Trialed
  -> Qualified
  -> Retired
```

**Candidate** means the procedure is plausible but unmeasured.

**Trialed** means it has been used on at least one concrete task and the outcome
has been recorded.

**Qualified** means it has helped on multiple tasks, including a held-out sibling
task that was not used to write the skill, without creating a semantic regression.

**Retired** means it no longer improves the work, duplicates a stronger current
owner, or encodes assumptions that are no longer true.

A qualified skill is still an AI-facing development aid, not household or
production authority.

## Trial protocol

Prefer paired trials when practical.

Hold constant:

- repository revision;
- model/backbone;
- tool access;
- task statement;
- approximate search / sampling budget.

Compare:

```text
baseline
    AI uses AGENTS.md + AI_WORKBENCH.md + ordinary repository evidence

skill arm
    same setup + one named candidate skill
```

The baseline must not receive the candidate skill text.

### Isolation rule

For a paired trial, seal the task and both arm prompts before either run starts.

Run baseline and skill arm in independent contexts that cannot see the other
arm's result. A fresh chat name or nominally separate session is not sufficient
if inherited conversation summaries, memory, prior-turn context, or another
shared context surface can expose the other arm.

Do not bring either result into a shared evaluator until both arms are complete.
Do not ask one already-exposed agent to reconstruct how it "would have" worked
without the missing information.

If either arm reports prior exposure to the other arm's decisive result, mark the
pair **contaminated / unscored** even when repository claims are independently
rechecked:

- keep a clean arm as valid standalone audit evidence;
- keep the contaminated arm only as exploratory evidence;
- count no Better / Same / Worse result from the pair;
- count no promotion win from the pair;
- do not use token, tool-call, elapsed-work, or wrong-turn differences as causal
  evidence for the skill.

This prevents both candidate-skill leakage into the control condition and result
leakage between otherwise separate arms.

### Pinned-evidence rule

A baseline pinned to an earlier repository revision must treat only file contents
fetched explicitly at that revision as repository evidence.

During the control run:

- do not fetch commit metadata or commit diffs;
- do not fetch issue / PR comments, reviews, or current discussion;
- do not use current issue / PR bodies as evidence unless their exact text was
  sealed into the task before the run;
- do not use default-branch code-search snippets as evidence;
- avoid unpinned repository search for discovery when it can expose later source
  text; follow paths, imports, and links from pinned files instead;
- every source claim must be re-openable from an exact path at the pinned
  revision.

If any forbidden later text is exposed, mark the control **contaminated** and
count no Better / Same / Worse result from that run. The audit may still be kept
as exploratory evidence, but it is not a paired baseline.


Record the smallest useful observations:

| Field | Question |
| --- | --- |
| task | What concrete change or audit was attempted? |
| revision | Which repository state was used? |
| first instrument | Did the agent choose an appropriate evidence surface early? |
| wrong turns | How many materially incorrect paths required backtracking? |
| semantic correction | Did a reviewer need to repair an authority, unknown, lifecycle, or projection mistake? |
| qualification | Were the right tests / proofs / model checks selected for the actual seam? |
| cost | Tokens, tool calls, or elapsed work only when they are available and comparable. |
| result | Better / same / worse, with one sentence of evidence. |

Do not turn tiny sample counts into statistical claims. The purpose of early
trials is to reject useless skills quickly.

## Promotion rule

A Candidate may become Qualified only when all of the following hold:

1. at least three paired or otherwise comparable concrete trials exist;
2. at least one trial is held out from the examples used to author or mutate the
   skill;
3. the skill produces a material improvement in at least two trials;
4. no trial shows a serious semantic regression caused by the skill;
5. the improvement is not merely "more checks were run";
6. the procedure remains smaller than the repository evidence it routes to.

A severe regression blocks promotion even if average performance improves.

## Mutation rule

Mutate a skill only after a concrete failure exposes a missing reusable step.

Good mutation:

```text
failure: Scheduled replacement audit missed stale future occurrences
change: add one explicit stale-occurrence falsifier
retest: use a different Scheduled lifecycle task
```

Bad mutation:

```text
failure
    -> copy another large section of repository knowledge into the skill
    -> run more tools by default
```

Prefer deleting a bad instruction to accumulating exceptions.

## Current candidates

- [CurrentQuantityAnchor change audit](current-quantity-anchor.md) — Trialed; evaluation closed after Trial 06; Trial 03 BETTER, Trial 04 UNSCORED, Trials 05/06 SAME; 1 promotion win; not Qualified.
- [Scheduled transition audit](scheduled-transition.md)
- [Correspondence boundary audit](correspondence-boundary.md)

These were chosen because they recur, cross meaningful semantic boundaries, and
have verifier/test surfaces that can provide useful feedback.

Current trial records:

- Trial 01 — Scheduled terminal lifecycle canonicality: recorded inline below;
- [Trial 02 — CapacityMovement / CapacityEffective correspondence](trials/02-capacity-correspondence.md): paired trial complete; result SAME; 0 promotion wins;
- [Trial 03 — Presence-only support to exact current quantity](trials/03-presence-to-exact-anchor.md): paired trial complete; result BETTER; 1 promotion win;
- [Trial 04 — Exact anchor across later correction-root change](trials/04-stale-anchor-correction.md): clean baseline + contaminated skill arm; result UNSCORED; 0 promotion wins;
- [Trial 05 — Partial re-observation from a legacy v1 anchor](trials/05-v1-partial-reobservation.md): clean paired held-out trial; result SAME; 0 promotion wins;
- [Trial 06 — Bounded history versus same stored scalar](trials/06-bounded-history-same-stored-scalar.md): clean paired final evaluation; result SAME; 0 promotion wins.

## Closed CurrentQuantityAnchor evaluation

The CurrentQuantityAnchor candidate completed its planned promotion experiment
after Trial 06.

Counted result:

```text
Trial 03   BETTER    1 promotion win
Trial 04   UNSCORED  contaminated skill arm
Trial 05   SAME      clean held-out sibling
Trial 06   SAME      clean held-out sibling
```

It satisfies the comparable-trial and held-out requirements but has only one
material improvement, below the two required for Qualified status. No scored
trial produced a serious semantic regression.

The lifecycle remains **Trialed** rather than Qualified or Retired. Further
promotion trials are not planned unless repository ownership changes materially,
a new concrete failure exposes a reusable skill defect, or a different evaluation
protocol creates a genuinely new question.

This is intentionally a stop point rather than an invitation to accumulate more
near-duplicate trials.

## Trial record template

Append a compact record here or in a task-specific research note:

```text
Trial:
Date:
Repository revision:
Task:
Skill:
Baseline outcome:
Skill outcome:
Material difference:
Regression observed:
Skill mutation:
Disposition: Candidate | Trialed | Qualified | Retired
```

Do not preserve every trajectory. Retain only the evidence needed to explain a
skill mutation, promotion, or retirement.

## Trial 01 — Scheduled terminal lifecycle canonicality

```text
Trial: 01
Date: 2026-10-03
Repository revision: 0a77c1dc086aa4d5c185146bd2b564be4225f481
Task: Revisit issue #700 candidate 3: whether Scheduled terminal lifecycle still
      requires independently retained completion / retirement / replacement
      runtime representations.
Skill: Scheduled transition audit
Baseline outcome: Not run. The same agent had already read the candidate skill,
                  so a post-hoc baseline would be contaminated.
Skill outcome: The audit named current-open lifecycle as the protected answer,
               followed ScheduledTerminal -> currentOpenScheduled -> Review and
               lifecycle persistence, and then found that PR #706 had already
               removed the three obsolete runtime memories/codecs while
               preserving terminal meanings and v1 wire bytes.
Material difference: The skill routed the investigation toward current owner,
                     projection, and persistence evidence early enough to detect
                     that the apparent #700 research candidate was already
                     graduated. This is useful routing evidence, not a measured
                     baseline win.
Regression observed: None. No production or household-data change was made.
Skill mutation: None. No concrete skill failure was observed.
Disposition: Trialed
Promotion evidence: 0 wins counted; this unpaired exploratory trial does not
                    count toward the Qualified threshold.
```

## Extraction rule

Do not create a generic library merely because the experiment has a directory.

Consider extraction only if several Qualified skills reveal a reusable mechanism
that is not LOAM-specific, for example:

- versioned skill documents with explicit triggers and falsifiers;
- verifier-backed trial recording;
- promotion / retirement rules;
- controlled mutation from concrete failures;
- held-out replay against repository revisions.

Until then, the experiment stays as repository-local Markdown. If extraction is
eventually justified, LOAM should consume the library only if it remains simpler
than keeping the small local procedure.
