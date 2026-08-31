// Lean compiler output
// Module: Loam.Core.EventCorrection
// Imports: public import Init public meta import Init public import Loam.Core.EventMemory
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
lean_object* lean_nat_to_int(lean_object*);
lean_object* l_String_quote(lean_object*);
lean_object* lean_string_length(lean_object*);
lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg(lean_object*);
uint8_t lean_string_dec_eq(lean_object*, lean_object*);
lean_object* lp_loam___private_Loam_Core_EventMemory_0__Loam_Core_EventMemory_findEventById_x3f(lean_object*, lean_object*);
lean_object* l_List_reverse___redArg(lean_object*);
static const lean_string_object lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "{ "};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__0 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__0_value;
static const lean_string_object lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 6, .m_capacity = 6, .m_length = 5, .m_data = "token"};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__1 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__1_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__1_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__2 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__2_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__2_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__3 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__3_value;
static const lean_string_object lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 5, .m_capacity = 5, .m_length = 4, .m_data = " := "};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__4 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__4_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__4_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__5 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__5_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__3_value),((lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__5_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__6 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__6_value;
static lean_once_cell_t lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__7_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__7;
static const lean_string_object lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = " }"};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__8 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__8_value;
static lean_once_cell_t lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__9_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__9;
static lean_once_cell_t lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__10_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__10;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__0_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__11 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__11_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__8_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__12 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__12_value;
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_loam_Loam_Core_instReprEventCorrectionId___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_loam_Loam_Core_instReprEventCorrectionId_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_loam_Loam_Core_instReprEventCorrectionId___closed__0 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId___closed__0_value;
LEAN_EXPORT const lean_object* lp_loam_Loam_Core_instReprEventCorrectionId = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId___closed__0_value;
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEventCorrectionId_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEventCorrectionId_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEventCorrectionId(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEventCorrectionId___boxed(lean_object*, lean_object*);
static const lean_string_object lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "id"};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__0 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__0_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__0_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__1 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__1_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__1_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__2 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__2_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__2_value),((lean_object*)&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__5_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__3 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__3_value;
static lean_once_cell_t lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__4_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__4;
static const lean_string_object lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = ","};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__5 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__5_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__5_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__6 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__6_value;
static const lean_string_object lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "target"};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__7 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__7_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__7_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__8 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__8_value;
static lean_once_cell_t lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__9_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__9;
static const lean_string_object lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__10_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 12, .m_capacity = 12, .m_length = 11, .m_data = "replacement"};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__10 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__10_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__10_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__11 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__11_value;
static lean_once_cell_t lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__12_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__12;
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_loam_Loam_Core_instReprEventCorrection___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_loam_Loam_Core_instReprEventCorrection_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_loam_Loam_Core_instReprEventCorrection___closed__0 = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrection___closed__0_value;
LEAN_EXPORT const lean_object* lp_loam_Loam_Core_instReprEventCorrection = (const lean_object*)&lp_loam_Loam_Core_instReprEventCorrection___closed__0_value;
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEventCorrection_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEventCorrection_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEventCorrection(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEventCorrection___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_List_mapTR_loop___at___00Loam_Core_UnresolvedCorrection_candidateIds_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_UnresolvedCorrection_candidateIds(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_project_x3f(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_project_x3f___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_projectFromTip_x3f(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_projectFromTip_x3f___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_projectNext_x3f(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_projectNext_x3f___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_projectSiblingConflict_x3f(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_projectSiblingConflict_x3f___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
static lean_object* _init_lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__7(void){
_start:
{
lean_object* v___x_14_; lean_object* v___x_15_; 
v___x_14_ = lean_unsigned_to_nat(9u);
v___x_15_ = lean_nat_to_int(v___x_14_);
return v___x_15_;
}
}
static lean_object* _init_lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__9(void){
_start:
{
lean_object* v___x_17_; lean_object* v___x_18_; 
v___x_17_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__0));
v___x_18_ = lean_string_length(v___x_17_);
return v___x_18_;
}
}
static lean_object* _init_lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__10(void){
_start:
{
lean_object* v___x_19_; lean_object* v___x_20_; 
v___x_19_ = lean_obj_once(&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__9, &lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__9_once, _init_lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__9);
v___x_20_ = lean_nat_to_int(v___x_19_);
return v___x_20_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg(lean_object* v_x_25_){
_start:
{
lean_object* v___x_26_; lean_object* v___x_27_; lean_object* v___x_28_; lean_object* v___x_29_; lean_object* v___x_30_; uint8_t v___x_31_; lean_object* v___x_32_; lean_object* v___x_33_; lean_object* v___x_34_; lean_object* v___x_35_; lean_object* v___x_36_; lean_object* v___x_37_; lean_object* v___x_38_; lean_object* v___x_39_; lean_object* v___x_40_; 
v___x_26_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__6));
v___x_27_ = lean_obj_once(&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__7, &lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__7_once, _init_lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__7);
v___x_28_ = l_String_quote(v_x_25_);
v___x_29_ = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(v___x_29_, 0, v___x_28_);
v___x_30_ = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(v___x_30_, 0, v___x_27_);
lean_ctor_set(v___x_30_, 1, v___x_29_);
v___x_31_ = 0;
v___x_32_ = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(v___x_32_, 0, v___x_30_);
lean_ctor_set_uint8(v___x_32_, sizeof(void*)*1, v___x_31_);
v___x_33_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_33_, 0, v___x_26_);
lean_ctor_set(v___x_33_, 1, v___x_32_);
v___x_34_ = lean_obj_once(&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__10, &lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__10_once, _init_lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__10);
v___x_35_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__11));
v___x_36_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_36_, 0, v___x_35_);
lean_ctor_set(v___x_36_, 1, v___x_33_);
v___x_37_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__12));
v___x_38_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_38_, 0, v___x_36_);
lean_ctor_set(v___x_38_, 1, v___x_37_);
v___x_39_ = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(v___x_39_, 0, v___x_34_);
lean_ctor_set(v___x_39_, 1, v___x_38_);
v___x_40_ = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(v___x_40_, 0, v___x_39_);
lean_ctor_set_uint8(v___x_40_, sizeof(void*)*1, v___x_31_);
return v___x_40_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr(lean_object* v_x_41_, lean_object* v_prec_42_){
_start:
{
lean_object* v___x_43_; 
v___x_43_ = lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg(v_x_41_);
return v___x_43_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventCorrectionId_repr___boxed(lean_object* v_x_44_, lean_object* v_prec_45_){
_start:
{
lean_object* v_res_46_; 
v_res_46_ = lp_loam_Loam_Core_instReprEventCorrectionId_repr(v_x_44_, v_prec_45_);
lean_dec(v_prec_45_);
return v_res_46_;
}
}
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEventCorrectionId_decEq(lean_object* v_x_49_, lean_object* v_x_50_){
_start:
{
uint8_t v___x_51_; 
v___x_51_ = lean_string_dec_eq(v_x_49_, v_x_50_);
return v___x_51_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEventCorrectionId_decEq___boxed(lean_object* v_x_52_, lean_object* v_x_53_){
_start:
{
uint8_t v_res_54_; lean_object* v_r_55_; 
v_res_54_ = lp_loam_Loam_Core_instDecidableEqEventCorrectionId_decEq(v_x_52_, v_x_53_);
lean_dec_ref(v_x_53_);
lean_dec_ref(v_x_52_);
v_r_55_ = lean_box(v_res_54_);
return v_r_55_;
}
}
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEventCorrectionId(lean_object* v_x_56_, lean_object* v_x_57_){
_start:
{
uint8_t v___x_58_; 
v___x_58_ = lean_string_dec_eq(v_x_56_, v_x_57_);
return v___x_58_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEventCorrectionId___boxed(lean_object* v_x_59_, lean_object* v_x_60_){
_start:
{
uint8_t v_res_61_; lean_object* v_r_62_; 
v_res_61_ = lp_loam_Loam_Core_instDecidableEqEventCorrectionId(v_x_59_, v_x_60_);
lean_dec_ref(v_x_60_);
lean_dec_ref(v_x_59_);
v_r_62_ = lean_box(v_res_61_);
return v_r_62_;
}
}
static lean_object* _init_lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__4(void){
_start:
{
lean_object* v___x_72_; lean_object* v___x_73_; 
v___x_72_ = lean_unsigned_to_nat(6u);
v___x_73_ = lean_nat_to_int(v___x_72_);
return v___x_73_;
}
}
static lean_object* _init_lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__9(void){
_start:
{
lean_object* v___x_80_; lean_object* v___x_81_; 
v___x_80_ = lean_unsigned_to_nat(10u);
v___x_81_ = lean_nat_to_int(v___x_80_);
return v___x_81_;
}
}
static lean_object* _init_lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__12(void){
_start:
{
lean_object* v___x_85_; lean_object* v___x_86_; 
v___x_85_ = lean_unsigned_to_nat(15u);
v___x_86_ = lean_nat_to_int(v___x_85_);
return v___x_86_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___redArg(lean_object* v_x_87_){
_start:
{
lean_object* v_id_88_; lean_object* v_target_89_; lean_object* v_replacement_90_; lean_object* v___x_91_; lean_object* v___x_92_; lean_object* v___x_93_; lean_object* v___x_94_; lean_object* v___x_95_; uint8_t v___x_96_; lean_object* v___x_97_; lean_object* v___x_98_; lean_object* v___x_99_; lean_object* v___x_100_; lean_object* v___x_101_; lean_object* v___x_102_; lean_object* v___x_103_; lean_object* v___x_104_; lean_object* v___x_105_; lean_object* v___x_106_; lean_object* v___x_107_; lean_object* v___x_108_; lean_object* v___x_109_; lean_object* v___x_110_; lean_object* v___x_111_; lean_object* v___x_112_; lean_object* v___x_113_; lean_object* v___x_114_; lean_object* v___x_115_; lean_object* v___x_116_; lean_object* v___x_117_; lean_object* v___x_118_; lean_object* v___x_119_; lean_object* v___x_120_; lean_object* v___x_121_; lean_object* v___x_122_; lean_object* v___x_123_; lean_object* v___x_124_; lean_object* v___x_125_; lean_object* v___x_126_; lean_object* v___x_127_; 
v_id_88_ = lean_ctor_get(v_x_87_, 0);
lean_inc_ref(v_id_88_);
v_target_89_ = lean_ctor_get(v_x_87_, 1);
lean_inc_ref(v_target_89_);
v_replacement_90_ = lean_ctor_get(v_x_87_, 2);
lean_inc_ref(v_replacement_90_);
lean_dec_ref(v_x_87_);
v___x_91_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__5));
v___x_92_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__3));
v___x_93_ = lean_obj_once(&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__4, &lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__4_once, _init_lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__4);
v___x_94_ = lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg(v_id_88_);
v___x_95_ = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(v___x_95_, 0, v___x_93_);
lean_ctor_set(v___x_95_, 1, v___x_94_);
v___x_96_ = 0;
v___x_97_ = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(v___x_97_, 0, v___x_95_);
lean_ctor_set_uint8(v___x_97_, sizeof(void*)*1, v___x_96_);
v___x_98_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_98_, 0, v___x_92_);
lean_ctor_set(v___x_98_, 1, v___x_97_);
v___x_99_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__6));
v___x_100_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_100_, 0, v___x_98_);
lean_ctor_set(v___x_100_, 1, v___x_99_);
v___x_101_ = lean_box(1);
v___x_102_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_102_, 0, v___x_100_);
lean_ctor_set(v___x_102_, 1, v___x_101_);
v___x_103_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__8));
v___x_104_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_104_, 0, v___x_102_);
lean_ctor_set(v___x_104_, 1, v___x_103_);
v___x_105_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_105_, 0, v___x_104_);
lean_ctor_set(v___x_105_, 1, v___x_91_);
v___x_106_ = lean_obj_once(&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__9, &lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__9_once, _init_lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__9);
v___x_107_ = lp_loam_Loam_Core_instReprEventId_repr___redArg(v_target_89_);
v___x_108_ = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(v___x_108_, 0, v___x_106_);
lean_ctor_set(v___x_108_, 1, v___x_107_);
v___x_109_ = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(v___x_109_, 0, v___x_108_);
lean_ctor_set_uint8(v___x_109_, sizeof(void*)*1, v___x_96_);
v___x_110_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_110_, 0, v___x_105_);
lean_ctor_set(v___x_110_, 1, v___x_109_);
v___x_111_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_111_, 0, v___x_110_);
lean_ctor_set(v___x_111_, 1, v___x_99_);
v___x_112_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_112_, 0, v___x_111_);
lean_ctor_set(v___x_112_, 1, v___x_101_);
v___x_113_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__11));
v___x_114_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_114_, 0, v___x_112_);
lean_ctor_set(v___x_114_, 1, v___x_113_);
v___x_115_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_115_, 0, v___x_114_);
lean_ctor_set(v___x_115_, 1, v___x_91_);
v___x_116_ = lean_obj_once(&lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__12, &lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__12_once, _init_lp_loam_Loam_Core_instReprEventCorrection_repr___redArg___closed__12);
v___x_117_ = lp_loam_Loam_Core_instReprEventId_repr___redArg(v_replacement_90_);
v___x_118_ = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(v___x_118_, 0, v___x_116_);
lean_ctor_set(v___x_118_, 1, v___x_117_);
v___x_119_ = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(v___x_119_, 0, v___x_118_);
lean_ctor_set_uint8(v___x_119_, sizeof(void*)*1, v___x_96_);
v___x_120_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_120_, 0, v___x_115_);
lean_ctor_set(v___x_120_, 1, v___x_119_);
v___x_121_ = lean_obj_once(&lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__10, &lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__10_once, _init_lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__10);
v___x_122_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__11));
v___x_123_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_123_, 0, v___x_122_);
lean_ctor_set(v___x_123_, 1, v___x_120_);
v___x_124_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventCorrectionId_repr___redArg___closed__12));
v___x_125_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_125_, 0, v___x_123_);
lean_ctor_set(v___x_125_, 1, v___x_124_);
v___x_126_ = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(v___x_126_, 0, v___x_121_);
lean_ctor_set(v___x_126_, 1, v___x_125_);
v___x_127_ = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(v___x_127_, 0, v___x_126_);
lean_ctor_set_uint8(v___x_127_, sizeof(void*)*1, v___x_96_);
return v___x_127_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr(lean_object* v_x_128_, lean_object* v_prec_129_){
_start:
{
lean_object* v___x_130_; 
v___x_130_ = lp_loam_Loam_Core_instReprEventCorrection_repr___redArg(v_x_128_);
return v___x_130_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventCorrection_repr___boxed(lean_object* v_x_131_, lean_object* v_prec_132_){
_start:
{
lean_object* v_res_133_; 
v_res_133_ = lp_loam_Loam_Core_instReprEventCorrection_repr(v_x_131_, v_prec_132_);
lean_dec(v_prec_132_);
return v_res_133_;
}
}
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEventCorrection_decEq(lean_object* v_x_136_, lean_object* v_x_137_){
_start:
{
lean_object* v_id_138_; lean_object* v_target_139_; lean_object* v_replacement_140_; lean_object* v_id_141_; lean_object* v_target_142_; lean_object* v_replacement_143_; uint8_t v___x_144_; 
v_id_138_ = lean_ctor_get(v_x_136_, 0);
v_target_139_ = lean_ctor_get(v_x_136_, 1);
v_replacement_140_ = lean_ctor_get(v_x_136_, 2);
v_id_141_ = lean_ctor_get(v_x_137_, 0);
v_target_142_ = lean_ctor_get(v_x_137_, 1);
v_replacement_143_ = lean_ctor_get(v_x_137_, 2);
v___x_144_ = lean_string_dec_eq(v_id_138_, v_id_141_);
if (v___x_144_ == 0)
{
return v___x_144_;
}
else
{
uint8_t v___x_145_; 
v___x_145_ = lean_string_dec_eq(v_target_139_, v_target_142_);
if (v___x_145_ == 0)
{
return v___x_145_;
}
else
{
uint8_t v___x_146_; 
v___x_146_ = lean_string_dec_eq(v_replacement_140_, v_replacement_143_);
return v___x_146_;
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEventCorrection_decEq___boxed(lean_object* v_x_147_, lean_object* v_x_148_){
_start:
{
uint8_t v_res_149_; lean_object* v_r_150_; 
v_res_149_ = lp_loam_Loam_Core_instDecidableEqEventCorrection_decEq(v_x_147_, v_x_148_);
lean_dec_ref(v_x_148_);
lean_dec_ref(v_x_147_);
v_r_150_ = lean_box(v_res_149_);
return v_r_150_;
}
}
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEventCorrection(lean_object* v_x_151_, lean_object* v_x_152_){
_start:
{
uint8_t v___x_153_; 
v___x_153_ = lp_loam_Loam_Core_instDecidableEqEventCorrection_decEq(v_x_151_, v_x_152_);
return v___x_153_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEventCorrection___boxed(lean_object* v_x_154_, lean_object* v_x_155_){
_start:
{
uint8_t v_res_156_; lean_object* v_r_157_; 
v_res_156_ = lp_loam_Loam_Core_instDecidableEqEventCorrection(v_x_154_, v_x_155_);
lean_dec_ref(v_x_155_);
lean_dec_ref(v_x_154_);
v_r_157_ = lean_box(v_res_156_);
return v_r_157_;
}
}
LEAN_EXPORT lean_object* lp_loam_List_mapTR_loop___at___00Loam_Core_UnresolvedCorrection_candidateIds_spec__0(lean_object* v_a_158_, lean_object* v_a_159_){
_start:
{
if (lean_obj_tag(v_a_158_) == 0)
{
lean_object* v___x_160_; 
v___x_160_ = l_List_reverse___redArg(v_a_159_);
return v___x_160_;
}
else
{
lean_object* v_head_161_; lean_object* v_tail_162_; lean_object* v___x_164_; uint8_t v_isShared_165_; uint8_t v_isSharedCheck_171_; 
v_head_161_ = lean_ctor_get(v_a_158_, 0);
v_tail_162_ = lean_ctor_get(v_a_158_, 1);
v_isSharedCheck_171_ = !lean_is_exclusive(v_a_158_);
if (v_isSharedCheck_171_ == 0)
{
v___x_164_ = v_a_158_;
v_isShared_165_ = v_isSharedCheck_171_;
goto v_resetjp_163_;
}
else
{
lean_inc(v_tail_162_);
lean_inc(v_head_161_);
lean_dec(v_a_158_);
v___x_164_ = lean_box(0);
v_isShared_165_ = v_isSharedCheck_171_;
goto v_resetjp_163_;
}
v_resetjp_163_:
{
lean_object* v_replacement_166_; lean_object* v___x_168_; 
v_replacement_166_ = lean_ctor_get(v_head_161_, 2);
lean_inc_ref(v_replacement_166_);
lean_dec(v_head_161_);
if (v_isShared_165_ == 0)
{
lean_ctor_set(v___x_164_, 1, v_a_159_);
lean_ctor_set(v___x_164_, 0, v_replacement_166_);
v___x_168_ = v___x_164_;
goto v_reusejp_167_;
}
else
{
lean_object* v_reuseFailAlloc_170_; 
v_reuseFailAlloc_170_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_170_, 0, v_replacement_166_);
lean_ctor_set(v_reuseFailAlloc_170_, 1, v_a_159_);
v___x_168_ = v_reuseFailAlloc_170_;
goto v_reusejp_167_;
}
v_reusejp_167_:
{
v_a_158_ = v_tail_162_;
v_a_159_ = v___x_168_;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_UnresolvedCorrection_candidateIds(lean_object* v_conflict_172_){
_start:
{
lean_object* v_branches_173_; lean_object* v___x_174_; lean_object* v___x_175_; 
v_branches_173_ = lean_ctor_get(v_conflict_172_, 1);
lean_inc(v_branches_173_);
lean_dec_ref(v_conflict_172_);
v___x_174_ = lean_box(0);
v___x_175_ = lp_loam_List_mapTR_loop___at___00Loam_Core_UnresolvedCorrection_candidateIds_spec__0(v_branches_173_, v___x_174_);
return v___x_175_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_project_x3f(lean_object* v_memory_176_, lean_object* v_correction_177_){
_start:
{
lean_object* v_target_178_; lean_object* v_replacement_179_; lean_object* v___x_180_; 
v_target_178_ = lean_ctor_get(v_correction_177_, 1);
v_replacement_179_ = lean_ctor_get(v_correction_177_, 2);
v___x_180_ = lp_loam___private_Loam_Core_EventMemory_0__Loam_Core_EventMemory_findEventById_x3f(v_memory_176_, v_target_178_);
if (lean_obj_tag(v___x_180_) == 0)
{
lean_object* v___x_181_; 
lean_dec_ref(v_correction_177_);
v___x_181_ = lean_box(0);
return v___x_181_;
}
else
{
lean_object* v_val_182_; lean_object* v___x_183_; 
v_val_182_ = lean_ctor_get(v___x_180_, 0);
lean_inc(v_val_182_);
lean_dec_ref_known(v___x_180_, 1);
v___x_183_ = lp_loam___private_Loam_Core_EventMemory_0__Loam_Core_EventMemory_findEventById_x3f(v_memory_176_, v_replacement_179_);
if (lean_obj_tag(v___x_183_) == 0)
{
lean_object* v___x_184_; 
lean_dec(v_val_182_);
lean_dec_ref(v_correction_177_);
v___x_184_ = lean_box(0);
return v___x_184_;
}
else
{
lean_object* v_val_185_; lean_object* v___x_187_; uint8_t v_isShared_188_; uint8_t v_isSharedCheck_193_; 
v_val_185_ = lean_ctor_get(v___x_183_, 0);
v_isSharedCheck_193_ = !lean_is_exclusive(v___x_183_);
if (v_isSharedCheck_193_ == 0)
{
v___x_187_ = v___x_183_;
v_isShared_188_ = v_isSharedCheck_193_;
goto v_resetjp_186_;
}
else
{
lean_inc(v_val_185_);
lean_dec(v___x_183_);
v___x_187_ = lean_box(0);
v_isShared_188_ = v_isSharedCheck_193_;
goto v_resetjp_186_;
}
v_resetjp_186_:
{
lean_object* v___x_189_; lean_object* v___x_191_; 
v___x_189_ = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(v___x_189_, 0, v_correction_177_);
lean_ctor_set(v___x_189_, 1, v_val_182_);
lean_ctor_set(v___x_189_, 2, v_val_185_);
if (v_isShared_188_ == 0)
{
lean_ctor_set(v___x_187_, 0, v___x_189_);
v___x_191_ = v___x_187_;
goto v_reusejp_190_;
}
else
{
lean_object* v_reuseFailAlloc_192_; 
v_reuseFailAlloc_192_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_192_, 0, v___x_189_);
v___x_191_ = v_reuseFailAlloc_192_;
goto v_reusejp_190_;
}
v_reusejp_190_:
{
return v___x_191_;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_project_x3f___boxed(lean_object* v_memory_194_, lean_object* v_correction_195_){
_start:
{
lean_object* v_res_196_; 
v_res_196_ = lp_loam_Loam_Core_EventCorrection_project_x3f(v_memory_194_, v_correction_195_);
lean_dec(v_memory_194_);
return v_res_196_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_projectFromTip_x3f(lean_object* v_memory_197_, lean_object* v_tip_198_, lean_object* v_correction_199_){
_start:
{
lean_object* v_target_200_; uint8_t v___x_201_; 
v_target_200_ = lean_ctor_get(v_correction_199_, 1);
v___x_201_ = lean_string_dec_eq(v_target_200_, v_tip_198_);
if (v___x_201_ == 0)
{
lean_object* v___x_202_; 
lean_dec_ref(v_correction_199_);
v___x_202_ = lean_box(0);
return v___x_202_;
}
else
{
lean_object* v___x_203_; 
v___x_203_ = lp_loam_Loam_Core_EventCorrection_project_x3f(v_memory_197_, v_correction_199_);
return v___x_203_;
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_projectFromTip_x3f___boxed(lean_object* v_memory_204_, lean_object* v_tip_205_, lean_object* v_correction_206_){
_start:
{
lean_object* v_res_207_; 
v_res_207_ = lp_loam_Loam_Core_EventCorrection_projectFromTip_x3f(v_memory_204_, v_tip_205_, v_correction_206_);
lean_dec_ref(v_tip_205_);
lean_dec(v_memory_204_);
return v_res_207_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_projectNext_x3f(lean_object* v_memory_208_, lean_object* v_current_209_, lean_object* v_next_210_){
_start:
{
lean_object* v_effective_211_; lean_object* v_id_212_; lean_object* v___x_213_; 
v_effective_211_ = lean_ctor_get(v_current_209_, 2);
v_id_212_ = lean_ctor_get(v_effective_211_, 0);
v___x_213_ = lp_loam_Loam_Core_EventCorrection_projectFromTip_x3f(v_memory_208_, v_id_212_, v_next_210_);
return v___x_213_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_projectNext_x3f___boxed(lean_object* v_memory_214_, lean_object* v_current_215_, lean_object* v_next_216_){
_start:
{
lean_object* v_res_217_; 
v_res_217_ = lp_loam_Loam_Core_EventCorrection_projectNext_x3f(v_memory_214_, v_current_215_, v_next_216_);
lean_dec_ref(v_current_215_);
lean_dec(v_memory_214_);
return v_res_217_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_projectSiblingConflict_x3f(lean_object* v_memory_218_, lean_object* v_tip_219_, lean_object* v_left_220_, lean_object* v_right_221_){
_start:
{
lean_object* v_id_222_; lean_object* v_target_223_; lean_object* v_replacement_224_; uint8_t v___x_225_; 
v_id_222_ = lean_ctor_get(v_left_220_, 0);
v_target_223_ = lean_ctor_get(v_left_220_, 1);
v_replacement_224_ = lean_ctor_get(v_left_220_, 2);
v___x_225_ = lean_string_dec_eq(v_target_223_, v_tip_219_);
if (v___x_225_ == 0)
{
lean_object* v___x_226_; 
lean_dec_ref(v_right_221_);
lean_dec_ref(v_left_220_);
lean_dec_ref(v_tip_219_);
v___x_226_ = lean_box(0);
return v___x_226_;
}
else
{
lean_object* v_id_227_; lean_object* v_target_228_; lean_object* v_replacement_229_; uint8_t v___x_230_; 
v_id_227_ = lean_ctor_get(v_right_221_, 0);
v_target_228_ = lean_ctor_get(v_right_221_, 1);
v_replacement_229_ = lean_ctor_get(v_right_221_, 2);
v___x_230_ = lean_string_dec_eq(v_target_228_, v_tip_219_);
if (v___x_230_ == 0)
{
lean_object* v___x_231_; 
lean_dec_ref(v_right_221_);
lean_dec_ref(v_left_220_);
lean_dec_ref(v_tip_219_);
v___x_231_ = lean_box(0);
return v___x_231_;
}
else
{
uint8_t v___x_232_; 
v___x_232_ = lean_string_dec_eq(v_id_222_, v_id_227_);
if (v___x_232_ == 0)
{
if (v___x_230_ == 0)
{
lean_object* v___x_233_; 
lean_dec_ref(v_right_221_);
lean_dec_ref(v_left_220_);
lean_dec_ref(v_tip_219_);
v___x_233_ = lean_box(0);
return v___x_233_;
}
else
{
uint8_t v___x_234_; 
v___x_234_ = lean_string_dec_eq(v_replacement_224_, v_replacement_229_);
if (v___x_234_ == 0)
{
lean_object* v___x_235_; 
lean_inc_ref(v_left_220_);
v___x_235_ = lp_loam_Loam_Core_EventCorrection_project_x3f(v_memory_218_, v_left_220_);
if (lean_obj_tag(v___x_235_) == 1)
{
lean_object* v___x_236_; 
lean_dec_ref_known(v___x_235_, 1);
lean_inc_ref(v_right_221_);
v___x_236_ = lp_loam_Loam_Core_EventCorrection_project_x3f(v_memory_218_, v_right_221_);
if (lean_obj_tag(v___x_236_) == 1)
{
lean_object* v___x_238_; uint8_t v_isShared_239_; uint8_t v_isSharedCheck_247_; 
v_isSharedCheck_247_ = !lean_is_exclusive(v___x_236_);
if (v_isSharedCheck_247_ == 0)
{
lean_object* v_unused_248_; 
v_unused_248_ = lean_ctor_get(v___x_236_, 0);
lean_dec(v_unused_248_);
v___x_238_ = v___x_236_;
v_isShared_239_ = v_isSharedCheck_247_;
goto v_resetjp_237_;
}
else
{
lean_dec(v___x_236_);
v___x_238_ = lean_box(0);
v_isShared_239_ = v_isSharedCheck_247_;
goto v_resetjp_237_;
}
v_resetjp_237_:
{
lean_object* v___x_240_; lean_object* v___x_241_; lean_object* v___x_242_; lean_object* v___x_243_; lean_object* v___x_245_; 
v___x_240_ = lean_box(0);
v___x_241_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v___x_241_, 0, v_right_221_);
lean_ctor_set(v___x_241_, 1, v___x_240_);
v___x_242_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v___x_242_, 0, v_left_220_);
lean_ctor_set(v___x_242_, 1, v___x_241_);
v___x_243_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v___x_243_, 0, v_tip_219_);
lean_ctor_set(v___x_243_, 1, v___x_242_);
if (v_isShared_239_ == 0)
{
lean_ctor_set(v___x_238_, 0, v___x_243_);
v___x_245_ = v___x_238_;
goto v_reusejp_244_;
}
else
{
lean_object* v_reuseFailAlloc_246_; 
v_reuseFailAlloc_246_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_246_, 0, v___x_243_);
v___x_245_ = v_reuseFailAlloc_246_;
goto v_reusejp_244_;
}
v_reusejp_244_:
{
return v___x_245_;
}
}
}
else
{
lean_object* v___x_249_; 
lean_dec(v___x_236_);
lean_dec_ref(v_right_221_);
lean_dec_ref(v_left_220_);
lean_dec_ref(v_tip_219_);
v___x_249_ = lean_box(0);
return v___x_249_;
}
}
else
{
lean_object* v___x_250_; 
lean_dec(v___x_235_);
lean_dec_ref(v_right_221_);
lean_dec_ref(v_left_220_);
lean_dec_ref(v_tip_219_);
v___x_250_ = lean_box(0);
return v___x_250_;
}
}
else
{
lean_object* v___x_251_; 
lean_dec_ref(v_right_221_);
lean_dec_ref(v_left_220_);
lean_dec_ref(v_tip_219_);
v___x_251_ = lean_box(0);
return v___x_251_;
}
}
}
else
{
lean_object* v___x_252_; 
lean_dec_ref(v_right_221_);
lean_dec_ref(v_left_220_);
lean_dec_ref(v_tip_219_);
v___x_252_ = lean_box(0);
return v___x_252_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_EventCorrection_projectSiblingConflict_x3f___boxed(lean_object* v_memory_253_, lean_object* v_tip_254_, lean_object* v_left_255_, lean_object* v_right_256_){
_start:
{
lean_object* v_res_257_; 
v_res_257_ = lp_loam_Loam_Core_EventCorrection_projectSiblingConflict_x3f(v_memory_253_, v_tip_254_, v_left_255_, v_right_256_);
lean_dec(v_memory_253_);
return v_res_257_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_loam_Loam_Core_EventMemory(uint8_t builtin);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_loam_Loam_Core_EventCorrection(uint8_t builtin) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_loam_Loam_Core_EventMemory(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
