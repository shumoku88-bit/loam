module experiments/zero_origin_factorization_247

-- Observation 247
--
-- Challenge whether current per-coordinate zero-origin coverage necessarily
-- represents independent household facts. Compare two semantic shapes while
-- preserving the coverage answer itself.

abstract sig Coordinate {}
one sig Cash, PayPay, Smbc, Yucho, AllCountry extends Coordinate {}

one sig Origin {}

sig DirectWorld {
  covered : set Coordinate
}

sig FactoredWorld {
  origin : lone Origin,
  trackedFromOrigin : set Coordinate
}

fun directCoverage[w : DirectWorld] : set Coordinate {
  w.covered
}

fun factoredCoverage[w : FactoredWorld] : set Coordinate {
  { c : Coordinate |
      some w.origin and c in w.trackedFromOrigin }
}

pred equivalent[d : DirectWorld, f : FactoredWorld] {
  directCoverage[d] = factoredCoverage[f]
}

pred everyDirectHasFactoredImage {
  all d : DirectWorld |
    some f : FactoredWorld |
      equivalent[d, f]
}

pred explicitOriginReconstructsDirect {
  all d : DirectWorld |
    some f : FactoredWorld |
      some f.origin
      and f.trackedFromOrigin = d.covered
      and equivalent[d, f]
}

pred trackedSetStillCarriesInformation {
  some f1, f2 : FactoredWorld, c : Coordinate |
    f1 != f2
    and some f1.origin
    and some f2.origin
    and c in f1.trackedFromOrigin
    and c not in f2.trackedFromOrigin
    and c in factoredCoverage[f1]
    and c not in factoredCoverage[f2]
}

pred originFactAloneIsInsufficient {
  some f1, f2 : FactoredWorld, c : Coordinate |
    f1 != f2
    and f1.origin = f2.origin
    and some f1.origin
    and c in factoredCoverage[f1]
    and c not in factoredCoverage[f2]
}

assert DirectToFactoredCoveragePreserved {
  all d : DirectWorld, f : FactoredWorld |
    equivalent[d, f] implies directCoverage[d] = factoredCoverage[f]
}

run everyDirectHasFactoredImage for 5 DirectWorld, 5 FactoredWorld
run explicitOriginReconstructsDirect for 5 DirectWorld, 5 FactoredWorld
run trackedSetStillCarriesInformation for 2 FactoredWorld
run originFactAloneIsInsufficient for 2 FactoredWorld
check DirectToFactoredCoveragePreserved for 5 DirectWorld, 5 FactoredWorld
