/* Observation 177: Movement open-relation split publication.

   This model asks whether fresh Movement publication can keep one independent
   positive RelationUnit stream without a stored negative/no-relation receipt.

   The writer first decides relation meaning. If the movement has a positive
   open relation, it publishes that raw relation before Event authority. If the
   movement has no open relation, the relation stream remains unchanged. The
   writer then marks relation qualification complete and may either crash before
   Event publication or publish the Event as the authority commit.

   Writer order:
     relation decision
     -> positive relation row when needed
     -> qualification complete
     -> Event last

   Reader order:
     Event
     -> relation

   `disk_event` is the semantic activation edge. Supporting validity and
   description evidence are omitted because current Movement already publishes
   them before Event and they are inert while EventId is absent.
*/

bool disk_event = false;
bool disk_relation = false;
bool truth_has_edge = false;
bool qualification_done = false;

proctype Writer()
{
    /* The operation-specific adapter decides relation meaning before the
       authority commit. Only positive meaning adds a physical relation row. */
    if
    :: truth_has_edge = true;
       disk_relation = true
    :: truth_has_edge = false
    fi;

    qualification_done = true;

    /* Crash-prefix probe: the writer may stop here. In that state supporting
       relation evidence may be visible, but Event authority is still absent. */
    if
    :: skip
    :: disk_event = true
    fi
}

proctype Reader()
{
    bool seen_event;
    bool seen_relation;

    seen_event = disk_event;
    seen_relation = disk_relation;

    if
    :: seen_event ->
        /* Seeing Event authority must imply that relation qualification had
           already finished for this writer. */
        assert(qualification_done);

        if
        :: seen_relation ->
            /* A current positive row must correspond to positive meaning. */
            assert(truth_has_edge)
        :: !seen_relation ->
            /* Covered absence after Event activation may be compressed to
               known-none only when the qualified meaning really has no edge. */
            assert(!truth_has_edge)
        fi
    :: !seen_event ->
        /* Relation-first crash prefixes are semantically inert because the
           source Event has not been activated. */
        skip
    fi
}

init
{
    atomic {
        run Writer();
        run Reader()
    }
}
