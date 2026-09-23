import Loam.Persistence.NormalizedActualAdmission
import Loam.Application.ZeroOriginQuantity

namespace Loam.Observation319

open Loam.Core

set_option autoImplicit false

/-!
# Observation 319 — ZeroOriginCoverage needs the Measure coordinate

Issue #700 asks whether retained zero-origin evidence can be compressed below
the current finite set of EffectCoordinate values.

This observation tests one specific candidate compression:

    Locus × Measure coverage
        -> Locus-only coverage

The witness uses one admitted Actual world in which the same Locus participates
in both JPY and USD. Two zero-origin evidence worlds then retain exactly one
covered coordinate each:

    world JPY: wallet / JPY covered, wallet / USD uncovered
    world USD: wallet / USD covered, wallet / JPY uncovered

If Measure were erased from zero-origin evidence, both worlds would retain the
same covered Locus: wallet.

Current quantity answers nevertheless differ. A covered coordinate returns the
ordinary correction-aware quantity, while the other coordinate remains
coverageMissing. Therefore the Measure dimension cannot be removed from
ZeroOriginCoverage while preserving the current read vocabulary.

This is deliberately a partial minimality result. It does not prove that the
entire current ZeroOriginCoverage representation is globally minimal, nor does
it rule out a different representation carrying information equivalent to the
same per-coordinate distinction.
-/

private def jpy : MeasureId := ⟨"jpy"⟩
private def usd : MeasureId := ⟨"usd"⟩
private def wallet : LocusId := ⟨"o319-wallet"⟩
private def expense : LocusId := ⟨"o319-expense"⟩

private def walletJpy : EffectCoordinate := ⟨wallet, jpy⟩
private def walletUsd : EffectCoordinate := ⟨wallet, usd⟩

private def eventId : EventId := ⟨"o319-mixed-measure"⟩

private def mixedEffects : List Effect :=
  [ Effect.ofAnonymousQuantity wallet jpy (Quantity.ofQuanta (-100))
  , Effect.ofAnonymousQuantity expense jpy (Quantity.ofQuanta 100)
  , Effect.ofAnonymousQuantity wallet usd (Quantity.ofQuanta (-250))
  , Effect.ofAnonymousQuantity expense usd (Quantity.ofQuanta 250)
  ]

private def mixedEvent : Event :=
  { id := eventId
    effects := mixedEffects
    keyNodup := by native_decide }

private def events : EventMemory :=
  { events := [mixedEvent]
    idNodup := by simp }

private def validity : ActualValidityHistory String :=
  { facts := [.base eventId "2026-09-01"]
    factRefNodup := by simp
    corrections := []
    correctionIdNodup := by simp }

private def corrections : EventCorrectionMemory :=
  { corrections := []
    idNodup := by simp }

private def actual : Loam.ActualEvidence :=
  { events := events
    validity := validity
    descriptions := EventDescriptionMemory.empty
    merchants := EventMerchantEvidenceMemory.empty
    movementOperations := MovementOperationEvidenceMemory.empty
    corrections := corrections
    reversals := ActualReversalMemory.empty
    relations := []
    discharges := [] }

theorem common_actual_is_admitted :
    (Loam.Persistence.admitActualImage? actual).isSome = true := by
  native_decide

private def coverageJpy : ZeroOriginCoverage :=
  { coordinates := [walletJpy]
    nodup := by simp }

private def coverageUsd : ZeroOriginCoverage :=
  { coordinates := [walletUsd]
    nodup := by simp }

/-! ## Locus-only compression collides -/

def coveredLoci (coverage : ZeroOriginCoverage) : List LocusId :=
  (coverage.coordinates.map EffectCoordinate.locus).eraseDups

theorem locus_only_summaries_collide :
    coveredLoci coverageJpy = coveredLoci coverageUsd := by
  native_decide

theorem retained_coverages_differ :
    coverageJpy.coordinates ≠ coverageUsd.coordinates := by
  native_decide

/-! ## Current read answers distinguish the worlds -/

theorem jpy_answer_distinguishes :
    Loam.Application.inspectZeroOriginQuantity
        coverageJpy events corrections walletJpy =
      .current (Quantity.ofQuanta (-100)) ∧
    Loam.Application.inspectZeroOriginQuantity
        coverageUsd events corrections walletJpy =
      .coverageMissing := by
  native_decide

theorem usd_answer_distinguishes :
    Loam.Application.inspectZeroOriginQuantity
        coverageJpy events corrections walletUsd =
      .coverageMissing ∧
    Loam.Application.inspectZeroOriginQuantity
        coverageUsd events corrections walletUsd =
      .current (Quantity.ofQuanta (-250)) := by
  native_decide

/--
Any summary that remembers only covered Locus identities identifies these two
coverage worlds even though the current production read vocabulary distinguishes
them.
-/
theorem locus_only_coverage_is_not_sufficient :
    coveredLoci coverageJpy = coveredLoci coverageUsd ∧
    Loam.Application.inspectZeroOriginQuantity
        coverageJpy events corrections walletJpy ≠
      Loam.Application.inspectZeroOriginQuantity
        coverageUsd events corrections walletJpy := by
  constructor
  · exact locus_only_summaries_collide
  · native_decide

/-!
## Finding

For the current read vocabulary:

    same admitted Actual
    + same covered Locus set
    !=
    same zero-origin quantity answers

when one Locus participates in more than one Measure.

Canonical-basis classification for #700:

    ZeroOriginCoverage Measure dimension : WITNESS

The result protects the information distinction, not the current concrete list
representation or physical file. A future representation may still compress
ZeroOriginCoverage if it preserves information equivalent to per
Locus × Measure membership.
-/

end Loam.Observation319
