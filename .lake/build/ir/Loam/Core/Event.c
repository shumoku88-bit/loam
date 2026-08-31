// Lean compiler output
// Module: Loam.Core.Event
// Imports: public import Init public meta import Init public import Loam.Core.Effect
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
lean_object* lean_string_length(lean_object*);
lean_object* lean_nat_to_int(lean_object*);
lean_object* l_String_quote(lean_object*);
uint8_t lean_string_dec_eq(lean_object*, lean_object*);
lean_object* lp_loam_Loam_Core_Effect_measure(lean_object*);
lean_object* lean_array_mk(lean_object*);
lean_object* lean_array_get_size(lean_object*);
uint8_t lean_nat_dec_lt(lean_object*, lean_object*);
size_t lean_usize_of_nat(lean_object*);
uint8_t lean_usize_dec_eq(size_t, size_t);
size_t lean_usize_sub(size_t, size_t);
lean_object* lean_array_uget_borrowed(lean_object*, size_t);
lean_object* lp_loam_Loam_Core_Effect_quantity(lean_object*);
lean_object* lean_int_add(lean_object*, lean_object*);
lean_object* lp_loam_Loam_Core_instReprLocusId_repr___redArg(lean_object*);
lean_object* lp_loam_Loam_Core_instReprMeasureId_repr___redArg(lean_object*);
lean_object* l_List_reverse___redArg(lean_object*);
lean_object* lp_loam_Loam_Core_instDecidableEqEffectKey___boxed(lean_object*, lean_object*);
uint8_t l_List_nodupDecidable___redArg(lean_object*, lean_object*);
static const lean_string_object lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "{ "};
static const lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__0 = (const lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__0_value;
static const lean_string_object lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 6, .m_capacity = 6, .m_length = 5, .m_data = "token"};
static const lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__1 = (const lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__1_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__1_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__2 = (const lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__2_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__2_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__3 = (const lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__3_value;
static const lean_string_object lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 5, .m_capacity = 5, .m_length = 4, .m_data = " := "};
static const lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__4 = (const lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__4_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__4_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__5 = (const lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__5_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__3_value),((lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__5_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__6 = (const lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__6_value;
static lean_once_cell_t lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__7_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__7;
static const lean_string_object lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = " }"};
static const lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__8 = (const lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__8_value;
static lean_once_cell_t lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__9_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__9;
static lean_once_cell_t lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__10_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__10;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__0_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__11 = (const lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__11_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__8_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__12 = (const lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__12_value;
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventId_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventId_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_loam_Loam_Core_instReprEventId___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_loam_Loam_Core_instReprEventId_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_loam_Loam_Core_instReprEventId___closed__0 = (const lean_object*)&lp_loam_Loam_Core_instReprEventId___closed__0_value;
LEAN_EXPORT const lean_object* lp_loam_Loam_Core_instReprEventId = (const lean_object*)&lp_loam_Loam_Core_instReprEventId___closed__0_value;
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEventId_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEventId_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEventId(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEventId___boxed(lean_object*, lean_object*);
static const lean_string_object lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 6, .m_capacity = 6, .m_length = 5, .m_data = "locus"};
static const lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__0 = (const lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__0_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__0_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__1 = (const lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__1_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__1_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__2 = (const lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__2_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__2_value),((lean_object*)&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__5_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__3 = (const lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__3_value;
static const lean_string_object lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = ","};
static const lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__4 = (const lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__4_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__4_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__5 = (const lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__5_value;
static const lean_string_object lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "measure"};
static const lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__6 = (const lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__6_value;
static const lean_ctor_object lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__6_value)}};
static const lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__7 = (const lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__7_value;
static lean_once_cell_t lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__8_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__8;
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_loam_Loam_Core_instReprEffectCoordinate___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_loam_Loam_Core_instReprEffectCoordinate_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_loam_Loam_Core_instReprEffectCoordinate___closed__0 = (const lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate___closed__0_value;
LEAN_EXPORT const lean_object* lp_loam_Loam_Core_instReprEffectCoordinate = (const lean_object*)&lp_loam_Loam_Core_instReprEffectCoordinate___closed__0_value;
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEffectCoordinate_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEffectCoordinate_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEffectCoordinate(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEffectCoordinate___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_Effect_coordinate(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_Effect_coordinate___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_loam_List_mapTR_loop___at___00Loam_Core_Event_ofEffects_x3f_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Core_Event_ofEffects_x3f(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00List_foldrTR___at___00Loam_Core_Event_quantityAt_spec__0_spec__0(lean_object*, lean_object*, lean_object*, size_t, size_t, lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00List_foldrTR___at___00Loam_Core_Event_quantityAt_spec__0_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_List_foldrTR___at___00Loam_Core_Event_quantityAt_spec__0(lean_object*, lean_object*, lean_object*, lean_object*);
static lean_once_cell_t lp_loam_Loam_Core_Event_quantityAt___closed__0_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam_Loam_Core_Event_quantityAt___closed__0;
LEAN_EXPORT lean_object* lp_loam_Loam_Core_Event_quantityAt(lean_object*, lean_object*, lean_object*);
static lean_object* _init_lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__7(void){
_start:
{
lean_object* v___x_14_; lean_object* v___x_15_; 
v___x_14_ = lean_unsigned_to_nat(9u);
v___x_15_ = lean_nat_to_int(v___x_14_);
return v___x_15_;
}
}
static lean_object* _init_lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__9(void){
_start:
{
lean_object* v___x_17_; lean_object* v___x_18_; 
v___x_17_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__0));
v___x_18_ = lean_string_length(v___x_17_);
return v___x_18_;
}
}
static lean_object* _init_lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__10(void){
_start:
{
lean_object* v___x_19_; lean_object* v___x_20_; 
v___x_19_ = lean_obj_once(&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__9, &lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__9_once, _init_lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__9);
v___x_20_ = lean_nat_to_int(v___x_19_);
return v___x_20_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventId_repr___redArg(lean_object* v_x_25_){
_start:
{
lean_object* v___x_26_; lean_object* v___x_27_; lean_object* v___x_28_; lean_object* v___x_29_; lean_object* v___x_30_; uint8_t v___x_31_; lean_object* v___x_32_; lean_object* v___x_33_; lean_object* v___x_34_; lean_object* v___x_35_; lean_object* v___x_36_; lean_object* v___x_37_; lean_object* v___x_38_; lean_object* v___x_39_; lean_object* v___x_40_; 
v___x_26_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__6));
v___x_27_ = lean_obj_once(&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__7, &lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__7_once, _init_lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__7);
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
v___x_34_ = lean_obj_once(&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__10, &lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__10_once, _init_lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__10);
v___x_35_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__11));
v___x_36_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_36_, 0, v___x_35_);
lean_ctor_set(v___x_36_, 1, v___x_33_);
v___x_37_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__12));
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
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventId_repr(lean_object* v_x_41_, lean_object* v_prec_42_){
_start:
{
lean_object* v___x_43_; 
v___x_43_ = lp_loam_Loam_Core_instReprEventId_repr___redArg(v_x_41_);
return v___x_43_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEventId_repr___boxed(lean_object* v_x_44_, lean_object* v_prec_45_){
_start:
{
lean_object* v_res_46_; 
v_res_46_ = lp_loam_Loam_Core_instReprEventId_repr(v_x_44_, v_prec_45_);
lean_dec(v_prec_45_);
return v_res_46_;
}
}
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEventId_decEq(lean_object* v_x_49_, lean_object* v_x_50_){
_start:
{
uint8_t v___x_51_; 
v___x_51_ = lean_string_dec_eq(v_x_49_, v_x_50_);
return v___x_51_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEventId_decEq___boxed(lean_object* v_x_52_, lean_object* v_x_53_){
_start:
{
uint8_t v_res_54_; lean_object* v_r_55_; 
v_res_54_ = lp_loam_Loam_Core_instDecidableEqEventId_decEq(v_x_52_, v_x_53_);
lean_dec_ref(v_x_53_);
lean_dec_ref(v_x_52_);
v_r_55_ = lean_box(v_res_54_);
return v_r_55_;
}
}
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEventId(lean_object* v_x_56_, lean_object* v_x_57_){
_start:
{
uint8_t v___x_58_; 
v___x_58_ = lean_string_dec_eq(v_x_56_, v_x_57_);
return v___x_58_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEventId___boxed(lean_object* v_x_59_, lean_object* v_x_60_){
_start:
{
uint8_t v_res_61_; lean_object* v_r_62_; 
v_res_61_ = lp_loam_Loam_Core_instDecidableEqEventId(v_x_59_, v_x_60_);
lean_dec_ref(v_x_60_);
lean_dec_ref(v_x_59_);
v_r_62_ = lean_box(v_res_61_);
return v_r_62_;
}
}
static lean_object* _init_lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__8(void){
_start:
{
lean_object* v___x_78_; lean_object* v___x_79_; 
v___x_78_ = lean_unsigned_to_nat(11u);
v___x_79_ = lean_nat_to_int(v___x_78_);
return v___x_79_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg(lean_object* v_x_80_){
_start:
{
lean_object* v_locus_81_; lean_object* v_measure_82_; lean_object* v___x_84_; uint8_t v_isShared_85_; uint8_t v_isSharedCheck_115_; 
v_locus_81_ = lean_ctor_get(v_x_80_, 0);
v_measure_82_ = lean_ctor_get(v_x_80_, 1);
v_isSharedCheck_115_ = !lean_is_exclusive(v_x_80_);
if (v_isSharedCheck_115_ == 0)
{
v___x_84_ = v_x_80_;
v_isShared_85_ = v_isSharedCheck_115_;
goto v_resetjp_83_;
}
else
{
lean_inc(v_measure_82_);
lean_inc(v_locus_81_);
lean_dec(v_x_80_);
v___x_84_ = lean_box(0);
v_isShared_85_ = v_isSharedCheck_115_;
goto v_resetjp_83_;
}
v_resetjp_83_:
{
lean_object* v___x_86_; lean_object* v___x_87_; lean_object* v___x_88_; lean_object* v___x_89_; lean_object* v___x_91_; 
v___x_86_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__5));
v___x_87_ = ((lean_object*)(lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__3));
v___x_88_ = lean_obj_once(&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__7, &lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__7_once, _init_lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__7);
v___x_89_ = lp_loam_Loam_Core_instReprLocusId_repr___redArg(v_locus_81_);
if (v_isShared_85_ == 0)
{
lean_ctor_set_tag(v___x_84_, 4);
lean_ctor_set(v___x_84_, 1, v___x_89_);
lean_ctor_set(v___x_84_, 0, v___x_88_);
v___x_91_ = v___x_84_;
goto v_reusejp_90_;
}
else
{
lean_object* v_reuseFailAlloc_114_; 
v_reuseFailAlloc_114_ = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(v_reuseFailAlloc_114_, 0, v___x_88_);
lean_ctor_set(v_reuseFailAlloc_114_, 1, v___x_89_);
v___x_91_ = v_reuseFailAlloc_114_;
goto v_reusejp_90_;
}
v_reusejp_90_:
{
uint8_t v___x_92_; lean_object* v___x_93_; lean_object* v___x_94_; lean_object* v___x_95_; lean_object* v___x_96_; lean_object* v___x_97_; lean_object* v___x_98_; lean_object* v___x_99_; lean_object* v___x_100_; lean_object* v___x_101_; lean_object* v___x_102_; lean_object* v___x_103_; lean_object* v___x_104_; lean_object* v___x_105_; lean_object* v___x_106_; lean_object* v___x_107_; lean_object* v___x_108_; lean_object* v___x_109_; lean_object* v___x_110_; lean_object* v___x_111_; lean_object* v___x_112_; lean_object* v___x_113_; 
v___x_92_ = 0;
v___x_93_ = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(v___x_93_, 0, v___x_91_);
lean_ctor_set_uint8(v___x_93_, sizeof(void*)*1, v___x_92_);
v___x_94_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_94_, 0, v___x_87_);
lean_ctor_set(v___x_94_, 1, v___x_93_);
v___x_95_ = ((lean_object*)(lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__5));
v___x_96_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_96_, 0, v___x_94_);
lean_ctor_set(v___x_96_, 1, v___x_95_);
v___x_97_ = lean_box(1);
v___x_98_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_98_, 0, v___x_96_);
lean_ctor_set(v___x_98_, 1, v___x_97_);
v___x_99_ = ((lean_object*)(lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__7));
v___x_100_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_100_, 0, v___x_98_);
lean_ctor_set(v___x_100_, 1, v___x_99_);
v___x_101_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_101_, 0, v___x_100_);
lean_ctor_set(v___x_101_, 1, v___x_86_);
v___x_102_ = lean_obj_once(&lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__8, &lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__8_once, _init_lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg___closed__8);
v___x_103_ = lp_loam_Loam_Core_instReprMeasureId_repr___redArg(v_measure_82_);
v___x_104_ = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(v___x_104_, 0, v___x_102_);
lean_ctor_set(v___x_104_, 1, v___x_103_);
v___x_105_ = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(v___x_105_, 0, v___x_104_);
lean_ctor_set_uint8(v___x_105_, sizeof(void*)*1, v___x_92_);
v___x_106_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_106_, 0, v___x_101_);
lean_ctor_set(v___x_106_, 1, v___x_105_);
v___x_107_ = lean_obj_once(&lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__10, &lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__10_once, _init_lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__10);
v___x_108_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__11));
v___x_109_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_109_, 0, v___x_108_);
lean_ctor_set(v___x_109_, 1, v___x_106_);
v___x_110_ = ((lean_object*)(lp_loam_Loam_Core_instReprEventId_repr___redArg___closed__12));
v___x_111_ = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(v___x_111_, 0, v___x_109_);
lean_ctor_set(v___x_111_, 1, v___x_110_);
v___x_112_ = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(v___x_112_, 0, v___x_107_);
lean_ctor_set(v___x_112_, 1, v___x_111_);
v___x_113_ = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(v___x_113_, 0, v___x_112_);
lean_ctor_set_uint8(v___x_113_, sizeof(void*)*1, v___x_92_);
return v___x_113_;
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr(lean_object* v_x_116_, lean_object* v_prec_117_){
_start:
{
lean_object* v___x_118_; 
v___x_118_ = lp_loam_Loam_Core_instReprEffectCoordinate_repr___redArg(v_x_116_);
return v___x_118_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instReprEffectCoordinate_repr___boxed(lean_object* v_x_119_, lean_object* v_prec_120_){
_start:
{
lean_object* v_res_121_; 
v_res_121_ = lp_loam_Loam_Core_instReprEffectCoordinate_repr(v_x_119_, v_prec_120_);
lean_dec(v_prec_120_);
return v_res_121_;
}
}
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEffectCoordinate_decEq(lean_object* v_x_124_, lean_object* v_x_125_){
_start:
{
lean_object* v_locus_126_; lean_object* v_measure_127_; lean_object* v_locus_128_; lean_object* v_measure_129_; uint8_t v___x_130_; 
v_locus_126_ = lean_ctor_get(v_x_124_, 0);
v_measure_127_ = lean_ctor_get(v_x_124_, 1);
v_locus_128_ = lean_ctor_get(v_x_125_, 0);
v_measure_129_ = lean_ctor_get(v_x_125_, 1);
v___x_130_ = lean_string_dec_eq(v_locus_126_, v_locus_128_);
if (v___x_130_ == 0)
{
return v___x_130_;
}
else
{
uint8_t v___x_131_; 
v___x_131_ = lean_string_dec_eq(v_measure_127_, v_measure_129_);
return v___x_131_;
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEffectCoordinate_decEq___boxed(lean_object* v_x_132_, lean_object* v_x_133_){
_start:
{
uint8_t v_res_134_; lean_object* v_r_135_; 
v_res_134_ = lp_loam_Loam_Core_instDecidableEqEffectCoordinate_decEq(v_x_132_, v_x_133_);
lean_dec_ref(v_x_133_);
lean_dec_ref(v_x_132_);
v_r_135_ = lean_box(v_res_134_);
return v_r_135_;
}
}
LEAN_EXPORT uint8_t lp_loam_Loam_Core_instDecidableEqEffectCoordinate(lean_object* v_x_136_, lean_object* v_x_137_){
_start:
{
uint8_t v___x_138_; 
v___x_138_ = lp_loam_Loam_Core_instDecidableEqEffectCoordinate_decEq(v_x_136_, v_x_137_);
return v___x_138_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_instDecidableEqEffectCoordinate___boxed(lean_object* v_x_139_, lean_object* v_x_140_){
_start:
{
uint8_t v_res_141_; lean_object* v_r_142_; 
v_res_141_ = lp_loam_Loam_Core_instDecidableEqEffectCoordinate(v_x_139_, v_x_140_);
lean_dec_ref(v_x_140_);
lean_dec_ref(v_x_139_);
v_r_142_ = lean_box(v_res_141_);
return v_r_142_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_Effect_coordinate(lean_object* v_effect_143_){
_start:
{
lean_object* v_locus_144_; lean_object* v___x_145_; lean_object* v___x_146_; 
v_locus_144_ = lean_ctor_get(v_effect_143_, 1);
v___x_145_ = lp_loam_Loam_Core_Effect_measure(v_effect_143_);
lean_inc_ref(v_locus_144_);
v___x_146_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v___x_146_, 0, v_locus_144_);
lean_ctor_set(v___x_146_, 1, v___x_145_);
return v___x_146_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_Effect_coordinate___boxed(lean_object* v_effect_147_){
_start:
{
lean_object* v_res_148_; 
v_res_148_ = lp_loam_Loam_Core_Effect_coordinate(v_effect_147_);
lean_dec_ref(v_effect_147_);
return v_res_148_;
}
}
LEAN_EXPORT lean_object* lp_loam_List_mapTR_loop___at___00Loam_Core_Event_ofEffects_x3f_spec__0(lean_object* v_a_149_, lean_object* v_a_150_){
_start:
{
if (lean_obj_tag(v_a_149_) == 0)
{
lean_object* v___x_151_; 
v___x_151_ = l_List_reverse___redArg(v_a_150_);
return v___x_151_;
}
else
{
lean_object* v_head_152_; lean_object* v_tail_153_; lean_object* v___x_155_; uint8_t v_isShared_156_; uint8_t v_isSharedCheck_162_; 
v_head_152_ = lean_ctor_get(v_a_149_, 0);
v_tail_153_ = lean_ctor_get(v_a_149_, 1);
v_isSharedCheck_162_ = !lean_is_exclusive(v_a_149_);
if (v_isSharedCheck_162_ == 0)
{
v___x_155_ = v_a_149_;
v_isShared_156_ = v_isSharedCheck_162_;
goto v_resetjp_154_;
}
else
{
lean_inc(v_tail_153_);
lean_inc(v_head_152_);
lean_dec(v_a_149_);
v___x_155_ = lean_box(0);
v_isShared_156_ = v_isSharedCheck_162_;
goto v_resetjp_154_;
}
v_resetjp_154_:
{
lean_object* v_key_157_; lean_object* v___x_159_; 
v_key_157_ = lean_ctor_get(v_head_152_, 0);
lean_inc_ref(v_key_157_);
lean_dec(v_head_152_);
if (v_isShared_156_ == 0)
{
lean_ctor_set(v___x_155_, 1, v_a_150_);
lean_ctor_set(v___x_155_, 0, v_key_157_);
v___x_159_ = v___x_155_;
goto v_reusejp_158_;
}
else
{
lean_object* v_reuseFailAlloc_161_; 
v_reuseFailAlloc_161_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_161_, 0, v_key_157_);
lean_ctor_set(v_reuseFailAlloc_161_, 1, v_a_150_);
v___x_159_ = v_reuseFailAlloc_161_;
goto v_reusejp_158_;
}
v_reusejp_158_:
{
v_a_149_ = v_tail_153_;
v_a_150_ = v___x_159_;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_Event_ofEffects_x3f(lean_object* v_id_163_, lean_object* v_effects_164_){
_start:
{
lean_object* v___x_165_; lean_object* v___x_166_; lean_object* v___x_167_; uint8_t v___x_168_; 
v___x_165_ = lean_alloc_closure((void*)(lp_loam_Loam_Core_instDecidableEqEffectKey___boxed), 2, 0);
v___x_166_ = lean_box(0);
lean_inc(v_effects_164_);
v___x_167_ = lp_loam_List_mapTR_loop___at___00Loam_Core_Event_ofEffects_x3f_spec__0(v_effects_164_, v___x_166_);
v___x_168_ = l_List_nodupDecidable___redArg(v___x_165_, v___x_167_);
if (v___x_168_ == 0)
{
lean_object* v___x_169_; 
lean_dec(v_effects_164_);
lean_dec_ref(v_id_163_);
v___x_169_ = lean_box(0);
return v___x_169_;
}
else
{
lean_object* v___x_170_; lean_object* v___x_171_; 
v___x_170_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v___x_170_, 0, v_id_163_);
lean_ctor_set(v___x_170_, 1, v_effects_164_);
v___x_171_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_171_, 0, v___x_170_);
return v___x_171_;
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00List_foldrTR___at___00Loam_Core_Event_quantityAt_spec__0_spec__0(lean_object* v_locus_172_, lean_object* v_measure_173_, lean_object* v_as_174_, size_t v_i_175_, size_t v_stop_176_, lean_object* v_b_177_){
_start:
{
uint8_t v___x_178_; 
v___x_178_ = lean_usize_dec_eq(v_i_175_, v_stop_176_);
if (v___x_178_ == 0)
{
size_t v___x_179_; size_t v___x_180_; lean_object* v___x_181_; lean_object* v___x_182_; lean_object* v___x_183_; uint8_t v___x_184_; 
v___x_179_ = ((size_t)1ULL);
v___x_180_ = lean_usize_sub(v_i_175_, v___x_179_);
v___x_181_ = lean_array_uget_borrowed(v_as_174_, v___x_180_);
v___x_182_ = lp_loam_Loam_Core_Effect_coordinate(v___x_181_);
lean_inc_ref(v_measure_173_);
lean_inc_ref(v_locus_172_);
v___x_183_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v___x_183_, 0, v_locus_172_);
lean_ctor_set(v___x_183_, 1, v_measure_173_);
v___x_184_ = lp_loam_Loam_Core_instDecidableEqEffectCoordinate_decEq(v___x_182_, v___x_183_);
lean_dec_ref_known(v___x_183_, 2);
lean_dec_ref(v___x_182_);
if (v___x_184_ == 0)
{
v_i_175_ = v___x_180_;
goto _start;
}
else
{
lean_object* v___x_186_; lean_object* v___x_187_; 
v___x_186_ = lp_loam_Loam_Core_Effect_quantity(v___x_181_);
v___x_187_ = lean_int_add(v___x_186_, v_b_177_);
lean_dec(v_b_177_);
lean_dec(v___x_186_);
v_i_175_ = v___x_180_;
v_b_177_ = v___x_187_;
goto _start;
}
}
else
{
lean_dec_ref(v_measure_173_);
lean_dec_ref(v_locus_172_);
return v_b_177_;
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00List_foldrTR___at___00Loam_Core_Event_quantityAt_spec__0_spec__0___boxed(lean_object* v_locus_189_, lean_object* v_measure_190_, lean_object* v_as_191_, lean_object* v_i_192_, lean_object* v_stop_193_, lean_object* v_b_194_){
_start:
{
size_t v_i_boxed_195_; size_t v_stop_boxed_196_; lean_object* v_res_197_; 
v_i_boxed_195_ = lean_unbox_usize(v_i_192_);
lean_dec(v_i_192_);
v_stop_boxed_196_ = lean_unbox_usize(v_stop_193_);
lean_dec(v_stop_193_);
v_res_197_ = lp_loam___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00List_foldrTR___at___00Loam_Core_Event_quantityAt_spec__0_spec__0(v_locus_189_, v_measure_190_, v_as_191_, v_i_boxed_195_, v_stop_boxed_196_, v_b_194_);
lean_dec_ref(v_as_191_);
return v_res_197_;
}
}
LEAN_EXPORT lean_object* lp_loam_List_foldrTR___at___00Loam_Core_Event_quantityAt_spec__0(lean_object* v_locus_198_, lean_object* v_measure_199_, lean_object* v_init_200_, lean_object* v_l_201_){
_start:
{
lean_object* v___x_202_; lean_object* v___x_203_; lean_object* v___x_204_; uint8_t v___x_205_; 
v___x_202_ = lean_array_mk(v_l_201_);
v___x_203_ = lean_array_get_size(v___x_202_);
v___x_204_ = lean_unsigned_to_nat(0u);
v___x_205_ = lean_nat_dec_lt(v___x_204_, v___x_203_);
if (v___x_205_ == 0)
{
lean_dec_ref(v___x_202_);
lean_dec_ref(v_measure_199_);
lean_dec_ref(v_locus_198_);
return v_init_200_;
}
else
{
size_t v___x_206_; size_t v___x_207_; lean_object* v___x_208_; 
v___x_206_ = lean_usize_of_nat(v___x_203_);
v___x_207_ = ((size_t)0ULL);
v___x_208_ = lp_loam___private_Init_Data_Array_Basic_0__Array_foldrMUnsafe_fold___at___00List_foldrTR___at___00Loam_Core_Event_quantityAt_spec__0_spec__0(v_locus_198_, v_measure_199_, v___x_202_, v___x_206_, v___x_207_, v_init_200_);
lean_dec_ref(v___x_202_);
return v___x_208_;
}
}
}
static lean_object* _init_lp_loam_Loam_Core_Event_quantityAt___closed__0(void){
_start:
{
lean_object* v___x_209_; lean_object* v___x_210_; 
v___x_209_ = lean_unsigned_to_nat(0u);
v___x_210_ = lean_nat_to_int(v___x_209_);
return v___x_210_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Core_Event_quantityAt(lean_object* v_event_211_, lean_object* v_locus_212_, lean_object* v_measure_213_){
_start:
{
lean_object* v_effects_214_; lean_object* v___x_215_; lean_object* v___x_216_; 
v_effects_214_ = lean_ctor_get(v_event_211_, 1);
lean_inc(v_effects_214_);
lean_dec_ref(v_event_211_);
v___x_215_ = lean_obj_once(&lp_loam_Loam_Core_Event_quantityAt___closed__0, &lp_loam_Loam_Core_Event_quantityAt___closed__0_once, _init_lp_loam_Loam_Core_Event_quantityAt___closed__0);
v___x_216_ = lp_loam_List_foldrTR___at___00Loam_Core_Event_quantityAt_spec__0(v_locus_212_, v_measure_213_, v___x_215_, v_effects_214_);
return v___x_216_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_loam_Loam_Core_Effect(uint8_t builtin);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_loam_Loam_Core_Event(uint8_t builtin) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_loam_Loam_Core_Effect(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
