module experiments/247_zero_origin_factorization

-- Observation 247
--
-- Challenge whether current per-coordinate zero-origin coverage necessarily
-- represents independent household facts. Compare two semantic shapes while
-- preserving the coverage answer itself.

abstract sig Coordinate {}
one sig Cash, PayPay, Smbc, Yucho, AllCountry extends Coordinate {}

sig DirectWorld {
  covered : set Coordinate
}

sig FactoredWorld {
  originEstablished : one Bool,
  trackedFromOrigin : set Coordinate
}

abstract sig Bool {}
one sig Yes, No extends Bool {}

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

-- Every current-style direct coverage set has some factored representation.
pred everyDirectHasFactoredImage {
  all d : DirectWorld |
    some f : FactoredWorld |
      equivalent[d, f]
}

-- When an origin is explicitly established, one origin fact plus the tracked
-- coordinate set can reconstruct any direct covered set exactly.
pred explicitOriginReconstructsDirect {
  all d : DirectWorld |
    some f : FactoredWorld |
      f.originEstablished = Yes
      and f.trackedFromOrigin = d.covered
      and equivalent[d, f]
}

-- The factorization is not itself a compression result if trackedFromOrigin
-- remains an arbitrary set: distinct tracked coordinate sets remain observably
-- distinct. This witness prevents us from claiming that one Boolean origin fact
-- alone can replace the current coordinate evidence.
pred trackedSetStillCarriesInformation {
  some disj f1, f2 : FactoredWorld |
    f1.originEstablished = Yes
    and f2.originEstablished = Yes
    and f1.trackedFromOrigin != f2.trackedFromOrigin
    and factoredCoverage[f1] != factoredCoverage[f2]
}

-- If one tried to retain only the origin flag and discard tracked coordinates,
-- worlds with the same origin flag could still require different coverage
-- answers. This is the key counterexample against over-compression.
pred originFlagAloneIsInsufficient {
  some disj f1, f2 : FactoredWorld |
    f1.originEstablished = Yes
    and f2.originEstablished = Yes
    and factoredCoverage[f1] != factoredCoverage[f2]
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
