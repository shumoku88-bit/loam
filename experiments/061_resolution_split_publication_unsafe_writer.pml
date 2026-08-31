/* Observation 061 boundary: unsafe Event-first Resolution writer.

   Stable unresolved frontier: parent A and parent B are already visible.

   Writer order: Event -> Resolution relation
   Reader order: Event -> Resolution relation

   A reader can observe the replacement Event after the first writer step while
   still observing the old Resolution stream. The replacement is then visible
   without an admitted whole-frontier Resolution.
*/

bool disk_replacement_new = false;
bool disk_resolution_new = false;

proctype Writer()
{
    disk_replacement_new = true;
    disk_resolution_new = true;
}

proctype Reader()
{
    bool seen_replacement;
    bool seen_resolution;
    bool admitted;

    seen_replacement = disk_replacement_new;
    seen_resolution = disk_resolution_new;

    admitted = seen_resolution && seen_replacement;
    assert(!(seen_replacement && !admitted));
}

init
{
    atomic {
        run Writer();
        run Reader();
    }
}
