# EffectKey persistence pressure

This read-only follow-up asks a narrower question than SA-010.

SA-010 already earned `EffectKey` as semantic nested identity because later relation provenance can distinguish one Effect from another inside the same Event. This experiment does **not** ask to delete that distinction.

Question:

> Must every Effect persist a stable key before any later reference exists, or can stable identity be introduced only when an Effect first becomes independently referable?

The current household checkpoint has no retained RelationUnit rows, so every currently persisted EffectKey is unreferenced by relation authority. That makes the byte pressure measurable, but does not by itself authorize deletion: the ability to attach a future relation to a historical Effect is also part of the semantics.

Candidates to compare:

1. current LOAM: every Effect receives a stable key at Event creation;
2. HRA-N-like positional reconstruction: keys are synthesized from flow order on read;
3. sparse identity: ordinary Effects are keyless until a later overlay makes one independently referable, at which point publication introduces a stable key without changing physical quantity.

A valid sparse candidate must preserve permutation-insensitive Event quantity semantics, allow two coordinate-equal Effects, and retain exact `(EventId, EffectKey)` relation provenance after identity introduction. It must not quietly promote list position to semantic identity.
