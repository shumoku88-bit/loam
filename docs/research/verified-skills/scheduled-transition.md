# Skill: Scheduled transition audit

Status: **Trialed**

## Trigger

Use this skill when a change touches Scheduled creation, recurrence, extension,
replacement, retirement, coverage horizon, current-series selection, or
persistence / recovery of Scheduled state.

Do not invoke it for a renderer that receives an unchanged Scheduled review.

## Protected answer

For a given plan and observation coordinate, LOAM should expose the intended
current Scheduled series without stale, duplicated, silently missing, or
resurrected occurrences.

The skill protects lifecycle and temporal meaning, not a particular UI shape.

## Procedure

1. **Write the lifecycle question in one sentence.**
   Examples: "Which occurrence is current after replacement?" or "What does
   extend add, and until which horizon?"

2. **Identify the retained owner and current projection.**
   Separate plan identity, generated occurrences, replacement / retirement
   evidence, coverage configuration, and presentation.

3. **Sketch the smallest transition sequence.**
   Use plain text first. If operation order remains ambiguous, use the TLA+ /
   temporal instrument selected by `AI_WORKBENCH.md`; do not introduce a temporal
   model when a local test already answers the question.

4. **Check replacement and retry behavior.**
   Follow the nearest persistence / publication / recovery path so a partial
   failure cannot produce a plausible but semantically split result.

5. **Try the falsifiers below.**

6. **Qualify the exact transition seam.**
   Prefer a focused lifecycle test or retained temporal obligation over broad
   unrelated CI expansion.

7. **Review the human answer.**
   Verify that the resulting behavior still answers the operator's question:
   what plan exists, at what cadence, through what horizon, and which occurrence
   is current.

## Falsifiers

Use the relevant subset:

- two plans show the same next visible occurrence but have different retained
  horizons;
- replacement leaves an older future occurrence visible;
- extend is repeated and duplicates an occurrence;
- monthly and bi-monthly cadence agree initially but diverge after several
  steps;
- an occurrence lies exactly on the coverage / observation boundary;
- partial publication or recovery makes plan metadata and generated occurrences
  disagree;
- a terminal or replaced series becomes active again after reload.

## Qualification evidence

A successful use should show that:

- current-series selection follows retained lifecycle evidence;
- recurrence / extension is deterministic for the qualified coordinate;
- replacement does not leave stale active future state;
- retry / reload does not duplicate or resurrect occurrences;
- UI summaries remain projections over the same qualified Scheduled answer.

## Stop / retire conditions

Stop when the change cannot alter Scheduled lifecycle, time, selection, or
persistence meaning.

Retire or mutate the skill when a concrete failure shows that the listed
transition checks no longer match the production Scheduled model.
