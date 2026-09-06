module Loam/Prototype/Interaction08/Minimality

-- Structural pressure only.
--
-- The model asks whether current interaction goals require independent
-- top-level surfaces, or whether some HRA-derived views can remain local modes
-- inside one semantic-family workspace.

abstract sig Goal {}
one sig SelectDay,
        ReviewActual,
        InspectActual,
        RecordActual,
        ReviewScheduled,
        ReviewIssues,
        ViewReports extends Goal {}

abstract sig Surface {
  provides: set Goal,
  next: set Surface
}

one sig Home,
        ActualWorkspace,
        ActualList,
        ActualDetail,
        ScheduledWorkspace,
        IssueWorkspace,
        ReportWorkspace,
        Palette,
        EntitlementWorkspace extends Surface {}

sig Config {
  kept: set Surface
}

fact Capabilities {
  Home.provides = SelectDay

  -- HRA-like shape: browse/detail stay local to one Actual workspace.
  ActualWorkspace.provides = ReviewActual + InspectActual + RecordActual

  -- Prototype-07-like split: list and detail are independent top-level nodes.
  ActualList.provides = ReviewActual + RecordActual
  ActualDetail.provides = InspectActual

  ScheduledWorkspace.provides = ReviewScheduled
  IssueWorkspace.provides = ReviewIssues
  ReportWorkspace.provides = ViewReports

  -- These are additive candidates in this study. They provide no currently
  -- required interaction goal merely by existing.
  no Palette.provides
  no EntitlementWorkspace.provides
}

fact CandidateNavigation {
  -- Home is the stable temporal root.
  Home.next = ActualWorkspace + ActualList + ScheduledWorkspace +
              IssueWorkspace + ReportWorkspace + Palette +
              EntitlementWorkspace

  -- One-workspace Actual shape.
  ActualWorkspace.next = Home

  -- Split Actual shape.
  ActualList.next = Home + ActualDetail
  ActualDetail.next = ActualList

  ScheduledWorkspace.next = Home
  IssueWorkspace.next = Home
  ReportWorkspace.next = Home
  EntitlementWorkspace.next = Home

  -- A palette can route, but it creates no new household capability here.
  Palette.next = ActualWorkspace + ActualList + ScheduledWorkspace +
                 IssueWorkspace + ReportWorkspace
}

fun activeEdges[c: Config]: Surface -> Surface {
  next & (c.kept -> c.kept)
}

pred reaches[c: Config, source, target: Surface] {
  let relation = activeEdges[c] |
    target in source.*relation
}

pred sufficient[c: Config] {
  Home in c.kept
  all g: Goal |
    some s: c.kept |
      g in s.provides and reaches[c, Home, s]
}

pred workspaceCore {
  some c: Config |
    c.kept = Home + ActualWorkspace + ScheduledWorkspace +
             IssueWorkspace + ReportWorkspace
    and sufficient[c]
}

pred splitActualCore {
  some c: Config |
    c.kept = Home + ActualList + ActualDetail + ScheduledWorkspace +
             IssueWorkspace + ReportWorkspace
    and sufficient[c]
}

pred hraAdditiveEntitlement {
  some c: Config |
    c.kept = Home + ActualWorkspace + ScheduledWorkspace +
             IssueWorkspace + ReportWorkspace + EntitlementWorkspace
    and sufficient[c]
}

assert NoFourSurfaceSufficient {
  all c: Config |
    sufficient[c] implies #c.kept >= 5
}

assert FiveSurfaceCoreIsWorkspace {
  all c: Config |
    sufficient[c] and #c.kept = 5 implies
      c.kept = Home + ActualWorkspace + ScheduledWorkspace +
               IssueWorkspace + ReportWorkspace
}

assert MinimalExcludesPaletteAndEntitlement {
  all c: Config |
    sufficient[c] and #c.kept = 5 implies
      no c.kept & (Palette + EntitlementWorkspace + ActualList + ActualDetail)
}

-- 5-bit integers are intentional: the model contains nine candidate surfaces,
-- so cardinality checks must represent 0..9 without signed overflow.
run workspaceCore for exactly 7 Goal, exactly 9 Surface, 6 Config, 5 Int
run splitActualCore for exactly 7 Goal, exactly 9 Surface, 6 Config, 5 Int
run hraAdditiveEntitlement for exactly 7 Goal, exactly 9 Surface, 6 Config, 5 Int
check NoFourSurfaceSufficient for exactly 7 Goal, exactly 9 Surface, 6 Config, 5 Int
check FiveSurfaceCoreIsWorkspace for exactly 7 Goal, exactly 9 Surface, 6 Config, 5 Int
check MinimalExcludesPaletteAndEntitlement for exactly 7 Goal, exactly 9 Surface, 6 Config, 5 Int
