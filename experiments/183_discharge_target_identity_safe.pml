/* Observation 183: RelationUnit identity reservation against retained discharge targets.

   Raw RelationDischarge persistence intentionally retains missing targets. Such a
   row is not semantic authority for some future unrelated relation merely because
   its opaque target token is reused later.

   Candidate safety law:

     fresh RelationUnitId
       not in existing RelationUnit ids
       not in retained RelationDischarge target ids

   This bounded model represents the safe allocator. A retained orphan discharge
   targets relation-1. The unrelated writer must allocate relation-2 instead, so
   the old discharge cannot become active merely through identity reuse.
*/

byte existing_relation_id = 9;
byte orphan_discharge_target = 1;
byte allocated_relation_id = 0;
bool orphan_discharge_active = false;
bool writer_done = false;

proctype Writer()
{
    if
    :: (1 != existing_relation_id && 1 != orphan_discharge_target) ->
       allocated_relation_id = 1
    :: (1 == existing_relation_id || 1 == orphan_discharge_target) ->
       allocated_relation_id = 2
    fi;

    orphan_discharge_active =
        (allocated_relation_id == orphan_discharge_target);
    writer_done = true
}

proctype Reader()
{
    writer_done;
    assert(allocated_relation_id != orphan_discharge_target);
    assert(!orphan_discharge_active)
}

init
{
    run Writer();
    run Reader()
}
