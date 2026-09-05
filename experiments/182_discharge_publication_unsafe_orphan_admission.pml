/* Observation 182 counterexample: strict admission of pre-Event discharge residue.

   The writer publishes supporting discharge provenance and then crashes before
   the later Event. The earlier RelationUnit is still authoritative and its
   outstanding quantity is still 10. Treating the raw discharge row itself as a
   reason to make the query unresolved loses an otherwise valid old answer.

   Candidate admission instead treats discharge rows whose later Event is absent
   as inert until Event authority appears. Malformed discharge evidence attached
   to an already-present later Event remains a separate fail-closed case.
*/

bool disk_event = false;
bool disk_discharge = false;

proctype Writer()
{
    disk_discharge = true;
    /* crash: no Event publication */
    skip
}

proctype StrictReader()
{
    bool seen_event;
    bool seen_discharge;
    bool query_available;

    seen_event = disk_event;
    seen_discharge = disk_discharge;
    query_available = true;

    if
    :: seen_discharge && !seen_event ->
        /* Current #369-style strict reference admission would reject the raw
           target discharge because its later Event does not resolve. */
        query_available = false
    :: else -> skip
    fi;

    /* Without later Event authority, crash residue must not suppress the still
       valid pre-discharge outstanding answer. */
    assert(query_available)
}

init
{
    atomic {
        run Writer();
        run StrictReader()
    }
}
