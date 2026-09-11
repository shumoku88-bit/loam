module experiments/zero_origin_factorization_247

-- Observation 247
--
-- Challenge whether current per-coordinate zero-origin coverage necessarily
-- represents independent household facts. Compare two semantic shapes while
-- preserving the coverage answer itself.

abstract sig Coordinate {}
one sig Cash, PayPay, Smbc, Yucho, AllCountry extends Coordinate {}

abstract sig Bool {}
one sig Yes, No extends Bool {}

sig DirectWorld {
  covered : set Coordinate
}

sig FactoredWorld {
  originEstablished : one Bool,
  trackedFromOrigin : set Coordinate
}

fun directCoverage[w : DirectWorld] : set Coordinate {
  w.covered
}

fun factoredCoverage[w : FactoredWorld] : set Coordinate {
  { c : Coordinate |
      w.originEstablished = Yes and c in w.trackedFromOrigin }
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
      f.originEstablished = Yes
      and f.trackedFromOrigin = d.covered
      and equivalent[d, f]
}

-- Direct witness: with the same established origin, one coordinate can be
-- tracked in one world and not in another, changing the coverage answer.
pred trackedSetStillCarriesInformation {
  some f1, f2 : FactoredWorld, c : Coordinate |
    f1 != f2
    and f1.originEstablished = Yes
    and f2.originEstablished = Yes
    and c in f1.trackedFromOrigin
    and c not in f2.trackedFromOrigin
    and c in factoredCoverage[f1]
    and c not in factoredCoverage[f2]
}

-- Therefore retaining only the origin flag identifies worlds whose coverage
-- answers differ.
pred originFlagAloneIsInsufficient {
  some f1, f2 : FactoredWorld, c : Coordinate |
    f1 != f2
    and f1.originEstablished = f2.originEstablished
    and f1.originEstablished = Yes
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
run originFlagAloneIsInsufficient for 2 FactoredWorld
check DirectToFactoredCoveragePreserved for 5 DirectWorld, 5 FactoredWorld
