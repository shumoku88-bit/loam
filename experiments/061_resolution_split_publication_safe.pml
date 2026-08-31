/* Observation 061: bounded split-stream publication for a whole-frontier Resolution.

   The unresolved frontier is already visible and stable:
     parent A Event is visible
     parent B Event is visible

   Old semantic state:
     replacement Event is not visible
     Resolution is not visible

   New semantic state:
     replacement Event is visible
     Resolution is visible and covers both parents

   Writer order: Resolution relation -> Event
   Reader order: Event -> Resolution relation

   Because both parent Events are pre-existing, the only new semantic activation
   edge is the replacement Event. A Resolution observed before that Event remains
   fail-closed and inert. The dangerous mixed snapshot is the opposite one:
   replacement Event visible while the Resolution relation is not admitted.
*/

bool disk_replacement_new = false;
bool disk_resolution_new = false;

bool parent_a_visible = true;
bool parent_b_visible = true;

proctype Writer()
{
    disk_resolution_new = true;
    disk_replacement_new = true;
}

proctype Reader()
{
    bool seen_replacement;
    bool seen_resolution;
    bool seen_parent_a;
    bool seen_parent_b;
    bool admitted;

    seen_parent_a = parent_a_visible;
    seen_parent_b = parent_b_visible;
    seen_replacement = disk_replacement_new;
    seen_resolution = disk_resolution_new;

    admitted = seen_resolution
        && seen_parent_a
        && seen_parent_b
        && seen_replacement;

    assert(!(seen_replacement && !admitted));
}

init
{
    atomic {
        run Writer();
        run Reader();
    }
}
