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

- [CurrentQuantityAnchor change audit](current-quantity-anchor.md)
- [Scheduled transition audit](scheduled-transition.md)
- [Correspondence boundary audit](correspondence-boundary.md)

These were chosen because they recur, cross meaningful semantic boundaries, and
have verifier/test surfaces that can provide useful feedback.

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
