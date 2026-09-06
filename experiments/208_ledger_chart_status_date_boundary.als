module experiments/observation_208_ledger_chart_status_date_boundary

abstract sig AccountingRole {}
one sig AssetRole, ExpenseRole extends AccountingRole {}

abstract sig Status {}
one sig Unmarked, Pending, Cleared extends Status {}

abstract sig Date {}
one sig D0, D1 extends Date {}

sig Event {}
sig Locus {}

sig Effect {
  event : one Event,
  locus : one Locus
}

sig World {
  parent : Locus -> lone Locus,
  declaredRole : Locus -> lone AccountingRole,

  transactionStatus : Event -> one Status,
  postingStatus : Effect -> lone Status,

  transactionDate : Event -> one Date,
  postingDate : Effect -> lone Date,

  root : one Locus,
  roleQuery : one AccountingRole,
  statusQuery : one Status,
  throughDate : one Date
}

fact AcyclicHierarchy {
  all w : World | no iden & ^(w.parent)
}

pred onOrBefore[a, b : Date] {
  a = b or (a = D0 and b = D1)
}

pred nearestDeclaredAncestor[w : World, child, ancestor : Locus] {
  ancestor in child.^(w.parent)
  some ancestor.(w.declaredRole)
  no between : Locus |
    between in child.^(w.parent) and
    between != ancestor and
    ancestor in between.^(w.parent) and
    some between.(w.declaredRole)
}

pred effectiveRole[w : World, locus : Locus, role : AccountingRole] {
  (some locus.(w.declaredRole) and role in locus.(w.declaredRole)) or
  (no locus.(w.declaredRole) and
    some ancestor : Locus |
      nearestDeclaredAncestor[w, locus, ancestor] and
      role in ancestor.(w.declaredRole))
}

pred effectiveStatus[w : World, effect : Effect, status : Status] {
  (some effect.(w.postingStatus) and status in effect.(w.postingStatus)) or
  (no effect.(w.postingStatus) and status in effect.event.(w.transactionStatus))
}

pred effectiveDate[w : World, effect : Effect, date : Date] {
  (some effect.(w.postingDate) and date in effect.(w.postingDate)) or
  (no effect.(w.postingDate) and date in effect.event.(w.transactionDate))
}

pred inSelectedSubtree[w : World, effect : Effect] {
  w.root in effect.locus.*(w.parent)
}

pred reportSelected[w : World, effect : Effect] {
  inSelectedSubtree[w, effect]
  some role : AccountingRole |
    effectiveRole[w, effect.locus, role] and role = w.roleQuery
  some status : Status |
    effectiveStatus[w, effect, status] and status = w.statusQuery
  some date : Date |
    effectiveDate[w, effect, date] and onOrBefore[date, w.throughDate]
}

pred assertionSelected[w : World, effect : Effect] {
  inSelectedSubtree[w, effect]
  some date : Date |
    effectiveDate[w, effect, date] and onOrBefore[date, w.throughDate]
}

fun reportEffects[w : World] : set Effect {
  { effect : Effect | reportSelected[w, effect] }
}

fun assertionEffects[w : World] : set Effect {
  { effect : Effect | assertionSelected[w, effect] }
}

pred sameExceptParent[a, b : World] {
  a.declaredRole = b.declaredRole
  a.transactionStatus = b.transactionStatus
  a.postingStatus = b.postingStatus
  a.transactionDate = b.transactionDate
  a.postingDate = b.postingDate
  a.root = b.root
  a.roleQuery = b.roleQuery
  a.statusQuery = b.statusQuery
  a.throughDate = b.throughDate
}

pred sameExceptPostingStatus[a, b : World] {
  a.parent = b.parent
  a.declaredRole = b.declaredRole
  a.transactionStatus = b.transactionStatus
  a.transactionDate = b.transactionDate
  a.postingDate = b.postingDate
  a.root = b.root
  a.roleQuery = b.roleQuery
  a.statusQuery = b.statusQuery
  a.throughDate = b.throughDate
}

pred sameExceptPostingDate[a, b : World] {
  a.parent = b.parent
  a.declaredRole = b.declaredRole
  a.transactionStatus = b.transactionStatus
  a.postingStatus = b.postingStatus
  a.transactionDate = b.transactionDate
  a.root = b.root
  a.roleQuery = b.roleQuery
  a.statusQuery = b.statusQuery
  a.throughDate = b.throughDate
}

pred hierarchyChangesSubtreeReport {
  some disj a, b : World, effect : Effect, disj rootLocus, child : Locus |
    sameExceptParent[a, b] and
    a.root = rootLocus and b.root = rootLocus and
    effect.locus = child and
    child->rootLocus in a.parent and
    no child.(b.parent) and
    child->AssetRole in a.declaredRole and
    effect.event->Cleared in a.transactionStatus and
    no effect.(a.postingStatus) and
    effect.event->D0 in a.transactionDate and
    no effect.(a.postingDate) and
    a.roleQuery = AssetRole and
    a.statusQuery = Cleared and
    a.throughDate = D1 and
    reportSelected[a, effect] and
    not reportSelected[b, effect]
}

