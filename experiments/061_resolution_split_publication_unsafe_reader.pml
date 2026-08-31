/* Observation 061 boundary: unsafe Resolution-first reader.

   Stable unresolved frontier: parent A and parent B are already visible.

   Writer order: Resolution relation -> Event
   Reader order: Resolution relation -> Event

   The reader can first acquire the old Resolution stream, then the writer can
   complete both publications, and finally the reader can acquire the new Event
   stream. That snapshot exposes the replacement without an admitted Resolution.
*/

bool disk_replacement_new = false;
bool disk_resolution_new = false;

proctype Writer()
{
    disk_resolution_new = true;
    disk_replacement_new = true;
}

proctype Reader()
{
    bool seen_resolution;
    bool seen_replacement;
    bool admitted;

    seen_resolution = disk_resolution_new;
    seen_replacement = disk_replacement_new;

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
