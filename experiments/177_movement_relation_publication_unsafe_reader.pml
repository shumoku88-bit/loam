/* Observation 177 counterexample: relation-first reader.

   The writer uses the candidate safe order: positive relation first, Event last.
   But a reader that samples the relation stream first can retain an old empty
   relation snapshot, then observe the newly activated Event and mispublish
   covered known-none for a source that really has a positive edge.
*/

bool disk_event = false;
bool disk_relation = false;
bool truth_has_edge = true;
bool qualification_done = false;

proctype Writer()
{
    disk_relation = true;
    qualification_done = true;
    disk_event = true
}

proctype Reader()
{
    bool seen_event;
    bool seen_relation;

    seen_relation = disk_relation;
    seen_event = disk_event;

    if
    :: seen_event && !seen_relation ->
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
