/* Observation 177 counterexample: Event-first writer.

   The retained meaning has a positive open relation, but the writer exposes the
   Event authority before the positive relation row. A reader that samples Event
   first and relation second can therefore observe a covered current Event with
   apparent relation absence and mispublish known-none.
*/

bool disk_event = false;
bool disk_relation = false;
bool truth_has_edge = true;
bool qualification_done = false;

proctype Writer()
{
    qualification_done = true;
    disk_event = true;
    disk_relation = true
}

proctype Reader()
{
    bool seen_event;
    bool seen_relation;

    seen_event = disk_event;
    seen_relation = disk_relation;

    if
    :: seen_event && !seen_relation ->
        /* This is exactly the false-known-none state the protocol must forbid. */
        assert(!truth_has_edge)
    :: else -> skip
    fi
}

init
{
    atomic {
        run Writer();
        run Reader()
    }
}