pred inheritedRoleChangesStatementSelection {
  some disj a, b : World, effect : Effect, disj rootLocus, child : Locus |
    a.parent = b.parent and
    child->rootLocus in a.parent and
    a.root = rootLocus and b.root = rootLocus and
    effect.locus = child and
    no child.(a.declaredRole) and
    no child.(b.declaredRole) and
    rootLocus->AssetRole in a.declaredRole and
    rootLocus->ExpenseRole in b.declaredRole and
    a.transactionStatus = b.transactionStatus and
    a.postingStatus = b.postingStatus and
    a.transactionDate = b.transactionDate and
    a.postingDate = b.postingDate and
    effect.event->Cleared in a.transactionStatus and
    no effect.(a.postingStatus) and
    effect.event->D0 in a.transactionDate and
    no effect.(a.postingDate) and
    a.roleQuery = AssetRole and b.roleQuery = AssetRole and
    a.statusQuery = Cleared and b.statusQuery = Cleared and
    a.throughDate = D1 and b.throughDate = D1 and
    reportSelected[a, effect] and
    not reportSelected[b, effect]
}

pred childRoleOverrideWitness {
  some w : World, effect : Effect, disj rootLocus, child : Locus |
    child->rootLocus in w.parent and
    w.root = rootLocus and
    effect.locus = child and
    rootLocus->AssetRole in w.declaredRole and
    child->ExpenseRole in w.declaredRole and
    effect.event->Cleared in w.transactionStatus and
    no effect.(w.postingStatus) and
    effect.event->D0 in w.transactionDate and
    no effect.(w.postingDate) and
    w.roleQuery = ExpenseRole and
    w.statusQuery = Cleared and
    w.throughDate = D1 and
    effectiveRole[w, child, ExpenseRole] and
    not effectiveRole[w, child, AssetRole] and
    reportSelected[w, effect]
}

pred postingStatusChangesReportButNotAssertion {
  some disj a, b : World, effect : Effect |
    sameExceptPostingStatus[a, b] and
    a.root = effect.locus and b.root = effect.locus and
    effect.locus->AssetRole in a.declaredRole and
    effect.event->Cleared in a.transactionStatus and
    effect->Pending in a.postingStatus and
    effect->Cleared in b.postingStatus and
    effect.event->D0 in a.transactionDate and
    no effect.(a.postingDate) and
    a.roleQuery = AssetRole and b.roleQuery = AssetRole and
    a.statusQuery = Pending and b.statusQuery = Pending and
    a.throughDate = D1 and b.throughDate = D1 and
    reportSelected[a, effect] and
    not reportSelected[b, effect] and
    assertionSelected[a, effect] and
    assertionSelected[b, effect]
}

pred postingDateChangesPeriodSelection {
  some disj a, b : World, effect : Effect |
    sameExceptPostingDate[a, b] and
    a.root = effect.locus and b.root = effect.locus and
    effect.locus->AssetRole in a.declaredRole and
    effect.event->Cleared in a.transactionStatus and
    no effect.(a.postingStatus) and
    effect.event->D0 in a.transactionDate and
    effect->D0 in a.postingDate and
    effect->D1 in b.postingDate and
    a.roleQuery = AssetRole and b.roleQuery = AssetRole and
    a.statusQuery = Cleared and b.statusQuery = Cleared and
    a.throughDate = D0 and b.throughDate = D0 and
    reportSelected[a, effect] and
    not reportSelected[b, effect]
}

assert FlatRoleDataDeterminesTreeReport {
  all a, b : World |
    sameExceptParent[a, b] => reportEffects[a] = reportEffects[b]
}

assert TransactionStatusDeterminesStatusFilteredReport {
  all a, b : World |
    sameExceptPostingStatus[a, b] => reportEffects[a] = reportEffects[b]
}

assert TransactionDateDeterminesDatedReport {
  all a, b : World |
    sameExceptPostingDate[a, b] => reportEffects[a] = reportEffects[b]
}

assert AssertionSelectionIndependentOfStatusQuery {
  all a, b : World |
    (a.parent = b.parent and
     a.declaredRole = b.declaredRole and
     a.transactionStatus = b.transactionStatus and
     a.postingStatus = b.postingStatus and
     a.transactionDate = b.transactionDate and
     a.postingDate = b.postingDate and
     a.root = b.root and
     a.roleQuery = b.roleQuery and
     a.throughDate = b.throughDate)
      => assertionEffects[a] = assertionEffects[b]
}

assert ExplicitOverlaysDetermineSelectedViews {
  all a, b : World |
    (a.parent = b.parent and
     a.declaredRole = b.declaredRole and
     a.transactionStatus = b.transactionStatus and
     a.postingStatus = b.postingStatus and
     a.transactionDate = b.transactionDate and
     a.postingDate = b.postingDate and
     a.root = b.root and
     a.roleQuery = b.roleQuery and
     a.statusQuery = b.statusQuery and
     a.throughDate = b.throughDate)
      => (reportEffects[a] = reportEffects[b] and
          assertionEffects[a] = assertionEffects[b])
}

run hierarchyChangesSubtreeReport for 6 World, 4 Event, 5 Effect, 5 Locus
run inheritedRoleChangesStatementSelection for 6 World, 4 Event, 5 Effect, 5 Locus
run childRoleOverrideWitness for 6 World, 4 Event, 5 Effect, 5 Locus
run postingStatusChangesReportButNotAssertion for 6 World, 4 Event, 5 Effect, 5 Locus
run postingDateChangesPeriodSelection for 6 World, 4 Event, 5 Effect, 5 Locus

check FlatRoleDataDeterminesTreeReport for 6 World, 4 Event, 5 Effect, 5 Locus
check TransactionStatusDeterminesStatusFilteredReport for 6 World, 4 Event, 5 Effect, 5 Locus
check TransactionDateDeterminesDatedReport for 6 World, 4 Event, 5 Effect, 5 Locus
check AssertionSelectionIndependentOfStatusQuery for 6 World, 4 Event, 5 Effect, 5 Locus
check ExplicitOverlaysDetermineSelectedViews for 6 World, 4 Event, 5 Effect, 5 Locus
