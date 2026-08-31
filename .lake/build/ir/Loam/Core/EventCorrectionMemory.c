// Lean compiler output
// Module: Loam.Core.EventCorrectionMemory
// Imports: public import Init public meta import Init public import Init.Data.List.Perm public import Loam.Core.EventCorrection
#include <lean/lean.h>
#if defined(__clang__)
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-label"
#elif defined(__GNUC__) && !defined(__CLANG__)
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wunused-label"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#endif
#ifdef __cplusplus
extern "C" {
#endif
lean_object* l_List_reverse___redArg(lean_object*);
uint8_t lean_string_dec_eq(lean_object*, lean_object*);
lean_object* lp_loam_Loam_Core_instDecidableEqEventCorrectionId___boxed(lean_object*, lean_object*);
uint8_t l_List_nodupDecidable___redArg(lean_object*, lean_object*);
lean_object* l_List_appendTR___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_List_mapTR_loop___at___00Loam_Core_EventCorrectionMemory_ofCorrections_x3f_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrectionMemory_ofCorrections_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Core_EventCorrectionMemory_0__Loam_Core_EventCorrectionMemory_findCorrectionById_x3f(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Core_EventCorrectionMemory_0__Loam_Core_EventCorrectionMemory_findCorrectionById_x3f___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Core_EventCorrectionMemory_0__Loam_Core_EventCorrectionMemory_findCorrectionById_x3f_match__1_splitter___redArg(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Core_EventCorrectionMemory_0__Loam_Core_EventCorrectionMemory_findCorrectionById_x3f_match__1_splitter(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrectionMemory_findById_x3f(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrectionMemory_findById_x3f___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrectionMemory_add_x3f(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_List_mapTR_loop___at___00Loam_Core_EventCorrectionMemory_ofCorrections_x3f_spec__0(lean_object* v_a_1_, lean_object* v_a_2_){
_start:
{
if (lean_obj_tag(v_a_1_) == 0)
{
lean_object* v___x_3_; 
v___x_3_ = l_List_reverse___redArg(v_a_2_);
return v___x_3_;
}
else
{
lean_object* v_head_4_; lean_object* v_tail_5_; lean_object* v___x_7_; uint8_t v_isShared_8_; uint8_t v_isSharedCheck_14_; 
v_head_4_ = lean_ctor_get(v_a_1_, 0);
v_tail_5_ = lean_ctor_get(v_a_1_, 1);
v_isSharedCheck_14_ = !lean_is_exclusive(v_a_1_);
if (v_isSharedCheck_14_ == 0)
{
v___x_7_ = v_a_1_;
v_isShared_8_ = v_isSharedCheck_14_;
goto v_resetjp_6_;
}
else
{
lean_inc(v_tail_5_);
lean_inc(v_head_4_);
lean_dec(v_a_1_);
v___x_7_ = lean_box(0);
v_isShared_8_ = v_isSharedCheck_14_;
goto v_resetjp_6_;
}
v_resetjp_6_:
{
lean_object* v_id_9_; lean_object* v___x_11_; 
v_id_9_ = lean_ctor_get(v_head_4_, 0);
lean_inc_ref(v_id_9_);
lean_dec(v_head_4_);
if (v_isShared_8_ == 0)
{
lean_ctor_set(v___x_7_, 1, v_a_2_);
lean_ctor_set(v___x_7_, 0, v_id_9_);
v___x_11_ = v___x_7_;
goto v_reusejp_10_;
}
else
{
lean_object* v_reuseFailAlloc_13_; 
v_reuseFailAlloc_13_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_13_, 0, v_id_9_);
lean_ctor_set(v_reuseFailAlloc_13_, 1, v_a_2_);
v___x_11_ = v_reuseFailAlloc_13_;
goto v_reusejp_10_;
}
v_reusejp_10_:
{
v_a_1_ = v_tail_5_;
v_a_2_ = v___x_11_;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrectionMemory_ofCorrections_x3f(lean_object* v_corrections_15_){
_start:
{
lean_object* v___x_16_; lean_object* v___x_17_; lean_object* v___x_18_; uint8_t v___x_19_; 
v___x_16_ = lean_alloc_closure((void*)(lp_loam_Loam_Core_instDecidableEqEventCorrectionId___boxed), 2, 0);
v___x_17_ = lean_box(0);
lean_inc(v_corrections_15_);
v___x_18_ = lp_loam_List_mapTR_loop___at___00Loam_Core_EventCorrectionMemory_ofCorrections_x3f_spec__0(v_corrections_15_, v___x_17_);
v___x_19_ = l_List_nodupDecidable___redArg(v___x_16_, v___x_18_);
if (v___x_19_ == 0)
{
lean_object* v___x_20_; 
lean_dec(v_corrections_15_);
v___x_20_ = lean_box(0);
return v___x_20_;
}
else
{
lean_object* v___x_21_; 
v___x_21_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_21_, 0, v_corrections_15_);
return v___x_21_;
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Core_EventCorrectionMemory_0__Loam_Core_EventCorrectionMemory_findCorrectionById_x3f(lean_object* v_x_22_, lean_object* v_x_23_){
_start:
{
if (lean_obj_tag(v_x_22_) == 0)
{
lean_object* v___x_24_; 
v___x_24_ = lean_box(0);
return v___x_24_;
}
else
{
lean_object* v_head_25_; lean_object* v_tail_26_; lean_object* v_id_27_; uint8_t v___x_28_; 
v_head_25_ = lean_ctor_get(v_x_22_, 0);
v_tail_26_ = lean_ctor_get(v_x_22_, 1);
v_id_27_ = lean_ctor_get(v_head_25_, 0);
v___x_28_ = lean_string_dec_eq(v_id_27_, v_x_23_);
if (v___x_28_ == 0)
{
v_x_22_ = v_tail_26_;
goto _start;
}
else
{
lean_object* v___x_30_; 
lean_inc(v_head_25_);
v___x_30_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_30_, 0, v_head_25_);
return v___x_30_;
}
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Core_EventCorrectionMemory_0__Loam_Core_EventCorrectionMemory_findCorrectionById_x3f___boxed(lean_object* v_x_31_, lean_object* v_x_32_){
_start:
{
lean_object* v_res_33_; 
v_res_33_ = lp_loam___private_Loam_Core_EventCorrectionMemory_0__Loam_Core_EventCorrectionMemory_findCorrectionById_x3f(v_x_31_, v_x_32_);
lean_dec_ref(v_x_32_);
lean_dec(v_x_31_);
return v_res_33_;
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Core_EventCorrectionMemory_0__Loam_Core_EventCorrectionMemory_findCorrectionById_x3f_match__1_splitter___redArg(lean_object* v_x_34_, lean_object* v_x_35_, lean_object* v_h__1_36_, lean_object* v_h__2_37_){
_start:
{
if (lean_obj_tag(v_x_34_) == 0)
{
lean_object* v___x_38_; 
lean_dec(v_h__2_37_);
v___x_38_ = lean_apply_1(v_h__1_36_, v_x_35_);
return v___x_38_;
}
else
{
lean_object* v_head_39_; lean_object* v_tail_40_; lean_object* v___x_41_; 
lean_dec(v_h__1_36_);
v_head_39_ = lean_ctor_get(v_x_34_, 0);
lean_inc(v_head_39_);
v_tail_40_ = lean_ctor_get(v_x_34_, 1);
lean_inc(v_tail_40_);
lean_dec_ref_known(v_x_34_, 2);
v___x_41_ = lean_apply_3(v_h__2_37_, v_head_39_, v_tail_40_, v_x_35_);
return v___x_41_;
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Core_EventCorrectionMemory_0__Loam_Core_EventCorrectionMemory_findCorrectionById_x3f_match__1_splitter(lean_object* v_motive_42_, lean_object* v_x_43_, lean_object* v_x_44_, lean_object* v_h__1_45_, lean_object* v_h__2_46_){
_start:
{
if (lean_obj_tag(v_x_43_) == 0)
{
lean_object* v___x_47_; 
lean_dec(v_h__2_46_);
v___x_47_ = lean_apply_1(v_h__1_45_, v_x_44_);
return v___x_47_;
}
else
{
lean_object* v_head_48_; lean_object* v_tail_49_; lean_object* v___x_50_; 
lean_dec(v_h__1_45_);
v_head_48_ = lean_ctor_get(v_x_43_, 0);
lean_inc(v_head_48_);
v_tail_49_ = lean_ctor_get(v_x_43_, 1);
lean_inc(v_tail_49_);
lean_dec_ref_known(v_x_43_, 2);
v___x_50_ = lean_apply_3(v_h__2_46_, v_head_48_, v_tail_49_, v_x_44_);
return v___x_50_;
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrectionMemory_findById_x3f(lean_object* v_memory_51_, lean_object* v_id_52_){
_start:
{
lean_object* v___x_53_; 
v___x_53_ = lp_loam___private_Loam_Core_EventCorrectionMemory_0__Loam_Core_EventCorrectionMemory_findCorrectionById_x3f(v_memory_51_, v_id_52_);
return v___x_53_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrectionMemory_findById_x3f___boxed(lean_object* v_memory_54_, lean_object* v_id_55_){
_start:
{
lean_object* v_res_56_; 
v_res_56_ = lp_loam_Loam_Core_EventCorrectionMemory_findById_x3f(v_memory_54_, v_id_55_);
lean_dec_ref(v_id_55_);
lean_dec(v_memory_54_);
return v_res_56_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrectionMemory_add_x3f(lean_object* v_memory_57_, lean_object* v_correction_58_){
_start:
{
lean_object* v___x_59_; lean_object* v___x_60_; lean_object* v___x_61_; lean_object* v___x_62_; 
v___x_59_ = lean_box(0);
v___x_60_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v___x_60_, 0, v_correction_58_);
lean_ctor_set(v___x_60_, 1, v___x_59_);
v___x_61_ = l_List_appendTR___redArg(v_memory_57_, v___x_60_);
v___x_62_ = lp_loam_Loam_Core_EventCorrectionMemory_ofCorrections_x3f(v___x_61_);
return v___x_62_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init_Data_List_Perm(uint8_t builtin);
lean_object* initialize_loam_Loam_Core_EventCorrection(uint8_t builtin);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_loam_Loam_Core_EventCorrectionMemory(uint8_t builtin) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_Init_Data_List_Perm(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_loam_Loam_Core_EventCorrection(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
