/* Observation 182: fresh Movement discharge publication activation.

   A later Movement Event may explicitly discharge part of an already-current
   RelationUnit. Raw discharge evidence is supporting provenance for that later
   Event, not authority on its own.

   Candidate writer order:
     discharge meaning decision
     -> positive discharge row when needed
     -> qualification complete
     -> Event last

   Candidate reader order:
     Event
     -> discharge

   A discharge row may survive a crash before its later Event. That row must stay
   inert while the Event is absent, so the earlier RelationUnit remains readable
   at its old outstanding quantity. Once Event authority is visible, a required
   discharge row must already be visible to an Event-first reader.
*/

bool disk_event = false;
bool disk_discharge = false;
bool truth_has_discharge = false;
bool qualification_done = false;

proctype Writer()
{
    if
    :: truth_has_discharge = true;
       disk_discharge = true
    :: truth_has_discharge = false
    fi;

    qualification_done = true;

    /* Crash prefix: supporting discharge provenance may survive while the later
       Event never becomes authoritative. */
    if
    :: skip
    :: disk_event = true
    fi
}

proctype Reader()
{
    bool seen_event;
    bool seen_discharge;
    byte observed_outstanding;

    /* Event-first acquisition is the candidate ordering. */
    seen_event = disk_event;
    seen_discharge = disk_discharge;

    /* The already-current relation begins with outstanding quantity 10. */
    observed_outstanding = 10;

    if
    :: seen_event ->
        assert(qualification_done);
        if
        :: truth_has_discharge ->
            /* The authoritative later Event must not be observed without its
               already-published exact discharge support. */
            assert(seen_discharge);
            observed_outstanding = 6;
            assert(observed_outstanding == 6)
        :: !truth_has_discharge ->
            assert(!seen_discharge);
            assert(observed_outstanding == 10)
        fi
    :: !seen_event ->
        /* A pre-Event discharge row is raw crash residue only. It cannot reduce
           outstanding and cannot make the old relation query unavailable. */
        assert(observed_outstanding == 10)
    fi
}

init
{
    atomic {
        run Writer();
        run Reader()
    }
}
