import Loam.Application.CorrectionFrontier

namespace Loam.StructuralS008

open Loam.Core

set_option autoImplicit false

/-!
# Structural S008 — correction-chain length independence

S008 asks whether the current correction frontier is only demonstrated for short
examples, or whether its terminal-selection rule is independent of finite linear
chain length.

The production `CorrectionFrontier` already admits only disjoint finite paths.
This observation therefore does not introduce a graph model. It uses the public
frontier result and the retained correction facts directly.
-/

/--
For an arbitrary finite list of Events selected as one admitted linear chain,
if every nonterminal Event is targeted by a retained Correction and the terminal
Event is not targeted, then the successful production frontier contains exactly
the terminal Event from that chain.

The list may have any finite length. No induction on a fixed bound, correction
arrival order, or winner-by-position rule appears in the theorem.
-/
theorem arbitrary_linear_chain_terminal_only
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (frontier : EventMemory)
    (hFrontier :
      Loam.Application.correctionFrontierMemory? events corrections = some frontier)
    (chain : List Event)
    (terminal : Event)
    (hTerminalInChain : terminal ∈ chain)
    (hChainRemembered : ∀ event ∈ chain, event ∈ events.events)
    (hTerminalUntargeted :
      ∀ correction ∈ corrections.corrections,
        correction.target ≠ terminal.id)
    (hEveryOtherTargeted :
      ∀ event ∈ chain, event ≠ terminal →
        ∃ correction ∈ corrections.corrections,
          correction.target = event.id) :
    ∀ event ∈ chain, (event ∈ frontier.events ↔ event = terminal) := by
  classical
  intro event hEventInChain
  constructor
  · intro hInFrontier
    have hCharacterization :=
      (Loam.Application.correctionFrontierMemory?_mem_iff
        events corrections frontier hFrontier event).mp hInFrontier
    by_cases hEqual : event = terminal
    · exact hEqual
    · obtain ⟨correction, hCorrection, hTarget⟩ :=
        hEveryOtherTargeted event hEventInChain hEqual
      exact False.elim (hCharacterization.2 correction hCorrection hTarget)
  · intro hEqual
    cases hEqual
    exact
      (Loam.Application.correctionFrontierMemory?_mem_iff
        events corrections frontier hFrontier terminal).2
        ⟨hChainRemembered terminal hTerminalInChain, hTerminalUntargeted⟩

/-! ## Direct production specimen beyond Application 007's A -> B -> C sample -/

private def wallet : LocusId := ⟨"wallet"⟩
private def jpy : MeasureId := ⟨"jpy"⟩

private def oneEffectEvent
    (eventToken effectToken : String)
    (quanta : Int) : Event :=
  { id := ⟨eventToken⟩
    effects :=
      [Effect.ofQuantity
        ⟨effectToken⟩ wallet jpy (Quantity.ofQuanta quanta)]
    keyNodup := by simp }

private def correction
    (correctionToken targetToken replacementToken : String) : EventCorrection :=
  { id := ⟨correctionToken⟩
    target := ⟨targetToken⟩
    replacement := ⟨replacementToken⟩ }

private def fiveEventMemory : EventMemory :=
  { events :=
      [ oneEffectEvent "a" "ea" 10
      , oneEffectEvent "b" "eb" 20
      , oneEffectEvent "c" "ec" 30
      , oneEffectEvent "d" "ed" 40
      , oneEffectEvent "e" "ee" 50
      ]
    idNodup := by native_decide }

private def fourCorrectionChain : EventCorrectionMemory :=
  { corrections :=
      [ correction "c1" "a" "b"
      , correction "c2" "b" "c"
      , correction "c3" "c" "d"
      , correction "c4" "d" "e"
      ]
    idNodup := by native_decide }

/--
The real production frontier handles a four-edge chain and projects only the
terminal Event quantity. This is a mapping witness; the theorem above is the
unbounded structural result.
-/
example :
    Loam.Application.quantityAtCorrectionFrontier?
      fiveEventMemory fourCorrectionChain wallet jpy =
        some (Quantity.ofQuanta 50) := by
  native_decide

/-!
## Candidate finding

If this file compiles with the production membership theorem, S008 survives in
the narrow form actually needed by LOAM:

```text
successful admitted correction frontier
  + arbitrary finite selected linear chain
  + every nonterminal is a correction target
  + terminal is not a correction target
      -> exactly terminal survives from that chain
```

The result is stronger than checking lengths 1, 2, 3, ... independently because
path length disappears from the frontier-membership law.

It does not say every directed graph is admissible. Branching, merging, missing
endpoints, and cycles remain fail-closed at the existing admission boundary. It
also does not introduce a generic graph abstraction, correction normalization,
or new runtime state.
-/

end Loam.StructuralS008
