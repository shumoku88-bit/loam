module model/observation_009_information_vs_update_footprint

abstract sig Bit {}
one sig Off, On extends Bit {}

abstract sig Count {}
one sig C0, C1, C2 extends Count {}

abstract sig State {
  u0: one Bit,
  u1: one Bit,
  count: one Count
}

one sig S00, S10, S01, S11 extends State {}

fact FourBooleanStates {
  S00.u0 = Off
  S00.u1 = Off
  S00.count = C0

  S10.u0 = On
  S10.u1 = Off
  S10.count = C1

  S01.u0 = Off
  S01.u1 = On
  S01.count = C1

  S11.u0 = On
  S11.u1 = On
  S11.count = C2
}

pred informationEquivalent {
  all a, b: State |
    ((a.u0 = b.u0) and (a.u1 = b.u1)) iff
    ((a.u0 = b.u0) and (a.count = b.count))
}

pred directOneAltTwo {
  some disj a, b: State |
    (a.u0 != b.u0) and
    (a.u1 = b.u1) and
    (a.count != b.count)
}

pred footprintWitness {
  informationEquivalent
  directOneAltTwo
}

assert AlternativePreservesInformation {
  informationEquivalent
}

check AlternativePreservesInformation for exactly 4 State, exactly 2 Bit, exactly 3 Count
run footprintWitness for exactly 4 State, exactly 2 Bit, exactly 3 Count
