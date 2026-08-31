// Lean compiler output
// Module: Loam.Persistence
// Imports: public import Init public meta import Init public import Loam.Core.EventCorrectionMemory public import Loam.Core.EventMemory public import Std
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
lean_object* lean_nat_sub(lean_object*, lean_object*);
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
uint32_t lean_string_utf8_get_fast(lean_object*, lean_object*);
uint8_t lean_uint32_dec_eq(uint32_t, uint32_t);
lean_object* lean_string_utf8_next_fast(lean_object*, lean_object*);
lean_object* l_String_splitOnAux(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
uint8_t lean_string_dec_eq(lean_object*, lean_object*);
lean_object* l_List_reverse___redArg(lean_object*);
lean_object* lean_string_utf8_byte_size(lean_object*);
lean_object* lp_loam_Loam_Core_EventCorrectionMemory_ofCorrections_x3f(lean_object*);
lean_object* l_String_Slice_toInt_x3f(lean_object*);
lean_object* lp_loam_Loam_Core_Effect_ofQuantity(lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* lp_loam_Loam_Core_Effect_measure(lean_object*);
lean_object* lean_string_append(lean_object*, lean_object*);
lean_object* lp_loam_Loam_Core_Effect_quantity(lean_object*);
lean_object* l_Int_repr(lean_object*);
lean_object* l_IO_FS_readFile(lean_object*);
lean_object* lp_loam_Loam_Core_Event_ofEffects_x3f(lean_object*, lean_object*);
lean_object* lp_loam_Loam_Core_EventMemory_ofEvents_x3f(lean_object*);
lean_object* l_IO_FS_writeFile(lean_object*, lean_object*);
lean_object* l_String_intercalate(lean_object*, lean_object*);
lean_object* lean_io_rename(lean_object*, lean_object*);
lean_object* lean_mk_empty_array_with_capacity(lean_object*);
lean_object* lean_array_to_list(lean_object*);
lean_object* l_List_foldl___at___00Array_appendList_spec__0___redArg(lean_object*, lean_object*);
lean_object* l_List_appendTR___redArg(lean_object*, lean_object*);
static const lean_string_object lp_loam_Loam_Persistence_amountHeader___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 14, .m_capacity = 14, .m_length = 13, .m_data = "LOAM-AMOUNT\t1"};
static const lean_object* lp_loam_Loam_Persistence_amountHeader___closed__0 = (const lean_object*)&lp_loam_Loam_Persistence_amountHeader___closed__0_value;
LEAN_EXPORT const lean_object* lp_loam_Loam_Persistence_amountHeader = (const lean_object*)&lp_loam_Loam_Persistence_amountHeader___closed__0_value;
static const lean_string_object lp_loam_Loam_Persistence_eventHeader___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 13, .m_capacity = 13, .m_length = 12, .m_data = "LOAM-EVENT\t1"};
static const lean_object* lp_loam_Loam_Persistence_eventHeader___closed__0 = (const lean_object*)&lp_loam_Loam_Persistence_eventHeader___closed__0_value;
LEAN_EXPORT const lean_object* lp_loam_Loam_Persistence_eventHeader = (const lean_object*)&lp_loam_Loam_Persistence_eventHeader___closed__0_value;
static const lean_string_object lp_loam_Loam_Persistence_eventMemoryHeader___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 20, .m_capacity = 20, .m_length = 19, .m_data = "LOAM-EVENT-MEMORY\t1"};
static const lean_object* lp_loam_Loam_Persistence_eventMemoryHeader___closed__0 = (const lean_object*)&lp_loam_Loam_Persistence_eventMemoryHeader___closed__0_value;
LEAN_EXPORT const lean_object* lp_loam_Loam_Persistence_eventMemoryHeader = (const lean_object*)&lp_loam_Loam_Persistence_eventMemoryHeader___closed__0_value;
static const lean_string_object lp_loam_Loam_Persistence_eventCorrectionMemoryHeader___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 31, .m_capacity = 31, .m_length = 30, .m_data = "LOAM-EVENT-CORRECTION-MEMORY\t1"};
static const lean_object* lp_loam_Loam_Persistence_eventCorrectionMemoryHeader___closed__0 = (const lean_object*)&lp_loam_Loam_Persistence_eventCorrectionMemoryHeader___closed__0_value;
LEAN_EXPORT const lean_object* lp_loam_Loam_Persistence_eventCorrectionMemoryHeader = (const lean_object*)&lp_loam_Loam_Persistence_eventCorrectionMemoryHeader___closed__0_value;
LEAN_EXPORT uint8_t lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__2_spec__4___redArg(lean_object*, lean_object*, uint8_t);
LEAN_EXPORT lean_object* lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__2_spec__4___redArg___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__2(lean_object*);
LEAN_EXPORT lean_object* lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__2___boxed(lean_object*);
LEAN_EXPORT uint8_t lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__0_spec__0___redArg(lean_object*, lean_object*, uint8_t);
LEAN_EXPORT lean_object* lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__0_spec__0___redArg___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__0(lean_object*);
LEAN_EXPORT lean_object* lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__0___boxed(lean_object*);
LEAN_EXPORT uint8_t lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__1_spec__2___redArg(lean_object*, lean_object*, uint8_t);
LEAN_EXPORT lean_object* lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__1_spec__2___redArg___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__1(lean_object*);
LEAN_EXPORT lean_object* lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__1___boxed(lean_object*);
LEAN_EXPORT uint8_t lp_loam_Loam_Persistence_validToken(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_validToken___boxed(lean_object*);
LEAN_EXPORT uint8_t lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__0_spec__0(lean_object*, lean_object*, lean_object*, lean_object*, uint8_t, lean_object*);
LEAN_EXPORT lean_object* lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__0_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__1_spec__2(lean_object*, lean_object*, lean_object*, lean_object*, uint8_t, lean_object*);
LEAN_EXPORT lean_object* lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__1_spec__2___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__2_spec__4(lean_object*, lean_object*, lean_object*, lean_object*, uint8_t, lean_object*);
LEAN_EXPORT lean_object* lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__2_spec__4___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_loam_Loam_Persistence_validMeasureToken(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_validMeasureToken___boxed(lean_object*);
static const lean_string_object lp_loam_Loam_Persistence_encode_x3f___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "\n"};
static const lean_object* lp_loam_Loam_Persistence_encode_x3f___closed__0 = (const lean_object*)&lp_loam_Loam_Persistence_encode_x3f___closed__0_value;
static const lean_string_object lp_loam_Loam_Persistence_encode_x3f___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "LOAM-AMOUNT\t1\n"};
static const lean_object* lp_loam_Loam_Persistence_encode_x3f___closed__1 = (const lean_object*)&lp_loam_Loam_Persistence_encode_x3f___closed__1_value;
static const lean_string_object lp_loam_Loam_Persistence_encode_x3f___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "\t"};
static const lean_object* lp_loam_Loam_Persistence_encode_x3f___closed__2 = (const lean_object*)&lp_loam_Loam_Persistence_encode_x3f___closed__2_value;
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_encode_x3f(lean_object*);
static const lean_string_object lp_loam_Loam_Persistence_decode_x3f___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 1, .m_capacity = 1, .m_length = 0, .m_data = ""};
static const lean_object* lp_loam_Loam_Persistence_decode_x3f___closed__0 = (const lean_object*)&lp_loam_Loam_Persistence_decode_x3f___closed__0_value;
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decode_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decode_x3f___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeEffectRow_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEffectFields_x3f(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEffectRow_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEffectRow_x3f___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00Loam_Persistence_encodeEvent_x3f_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_encodeEvent_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00Loam_Persistence_decodeEvent_x3f_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decodeEvent_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decodeEvent_x3f___boxed(lean_object*);
static const lean_string_object lp_loam_List_mapTR_loop___at___00__private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f_spec__0___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "EFFECT\t"};
static const lean_object* lp_loam_List_mapTR_loop___at___00__private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f_spec__0___closed__0 = (const lean_object*)&lp_loam_List_mapTR_loop___at___00__private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f_spec__0___closed__0_value;
LEAN_EXPORT lean_object* lp_loam_List_mapTR_loop___at___00__private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f_spec__0(lean_object*, lean_object*);
static const lean_string_object lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "EVENT\t"};
static const lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f___closed__0 = (const lean_object*)&lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f___closed__0_value;
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f(lean_object*);
static const lean_string_object lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEffectRow_x3f___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "EFFECT"};
static const lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEffectRow_x3f___closed__0 = (const lean_object*)&lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEffectRow_x3f___closed__0_value;
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEffectRow_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEffectRow_x3f___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_withoutTrailingEmpty(lean_object*);
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00__private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEventChunk_x3f_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEventChunk_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEventChunk_x3f___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00Loam_Persistence_encodeEventMemory_x3f_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Init_Data_List_Impl_0__List_flatMapTR_go___at___00Loam_Persistence_encodeEventMemory_x3f_spec__1(lean_object*, lean_object*);
static const lean_array_object lp_loam_Loam_Persistence_encodeEventMemory_x3f___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_array_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 246}, .m_size = 0, .m_capacity = 0, .m_data = {}};
static const lean_object* lp_loam_Loam_Persistence_encodeEventMemory_x3f___closed__0 = (const lean_object*)&lp_loam_Loam_Persistence_encodeEventMemory_x3f___closed__0_value;
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_encodeEventMemory_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00Loam_Persistence_decodeEventMemory_x3f_spec__0(lean_object*, lean_object*);
static const lean_string_object lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 21, .m_capacity = 21, .m_length = 20, .m_data = "LOAM-EVENT-MEMORY\t1\n"};
static const lean_object* lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__0 = (const lean_object*)&lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__0_value;
static const lean_string_object lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "\nEVENT\t"};
static const lean_object* lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__1 = (const lean_object*)&lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__1_value;
static lean_once_cell_t lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__2_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__2;
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decodeEventMemory_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decodeEventMemory_x3f___boxed(lean_object*);
static const lean_string_object lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeEventCorrectionRow_x3f___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 12, .m_capacity = 12, .m_length = 11, .m_data = "CORRECTION\t"};
static const lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeEventCorrectionRow_x3f___closed__0 = (const lean_object*)&lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeEventCorrectionRow_x3f___closed__0_value;
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeEventCorrectionRow_x3f(lean_object*);
static const lean_string_object lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEventCorrectionRow_x3f___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 11, .m_capacity = 11, .m_length = 10, .m_data = "CORRECTION"};
static const lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEventCorrectionRow_x3f___closed__0 = (const lean_object*)&lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEventCorrectionRow_x3f___closed__0_value;
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEventCorrectionRow_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEventCorrectionRow_x3f___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00Loam_Persistence_encodeEventCorrectionMemory_x3f_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_encodeEventCorrectionMemory_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00Loam_Persistence_decodeEventCorrectionMemory_x3f_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decodeEventCorrectionMemory_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decodeEventCorrectionMemory_x3f___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_save_x3f(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_save_x3f___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_load_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_load_x3f___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_saveEvent_x3f(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_saveEvent_x3f___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_loadEvent_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_loadEvent_x3f___boxed(lean_object*, lean_object*);
static const lean_string_object lp_loam___private_Loam_Persistence_0__Loam_Persistence_eventMemoryStagePath___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 12, .m_capacity = 12, .m_length = 11, .m_data = ".loam-stage"};
static const lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_eventMemoryStagePath___closed__0 = (const lean_object*)&lp_loam___private_Loam_Persistence_0__Loam_Persistence_eventMemoryStagePath___closed__0_value;
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_eventMemoryStagePath(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_saveEventMemory_x3f(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_saveEventMemory_x3f___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_loadEventMemory_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_loadEventMemory_x3f___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_eventCorrectionMemoryStagePath(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_saveEventCorrectionMemory_x3f(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_saveEventCorrectionMemory_x3f___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_loadEventCorrectionMemory_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_loadEventCorrectionMemory_x3f___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__2_spec__4___redArg(lean_object* v_s_9_, lean_object* v_a_10_, uint8_t v_b_11_){
_start:
{
lean_object* v_str_12_; lean_object* v_startInclusive_13_; lean_object* v_endExclusive_14_; lean_object* v___x_15_; uint8_t v___x_16_; 
v_str_12_ = lean_ctor_get(v_s_9_, 0);
v_startInclusive_13_ = lean_ctor_get(v_s_9_, 1);
v_endExclusive_14_ = lean_ctor_get(v_s_9_, 2);
v___x_15_ = lean_nat_sub(v_endExclusive_14_, v_startInclusive_13_);
v___x_16_ = lean_nat_dec_eq(v_a_10_, v___x_15_);
lean_dec(v___x_15_);
if (v___x_16_ == 0)
{
lean_object* v___x_17_; uint32_t v___x_18_; uint32_t v___x_19_; uint8_t v___x_20_; 
v___x_17_ = lean_nat_add(v_startInclusive_13_, v_a_10_);
lean_dec(v_a_10_);
v___x_18_ = lean_string_utf8_get_fast(v_str_12_, v___x_17_);
v___x_19_ = 13;
v___x_20_ = lean_uint32_dec_eq(v___x_18_, v___x_19_);
if (v___x_20_ == 0)
{
lean_object* v___x_21_; lean_object* v___x_22_; 
v___x_21_ = lean_string_utf8_next_fast(v_str_12_, v___x_17_);
lean_dec(v___x_17_);
v___x_22_ = lean_nat_sub(v___x_21_, v_startInclusive_13_);
v_a_10_ = v___x_22_;
v_b_11_ = v___x_20_;
goto _start;
}
else
{
lean_dec(v___x_17_);
return v___x_20_;
}
}
else
{
lean_dec(v_a_10_);
return v_b_11_;
}
}
}
LEAN_EXPORT lean_object* lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__2_spec__4___redArg___boxed(lean_object* v_s_24_, lean_object* v_a_25_, lean_object* v_b_26_){
_start:
{
uint8_t v_b_boxed_27_; uint8_t v_res_28_; lean_object* v_r_29_; 
v_b_boxed_27_ = lean_unbox(v_b_26_);
v_res_28_ = lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__2_spec__4___redArg(v_s_24_, v_a_25_, v_b_boxed_27_);
lean_dec_ref(v_s_24_);
v_r_29_ = lean_box(v_res_28_);
return v_r_29_;
}
}
LEAN_EXPORT uint8_t lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__2(lean_object* v_s_30_){
_start:
{
lean_object* v_searcher_31_; uint8_t v___x_32_; uint8_t v___x_33_; 
v_searcher_31_ = lean_unsigned_to_nat(0u);
v___x_32_ = 0;
v___x_33_ = lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__2_spec__4___redArg(v_s_30_, v_searcher_31_, v___x_32_);
return v___x_33_;
}
}
LEAN_EXPORT lean_object* lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__2___boxed(lean_object* v_s_34_){
_start:
{
uint8_t v_res_35_; lean_object* v_r_36_; 
v_res_35_ = lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__2(v_s_34_);
lean_dec_ref(v_s_34_);
v_r_36_ = lean_box(v_res_35_);
return v_r_36_;
}
}
LEAN_EXPORT uint8_t lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__0_spec__0___redArg(lean_object* v_s_37_, lean_object* v_a_38_, uint8_t v_b_39_){
_start:
{
lean_object* v_str_40_; lean_object* v_startInclusive_41_; lean_object* v_endExclusive_42_; lean_object* v___x_43_; uint8_t v___x_44_; 
v_str_40_ = lean_ctor_get(v_s_37_, 0);
v_startInclusive_41_ = lean_ctor_get(v_s_37_, 1);
v_endExclusive_42_ = lean_ctor_get(v_s_37_, 2);
v___x_43_ = lean_nat_sub(v_endExclusive_42_, v_startInclusive_41_);
v___x_44_ = lean_nat_dec_eq(v_a_38_, v___x_43_);
lean_dec(v___x_43_);
if (v___x_44_ == 0)
{
lean_object* v___x_45_; uint32_t v___x_46_; uint32_t v___x_47_; uint8_t v___x_48_; 
v___x_45_ = lean_nat_add(v_startInclusive_41_, v_a_38_);
lean_dec(v_a_38_);
v___x_46_ = lean_string_utf8_get_fast(v_str_40_, v___x_45_);
v___x_47_ = 9;
v___x_48_ = lean_uint32_dec_eq(v___x_46_, v___x_47_);
if (v___x_48_ == 0)
{
lean_object* v___x_49_; lean_object* v___x_50_; 
v___x_49_ = lean_string_utf8_next_fast(v_str_40_, v___x_45_);
lean_dec(v___x_45_);
v___x_50_ = lean_nat_sub(v___x_49_, v_startInclusive_41_);
v_a_38_ = v___x_50_;
v_b_39_ = v___x_48_;
goto _start;
}
else
{
lean_dec(v___x_45_);
return v___x_48_;
}
}
else
{
lean_dec(v_a_38_);
return v_b_39_;
}
}
}
LEAN_EXPORT lean_object* lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__0_spec__0___redArg___boxed(lean_object* v_s_52_, lean_object* v_a_53_, lean_object* v_b_54_){
_start:
{
uint8_t v_b_boxed_55_; uint8_t v_res_56_; lean_object* v_r_57_; 
v_b_boxed_55_ = lean_unbox(v_b_54_);
v_res_56_ = lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__0_spec__0___redArg(v_s_52_, v_a_53_, v_b_boxed_55_);
lean_dec_ref(v_s_52_);
v_r_57_ = lean_box(v_res_56_);
return v_r_57_;
}
}
LEAN_EXPORT uint8_t lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__0(lean_object* v_s_58_){
_start:
{
lean_object* v_searcher_59_; uint8_t v___x_60_; uint8_t v___x_61_; 
v_searcher_59_ = lean_unsigned_to_nat(0u);
v___x_60_ = 0;
v___x_61_ = lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__0_spec__0___redArg(v_s_58_, v_searcher_59_, v___x_60_);
return v___x_61_;
}
}
LEAN_EXPORT lean_object* lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__0___boxed(lean_object* v_s_62_){
_start:
{
uint8_t v_res_63_; lean_object* v_r_64_; 
v_res_63_ = lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__0(v_s_62_);
lean_dec_ref(v_s_62_);
v_r_64_ = lean_box(v_res_63_);
return v_r_64_;
}
}
LEAN_EXPORT uint8_t lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__1_spec__2___redArg(lean_object* v_s_65_, lean_object* v_a_66_, uint8_t v_b_67_){
_start:
{
lean_object* v_str_68_; lean_object* v_startInclusive_69_; lean_object* v_endExclusive_70_; lean_object* v___x_71_; uint8_t v___x_72_; 
v_str_68_ = lean_ctor_get(v_s_65_, 0);
v_startInclusive_69_ = lean_ctor_get(v_s_65_, 1);
v_endExclusive_70_ = lean_ctor_get(v_s_65_, 2);
v___x_71_ = lean_nat_sub(v_endExclusive_70_, v_startInclusive_69_);
v___x_72_ = lean_nat_dec_eq(v_a_66_, v___x_71_);
lean_dec(v___x_71_);
if (v___x_72_ == 0)
{
lean_object* v___x_73_; uint32_t v___x_74_; uint32_t v___x_75_; uint8_t v___x_76_; 
v___x_73_ = lean_nat_add(v_startInclusive_69_, v_a_66_);
lean_dec(v_a_66_);
v___x_74_ = lean_string_utf8_get_fast(v_str_68_, v___x_73_);
v___x_75_ = 10;
v___x_76_ = lean_uint32_dec_eq(v___x_74_, v___x_75_);
if (v___x_76_ == 0)
{
lean_object* v___x_77_; lean_object* v___x_78_; 
v___x_77_ = lean_string_utf8_next_fast(v_str_68_, v___x_73_);
lean_dec(v___x_73_);
v___x_78_ = lean_nat_sub(v___x_77_, v_startInclusive_69_);
v_a_66_ = v___x_78_;
v_b_67_ = v___x_76_;
goto _start;
}
else
{
lean_dec(v___x_73_);
return v___x_76_;
}
}
else
{
lean_dec(v_a_66_);
return v_b_67_;
}
}
}
LEAN_EXPORT lean_object* lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__1_spec__2___redArg___boxed(lean_object* v_s_80_, lean_object* v_a_81_, lean_object* v_b_82_){
_start:
{
uint8_t v_b_boxed_83_; uint8_t v_res_84_; lean_object* v_r_85_; 
v_b_boxed_83_ = lean_unbox(v_b_82_);
v_res_84_ = lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__1_spec__2___redArg(v_s_80_, v_a_81_, v_b_boxed_83_);
lean_dec_ref(v_s_80_);
v_r_85_ = lean_box(v_res_84_);
return v_r_85_;
}
}
LEAN_EXPORT uint8_t lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__1(lean_object* v_s_86_){
_start:
{
lean_object* v_searcher_87_; uint8_t v___x_88_; uint8_t v___x_89_; 
v_searcher_87_ = lean_unsigned_to_nat(0u);
v___x_88_ = 0;
v___x_89_ = lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__1_spec__2___redArg(v_s_86_, v_searcher_87_, v___x_88_);
return v___x_89_;
}
}
LEAN_EXPORT lean_object* lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__1___boxed(lean_object* v_s_90_){
_start:
{
uint8_t v_res_91_; lean_object* v_r_92_; 
v_res_91_ = lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__1(v_s_90_);
lean_dec_ref(v_s_90_);
v_r_92_ = lean_box(v_res_91_);
return v_r_92_;
}
}
LEAN_EXPORT uint8_t lp_loam_Loam_Persistence_validToken(lean_object* v_token_93_){
_start:
{
lean_object* v___x_94_; lean_object* v___x_95_; uint8_t v___x_96_; 
v___x_94_ = lean_string_utf8_byte_size(v_token_93_);
v___x_95_ = lean_unsigned_to_nat(0u);
v___x_96_ = lean_nat_dec_eq(v___x_94_, v___x_95_);
if (v___x_96_ == 0)
{
lean_object* v___x_97_; uint8_t v___x_98_; 
v___x_97_ = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(v___x_97_, 0, v_token_93_);
lean_ctor_set(v___x_97_, 1, v___x_95_);
lean_ctor_set(v___x_97_, 2, v___x_94_);
v___x_98_ = lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__0(v___x_97_);
if (v___x_98_ == 0)
{
uint8_t v___x_99_; 
v___x_99_ = lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__1(v___x_97_);
if (v___x_99_ == 0)
{
uint8_t v___x_100_; 
v___x_100_ = lp_loam_String_Slice_contains___at___00Loam_Persistence_validToken_spec__2(v___x_97_);
lean_dec_ref_known(v___x_97_, 3);
if (v___x_100_ == 0)
{
uint8_t v___x_101_; 
v___x_101_ = 1;
return v___x_101_;
}
else
{
return v___x_99_;
}
}
else
{
lean_dec_ref_known(v___x_97_, 3);
return v___x_98_;
}
}
else
{
lean_dec_ref_known(v___x_97_, 3);
return v___x_96_;
}
}
else
{
uint8_t v___x_102_; 
lean_dec_ref(v_token_93_);
v___x_102_ = 0;
return v___x_102_;
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_validToken___boxed(lean_object* v_token_103_){
_start:
{
uint8_t v_res_104_; lean_object* v_r_105_; 
v_res_104_ = lp_loam_Loam_Persistence_validToken(v_token_103_);
v_r_105_ = lean_box(v_res_104_);
return v_r_105_;
}
}
LEAN_EXPORT uint8_t lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__0_spec__0(lean_object* v_s_106_, lean_object* v_inst_107_, lean_object* v_R_108_, lean_object* v_a_109_, uint8_t v_b_110_, lean_object* v_c_111_){
_start:
{
uint8_t v___x_112_; 
v___x_112_ = lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__0_spec__0___redArg(v_s_106_, v_a_109_, v_b_110_);
return v___x_112_;
}
}
LEAN_EXPORT lean_object* lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__0_spec__0___boxed(lean_object* v_s_113_, lean_object* v_inst_114_, lean_object* v_R_115_, lean_object* v_a_116_, lean_object* v_b_117_, lean_object* v_c_118_){
_start:
{
uint8_t v_b_boxed_119_; uint8_t v_res_120_; lean_object* v_r_121_; 
v_b_boxed_119_ = lean_unbox(v_b_117_);
v_res_120_ = lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__0_spec__0(v_s_113_, v_inst_114_, v_R_115_, v_a_116_, v_b_boxed_119_, v_c_118_);
lean_dec_ref(v_s_113_);
v_r_121_ = lean_box(v_res_120_);
return v_r_121_;
}
}
LEAN_EXPORT uint8_t lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__1_spec__2(lean_object* v_s_122_, lean_object* v_inst_123_, lean_object* v_R_124_, lean_object* v_a_125_, uint8_t v_b_126_, lean_object* v_c_127_){
_start:
{
uint8_t v___x_128_; 
v___x_128_ = lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__1_spec__2___redArg(v_s_122_, v_a_125_, v_b_126_);
return v___x_128_;
}
}
LEAN_EXPORT lean_object* lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__1_spec__2___boxed(lean_object* v_s_129_, lean_object* v_inst_130_, lean_object* v_R_131_, lean_object* v_a_132_, lean_object* v_b_133_, lean_object* v_c_134_){
_start:
{
uint8_t v_b_boxed_135_; uint8_t v_res_136_; lean_object* v_r_137_; 
v_b_boxed_135_ = lean_unbox(v_b_133_);
v_res_136_ = lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__1_spec__2(v_s_129_, v_inst_130_, v_R_131_, v_a_132_, v_b_boxed_135_, v_c_134_);
lean_dec_ref(v_s_129_);
v_r_137_ = lean_box(v_res_136_);
return v_r_137_;
}
}
LEAN_EXPORT uint8_t lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__2_spec__4(lean_object* v_s_138_, lean_object* v_inst_139_, lean_object* v_R_140_, lean_object* v_a_141_, uint8_t v_b_142_, lean_object* v_c_143_){
_start:
{
uint8_t v___x_144_; 
v___x_144_ = lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__2_spec__4___redArg(v_s_138_, v_a_141_, v_b_142_);
return v___x_144_;
}
}
LEAN_EXPORT lean_object* lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__2_spec__4___boxed(lean_object* v_s_145_, lean_object* v_inst_146_, lean_object* v_R_147_, lean_object* v_a_148_, lean_object* v_b_149_, lean_object* v_c_150_){
_start:
{
uint8_t v_b_boxed_151_; uint8_t v_res_152_; lean_object* v_r_153_; 
v_b_boxed_151_ = lean_unbox(v_b_149_);
v_res_152_ = lp_loam_WellFounded_opaqueFix_u2083___at___00String_Slice_contains___at___00Loam_Persistence_validToken_spec__2_spec__4(v_s_145_, v_inst_146_, v_R_147_, v_a_148_, v_b_boxed_151_, v_c_150_);
lean_dec_ref(v_s_145_);
v_r_153_ = lean_box(v_res_152_);
return v_r_153_;
}
}
LEAN_EXPORT uint8_t lp_loam_Loam_Persistence_validMeasureToken(lean_object* v_token_154_){
_start:
{
uint8_t v___x_155_; 
v___x_155_ = lp_loam_Loam_Persistence_validToken(v_token_154_);
return v___x_155_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_validMeasureToken___boxed(lean_object* v_token_156_){
_start:
{
uint8_t v_res_157_; lean_object* v_r_158_; 
v_res_157_ = lp_loam_Loam_Persistence_validMeasureToken(v_token_156_);
v_r_158_ = lean_box(v_res_157_);
return v_r_158_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_encode_x3f(lean_object* v_amount_162_){
_start:
{
lean_object* v_fst_163_; lean_object* v_snd_164_; uint8_t v___x_165_; 
v_fst_163_ = lean_ctor_get(v_amount_162_, 0);
lean_inc_n(v_fst_163_, 2);
v_snd_164_ = lean_ctor_get(v_amount_162_, 1);
lean_inc(v_snd_164_);
lean_dec_ref(v_amount_162_);
v___x_165_ = lp_loam_Loam_Persistence_validToken(v_fst_163_);
if (v___x_165_ == 0)
{
lean_object* v___x_166_; 
lean_dec(v_snd_164_);
lean_dec(v_fst_163_);
v___x_166_ = lean_box(0);
return v___x_166_;
}
else
{
lean_object* v___x_167_; lean_object* v___x_168_; lean_object* v___x_169_; lean_object* v___x_170_; lean_object* v___x_171_; lean_object* v___x_172_; lean_object* v___x_173_; lean_object* v___x_174_; lean_object* v___x_175_; 
v___x_167_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__0));
v___x_168_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__1));
v___x_169_ = lean_string_append(v___x_168_, v_fst_163_);
lean_dec(v_fst_163_);
v___x_170_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__2));
v___x_171_ = lean_string_append(v___x_169_, v___x_170_);
v___x_172_ = l_Int_repr(v_snd_164_);
lean_dec(v_snd_164_);
v___x_173_ = lean_string_append(v___x_171_, v___x_172_);
lean_dec_ref(v___x_172_);
v___x_174_ = lean_string_append(v___x_173_, v___x_167_);
v___x_175_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_175_, 0, v___x_174_);
return v___x_175_;
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decode_x3f(lean_object* v_input_177_){
_start:
{
lean_object* v___x_178_; lean_object* v___x_179_; lean_object* v___x_180_; lean_object* v___x_181_; 
v___x_178_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__0));
v___x_179_ = lean_unsigned_to_nat(0u);
v___x_180_ = lean_box(0);
v___x_181_ = l_String_splitOnAux(v_input_177_, v___x_178_, v___x_179_, v___x_179_, v___x_179_, v___x_180_);
if (lean_obj_tag(v___x_181_) == 1)
{
lean_object* v_tail_182_; 
v_tail_182_ = lean_ctor_get(v___x_181_, 1);
lean_inc(v_tail_182_);
if (lean_obj_tag(v_tail_182_) == 1)
{
lean_object* v_tail_183_; 
v_tail_183_ = lean_ctor_get(v_tail_182_, 1);
lean_inc(v_tail_183_);
if (lean_obj_tag(v_tail_183_) == 1)
{
lean_object* v_tail_184_; 
v_tail_184_ = lean_ctor_get(v_tail_183_, 1);
lean_inc(v_tail_184_);
if (lean_obj_tag(v_tail_184_) == 0)
{
lean_object* v_head_185_; lean_object* v_head_186_; lean_object* v_head_187_; lean_object* v___x_188_; uint8_t v___x_189_; 
v_head_185_ = lean_ctor_get(v___x_181_, 0);
lean_inc(v_head_185_);
lean_dec_ref_known(v___x_181_, 2);
v_head_186_ = lean_ctor_get(v_tail_182_, 0);
lean_inc(v_head_186_);
lean_dec_ref_known(v_tail_182_, 2);
v_head_187_ = lean_ctor_get(v_tail_183_, 0);
lean_inc(v_head_187_);
lean_dec_ref_known(v_tail_183_, 2);
v___x_188_ = ((lean_object*)(lp_loam_Loam_Persistence_amountHeader___closed__0));
v___x_189_ = lean_string_dec_eq(v_head_185_, v___x_188_);
lean_dec(v_head_185_);
if (v___x_189_ == 0)
{
lean_object* v___x_190_; 
lean_dec(v_head_187_);
lean_dec(v_head_186_);
v___x_190_ = lean_box(0);
return v___x_190_;
}
else
{
lean_object* v___x_191_; uint8_t v___x_192_; 
v___x_191_ = ((lean_object*)(lp_loam_Loam_Persistence_decode_x3f___closed__0));
v___x_192_ = lean_string_dec_eq(v_head_187_, v___x_191_);
lean_dec(v_head_187_);
if (v___x_192_ == 0)
{
lean_object* v___x_193_; 
lean_dec(v_head_186_);
v___x_193_ = lean_box(0);
return v___x_193_;
}
else
{
lean_object* v___x_194_; lean_object* v___x_195_; 
v___x_194_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__2));
v___x_195_ = l_String_splitOnAux(v_head_186_, v___x_194_, v___x_179_, v___x_179_, v___x_179_, v_tail_184_);
lean_dec(v_head_186_);
if (lean_obj_tag(v___x_195_) == 1)
{
lean_object* v_tail_196_; 
v_tail_196_ = lean_ctor_get(v___x_195_, 1);
lean_inc(v_tail_196_);
if (lean_obj_tag(v_tail_196_) == 1)
{
lean_object* v_tail_197_; 
v_tail_197_ = lean_ctor_get(v_tail_196_, 1);
if (lean_obj_tag(v_tail_197_) == 0)
{
lean_object* v_head_198_; lean_object* v_head_199_; lean_object* v___x_201_; uint8_t v_isShared_202_; uint8_t v_isSharedCheck_220_; 
v_head_198_ = lean_ctor_get(v___x_195_, 0);
lean_inc(v_head_198_);
lean_dec_ref_known(v___x_195_, 2);
v_head_199_ = lean_ctor_get(v_tail_196_, 0);
v_isSharedCheck_220_ = !lean_is_exclusive(v_tail_196_);
if (v_isSharedCheck_220_ == 0)
{
lean_object* v_unused_221_; 
v_unused_221_ = lean_ctor_get(v_tail_196_, 1);
lean_dec(v_unused_221_);
v___x_201_ = v_tail_196_;
v_isShared_202_ = v_isSharedCheck_220_;
goto v_resetjp_200_;
}
else
{
lean_inc(v_head_199_);
lean_dec(v_tail_196_);
v___x_201_ = lean_box(0);
v_isShared_202_ = v_isSharedCheck_220_;
goto v_resetjp_200_;
}
v_resetjp_200_:
{
uint8_t v___x_203_; 
lean_inc(v_head_198_);
v___x_203_ = lp_loam_Loam_Persistence_validToken(v_head_198_);
if (v___x_203_ == 0)
{
lean_object* v___x_204_; 
lean_del_object(v___x_201_);
lean_dec(v_head_199_);
lean_dec(v_head_198_);
v___x_204_ = lean_box(0);
return v___x_204_;
}
else
{
lean_object* v___x_205_; lean_object* v___x_206_; lean_object* v___x_207_; 
v___x_205_ = lean_string_utf8_byte_size(v_head_199_);
v___x_206_ = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(v___x_206_, 0, v_head_199_);
lean_ctor_set(v___x_206_, 1, v___x_179_);
lean_ctor_set(v___x_206_, 2, v___x_205_);
v___x_207_ = l_String_Slice_toInt_x3f(v___x_206_);
if (lean_obj_tag(v___x_207_) == 0)
{
lean_object* v___x_208_; 
lean_del_object(v___x_201_);
lean_dec(v_head_198_);
v___x_208_ = lean_box(0);
return v___x_208_;
}
else
{
lean_object* v_val_209_; lean_object* v___x_211_; uint8_t v_isShared_212_; uint8_t v_isSharedCheck_219_; 
v_val_209_ = lean_ctor_get(v___x_207_, 0);
v_isSharedCheck_219_ = !lean_is_exclusive(v___x_207_);
if (v_isSharedCheck_219_ == 0)
{
v___x_211_ = v___x_207_;
v_isShared_212_ = v_isSharedCheck_219_;
goto v_resetjp_210_;
}
else
{
lean_inc(v_val_209_);
lean_dec(v___x_207_);
v___x_211_ = lean_box(0);
v_isShared_212_ = v_isSharedCheck_219_;
goto v_resetjp_210_;
}
v_resetjp_210_:
{
lean_object* v___x_214_; 
if (v_isShared_202_ == 0)
{
lean_ctor_set_tag(v___x_201_, 0);
lean_ctor_set(v___x_201_, 1, v_val_209_);
lean_ctor_set(v___x_201_, 0, v_head_198_);
v___x_214_ = v___x_201_;
goto v_reusejp_213_;
}
else
{
lean_object* v_reuseFailAlloc_218_; 
v_reuseFailAlloc_218_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v_reuseFailAlloc_218_, 0, v_head_198_);
lean_ctor_set(v_reuseFailAlloc_218_, 1, v_val_209_);
v___x_214_ = v_reuseFailAlloc_218_;
goto v_reusejp_213_;
}
v_reusejp_213_:
{
lean_object* v___x_216_; 
if (v_isShared_212_ == 0)
{
lean_ctor_set(v___x_211_, 0, v___x_214_);
v___x_216_ = v___x_211_;
goto v_reusejp_215_;
}
else
{
lean_object* v_reuseFailAlloc_217_; 
v_reuseFailAlloc_217_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_217_, 0, v___x_214_);
v___x_216_ = v_reuseFailAlloc_217_;
goto v_reusejp_215_;
}
v_reusejp_215_:
{
return v___x_216_;
}
}
}
}
}
}
}
else
{
lean_object* v___x_222_; 
lean_dec_ref_known(v_tail_196_, 2);
lean_dec_ref_known(v___x_195_, 2);
v___x_222_ = lean_box(0);
return v___x_222_;
}
}
else
{
lean_object* v___x_223_; 
lean_dec_ref_known(v___x_195_, 2);
lean_dec(v_tail_196_);
v___x_223_ = lean_box(0);
return v___x_223_;
}
}
else
{
lean_object* v___x_224_; 
lean_dec(v___x_195_);
v___x_224_ = lean_box(0);
return v___x_224_;
}
}
}
}
else
{
lean_object* v___x_225_; 
lean_dec(v_tail_184_);
lean_dec_ref_known(v_tail_183_, 2);
lean_dec_ref_known(v_tail_182_, 2);
lean_dec_ref_known(v___x_181_, 2);
v___x_225_ = lean_box(0);
return v___x_225_;
}
}
else
{
lean_object* v___x_226_; 
lean_dec_ref_known(v_tail_182_, 2);
lean_dec(v_tail_183_);
lean_dec_ref_known(v___x_181_, 2);
v___x_226_ = lean_box(0);
return v___x_226_;
}
}
else
{
lean_object* v___x_227_; 
lean_dec(v_tail_182_);
lean_dec_ref_known(v___x_181_, 2);
v___x_227_ = lean_box(0);
return v___x_227_;
}
}
else
{
lean_object* v___x_228_; 
lean_dec(v___x_181_);
v___x_228_ = lean_box(0);
return v___x_228_;
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decode_x3f___boxed(lean_object* v_input_229_){
_start:
{
lean_object* v_res_230_; 
v_res_230_ = lp_loam_Loam_Persistence_decode_x3f(v_input_229_);
lean_dec_ref(v_input_229_);
return v_res_230_;
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeEffectRow_x3f(lean_object* v_effect_231_){
_start:
{
lean_object* v_key_232_; lean_object* v_locus_233_; lean_object* v_measure_234_; uint8_t v___y_236_; uint8_t v___x_250_; 
v_key_232_ = lean_ctor_get(v_effect_231_, 0);
v_locus_233_ = lean_ctor_get(v_effect_231_, 1);
v_measure_234_ = lp_loam_Loam_Core_Effect_measure(v_effect_231_);
lean_inc_ref(v_key_232_);
v___x_250_ = lp_loam_Loam_Persistence_validToken(v_key_232_);
if (v___x_250_ == 0)
{
v___y_236_ = v___x_250_;
goto v___jp_235_;
}
else
{
uint8_t v___x_251_; 
lean_inc_ref(v_locus_233_);
v___x_251_ = lp_loam_Loam_Persistence_validToken(v_locus_233_);
v___y_236_ = v___x_251_;
goto v___jp_235_;
}
v___jp_235_:
{
if (v___y_236_ == 0)
{
lean_object* v___x_237_; 
lean_dec_ref(v_measure_234_);
lean_dec_ref(v_effect_231_);
v___x_237_ = lean_box(0);
return v___x_237_;
}
else
{
uint8_t v___x_238_; 
lean_inc_ref(v_measure_234_);
v___x_238_ = lp_loam_Loam_Persistence_validToken(v_measure_234_);
if (v___x_238_ == 0)
{
lean_object* v___x_239_; 
lean_dec_ref(v_measure_234_);
lean_dec_ref(v_effect_231_);
v___x_239_ = lean_box(0);
return v___x_239_;
}
else
{
lean_object* v___x_240_; lean_object* v___x_241_; lean_object* v___x_242_; lean_object* v___x_243_; lean_object* v___x_244_; lean_object* v___x_245_; lean_object* v___x_246_; lean_object* v___x_247_; lean_object* v___x_248_; lean_object* v___x_249_; 
v___x_240_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__2));
lean_inc_ref(v_key_232_);
v___x_241_ = lean_string_append(v_key_232_, v___x_240_);
v___x_242_ = lean_string_append(v___x_241_, v_locus_233_);
v___x_243_ = lean_string_append(v___x_242_, v___x_240_);
v___x_244_ = lean_string_append(v___x_243_, v_measure_234_);
lean_dec_ref(v_measure_234_);
v___x_245_ = lean_string_append(v___x_244_, v___x_240_);
v___x_246_ = lp_loam_Loam_Core_Effect_quantity(v_effect_231_);
lean_dec_ref(v_effect_231_);
v___x_247_ = l_Int_repr(v___x_246_);
lean_dec(v___x_246_);
v___x_248_ = lean_string_append(v___x_245_, v___x_247_);
lean_dec_ref(v___x_247_);
v___x_249_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_249_, 0, v___x_248_);
return v___x_249_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEffectFields_x3f(lean_object* v_keyToken_252_, lean_object* v_locusToken_253_, lean_object* v_measureToken_254_, lean_object* v_quantaText_255_){
_start:
{
uint8_t v___y_257_; uint8_t v___x_275_; 
lean_inc_ref(v_keyToken_252_);
v___x_275_ = lp_loam_Loam_Persistence_validToken(v_keyToken_252_);
if (v___x_275_ == 0)
{
v___y_257_ = v___x_275_;
goto v___jp_256_;
}
else
{
uint8_t v___x_276_; 
lean_inc_ref(v_locusToken_253_);
v___x_276_ = lp_loam_Loam_Persistence_validToken(v_locusToken_253_);
v___y_257_ = v___x_276_;
goto v___jp_256_;
}
v___jp_256_:
{
if (v___y_257_ == 0)
{
lean_object* v___x_258_; 
lean_dec_ref(v_quantaText_255_);
lean_dec_ref(v_measureToken_254_);
lean_dec_ref(v_locusToken_253_);
lean_dec_ref(v_keyToken_252_);
v___x_258_ = lean_box(0);
return v___x_258_;
}
else
{
uint8_t v___x_259_; 
lean_inc_ref(v_measureToken_254_);
v___x_259_ = lp_loam_Loam_Persistence_validToken(v_measureToken_254_);
if (v___x_259_ == 0)
{
lean_object* v___x_260_; 
lean_dec_ref(v_quantaText_255_);
lean_dec_ref(v_measureToken_254_);
lean_dec_ref(v_locusToken_253_);
lean_dec_ref(v_keyToken_252_);
v___x_260_ = lean_box(0);
return v___x_260_;
}
else
{
lean_object* v___x_261_; lean_object* v___x_262_; lean_object* v___x_263_; lean_object* v___x_264_; 
v___x_261_ = lean_unsigned_to_nat(0u);
v___x_262_ = lean_string_utf8_byte_size(v_quantaText_255_);
v___x_263_ = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(v___x_263_, 0, v_quantaText_255_);
lean_ctor_set(v___x_263_, 1, v___x_261_);
lean_ctor_set(v___x_263_, 2, v___x_262_);
v___x_264_ = l_String_Slice_toInt_x3f(v___x_263_);
if (lean_obj_tag(v___x_264_) == 0)
{
lean_object* v___x_265_; 
lean_dec_ref(v_measureToken_254_);
lean_dec_ref(v_locusToken_253_);
lean_dec_ref(v_keyToken_252_);
v___x_265_ = lean_box(0);
return v___x_265_;
}
else
{
lean_object* v_val_266_; lean_object* v___x_268_; uint8_t v_isShared_269_; uint8_t v_isSharedCheck_274_; 
v_val_266_ = lean_ctor_get(v___x_264_, 0);
v_isSharedCheck_274_ = !lean_is_exclusive(v___x_264_);
if (v_isSharedCheck_274_ == 0)
{
v___x_268_ = v___x_264_;
v_isShared_269_ = v_isSharedCheck_274_;
goto v_resetjp_267_;
}
else
{
lean_inc(v_val_266_);
lean_dec(v___x_264_);
v___x_268_ = lean_box(0);
v_isShared_269_ = v_isSharedCheck_274_;
goto v_resetjp_267_;
}
v_resetjp_267_:
{
lean_object* v___x_270_; lean_object* v___x_272_; 
v___x_270_ = lp_loam_Loam_Core_Effect_ofQuantity(v_keyToken_252_, v_locusToken_253_, v_measureToken_254_, v_val_266_);
if (v_isShared_269_ == 0)
{
lean_ctor_set(v___x_268_, 0, v___x_270_);
v___x_272_ = v___x_268_;
goto v_reusejp_271_;
}
else
{
lean_object* v_reuseFailAlloc_273_; 
v_reuseFailAlloc_273_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_273_, 0, v___x_270_);
v___x_272_ = v_reuseFailAlloc_273_;
goto v_reusejp_271_;
}
v_reusejp_271_:
{
return v___x_272_;
}
}
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEffectRow_x3f(lean_object* v_row_277_){
_start:
{
lean_object* v___x_278_; lean_object* v___x_279_; lean_object* v___x_280_; lean_object* v___x_281_; 
v___x_278_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__2));
v___x_279_ = lean_unsigned_to_nat(0u);
v___x_280_ = lean_box(0);
v___x_281_ = l_String_splitOnAux(v_row_277_, v___x_278_, v___x_279_, v___x_279_, v___x_279_, v___x_280_);
if (lean_obj_tag(v___x_281_) == 1)
{
lean_object* v_tail_282_; 
v_tail_282_ = lean_ctor_get(v___x_281_, 1);
lean_inc(v_tail_282_);
if (lean_obj_tag(v_tail_282_) == 1)
{
lean_object* v_tail_283_; 
v_tail_283_ = lean_ctor_get(v_tail_282_, 1);
lean_inc(v_tail_283_);
if (lean_obj_tag(v_tail_283_) == 1)
{
lean_object* v_tail_284_; 
v_tail_284_ = lean_ctor_get(v_tail_283_, 1);
lean_inc(v_tail_284_);
if (lean_obj_tag(v_tail_284_) == 1)
{
lean_object* v_tail_285_; 
v_tail_285_ = lean_ctor_get(v_tail_284_, 1);
if (lean_obj_tag(v_tail_285_) == 0)
{
lean_object* v_head_286_; lean_object* v_head_287_; lean_object* v_head_288_; lean_object* v_head_289_; lean_object* v___x_290_; 
v_head_286_ = lean_ctor_get(v___x_281_, 0);
lean_inc(v_head_286_);
lean_dec_ref_known(v___x_281_, 2);
v_head_287_ = lean_ctor_get(v_tail_282_, 0);
lean_inc(v_head_287_);
lean_dec_ref_known(v_tail_282_, 2);
v_head_288_ = lean_ctor_get(v_tail_283_, 0);
lean_inc(v_head_288_);
lean_dec_ref_known(v_tail_283_, 2);
v_head_289_ = lean_ctor_get(v_tail_284_, 0);
lean_inc(v_head_289_);
lean_dec_ref_known(v_tail_284_, 2);
v___x_290_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEffectFields_x3f(v_head_286_, v_head_287_, v_head_288_, v_head_289_);
return v___x_290_;
}
else
{
lean_object* v___x_291_; 
lean_dec_ref_known(v_tail_284_, 2);
lean_dec_ref_known(v_tail_283_, 2);
lean_dec_ref_known(v_tail_282_, 2);
lean_dec_ref_known(v___x_281_, 2);
v___x_291_ = lean_box(0);
return v___x_291_;
}
}
else
{
lean_object* v___x_292_; 
lean_dec(v_tail_284_);
lean_dec_ref_known(v_tail_283_, 2);
lean_dec_ref_known(v_tail_282_, 2);
lean_dec_ref_known(v___x_281_, 2);
v___x_292_ = lean_box(0);
return v___x_292_;
}
}
else
{
lean_object* v___x_293_; 
lean_dec_ref_known(v_tail_282_, 2);
lean_dec(v_tail_283_);
lean_dec_ref_known(v___x_281_, 2);
v___x_293_ = lean_box(0);
return v___x_293_;
}
}
else
{
lean_object* v___x_294_; 
lean_dec(v_tail_282_);
lean_dec_ref_known(v___x_281_, 2);
v___x_294_ = lean_box(0);
return v___x_294_;
}
}
else
{
lean_object* v___x_295_; 
lean_dec(v___x_281_);
v___x_295_ = lean_box(0);
return v___x_295_;
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEffectRow_x3f___boxed(lean_object* v_row_296_){
_start:
{
lean_object* v_res_297_; 
v_res_297_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEffectRow_x3f(v_row_296_);
lean_dec_ref(v_row_296_);
return v_res_297_;
}
}
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00Loam_Persistence_encodeEvent_x3f_spec__0(lean_object* v_x_298_, lean_object* v_x_299_){
_start:
{
if (lean_obj_tag(v_x_298_) == 0)
{
lean_object* v___x_300_; lean_object* v___x_301_; 
v___x_300_ = l_List_reverse___redArg(v_x_299_);
v___x_301_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_301_, 0, v___x_300_);
return v___x_301_;
}
else
{
lean_object* v_head_302_; lean_object* v_tail_303_; lean_object* v___x_305_; uint8_t v_isShared_306_; uint8_t v_isSharedCheck_314_; 
v_head_302_ = lean_ctor_get(v_x_298_, 0);
v_tail_303_ = lean_ctor_get(v_x_298_, 1);
v_isSharedCheck_314_ = !lean_is_exclusive(v_x_298_);
if (v_isSharedCheck_314_ == 0)
{
v___x_305_ = v_x_298_;
v_isShared_306_ = v_isSharedCheck_314_;
goto v_resetjp_304_;
}
else
{
lean_inc(v_tail_303_);
lean_inc(v_head_302_);
lean_dec(v_x_298_);
v___x_305_ = lean_box(0);
v_isShared_306_ = v_isSharedCheck_314_;
goto v_resetjp_304_;
}
v_resetjp_304_:
{
lean_object* v___x_307_; 
v___x_307_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeEffectRow_x3f(v_head_302_);
if (lean_obj_tag(v___x_307_) == 0)
{
lean_object* v___x_308_; 
lean_del_object(v___x_305_);
lean_dec(v_tail_303_);
lean_dec(v_x_299_);
v___x_308_ = lean_box(0);
return v___x_308_;
}
else
{
lean_object* v_val_309_; lean_object* v___x_311_; 
v_val_309_ = lean_ctor_get(v___x_307_, 0);
lean_inc(v_val_309_);
lean_dec_ref_known(v___x_307_, 1);
if (v_isShared_306_ == 0)
{
lean_ctor_set(v___x_305_, 1, v_x_299_);
lean_ctor_set(v___x_305_, 0, v_val_309_);
v___x_311_ = v___x_305_;
goto v_reusejp_310_;
}
else
{
lean_object* v_reuseFailAlloc_313_; 
v_reuseFailAlloc_313_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_313_, 0, v_val_309_);
lean_ctor_set(v_reuseFailAlloc_313_, 1, v_x_299_);
v___x_311_ = v_reuseFailAlloc_313_;
goto v_reusejp_310_;
}
v_reusejp_310_:
{
v_x_298_ = v_tail_303_;
v_x_299_ = v___x_311_;
goto _start;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_encodeEvent_x3f(lean_object* v_event_315_){
_start:
{
lean_object* v_id_316_; lean_object* v_effects_317_; lean_object* v___x_319_; uint8_t v_isShared_320_; uint8_t v_isSharedCheck_343_; 
v_id_316_ = lean_ctor_get(v_event_315_, 0);
v_effects_317_ = lean_ctor_get(v_event_315_, 1);
v_isSharedCheck_343_ = !lean_is_exclusive(v_event_315_);
if (v_isSharedCheck_343_ == 0)
{
v___x_319_ = v_event_315_;
v_isShared_320_ = v_isSharedCheck_343_;
goto v_resetjp_318_;
}
else
{
lean_inc(v_effects_317_);
lean_inc(v_id_316_);
lean_dec(v_event_315_);
v___x_319_ = lean_box(0);
v_isShared_320_ = v_isSharedCheck_343_;
goto v_resetjp_318_;
}
v_resetjp_318_:
{
uint8_t v___x_321_; 
lean_inc_ref(v_id_316_);
v___x_321_ = lp_loam_Loam_Persistence_validToken(v_id_316_);
if (v___x_321_ == 0)
{
lean_object* v___x_322_; 
lean_del_object(v___x_319_);
lean_dec(v_effects_317_);
lean_dec_ref(v_id_316_);
v___x_322_ = lean_box(0);
return v___x_322_;
}
else
{
lean_object* v___x_323_; lean_object* v___x_324_; 
v___x_323_ = lean_box(0);
v___x_324_ = lp_loam_List_mapM_loop___at___00Loam_Persistence_encodeEvent_x3f_spec__0(v_effects_317_, v___x_323_);
if (lean_obj_tag(v___x_324_) == 0)
{
lean_object* v___x_325_; 
lean_del_object(v___x_319_);
lean_dec_ref(v_id_316_);
v___x_325_ = lean_box(0);
return v___x_325_;
}
else
{
lean_object* v_val_326_; lean_object* v___x_328_; uint8_t v_isShared_329_; uint8_t v_isSharedCheck_342_; 
v_val_326_ = lean_ctor_get(v___x_324_, 0);
v_isSharedCheck_342_ = !lean_is_exclusive(v___x_324_);
if (v_isSharedCheck_342_ == 0)
{
v___x_328_ = v___x_324_;
v_isShared_329_ = v_isSharedCheck_342_;
goto v_resetjp_327_;
}
else
{
lean_inc(v_val_326_);
lean_dec(v___x_324_);
v___x_328_ = lean_box(0);
v_isShared_329_ = v_isSharedCheck_342_;
goto v_resetjp_327_;
}
v_resetjp_327_:
{
lean_object* v___x_330_; lean_object* v___x_331_; lean_object* v___x_333_; 
v___x_330_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__0));
v___x_331_ = ((lean_object*)(lp_loam_Loam_Persistence_eventHeader___closed__0));
if (v_isShared_320_ == 0)
{
lean_ctor_set_tag(v___x_319_, 1);
lean_ctor_set(v___x_319_, 1, v___x_323_);
v___x_333_ = v___x_319_;
goto v_reusejp_332_;
}
else
{
lean_object* v_reuseFailAlloc_341_; 
v_reuseFailAlloc_341_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_341_, 0, v_id_316_);
lean_ctor_set(v_reuseFailAlloc_341_, 1, v___x_323_);
v___x_333_ = v_reuseFailAlloc_341_;
goto v_reusejp_332_;
}
v_reusejp_332_:
{
lean_object* v___x_334_; lean_object* v___x_335_; lean_object* v___x_336_; lean_object* v___x_337_; lean_object* v___x_339_; 
v___x_334_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v___x_334_, 0, v___x_331_);
lean_ctor_set(v___x_334_, 1, v___x_333_);
v___x_335_ = l_List_appendTR___redArg(v___x_334_, v_val_326_);
v___x_336_ = l_String_intercalate(v___x_330_, v___x_335_);
v___x_337_ = lean_string_append(v___x_336_, v___x_330_);
if (v_isShared_329_ == 0)
{
lean_ctor_set(v___x_328_, 0, v___x_337_);
v___x_339_ = v___x_328_;
goto v_reusejp_338_;
}
else
{
lean_object* v_reuseFailAlloc_340_; 
v_reuseFailAlloc_340_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_340_, 0, v___x_337_);
v___x_339_ = v_reuseFailAlloc_340_;
goto v_reusejp_338_;
}
v_reusejp_338_:
{
return v___x_339_;
}
}
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00Loam_Persistence_decodeEvent_x3f_spec__0(lean_object* v_x_344_, lean_object* v_x_345_){
_start:
{
if (lean_obj_tag(v_x_344_) == 0)
{
lean_object* v___x_346_; lean_object* v___x_347_; 
v___x_346_ = l_List_reverse___redArg(v_x_345_);
v___x_347_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_347_, 0, v___x_346_);
return v___x_347_;
}
else
{
lean_object* v_head_348_; lean_object* v_tail_349_; lean_object* v___x_351_; uint8_t v_isShared_352_; uint8_t v_isSharedCheck_360_; 
v_head_348_ = lean_ctor_get(v_x_344_, 0);
v_tail_349_ = lean_ctor_get(v_x_344_, 1);
v_isSharedCheck_360_ = !lean_is_exclusive(v_x_344_);
if (v_isSharedCheck_360_ == 0)
{
v___x_351_ = v_x_344_;
v_isShared_352_ = v_isSharedCheck_360_;
goto v_resetjp_350_;
}
else
{
lean_inc(v_tail_349_);
lean_inc(v_head_348_);
lean_dec(v_x_344_);
v___x_351_ = lean_box(0);
v_isShared_352_ = v_isSharedCheck_360_;
goto v_resetjp_350_;
}
v_resetjp_350_:
{
lean_object* v___x_353_; 
v___x_353_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEffectRow_x3f(v_head_348_);
lean_dec(v_head_348_);
if (lean_obj_tag(v___x_353_) == 0)
{
lean_object* v___x_354_; 
lean_del_object(v___x_351_);
lean_dec(v_tail_349_);
lean_dec(v_x_345_);
v___x_354_ = lean_box(0);
return v___x_354_;
}
else
{
lean_object* v_val_355_; lean_object* v___x_357_; 
v_val_355_ = lean_ctor_get(v___x_353_, 0);
lean_inc(v_val_355_);
lean_dec_ref_known(v___x_353_, 1);
if (v_isShared_352_ == 0)
{
lean_ctor_set(v___x_351_, 1, v_x_345_);
lean_ctor_set(v___x_351_, 0, v_val_355_);
v___x_357_ = v___x_351_;
goto v_reusejp_356_;
}
else
{
lean_object* v_reuseFailAlloc_359_; 
v_reuseFailAlloc_359_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_359_, 0, v_val_355_);
lean_ctor_set(v_reuseFailAlloc_359_, 1, v_x_345_);
v___x_357_ = v_reuseFailAlloc_359_;
goto v_reusejp_356_;
}
v_reusejp_356_:
{
v_x_344_ = v_tail_349_;
v_x_345_ = v___x_357_;
goto _start;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decodeEvent_x3f(lean_object* v_input_361_){
_start:
{
lean_object* v___x_362_; lean_object* v___x_363_; lean_object* v___x_364_; lean_object* v___x_365_; 
v___x_362_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__0));
v___x_363_ = lean_unsigned_to_nat(0u);
v___x_364_ = lean_box(0);
v___x_365_ = l_String_splitOnAux(v_input_361_, v___x_362_, v___x_363_, v___x_363_, v___x_363_, v___x_364_);
if (lean_obj_tag(v___x_365_) == 1)
{
lean_object* v_tail_366_; 
v_tail_366_ = lean_ctor_get(v___x_365_, 1);
lean_inc(v_tail_366_);
if (lean_obj_tag(v_tail_366_) == 1)
{
lean_object* v_head_367_; lean_object* v_head_368_; lean_object* v_tail_369_; lean_object* v___x_370_; uint8_t v___y_372_; lean_object* v___x_385_; uint8_t v___x_386_; 
v_head_367_ = lean_ctor_get(v___x_365_, 0);
lean_inc(v_head_367_);
lean_dec_ref_known(v___x_365_, 2);
v_head_368_ = lean_ctor_get(v_tail_366_, 0);
lean_inc(v_head_368_);
v_tail_369_ = lean_ctor_get(v_tail_366_, 1);
lean_inc(v_tail_369_);
lean_dec_ref_known(v_tail_366_, 2);
v___x_370_ = ((lean_object*)(lp_loam_Loam_Persistence_decode_x3f___closed__0));
v___x_385_ = ((lean_object*)(lp_loam_Loam_Persistence_eventHeader___closed__0));
v___x_386_ = lean_string_dec_eq(v_head_367_, v___x_385_);
lean_dec(v_head_367_);
if (v___x_386_ == 0)
{
v___y_372_ = v___x_386_;
goto v___jp_371_;
}
else
{
uint8_t v___x_387_; 
lean_inc(v_head_368_);
v___x_387_ = lp_loam_Loam_Persistence_validToken(v_head_368_);
v___y_372_ = v___x_387_;
goto v___jp_371_;
}
v___jp_371_:
{
if (v___y_372_ == 0)
{
lean_object* v___x_373_; 
lean_dec(v_tail_369_);
lean_dec(v_head_368_);
v___x_373_ = lean_box(0);
return v___x_373_;
}
else
{
lean_object* v___x_374_; 
v___x_374_ = l_List_reverse___redArg(v_tail_369_);
if (lean_obj_tag(v___x_374_) == 1)
{
lean_object* v_head_375_; lean_object* v_tail_376_; uint8_t v___x_377_; 
v_head_375_ = lean_ctor_get(v___x_374_, 0);
lean_inc(v_head_375_);
v_tail_376_ = lean_ctor_get(v___x_374_, 1);
lean_inc(v_tail_376_);
lean_dec_ref_known(v___x_374_, 2);
v___x_377_ = lean_string_dec_eq(v_head_375_, v___x_370_);
lean_dec(v_head_375_);
if (v___x_377_ == 0)
{
lean_object* v___x_378_; 
lean_dec(v_tail_376_);
lean_dec(v_head_368_);
v___x_378_ = lean_box(0);
return v___x_378_;
}
else
{
lean_object* v___x_379_; lean_object* v___x_380_; 
v___x_379_ = l_List_reverse___redArg(v_tail_376_);
v___x_380_ = lp_loam_List_mapM_loop___at___00Loam_Persistence_decodeEvent_x3f_spec__0(v___x_379_, v___x_364_);
if (lean_obj_tag(v___x_380_) == 0)
{
lean_object* v___x_381_; 
lean_dec(v_head_368_);
v___x_381_ = lean_box(0);
return v___x_381_;
}
else
{
lean_object* v_val_382_; lean_object* v___x_383_; 
v_val_382_ = lean_ctor_get(v___x_380_, 0);
lean_inc(v_val_382_);
lean_dec_ref_known(v___x_380_, 1);
v___x_383_ = lp_loam_Loam_Core_Event_ofEffects_x3f(v_head_368_, v_val_382_);
return v___x_383_;
}
}
}
else
{
lean_object* v___x_384_; 
lean_dec(v___x_374_);
lean_dec(v_head_368_);
v___x_384_ = lean_box(0);
return v___x_384_;
}
}
}
}
else
{
lean_object* v___x_388_; 
lean_dec_ref_known(v___x_365_, 2);
lean_dec(v_tail_366_);
v___x_388_ = lean_box(0);
return v___x_388_;
}
}
else
{
lean_object* v___x_389_; 
lean_dec(v___x_365_);
v___x_389_ = lean_box(0);
return v___x_389_;
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decodeEvent_x3f___boxed(lean_object* v_input_390_){
_start:
{
lean_object* v_res_391_; 
v_res_391_ = lp_loam_Loam_Persistence_decodeEvent_x3f(v_input_390_);
lean_dec_ref(v_input_390_);
return v_res_391_;
}
}
LEAN_EXPORT lean_object* lp_loam_List_mapTR_loop___at___00__private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f_spec__0(lean_object* v_a_393_, lean_object* v_a_394_){
_start:
{
if (lean_obj_tag(v_a_393_) == 0)
{
lean_object* v___x_395_; 
v___x_395_ = l_List_reverse___redArg(v_a_394_);
return v___x_395_;
}
else
{
lean_object* v_head_396_; lean_object* v_tail_397_; lean_object* v___x_399_; uint8_t v_isShared_400_; uint8_t v_isSharedCheck_407_; 
v_head_396_ = lean_ctor_get(v_a_393_, 0);
v_tail_397_ = lean_ctor_get(v_a_393_, 1);
v_isSharedCheck_407_ = !lean_is_exclusive(v_a_393_);
if (v_isSharedCheck_407_ == 0)
{
v___x_399_ = v_a_393_;
v_isShared_400_ = v_isSharedCheck_407_;
goto v_resetjp_398_;
}
else
{
lean_inc(v_tail_397_);
lean_inc(v_head_396_);
lean_dec(v_a_393_);
v___x_399_ = lean_box(0);
v_isShared_400_ = v_isSharedCheck_407_;
goto v_resetjp_398_;
}
v_resetjp_398_:
{
lean_object* v___x_401_; lean_object* v___x_402_; lean_object* v___x_404_; 
v___x_401_ = ((lean_object*)(lp_loam_List_mapTR_loop___at___00__private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f_spec__0___closed__0));
v___x_402_ = lean_string_append(v___x_401_, v_head_396_);
lean_dec(v_head_396_);
if (v_isShared_400_ == 0)
{
lean_ctor_set(v___x_399_, 1, v_a_394_);
lean_ctor_set(v___x_399_, 0, v___x_402_);
v___x_404_ = v___x_399_;
goto v_reusejp_403_;
}
else
{
lean_object* v_reuseFailAlloc_406_; 
v_reuseFailAlloc_406_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_406_, 0, v___x_402_);
lean_ctor_set(v_reuseFailAlloc_406_, 1, v_a_394_);
v___x_404_ = v_reuseFailAlloc_406_;
goto v_reusejp_403_;
}
v_reusejp_403_:
{
v_a_393_ = v_tail_397_;
v_a_394_ = v___x_404_;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f(lean_object* v_event_409_){
_start:
{
lean_object* v_id_410_; lean_object* v_effects_411_; lean_object* v___x_413_; uint8_t v_isShared_414_; uint8_t v_isSharedCheck_433_; 
v_id_410_ = lean_ctor_get(v_event_409_, 0);
v_effects_411_ = lean_ctor_get(v_event_409_, 1);
v_isSharedCheck_433_ = !lean_is_exclusive(v_event_409_);
if (v_isSharedCheck_433_ == 0)
{
v___x_413_ = v_event_409_;
v_isShared_414_ = v_isSharedCheck_433_;
goto v_resetjp_412_;
}
else
{
lean_inc(v_effects_411_);
lean_inc(v_id_410_);
lean_dec(v_event_409_);
v___x_413_ = lean_box(0);
v_isShared_414_ = v_isSharedCheck_433_;
goto v_resetjp_412_;
}
v_resetjp_412_:
{
uint8_t v___x_415_; 
lean_inc_ref(v_id_410_);
v___x_415_ = lp_loam_Loam_Persistence_validToken(v_id_410_);
if (v___x_415_ == 0)
{
lean_object* v___x_416_; 
lean_del_object(v___x_413_);
lean_dec(v_effects_411_);
lean_dec_ref(v_id_410_);
v___x_416_ = lean_box(0);
return v___x_416_;
}
else
{
lean_object* v___x_417_; lean_object* v___x_418_; 
v___x_417_ = lean_box(0);
v___x_418_ = lp_loam_List_mapM_loop___at___00Loam_Persistence_encodeEvent_x3f_spec__0(v_effects_411_, v___x_417_);
if (lean_obj_tag(v___x_418_) == 0)
{
lean_del_object(v___x_413_);
lean_dec_ref(v_id_410_);
return v___x_418_;
}
else
{
lean_object* v_val_419_; lean_object* v___x_421_; uint8_t v_isShared_422_; uint8_t v_isSharedCheck_432_; 
v_val_419_ = lean_ctor_get(v___x_418_, 0);
v_isSharedCheck_432_ = !lean_is_exclusive(v___x_418_);
if (v_isSharedCheck_432_ == 0)
{
v___x_421_ = v___x_418_;
v_isShared_422_ = v_isSharedCheck_432_;
goto v_resetjp_420_;
}
else
{
lean_inc(v_val_419_);
lean_dec(v___x_418_);
v___x_421_ = lean_box(0);
v_isShared_422_ = v_isSharedCheck_432_;
goto v_resetjp_420_;
}
v_resetjp_420_:
{
lean_object* v___x_423_; lean_object* v___x_424_; lean_object* v___x_425_; lean_object* v___x_427_; 
v___x_423_ = ((lean_object*)(lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f___closed__0));
v___x_424_ = lean_string_append(v___x_423_, v_id_410_);
lean_dec_ref(v_id_410_);
v___x_425_ = lp_loam_List_mapTR_loop___at___00__private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f_spec__0(v_val_419_, v___x_417_);
if (v_isShared_414_ == 0)
{
lean_ctor_set_tag(v___x_413_, 1);
lean_ctor_set(v___x_413_, 1, v___x_425_);
lean_ctor_set(v___x_413_, 0, v___x_424_);
v___x_427_ = v___x_413_;
goto v_reusejp_426_;
}
else
{
lean_object* v_reuseFailAlloc_431_; 
v_reuseFailAlloc_431_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_431_, 0, v___x_424_);
lean_ctor_set(v_reuseFailAlloc_431_, 1, v___x_425_);
v___x_427_ = v_reuseFailAlloc_431_;
goto v_reusejp_426_;
}
v_reusejp_426_:
{
lean_object* v___x_429_; 
if (v_isShared_422_ == 0)
{
lean_ctor_set(v___x_421_, 0, v___x_427_);
v___x_429_ = v___x_421_;
goto v_reusejp_428_;
}
else
{
lean_object* v_reuseFailAlloc_430_; 
v_reuseFailAlloc_430_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_430_, 0, v___x_427_);
v___x_429_ = v_reuseFailAlloc_430_;
goto v_reusejp_428_;
}
v_reusejp_428_:
{
return v___x_429_;
}
}
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEffectRow_x3f(lean_object* v_row_435_){
_start:
{
lean_object* v___x_436_; lean_object* v___x_437_; lean_object* v___x_438_; lean_object* v___x_439_; 
v___x_436_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__2));
v___x_437_ = lean_unsigned_to_nat(0u);
v___x_438_ = lean_box(0);
v___x_439_ = l_String_splitOnAux(v_row_435_, v___x_436_, v___x_437_, v___x_437_, v___x_437_, v___x_438_);
if (lean_obj_tag(v___x_439_) == 1)
{
lean_object* v_head_440_; lean_object* v_tail_441_; lean_object* v___x_442_; uint8_t v___x_443_; 
v_head_440_ = lean_ctor_get(v___x_439_, 0);
lean_inc(v_head_440_);
v_tail_441_ = lean_ctor_get(v___x_439_, 1);
lean_inc(v_tail_441_);
lean_dec_ref_known(v___x_439_, 2);
v___x_442_ = ((lean_object*)(lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEffectRow_x3f___closed__0));
v___x_443_ = lean_string_dec_eq(v_head_440_, v___x_442_);
lean_dec(v_head_440_);
if (v___x_443_ == 0)
{
lean_object* v___x_444_; 
lean_dec(v_tail_441_);
v___x_444_ = lean_box(0);
return v___x_444_;
}
else
{
if (lean_obj_tag(v_tail_441_) == 1)
{
lean_object* v_tail_445_; 
v_tail_445_ = lean_ctor_get(v_tail_441_, 1);
lean_inc(v_tail_445_);
if (lean_obj_tag(v_tail_445_) == 1)
{
lean_object* v_tail_446_; 
v_tail_446_ = lean_ctor_get(v_tail_445_, 1);
lean_inc(v_tail_446_);
if (lean_obj_tag(v_tail_446_) == 1)
{
lean_object* v_tail_447_; 
v_tail_447_ = lean_ctor_get(v_tail_446_, 1);
lean_inc(v_tail_447_);
if (lean_obj_tag(v_tail_447_) == 1)
{
lean_object* v_tail_448_; 
v_tail_448_ = lean_ctor_get(v_tail_447_, 1);
if (lean_obj_tag(v_tail_448_) == 0)
{
lean_object* v_head_449_; lean_object* v_head_450_; lean_object* v_head_451_; lean_object* v_head_452_; lean_object* v___x_453_; 
v_head_449_ = lean_ctor_get(v_tail_441_, 0);
lean_inc(v_head_449_);
lean_dec_ref_known(v_tail_441_, 2);
v_head_450_ = lean_ctor_get(v_tail_445_, 0);
lean_inc(v_head_450_);
lean_dec_ref_known(v_tail_445_, 2);
v_head_451_ = lean_ctor_get(v_tail_446_, 0);
lean_inc(v_head_451_);
lean_dec_ref_known(v_tail_446_, 2);
v_head_452_ = lean_ctor_get(v_tail_447_, 0);
lean_inc(v_head_452_);
lean_dec_ref_known(v_tail_447_, 2);
v___x_453_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEffectFields_x3f(v_head_449_, v_head_450_, v_head_451_, v_head_452_);
return v___x_453_;
}
else
{
lean_object* v___x_454_; 
lean_dec_ref_known(v_tail_447_, 2);
lean_dec_ref_known(v_tail_446_, 2);
lean_dec_ref_known(v_tail_445_, 2);
lean_dec_ref_known(v_tail_441_, 2);
v___x_454_ = lean_box(0);
return v___x_454_;
}
}
else
{
lean_object* v___x_455_; 
lean_dec(v_tail_447_);
lean_dec_ref_known(v_tail_446_, 2);
lean_dec_ref_known(v_tail_445_, 2);
lean_dec_ref_known(v_tail_441_, 2);
v___x_455_ = lean_box(0);
return v___x_455_;
}
}
else
{
lean_object* v___x_456_; 
lean_dec_ref_known(v_tail_445_, 2);
lean_dec(v_tail_446_);
lean_dec_ref_known(v_tail_441_, 2);
v___x_456_ = lean_box(0);
return v___x_456_;
}
}
else
{
lean_object* v___x_457_; 
lean_dec(v_tail_445_);
lean_dec_ref_known(v_tail_441_, 2);
v___x_457_ = lean_box(0);
return v___x_457_;
}
}
else
{
lean_object* v___x_458_; 
lean_dec(v_tail_441_);
v___x_458_ = lean_box(0);
return v___x_458_;
}
}
}
else
{
lean_object* v___x_459_; 
lean_dec(v___x_439_);
v___x_459_ = lean_box(0);
return v___x_459_;
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEffectRow_x3f___boxed(lean_object* v_row_460_){
_start:
{
lean_object* v_res_461_; 
v_res_461_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEffectRow_x3f(v_row_460_);
lean_dec_ref(v_row_460_);
return v_res_461_;
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_withoutTrailingEmpty(lean_object* v_rows_462_){
_start:
{
lean_object* v___x_463_; 
lean_inc(v_rows_462_);
v___x_463_ = l_List_reverse___redArg(v_rows_462_);
if (lean_obj_tag(v___x_463_) == 1)
{
lean_object* v_head_464_; lean_object* v_tail_465_; lean_object* v___x_466_; uint8_t v___x_467_; 
v_head_464_ = lean_ctor_get(v___x_463_, 0);
lean_inc(v_head_464_);
v_tail_465_ = lean_ctor_get(v___x_463_, 1);
lean_inc(v_tail_465_);
lean_dec_ref_known(v___x_463_, 2);
v___x_466_ = ((lean_object*)(lp_loam_Loam_Persistence_decode_x3f___closed__0));
v___x_467_ = lean_string_dec_eq(v_head_464_, v___x_466_);
lean_dec(v_head_464_);
if (v___x_467_ == 0)
{
lean_dec(v_tail_465_);
return v_rows_462_;
}
else
{
lean_object* v___x_468_; 
lean_dec(v_rows_462_);
v___x_468_ = l_List_reverse___redArg(v_tail_465_);
return v___x_468_;
}
}
else
{
lean_dec(v___x_463_);
return v_rows_462_;
}
}
}
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00__private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEventChunk_x3f_spec__0(lean_object* v_x_469_, lean_object* v_x_470_){
_start:
{
if (lean_obj_tag(v_x_469_) == 0)
{
lean_object* v___x_471_; lean_object* v___x_472_; 
v___x_471_ = l_List_reverse___redArg(v_x_470_);
v___x_472_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_472_, 0, v___x_471_);
return v___x_472_;
}
else
{
lean_object* v_head_473_; lean_object* v_tail_474_; lean_object* v___x_476_; uint8_t v_isShared_477_; uint8_t v_isSharedCheck_485_; 
v_head_473_ = lean_ctor_get(v_x_469_, 0);
v_tail_474_ = lean_ctor_get(v_x_469_, 1);
v_isSharedCheck_485_ = !lean_is_exclusive(v_x_469_);
if (v_isSharedCheck_485_ == 0)
{
v___x_476_ = v_x_469_;
v_isShared_477_ = v_isSharedCheck_485_;
goto v_resetjp_475_;
}
else
{
lean_inc(v_tail_474_);
lean_inc(v_head_473_);
lean_dec(v_x_469_);
v___x_476_ = lean_box(0);
v_isShared_477_ = v_isSharedCheck_485_;
goto v_resetjp_475_;
}
v_resetjp_475_:
{
lean_object* v___x_478_; 
v___x_478_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEffectRow_x3f(v_head_473_);
lean_dec(v_head_473_);
if (lean_obj_tag(v___x_478_) == 0)
{
lean_object* v___x_479_; 
lean_del_object(v___x_476_);
lean_dec(v_tail_474_);
lean_dec(v_x_470_);
v___x_479_ = lean_box(0);
return v___x_479_;
}
else
{
lean_object* v_val_480_; lean_object* v___x_482_; 
v_val_480_ = lean_ctor_get(v___x_478_, 0);
lean_inc(v_val_480_);
lean_dec_ref_known(v___x_478_, 1);
if (v_isShared_477_ == 0)
{
lean_ctor_set(v___x_476_, 1, v_x_470_);
lean_ctor_set(v___x_476_, 0, v_val_480_);
v___x_482_ = v___x_476_;
goto v_reusejp_481_;
}
else
{
lean_object* v_reuseFailAlloc_484_; 
v_reuseFailAlloc_484_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_484_, 0, v_val_480_);
lean_ctor_set(v_reuseFailAlloc_484_, 1, v_x_470_);
v___x_482_ = v_reuseFailAlloc_484_;
goto v_reusejp_481_;
}
v_reusejp_481_:
{
v_x_469_ = v_tail_474_;
v_x_470_ = v___x_482_;
goto _start;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEventChunk_x3f(lean_object* v_chunk_486_){
_start:
{
lean_object* v___x_487_; lean_object* v___x_488_; lean_object* v___x_489_; lean_object* v___x_490_; 
v___x_487_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__0));
v___x_488_ = lean_unsigned_to_nat(0u);
v___x_489_ = lean_box(0);
v___x_490_ = l_String_splitOnAux(v_chunk_486_, v___x_487_, v___x_488_, v___x_488_, v___x_488_, v___x_489_);
if (lean_obj_tag(v___x_490_) == 1)
{
lean_object* v_head_491_; lean_object* v_tail_492_; uint8_t v___x_493_; 
v_head_491_ = lean_ctor_get(v___x_490_, 0);
lean_inc_n(v_head_491_, 2);
v_tail_492_ = lean_ctor_get(v___x_490_, 1);
lean_inc(v_tail_492_);
lean_dec_ref_known(v___x_490_, 2);
v___x_493_ = lp_loam_Loam_Persistence_validToken(v_head_491_);
if (v___x_493_ == 0)
{
lean_object* v___x_494_; 
lean_dec(v_tail_492_);
lean_dec(v_head_491_);
v___x_494_ = lean_box(0);
return v___x_494_;
}
else
{
lean_object* v___x_495_; lean_object* v___x_496_; 
v___x_495_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_withoutTrailingEmpty(v_tail_492_);
v___x_496_ = lp_loam_List_mapM_loop___at___00__private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEventChunk_x3f_spec__0(v___x_495_, v___x_489_);
if (lean_obj_tag(v___x_496_) == 0)
{
lean_object* v___x_497_; 
lean_dec(v_head_491_);
v___x_497_ = lean_box(0);
return v___x_497_;
}
else
{
lean_object* v_val_498_; lean_object* v___x_499_; 
v_val_498_ = lean_ctor_get(v___x_496_, 0);
lean_inc(v_val_498_);
lean_dec_ref_known(v___x_496_, 1);
v___x_499_ = lp_loam_Loam_Core_Event_ofEffects_x3f(v_head_491_, v_val_498_);
return v___x_499_;
}
}
}
else
{
lean_object* v___x_500_; 
lean_dec(v___x_490_);
v___x_500_ = lean_box(0);
return v___x_500_;
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEventChunk_x3f___boxed(lean_object* v_chunk_501_){
_start:
{
lean_object* v_res_502_; 
v_res_502_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEventChunk_x3f(v_chunk_501_);
lean_dec_ref(v_chunk_501_);
return v_res_502_;
}
}
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00Loam_Persistence_encodeEventMemory_x3f_spec__0(lean_object* v_x_503_, lean_object* v_x_504_){
_start:
{
if (lean_obj_tag(v_x_503_) == 0)
{
lean_object* v___x_505_; lean_object* v___x_506_; 
v___x_505_ = l_List_reverse___redArg(v_x_504_);
v___x_506_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_506_, 0, v___x_505_);
return v___x_506_;
}
else
{
lean_object* v_head_507_; lean_object* v_tail_508_; lean_object* v___x_510_; uint8_t v_isShared_511_; uint8_t v_isSharedCheck_519_; 
v_head_507_ = lean_ctor_get(v_x_503_, 0);
v_tail_508_ = lean_ctor_get(v_x_503_, 1);
v_isSharedCheck_519_ = !lean_is_exclusive(v_x_503_);
if (v_isSharedCheck_519_ == 0)
{
v___x_510_ = v_x_503_;
v_isShared_511_ = v_isSharedCheck_519_;
goto v_resetjp_509_;
}
else
{
lean_inc(v_tail_508_);
lean_inc(v_head_507_);
lean_dec(v_x_503_);
v___x_510_ = lean_box(0);
v_isShared_511_ = v_isSharedCheck_519_;
goto v_resetjp_509_;
}
v_resetjp_509_:
{
lean_object* v___x_512_; 
v___x_512_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeMemoryEventLines_x3f(v_head_507_);
if (lean_obj_tag(v___x_512_) == 0)
{
lean_object* v___x_513_; 
lean_del_object(v___x_510_);
lean_dec(v_tail_508_);
lean_dec(v_x_504_);
v___x_513_ = lean_box(0);
return v___x_513_;
}
else
{
lean_object* v_val_514_; lean_object* v___x_516_; 
v_val_514_ = lean_ctor_get(v___x_512_, 0);
lean_inc(v_val_514_);
lean_dec_ref_known(v___x_512_, 1);
if (v_isShared_511_ == 0)
{
lean_ctor_set(v___x_510_, 1, v_x_504_);
lean_ctor_set(v___x_510_, 0, v_val_514_);
v___x_516_ = v___x_510_;
goto v_reusejp_515_;
}
else
{
lean_object* v_reuseFailAlloc_518_; 
v_reuseFailAlloc_518_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_518_, 0, v_val_514_);
lean_ctor_set(v_reuseFailAlloc_518_, 1, v_x_504_);
v___x_516_ = v_reuseFailAlloc_518_;
goto v_reusejp_515_;
}
v_reusejp_515_:
{
v_x_503_ = v_tail_508_;
v_x_504_ = v___x_516_;
goto _start;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Init_Data_List_Impl_0__List_flatMapTR_go___at___00Loam_Persistence_encodeEventMemory_x3f_spec__1(lean_object* v_a_520_, lean_object* v_a_521_){
_start:
{
if (lean_obj_tag(v_a_520_) == 0)
{
lean_object* v___x_522_; 
v___x_522_ = lean_array_to_list(v_a_521_);
return v___x_522_;
}
else
{
lean_object* v_head_523_; lean_object* v_tail_524_; lean_object* v___x_525_; 
v_head_523_ = lean_ctor_get(v_a_520_, 0);
lean_inc(v_head_523_);
v_tail_524_ = lean_ctor_get(v_a_520_, 1);
lean_inc(v_tail_524_);
lean_dec_ref_known(v_a_520_, 2);
v___x_525_ = l_List_foldl___at___00Array_appendList_spec__0___redArg(v_a_521_, v_head_523_);
v_a_520_ = v_tail_524_;
v_a_521_ = v___x_525_;
goto _start;
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_encodeEventMemory_x3f(lean_object* v_memory_529_){
_start:
{
lean_object* v___x_530_; lean_object* v___x_531_; 
v___x_530_ = lean_box(0);
v___x_531_ = lp_loam_List_mapM_loop___at___00Loam_Persistence_encodeEventMemory_x3f_spec__0(v_memory_529_, v___x_530_);
if (lean_obj_tag(v___x_531_) == 0)
{
lean_object* v___x_532_; 
v___x_532_ = lean_box(0);
return v___x_532_;
}
else
{
lean_object* v_val_533_; lean_object* v___x_535_; uint8_t v_isShared_536_; uint8_t v_isSharedCheck_547_; 
v_val_533_ = lean_ctor_get(v___x_531_, 0);
v_isSharedCheck_547_ = !lean_is_exclusive(v___x_531_);
if (v_isSharedCheck_547_ == 0)
{
v___x_535_ = v___x_531_;
v_isShared_536_ = v_isSharedCheck_547_;
goto v_resetjp_534_;
}
else
{
lean_inc(v_val_533_);
lean_dec(v___x_531_);
v___x_535_ = lean_box(0);
v_isShared_536_ = v_isSharedCheck_547_;
goto v_resetjp_534_;
}
v_resetjp_534_:
{
lean_object* v___x_537_; lean_object* v___x_538_; lean_object* v___x_539_; lean_object* v___x_540_; lean_object* v___x_541_; lean_object* v___x_542_; lean_object* v___x_543_; lean_object* v___x_545_; 
v___x_537_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__0));
v___x_538_ = ((lean_object*)(lp_loam_Loam_Persistence_eventMemoryHeader___closed__0));
v___x_539_ = ((lean_object*)(lp_loam_Loam_Persistence_encodeEventMemory_x3f___closed__0));
v___x_540_ = lp_loam___private_Init_Data_List_Impl_0__List_flatMapTR_go___at___00Loam_Persistence_encodeEventMemory_x3f_spec__1(v_val_533_, v___x_539_);
v___x_541_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v___x_541_, 0, v___x_538_);
lean_ctor_set(v___x_541_, 1, v___x_540_);
v___x_542_ = l_String_intercalate(v___x_537_, v___x_541_);
v___x_543_ = lean_string_append(v___x_542_, v___x_537_);
if (v_isShared_536_ == 0)
{
lean_ctor_set(v___x_535_, 0, v___x_543_);
v___x_545_ = v___x_535_;
goto v_reusejp_544_;
}
else
{
lean_object* v_reuseFailAlloc_546_; 
v_reuseFailAlloc_546_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_546_, 0, v___x_543_);
v___x_545_ = v_reuseFailAlloc_546_;
goto v_reusejp_544_;
}
v_reusejp_544_:
{
return v___x_545_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00Loam_Persistence_decodeEventMemory_x3f_spec__0(lean_object* v_x_548_, lean_object* v_x_549_){
_start:
{
if (lean_obj_tag(v_x_548_) == 0)
{
lean_object* v___x_550_; lean_object* v___x_551_; 
v___x_550_ = l_List_reverse___redArg(v_x_549_);
v___x_551_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_551_, 0, v___x_550_);
return v___x_551_;
}
else
{
lean_object* v_head_552_; lean_object* v_tail_553_; lean_object* v___x_555_; uint8_t v_isShared_556_; uint8_t v_isSharedCheck_564_; 
v_head_552_ = lean_ctor_get(v_x_548_, 0);
v_tail_553_ = lean_ctor_get(v_x_548_, 1);
v_isSharedCheck_564_ = !lean_is_exclusive(v_x_548_);
if (v_isSharedCheck_564_ == 0)
{
v___x_555_ = v_x_548_;
v_isShared_556_ = v_isSharedCheck_564_;
goto v_resetjp_554_;
}
else
{
lean_inc(v_tail_553_);
lean_inc(v_head_552_);
lean_dec(v_x_548_);
v___x_555_ = lean_box(0);
v_isShared_556_ = v_isSharedCheck_564_;
goto v_resetjp_554_;
}
v_resetjp_554_:
{
lean_object* v___x_557_; 
v___x_557_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeMemoryEventChunk_x3f(v_head_552_);
lean_dec(v_head_552_);
if (lean_obj_tag(v___x_557_) == 0)
{
lean_object* v___x_558_; 
lean_del_object(v___x_555_);
lean_dec(v_tail_553_);
lean_dec(v_x_549_);
v___x_558_ = lean_box(0);
return v___x_558_;
}
else
{
lean_object* v_val_559_; lean_object* v___x_561_; 
v_val_559_ = lean_ctor_get(v___x_557_, 0);
lean_inc(v_val_559_);
lean_dec_ref_known(v___x_557_, 1);
if (v_isShared_556_ == 0)
{
lean_ctor_set(v___x_555_, 1, v_x_549_);
lean_ctor_set(v___x_555_, 0, v_val_559_);
v___x_561_ = v___x_555_;
goto v_reusejp_560_;
}
else
{
lean_object* v_reuseFailAlloc_563_; 
v_reuseFailAlloc_563_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_563_, 0, v_val_559_);
lean_ctor_set(v_reuseFailAlloc_563_, 1, v_x_549_);
v___x_561_ = v_reuseFailAlloc_563_;
goto v_reusejp_560_;
}
v_reusejp_560_:
{
v_x_548_ = v_tail_553_;
v_x_549_ = v___x_561_;
goto _start;
}
}
}
}
}
}
static lean_object* _init_lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__2(void){
_start:
{
lean_object* v___x_567_; lean_object* v___x_568_; 
v___x_567_ = lean_box(0);
v___x_568_ = lp_loam_Loam_Core_EventMemory_ofEvents_x3f(v___x_567_);
return v___x_568_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decodeEventMemory_x3f(lean_object* v_input_569_){
_start:
{
lean_object* v___x_570_; uint8_t v___x_571_; 
v___x_570_ = ((lean_object*)(lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__0));
v___x_571_ = lean_string_dec_eq(v_input_569_, v___x_570_);
if (v___x_571_ == 0)
{
lean_object* v___x_572_; lean_object* v___x_573_; lean_object* v___x_574_; lean_object* v___x_575_; lean_object* v___x_576_; 
v___x_572_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__0));
v___x_573_ = lean_unsigned_to_nat(0u);
v___x_574_ = lean_box(0);
v___x_575_ = l_String_splitOnAux(v_input_569_, v___x_572_, v___x_573_, v___x_573_, v___x_573_, v___x_574_);
v___x_576_ = l_List_reverse___redArg(v___x_575_);
if (lean_obj_tag(v___x_576_) == 1)
{
lean_object* v_head_577_; lean_object* v___x_578_; uint8_t v___x_579_; 
v_head_577_ = lean_ctor_get(v___x_576_, 0);
lean_inc(v_head_577_);
lean_dec_ref_known(v___x_576_, 2);
v___x_578_ = ((lean_object*)(lp_loam_Loam_Persistence_decode_x3f___closed__0));
v___x_579_ = lean_string_dec_eq(v_head_577_, v___x_578_);
lean_dec(v_head_577_);
if (v___x_579_ == 0)
{
lean_object* v___x_580_; 
v___x_580_ = lean_box(0);
return v___x_580_;
}
else
{
lean_object* v___x_581_; lean_object* v___x_582_; 
v___x_581_ = ((lean_object*)(lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__1));
v___x_582_ = l_String_splitOnAux(v_input_569_, v___x_581_, v___x_573_, v___x_573_, v___x_573_, v___x_574_);
if (lean_obj_tag(v___x_582_) == 1)
{
lean_object* v_head_583_; lean_object* v_tail_584_; lean_object* v___x_585_; uint8_t v___x_586_; 
v_head_583_ = lean_ctor_get(v___x_582_, 0);
lean_inc(v_head_583_);
v_tail_584_ = lean_ctor_get(v___x_582_, 1);
lean_inc(v_tail_584_);
lean_dec_ref_known(v___x_582_, 2);
v___x_585_ = ((lean_object*)(lp_loam_Loam_Persistence_eventMemoryHeader___closed__0));
v___x_586_ = lean_string_dec_eq(v_head_583_, v___x_585_);
lean_dec(v_head_583_);
if (v___x_586_ == 0)
{
lean_object* v___x_587_; 
lean_dec(v_tail_584_);
v___x_587_ = lean_box(0);
return v___x_587_;
}
else
{
if (lean_obj_tag(v_tail_584_) == 0)
{
lean_object* v___x_588_; 
v___x_588_ = lean_box(0);
return v___x_588_;
}
else
{
lean_object* v___x_589_; 
v___x_589_ = lp_loam_List_mapM_loop___at___00Loam_Persistence_decodeEventMemory_x3f_spec__0(v_tail_584_, v___x_574_);
if (lean_obj_tag(v___x_589_) == 0)
{
lean_object* v___x_590_; 
v___x_590_ = lean_box(0);
return v___x_590_;
}
else
{
lean_object* v_val_591_; lean_object* v___x_592_; 
v_val_591_ = lean_ctor_get(v___x_589_, 0);
lean_inc(v_val_591_);
lean_dec_ref_known(v___x_589_, 1);
v___x_592_ = lp_loam_Loam_Core_EventMemory_ofEvents_x3f(v_val_591_);
return v___x_592_;
}
}
}
}
else
{
lean_object* v___x_593_; 
lean_dec(v___x_582_);
v___x_593_ = lean_box(0);
return v___x_593_;
}
}
}
else
{
lean_object* v___x_594_; 
lean_dec(v___x_576_);
v___x_594_ = lean_box(0);
return v___x_594_;
}
}
else
{
lean_object* v___x_595_; 
v___x_595_ = lean_obj_once(&lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__2, &lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__2_once, _init_lp_loam_Loam_Persistence_decodeEventMemory_x3f___closed__2);
return v___x_595_;
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decodeEventMemory_x3f___boxed(lean_object* v_input_596_){
_start:
{
lean_object* v_res_597_; 
v_res_597_ = lp_loam_Loam_Persistence_decodeEventMemory_x3f(v_input_596_);
lean_dec_ref(v_input_596_);
return v_res_597_;
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeEventCorrectionRow_x3f(lean_object* v_correction_599_){
_start:
{
lean_object* v_id_600_; lean_object* v_target_601_; lean_object* v_replacement_602_; uint8_t v___y_604_; uint8_t v___x_616_; 
v_id_600_ = lean_ctor_get(v_correction_599_, 0);
lean_inc_ref_n(v_id_600_, 2);
v_target_601_ = lean_ctor_get(v_correction_599_, 1);
lean_inc_ref(v_target_601_);
v_replacement_602_ = lean_ctor_get(v_correction_599_, 2);
lean_inc_ref(v_replacement_602_);
lean_dec_ref(v_correction_599_);
v___x_616_ = lp_loam_Loam_Persistence_validToken(v_id_600_);
if (v___x_616_ == 0)
{
v___y_604_ = v___x_616_;
goto v___jp_603_;
}
else
{
uint8_t v___x_617_; 
lean_inc_ref(v_target_601_);
v___x_617_ = lp_loam_Loam_Persistence_validToken(v_target_601_);
v___y_604_ = v___x_617_;
goto v___jp_603_;
}
v___jp_603_:
{
if (v___y_604_ == 0)
{
lean_object* v___x_605_; 
lean_dec_ref(v_replacement_602_);
lean_dec_ref(v_target_601_);
lean_dec_ref(v_id_600_);
v___x_605_ = lean_box(0);
return v___x_605_;
}
else
{
uint8_t v___x_606_; 
lean_inc_ref(v_replacement_602_);
v___x_606_ = lp_loam_Loam_Persistence_validToken(v_replacement_602_);
if (v___x_606_ == 0)
{
lean_object* v___x_607_; 
lean_dec_ref(v_replacement_602_);
lean_dec_ref(v_target_601_);
lean_dec_ref(v_id_600_);
v___x_607_ = lean_box(0);
return v___x_607_;
}
else
{
lean_object* v___x_608_; lean_object* v___x_609_; lean_object* v___x_610_; lean_object* v___x_611_; lean_object* v___x_612_; lean_object* v___x_613_; lean_object* v___x_614_; lean_object* v___x_615_; 
v___x_608_ = ((lean_object*)(lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeEventCorrectionRow_x3f___closed__0));
v___x_609_ = lean_string_append(v___x_608_, v_id_600_);
lean_dec_ref(v_id_600_);
v___x_610_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__2));
v___x_611_ = lean_string_append(v___x_609_, v___x_610_);
v___x_612_ = lean_string_append(v___x_611_, v_target_601_);
lean_dec_ref(v_target_601_);
v___x_613_ = lean_string_append(v___x_612_, v___x_610_);
v___x_614_ = lean_string_append(v___x_613_, v_replacement_602_);
lean_dec_ref(v_replacement_602_);
v___x_615_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_615_, 0, v___x_614_);
return v___x_615_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEventCorrectionRow_x3f(lean_object* v_row_619_){
_start:
{
lean_object* v___x_620_; lean_object* v___x_621_; lean_object* v___x_622_; lean_object* v___x_623_; 
v___x_620_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__2));
v___x_621_ = lean_unsigned_to_nat(0u);
v___x_622_ = lean_box(0);
v___x_623_ = l_String_splitOnAux(v_row_619_, v___x_620_, v___x_621_, v___x_621_, v___x_621_, v___x_622_);
if (lean_obj_tag(v___x_623_) == 1)
{
lean_object* v_head_624_; lean_object* v_tail_625_; lean_object* v___x_626_; uint8_t v___x_627_; 
v_head_624_ = lean_ctor_get(v___x_623_, 0);
lean_inc(v_head_624_);
v_tail_625_ = lean_ctor_get(v___x_623_, 1);
lean_inc(v_tail_625_);
lean_dec_ref_known(v___x_623_, 2);
v___x_626_ = ((lean_object*)(lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEventCorrectionRow_x3f___closed__0));
v___x_627_ = lean_string_dec_eq(v_head_624_, v___x_626_);
lean_dec(v_head_624_);
if (v___x_627_ == 0)
{
lean_object* v___x_628_; 
lean_dec(v_tail_625_);
v___x_628_ = lean_box(0);
return v___x_628_;
}
else
{
if (lean_obj_tag(v_tail_625_) == 1)
{
lean_object* v_tail_629_; 
v_tail_629_ = lean_ctor_get(v_tail_625_, 1);
lean_inc(v_tail_629_);
if (lean_obj_tag(v_tail_629_) == 1)
{
lean_object* v_tail_630_; 
v_tail_630_ = lean_ctor_get(v_tail_629_, 1);
lean_inc(v_tail_630_);
if (lean_obj_tag(v_tail_630_) == 1)
{
lean_object* v_head_631_; lean_object* v_head_632_; lean_object* v_head_633_; lean_object* v_tail_634_; uint8_t v___y_636_; 
v_head_631_ = lean_ctor_get(v_tail_625_, 0);
lean_inc(v_head_631_);
lean_dec_ref_known(v_tail_625_, 2);
v_head_632_ = lean_ctor_get(v_tail_629_, 0);
lean_inc(v_head_632_);
lean_dec_ref_known(v_tail_629_, 2);
v_head_633_ = lean_ctor_get(v_tail_630_, 0);
lean_inc(v_head_633_);
v_tail_634_ = lean_ctor_get(v_tail_630_, 1);
lean_inc(v_tail_634_);
lean_dec_ref_known(v_tail_630_, 2);
if (lean_obj_tag(v_tail_634_) == 0)
{
uint8_t v___x_642_; 
lean_inc(v_head_631_);
v___x_642_ = lp_loam_Loam_Persistence_validToken(v_head_631_);
if (v___x_642_ == 0)
{
v___y_636_ = v___x_642_;
goto v___jp_635_;
}
else
{
uint8_t v___x_643_; 
lean_inc(v_head_632_);
v___x_643_ = lp_loam_Loam_Persistence_validToken(v_head_632_);
v___y_636_ = v___x_643_;
goto v___jp_635_;
}
}
else
{
lean_object* v___x_644_; 
lean_dec(v_tail_634_);
lean_dec(v_head_633_);
lean_dec(v_head_632_);
lean_dec(v_head_631_);
v___x_644_ = lean_box(0);
return v___x_644_;
}
v___jp_635_:
{
if (v___y_636_ == 0)
{
lean_object* v___x_637_; 
lean_dec(v_head_633_);
lean_dec(v_head_632_);
lean_dec(v_head_631_);
v___x_637_ = lean_box(0);
return v___x_637_;
}
else
{
uint8_t v___x_638_; 
lean_inc(v_head_633_);
v___x_638_ = lp_loam_Loam_Persistence_validToken(v_head_633_);
if (v___x_638_ == 0)
{
lean_object* v___x_639_; 
lean_dec(v_head_633_);
lean_dec(v_head_632_);
lean_dec(v_head_631_);
v___x_639_ = lean_box(0);
return v___x_639_;
}
else
{
lean_object* v___x_640_; lean_object* v___x_641_; 
v___x_640_ = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(v___x_640_, 0, v_head_631_);
lean_ctor_set(v___x_640_, 1, v_head_632_);
lean_ctor_set(v___x_640_, 2, v_head_633_);
v___x_641_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_641_, 0, v___x_640_);
return v___x_641_;
}
}
}
}
else
{
lean_object* v___x_645_; 
lean_dec_ref_known(v_tail_629_, 2);
lean_dec(v_tail_630_);
lean_dec_ref_known(v_tail_625_, 2);
v___x_645_ = lean_box(0);
return v___x_645_;
}
}
else
{
lean_object* v___x_646_; 
lean_dec(v_tail_629_);
lean_dec_ref_known(v_tail_625_, 2);
v___x_646_ = lean_box(0);
return v___x_646_;
}
}
else
{
lean_object* v___x_647_; 
lean_dec(v_tail_625_);
v___x_647_ = lean_box(0);
return v___x_647_;
}
}
}
else
{
lean_object* v___x_648_; 
lean_dec(v___x_623_);
v___x_648_ = lean_box(0);
return v___x_648_;
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEventCorrectionRow_x3f___boxed(lean_object* v_row_649_){
_start:
{
lean_object* v_res_650_; 
v_res_650_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEventCorrectionRow_x3f(v_row_649_);
lean_dec_ref(v_row_649_);
return v_res_650_;
}
}
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00Loam_Persistence_encodeEventCorrectionMemory_x3f_spec__0(lean_object* v_x_651_, lean_object* v_x_652_){
_start:
{
if (lean_obj_tag(v_x_651_) == 0)
{
lean_object* v___x_653_; lean_object* v___x_654_; 
v___x_653_ = l_List_reverse___redArg(v_x_652_);
v___x_654_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_654_, 0, v___x_653_);
return v___x_654_;
}
else
{
lean_object* v_head_655_; lean_object* v_tail_656_; lean_object* v___x_658_; uint8_t v_isShared_659_; uint8_t v_isSharedCheck_667_; 
v_head_655_ = lean_ctor_get(v_x_651_, 0);
v_tail_656_ = lean_ctor_get(v_x_651_, 1);
v_isSharedCheck_667_ = !lean_is_exclusive(v_x_651_);
if (v_isSharedCheck_667_ == 0)
{
v___x_658_ = v_x_651_;
v_isShared_659_ = v_isSharedCheck_667_;
goto v_resetjp_657_;
}
else
{
lean_inc(v_tail_656_);
lean_inc(v_head_655_);
lean_dec(v_x_651_);
v___x_658_ = lean_box(0);
v_isShared_659_ = v_isSharedCheck_667_;
goto v_resetjp_657_;
}
v_resetjp_657_:
{
lean_object* v___x_660_; 
v___x_660_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_encodeEventCorrectionRow_x3f(v_head_655_);
if (lean_obj_tag(v___x_660_) == 0)
{
lean_object* v___x_661_; 
lean_del_object(v___x_658_);
lean_dec(v_tail_656_);
lean_dec(v_x_652_);
v___x_661_ = lean_box(0);
return v___x_661_;
}
else
{
lean_object* v_val_662_; lean_object* v___x_664_; 
v_val_662_ = lean_ctor_get(v___x_660_, 0);
lean_inc(v_val_662_);
lean_dec_ref_known(v___x_660_, 1);
if (v_isShared_659_ == 0)
{
lean_ctor_set(v___x_658_, 1, v_x_652_);
lean_ctor_set(v___x_658_, 0, v_val_662_);
v___x_664_ = v___x_658_;
goto v_reusejp_663_;
}
else
{
lean_object* v_reuseFailAlloc_666_; 
v_reuseFailAlloc_666_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_666_, 0, v_val_662_);
lean_ctor_set(v_reuseFailAlloc_666_, 1, v_x_652_);
v___x_664_ = v_reuseFailAlloc_666_;
goto v_reusejp_663_;
}
v_reusejp_663_:
{
v_x_651_ = v_tail_656_;
v_x_652_ = v___x_664_;
goto _start;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_encodeEventCorrectionMemory_x3f(lean_object* v_memory_668_){
_start:
{
lean_object* v___x_669_; lean_object* v___x_670_; 
v___x_669_ = lean_box(0);
v___x_670_ = lp_loam_List_mapM_loop___at___00Loam_Persistence_encodeEventCorrectionMemory_x3f_spec__0(v_memory_668_, v___x_669_);
if (lean_obj_tag(v___x_670_) == 0)
{
lean_object* v___x_671_; 
v___x_671_ = lean_box(0);
return v___x_671_;
}
else
{
lean_object* v_val_672_; lean_object* v___x_674_; uint8_t v_isShared_675_; uint8_t v_isSharedCheck_684_; 
v_val_672_ = lean_ctor_get(v___x_670_, 0);
v_isSharedCheck_684_ = !lean_is_exclusive(v___x_670_);
if (v_isSharedCheck_684_ == 0)
{
v___x_674_ = v___x_670_;
v_isShared_675_ = v_isSharedCheck_684_;
goto v_resetjp_673_;
}
else
{
lean_inc(v_val_672_);
lean_dec(v___x_670_);
v___x_674_ = lean_box(0);
v_isShared_675_ = v_isSharedCheck_684_;
goto v_resetjp_673_;
}
v_resetjp_673_:
{
lean_object* v___x_676_; lean_object* v___x_677_; lean_object* v___x_678_; lean_object* v___x_679_; lean_object* v___x_680_; lean_object* v___x_682_; 
v___x_676_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__0));
v___x_677_ = ((lean_object*)(lp_loam_Loam_Persistence_eventCorrectionMemoryHeader___closed__0));
v___x_678_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v___x_678_, 0, v___x_677_);
lean_ctor_set(v___x_678_, 1, v_val_672_);
v___x_679_ = l_String_intercalate(v___x_676_, v___x_678_);
v___x_680_ = lean_string_append(v___x_679_, v___x_676_);
if (v_isShared_675_ == 0)
{
lean_ctor_set(v___x_674_, 0, v___x_680_);
v___x_682_ = v___x_674_;
goto v_reusejp_681_;
}
else
{
lean_object* v_reuseFailAlloc_683_; 
v_reuseFailAlloc_683_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_683_, 0, v___x_680_);
v___x_682_ = v_reuseFailAlloc_683_;
goto v_reusejp_681_;
}
v_reusejp_681_:
{
return v___x_682_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_List_mapM_loop___at___00Loam_Persistence_decodeEventCorrectionMemory_x3f_spec__0(lean_object* v_x_685_, lean_object* v_x_686_){
_start:
{
if (lean_obj_tag(v_x_685_) == 0)
{
lean_object* v___x_687_; lean_object* v___x_688_; 
v___x_687_ = l_List_reverse___redArg(v_x_686_);
v___x_688_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_688_, 0, v___x_687_);
return v___x_688_;
}
else
{
lean_object* v_head_689_; lean_object* v_tail_690_; lean_object* v___x_692_; uint8_t v_isShared_693_; uint8_t v_isSharedCheck_701_; 
v_head_689_ = lean_ctor_get(v_x_685_, 0);
v_tail_690_ = lean_ctor_get(v_x_685_, 1);
v_isSharedCheck_701_ = !lean_is_exclusive(v_x_685_);
if (v_isSharedCheck_701_ == 0)
{
v___x_692_ = v_x_685_;
v_isShared_693_ = v_isSharedCheck_701_;
goto v_resetjp_691_;
}
else
{
lean_inc(v_tail_690_);
lean_inc(v_head_689_);
lean_dec(v_x_685_);
v___x_692_ = lean_box(0);
v_isShared_693_ = v_isSharedCheck_701_;
goto v_resetjp_691_;
}
v_resetjp_691_:
{
lean_object* v___x_694_; 
v___x_694_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_decodeEventCorrectionRow_x3f(v_head_689_);
lean_dec(v_head_689_);
if (lean_obj_tag(v___x_694_) == 0)
{
lean_object* v___x_695_; 
lean_del_object(v___x_692_);
lean_dec(v_tail_690_);
lean_dec(v_x_686_);
v___x_695_ = lean_box(0);
return v___x_695_;
}
else
{
lean_object* v_val_696_; lean_object* v___x_698_; 
v_val_696_ = lean_ctor_get(v___x_694_, 0);
lean_inc(v_val_696_);
lean_dec_ref_known(v___x_694_, 1);
if (v_isShared_693_ == 0)
{
lean_ctor_set(v___x_692_, 1, v_x_686_);
lean_ctor_set(v___x_692_, 0, v_val_696_);
v___x_698_ = v___x_692_;
goto v_reusejp_697_;
}
else
{
lean_object* v_reuseFailAlloc_700_; 
v_reuseFailAlloc_700_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_700_, 0, v_val_696_);
lean_ctor_set(v_reuseFailAlloc_700_, 1, v_x_686_);
v___x_698_ = v_reuseFailAlloc_700_;
goto v_reusejp_697_;
}
v_reusejp_697_:
{
v_x_685_ = v_tail_690_;
v_x_686_ = v___x_698_;
goto _start;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decodeEventCorrectionMemory_x3f(lean_object* v_input_702_){
_start:
{
lean_object* v___x_703_; lean_object* v___x_704_; lean_object* v___x_705_; lean_object* v___x_706_; 
v___x_703_ = ((lean_object*)(lp_loam_Loam_Persistence_encode_x3f___closed__0));
v___x_704_ = lean_unsigned_to_nat(0u);
v___x_705_ = lean_box(0);
v___x_706_ = l_String_splitOnAux(v_input_702_, v___x_703_, v___x_704_, v___x_704_, v___x_704_, v___x_705_);
if (lean_obj_tag(v___x_706_) == 1)
{
lean_object* v_head_707_; lean_object* v_tail_708_; lean_object* v___x_709_; uint8_t v___x_710_; 
v_head_707_ = lean_ctor_get(v___x_706_, 0);
lean_inc(v_head_707_);
v_tail_708_ = lean_ctor_get(v___x_706_, 1);
lean_inc(v_tail_708_);
lean_dec_ref_known(v___x_706_, 2);
v___x_709_ = ((lean_object*)(lp_loam_Loam_Persistence_eventCorrectionMemoryHeader___closed__0));
v___x_710_ = lean_string_dec_eq(v_head_707_, v___x_709_);
lean_dec(v_head_707_);
if (v___x_710_ == 0)
{
lean_object* v___x_711_; 
lean_dec(v_tail_708_);
v___x_711_ = lean_box(0);
return v___x_711_;
}
else
{
lean_object* v___x_712_; 
v___x_712_ = l_List_reverse___redArg(v_tail_708_);
if (lean_obj_tag(v___x_712_) == 1)
{
lean_object* v_head_713_; lean_object* v_tail_714_; lean_object* v___x_715_; uint8_t v___x_716_; 
v_head_713_ = lean_ctor_get(v___x_712_, 0);
lean_inc(v_head_713_);
v_tail_714_ = lean_ctor_get(v___x_712_, 1);
lean_inc(v_tail_714_);
lean_dec_ref_known(v___x_712_, 2);
v___x_715_ = ((lean_object*)(lp_loam_Loam_Persistence_decode_x3f___closed__0));
v___x_716_ = lean_string_dec_eq(v_head_713_, v___x_715_);
lean_dec(v_head_713_);
if (v___x_716_ == 0)
{
lean_object* v___x_717_; 
lean_dec(v_tail_714_);
v___x_717_ = lean_box(0);
return v___x_717_;
}
else
{
lean_object* v___x_718_; lean_object* v___x_719_; 
v___x_718_ = l_List_reverse___redArg(v_tail_714_);
v___x_719_ = lp_loam_List_mapM_loop___at___00Loam_Persistence_decodeEventCorrectionMemory_x3f_spec__0(v___x_718_, v___x_705_);
if (lean_obj_tag(v___x_719_) == 0)
{
lean_object* v___x_720_; 
v___x_720_ = lean_box(0);
return v___x_720_;
}
else
{
lean_object* v_val_721_; lean_object* v___x_722_; 
v_val_721_ = lean_ctor_get(v___x_719_, 0);
lean_inc(v_val_721_);
lean_dec_ref_known(v___x_719_, 1);
v___x_722_ = lp_loam_Loam_Core_EventCorrectionMemory_ofCorrections_x3f(v_val_721_);
return v___x_722_;
}
}
}
else
{
lean_object* v___x_723_; 
lean_dec(v___x_712_);
v___x_723_ = lean_box(0);
return v___x_723_;
}
}
}
else
{
lean_object* v___x_724_; 
lean_dec(v___x_706_);
v___x_724_ = lean_box(0);
return v___x_724_;
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_decodeEventCorrectionMemory_x3f___boxed(lean_object* v_input_725_){
_start:
{
lean_object* v_res_726_; 
v_res_726_ = lp_loam_Loam_Persistence_decodeEventCorrectionMemory_x3f(v_input_725_);
lean_dec_ref(v_input_725_);
return v_res_726_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_save_x3f(lean_object* v_path_727_, lean_object* v_amount_728_){
_start:
{
lean_object* v___x_730_; 
v___x_730_ = lp_loam_Loam_Persistence_encode_x3f(v_amount_728_);
if (lean_obj_tag(v___x_730_) == 0)
{
uint8_t v___x_731_; lean_object* v___x_732_; lean_object* v___x_733_; 
v___x_731_ = 0;
v___x_732_ = lean_box(v___x_731_);
v___x_733_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v___x_733_, 0, v___x_732_);
return v___x_733_;
}
else
{
lean_object* v_val_734_; lean_object* v___x_735_; 
v_val_734_ = lean_ctor_get(v___x_730_, 0);
lean_inc(v_val_734_);
lean_dec_ref_known(v___x_730_, 1);
v___x_735_ = l_IO_FS_writeFile(v_path_727_, v_val_734_);
lean_dec(v_val_734_);
if (lean_obj_tag(v___x_735_) == 0)
{
lean_object* v___x_737_; uint8_t v_isShared_738_; uint8_t v_isSharedCheck_744_; 
v_isSharedCheck_744_ = !lean_is_exclusive(v___x_735_);
if (v_isSharedCheck_744_ == 0)
{
lean_object* v_unused_745_; 
v_unused_745_ = lean_ctor_get(v___x_735_, 0);
lean_dec(v_unused_745_);
v___x_737_ = v___x_735_;
v_isShared_738_ = v_isSharedCheck_744_;
goto v_resetjp_736_;
}
else
{
lean_dec(v___x_735_);
v___x_737_ = lean_box(0);
v_isShared_738_ = v_isSharedCheck_744_;
goto v_resetjp_736_;
}
v_resetjp_736_:
{
uint8_t v___x_739_; lean_object* v___x_740_; lean_object* v___x_742_; 
v___x_739_ = 1;
v___x_740_ = lean_box(v___x_739_);
if (v_isShared_738_ == 0)
{
lean_ctor_set(v___x_737_, 0, v___x_740_);
v___x_742_ = v___x_737_;
goto v_reusejp_741_;
}
else
{
lean_object* v_reuseFailAlloc_743_; 
v_reuseFailAlloc_743_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_743_, 0, v___x_740_);
v___x_742_ = v_reuseFailAlloc_743_;
goto v_reusejp_741_;
}
v_reusejp_741_:
{
return v___x_742_;
}
}
}
else
{
lean_object* v_a_746_; lean_object* v___x_748_; uint8_t v_isShared_749_; uint8_t v_isSharedCheck_753_; 
v_a_746_ = lean_ctor_get(v___x_735_, 0);
v_isSharedCheck_753_ = !lean_is_exclusive(v___x_735_);
if (v_isSharedCheck_753_ == 0)
{
v___x_748_ = v___x_735_;
v_isShared_749_ = v_isSharedCheck_753_;
goto v_resetjp_747_;
}
else
{
lean_inc(v_a_746_);
lean_dec(v___x_735_);
v___x_748_ = lean_box(0);
v_isShared_749_ = v_isSharedCheck_753_;
goto v_resetjp_747_;
}
v_resetjp_747_:
{
lean_object* v___x_751_; 
if (v_isShared_749_ == 0)
{
v___x_751_ = v___x_748_;
goto v_reusejp_750_;
}
else
{
lean_object* v_reuseFailAlloc_752_; 
v_reuseFailAlloc_752_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_752_, 0, v_a_746_);
v___x_751_ = v_reuseFailAlloc_752_;
goto v_reusejp_750_;
}
v_reusejp_750_:
{
return v___x_751_;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_save_x3f___boxed(lean_object* v_path_754_, lean_object* v_amount_755_, lean_object* v_a_756_){
_start:
{
lean_object* v_res_757_; 
v_res_757_ = lp_loam_Loam_Persistence_save_x3f(v_path_754_, v_amount_755_);
lean_dec_ref(v_path_754_);
return v_res_757_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_load_x3f(lean_object* v_path_758_){
_start:
{
lean_object* v___x_760_; 
v___x_760_ = l_IO_FS_readFile(v_path_758_);
if (lean_obj_tag(v___x_760_) == 0)
{
lean_object* v_a_761_; lean_object* v___x_763_; uint8_t v_isShared_764_; uint8_t v_isSharedCheck_769_; 
v_a_761_ = lean_ctor_get(v___x_760_, 0);
v_isSharedCheck_769_ = !lean_is_exclusive(v___x_760_);
if (v_isSharedCheck_769_ == 0)
{
v___x_763_ = v___x_760_;
v_isShared_764_ = v_isSharedCheck_769_;
goto v_resetjp_762_;
}
else
{
lean_inc(v_a_761_);
lean_dec(v___x_760_);
v___x_763_ = lean_box(0);
v_isShared_764_ = v_isSharedCheck_769_;
goto v_resetjp_762_;
}
v_resetjp_762_:
{
lean_object* v___x_765_; lean_object* v___x_767_; 
v___x_765_ = lp_loam_Loam_Persistence_decode_x3f(v_a_761_);
lean_dec(v_a_761_);
if (v_isShared_764_ == 0)
{
lean_ctor_set(v___x_763_, 0, v___x_765_);
v___x_767_ = v___x_763_;
goto v_reusejp_766_;
}
else
{
lean_object* v_reuseFailAlloc_768_; 
v_reuseFailAlloc_768_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_768_, 0, v___x_765_);
v___x_767_ = v_reuseFailAlloc_768_;
goto v_reusejp_766_;
}
v_reusejp_766_:
{
return v___x_767_;
}
}
}
else
{
lean_object* v_a_770_; lean_object* v___x_772_; uint8_t v_isShared_773_; uint8_t v_isSharedCheck_777_; 
v_a_770_ = lean_ctor_get(v___x_760_, 0);
v_isSharedCheck_777_ = !lean_is_exclusive(v___x_760_);
if (v_isSharedCheck_777_ == 0)
{
v___x_772_ = v___x_760_;
v_isShared_773_ = v_isSharedCheck_777_;
goto v_resetjp_771_;
}
else
{
lean_inc(v_a_770_);
lean_dec(v___x_760_);
v___x_772_ = lean_box(0);
v_isShared_773_ = v_isSharedCheck_777_;
goto v_resetjp_771_;
}
v_resetjp_771_:
{
lean_object* v___x_775_; 
if (v_isShared_773_ == 0)
{
v___x_775_ = v___x_772_;
goto v_reusejp_774_;
}
else
{
lean_object* v_reuseFailAlloc_776_; 
v_reuseFailAlloc_776_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_776_, 0, v_a_770_);
v___x_775_ = v_reuseFailAlloc_776_;
goto v_reusejp_774_;
}
v_reusejp_774_:
{
return v___x_775_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_load_x3f___boxed(lean_object* v_path_778_, lean_object* v_a_779_){
_start:
{
lean_object* v_res_780_; 
v_res_780_ = lp_loam_Loam_Persistence_load_x3f(v_path_778_);
lean_dec_ref(v_path_778_);
return v_res_780_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_saveEvent_x3f(lean_object* v_path_781_, lean_object* v_event_782_){
_start:
{
lean_object* v___x_784_; 
v___x_784_ = lp_loam_Loam_Persistence_encodeEvent_x3f(v_event_782_);
if (lean_obj_tag(v___x_784_) == 0)
{
uint8_t v___x_785_; lean_object* v___x_786_; lean_object* v___x_787_; 
v___x_785_ = 0;
v___x_786_ = lean_box(v___x_785_);
v___x_787_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v___x_787_, 0, v___x_786_);
return v___x_787_;
}
else
{
lean_object* v_val_788_; lean_object* v___x_789_; 
v_val_788_ = lean_ctor_get(v___x_784_, 0);
lean_inc(v_val_788_);
lean_dec_ref_known(v___x_784_, 1);
v___x_789_ = l_IO_FS_writeFile(v_path_781_, v_val_788_);
lean_dec(v_val_788_);
if (lean_obj_tag(v___x_789_) == 0)
{
lean_object* v___x_791_; uint8_t v_isShared_792_; uint8_t v_isSharedCheck_798_; 
v_isSharedCheck_798_ = !lean_is_exclusive(v___x_789_);
if (v_isSharedCheck_798_ == 0)
{
lean_object* v_unused_799_; 
v_unused_799_ = lean_ctor_get(v___x_789_, 0);
lean_dec(v_unused_799_);
v___x_791_ = v___x_789_;
v_isShared_792_ = v_isSharedCheck_798_;
goto v_resetjp_790_;
}
else
{
lean_dec(v___x_789_);
v___x_791_ = lean_box(0);
v_isShared_792_ = v_isSharedCheck_798_;
goto v_resetjp_790_;
}
v_resetjp_790_:
{
uint8_t v___x_793_; lean_object* v___x_794_; lean_object* v___x_796_; 
v___x_793_ = 1;
v___x_794_ = lean_box(v___x_793_);
if (v_isShared_792_ == 0)
{
lean_ctor_set(v___x_791_, 0, v___x_794_);
v___x_796_ = v___x_791_;
goto v_reusejp_795_;
}
else
{
lean_object* v_reuseFailAlloc_797_; 
v_reuseFailAlloc_797_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_797_, 0, v___x_794_);
v___x_796_ = v_reuseFailAlloc_797_;
goto v_reusejp_795_;
}
v_reusejp_795_:
{
return v___x_796_;
}
}
}
else
{
lean_object* v_a_800_; lean_object* v___x_802_; uint8_t v_isShared_803_; uint8_t v_isSharedCheck_807_; 
v_a_800_ = lean_ctor_get(v___x_789_, 0);
v_isSharedCheck_807_ = !lean_is_exclusive(v___x_789_);
if (v_isSharedCheck_807_ == 0)
{
v___x_802_ = v___x_789_;
v_isShared_803_ = v_isSharedCheck_807_;
goto v_resetjp_801_;
}
else
{
lean_inc(v_a_800_);
lean_dec(v___x_789_);
v___x_802_ = lean_box(0);
v_isShared_803_ = v_isSharedCheck_807_;
goto v_resetjp_801_;
}
v_resetjp_801_:
{
lean_object* v___x_805_; 
if (v_isShared_803_ == 0)
{
v___x_805_ = v___x_802_;
goto v_reusejp_804_;
}
else
{
lean_object* v_reuseFailAlloc_806_; 
v_reuseFailAlloc_806_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_806_, 0, v_a_800_);
v___x_805_ = v_reuseFailAlloc_806_;
goto v_reusejp_804_;
}
v_reusejp_804_:
{
return v___x_805_;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_saveEvent_x3f___boxed(lean_object* v_path_808_, lean_object* v_event_809_, lean_object* v_a_810_){
_start:
{
lean_object* v_res_811_; 
v_res_811_ = lp_loam_Loam_Persistence_saveEvent_x3f(v_path_808_, v_event_809_);
lean_dec_ref(v_path_808_);
return v_res_811_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_loadEvent_x3f(lean_object* v_path_812_){
_start:
{
lean_object* v___x_814_; 
v___x_814_ = l_IO_FS_readFile(v_path_812_);
if (lean_obj_tag(v___x_814_) == 0)
{
lean_object* v_a_815_; lean_object* v___x_817_; uint8_t v_isShared_818_; uint8_t v_isSharedCheck_823_; 
v_a_815_ = lean_ctor_get(v___x_814_, 0);
v_isSharedCheck_823_ = !lean_is_exclusive(v___x_814_);
if (v_isSharedCheck_823_ == 0)
{
v___x_817_ = v___x_814_;
v_isShared_818_ = v_isSharedCheck_823_;
goto v_resetjp_816_;
}
else
{
lean_inc(v_a_815_);
lean_dec(v___x_814_);
v___x_817_ = lean_box(0);
v_isShared_818_ = v_isSharedCheck_823_;
goto v_resetjp_816_;
}
v_resetjp_816_:
{
lean_object* v___x_819_; lean_object* v___x_821_; 
v___x_819_ = lp_loam_Loam_Persistence_decodeEvent_x3f(v_a_815_);
lean_dec(v_a_815_);
if (v_isShared_818_ == 0)
{
lean_ctor_set(v___x_817_, 0, v___x_819_);
v___x_821_ = v___x_817_;
goto v_reusejp_820_;
}
else
{
lean_object* v_reuseFailAlloc_822_; 
v_reuseFailAlloc_822_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_822_, 0, v___x_819_);
v___x_821_ = v_reuseFailAlloc_822_;
goto v_reusejp_820_;
}
v_reusejp_820_:
{
return v___x_821_;
}
}
}
else
{
lean_object* v_a_824_; lean_object* v___x_826_; uint8_t v_isShared_827_; uint8_t v_isSharedCheck_831_; 
v_a_824_ = lean_ctor_get(v___x_814_, 0);
v_isSharedCheck_831_ = !lean_is_exclusive(v___x_814_);
if (v_isSharedCheck_831_ == 0)
{
v___x_826_ = v___x_814_;
v_isShared_827_ = v_isSharedCheck_831_;
goto v_resetjp_825_;
}
else
{
lean_inc(v_a_824_);
lean_dec(v___x_814_);
v___x_826_ = lean_box(0);
v_isShared_827_ = v_isSharedCheck_831_;
goto v_resetjp_825_;
}
v_resetjp_825_:
{
lean_object* v___x_829_; 
if (v_isShared_827_ == 0)
{
v___x_829_ = v___x_826_;
goto v_reusejp_828_;
}
else
{
lean_object* v_reuseFailAlloc_830_; 
v_reuseFailAlloc_830_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_830_, 0, v_a_824_);
v___x_829_ = v_reuseFailAlloc_830_;
goto v_reusejp_828_;
}
v_reusejp_828_:
{
return v___x_829_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_loadEvent_x3f___boxed(lean_object* v_path_832_, lean_object* v_a_833_){
_start:
{
lean_object* v_res_834_; 
v_res_834_ = lp_loam_Loam_Persistence_loadEvent_x3f(v_path_832_);
lean_dec_ref(v_path_832_);
return v_res_834_;
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_eventMemoryStagePath(lean_object* v_path_836_){
_start:
{
lean_object* v___x_837_; lean_object* v___x_838_; 
v___x_837_ = ((lean_object*)(lp_loam___private_Loam_Persistence_0__Loam_Persistence_eventMemoryStagePath___closed__0));
v___x_838_ = lean_string_append(v_path_836_, v___x_837_);
return v___x_838_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_saveEventMemory_x3f(lean_object* v_path_839_, lean_object* v_memory_840_){
_start:
{
lean_object* v___x_842_; 
v___x_842_ = lp_loam_Loam_Persistence_encodeEventMemory_x3f(v_memory_840_);
if (lean_obj_tag(v___x_842_) == 0)
{
uint8_t v___x_843_; lean_object* v___x_844_; lean_object* v___x_845_; 
lean_dec_ref(v_path_839_);
v___x_843_ = 0;
v___x_844_ = lean_box(v___x_843_);
v___x_845_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v___x_845_, 0, v___x_844_);
return v___x_845_;
}
else
{
lean_object* v_val_846_; lean_object* v_stagePath_847_; lean_object* v___x_848_; 
v_val_846_ = lean_ctor_get(v___x_842_, 0);
lean_inc(v_val_846_);
lean_dec_ref_known(v___x_842_, 1);
lean_inc_ref(v_path_839_);
v_stagePath_847_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_eventMemoryStagePath(v_path_839_);
v___x_848_ = l_IO_FS_writeFile(v_stagePath_847_, v_val_846_);
lean_dec(v_val_846_);
if (lean_obj_tag(v___x_848_) == 0)
{
lean_object* v___x_849_; 
lean_dec_ref_known(v___x_848_, 1);
v___x_849_ = lean_io_rename(v_stagePath_847_, v_path_839_);
lean_dec_ref(v_path_839_);
lean_dec_ref(v_stagePath_847_);
if (lean_obj_tag(v___x_849_) == 0)
{
lean_object* v___x_851_; uint8_t v_isShared_852_; uint8_t v_isSharedCheck_858_; 
v_isSharedCheck_858_ = !lean_is_exclusive(v___x_849_);
if (v_isSharedCheck_858_ == 0)
{
lean_object* v_unused_859_; 
v_unused_859_ = lean_ctor_get(v___x_849_, 0);
lean_dec(v_unused_859_);
v___x_851_ = v___x_849_;
v_isShared_852_ = v_isSharedCheck_858_;
goto v_resetjp_850_;
}
else
{
lean_dec(v___x_849_);
v___x_851_ = lean_box(0);
v_isShared_852_ = v_isSharedCheck_858_;
goto v_resetjp_850_;
}
v_resetjp_850_:
{
uint8_t v___x_853_; lean_object* v___x_854_; lean_object* v___x_856_; 
v___x_853_ = 1;
v___x_854_ = lean_box(v___x_853_);
if (v_isShared_852_ == 0)
{
lean_ctor_set(v___x_851_, 0, v___x_854_);
v___x_856_ = v___x_851_;
goto v_reusejp_855_;
}
else
{
lean_object* v_reuseFailAlloc_857_; 
v_reuseFailAlloc_857_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_857_, 0, v___x_854_);
v___x_856_ = v_reuseFailAlloc_857_;
goto v_reusejp_855_;
}
v_reusejp_855_:
{
return v___x_856_;
}
}
}
else
{
lean_object* v_a_860_; lean_object* v___x_862_; uint8_t v_isShared_863_; uint8_t v_isSharedCheck_867_; 
v_a_860_ = lean_ctor_get(v___x_849_, 0);
v_isSharedCheck_867_ = !lean_is_exclusive(v___x_849_);
if (v_isSharedCheck_867_ == 0)
{
v___x_862_ = v___x_849_;
v_isShared_863_ = v_isSharedCheck_867_;
goto v_resetjp_861_;
}
else
{
lean_inc(v_a_860_);
lean_dec(v___x_849_);
v___x_862_ = lean_box(0);
v_isShared_863_ = v_isSharedCheck_867_;
goto v_resetjp_861_;
}
v_resetjp_861_:
{
lean_object* v___x_865_; 
if (v_isShared_863_ == 0)
{
v___x_865_ = v___x_862_;
goto v_reusejp_864_;
}
else
{
lean_object* v_reuseFailAlloc_866_; 
v_reuseFailAlloc_866_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_866_, 0, v_a_860_);
v___x_865_ = v_reuseFailAlloc_866_;
goto v_reusejp_864_;
}
v_reusejp_864_:
{
return v___x_865_;
}
}
}
}
else
{
lean_object* v_a_868_; lean_object* v___x_870_; uint8_t v_isShared_871_; uint8_t v_isSharedCheck_875_; 
lean_dec_ref(v_stagePath_847_);
lean_dec_ref(v_path_839_);
v_a_868_ = lean_ctor_get(v___x_848_, 0);
v_isSharedCheck_875_ = !lean_is_exclusive(v___x_848_);
if (v_isSharedCheck_875_ == 0)
{
v___x_870_ = v___x_848_;
v_isShared_871_ = v_isSharedCheck_875_;
goto v_resetjp_869_;
}
else
{
lean_inc(v_a_868_);
lean_dec(v___x_848_);
v___x_870_ = lean_box(0);
v_isShared_871_ = v_isSharedCheck_875_;
goto v_resetjp_869_;
}
v_resetjp_869_:
{
lean_object* v___x_873_; 
if (v_isShared_871_ == 0)
{
v___x_873_ = v___x_870_;
goto v_reusejp_872_;
}
else
{
lean_object* v_reuseFailAlloc_874_; 
v_reuseFailAlloc_874_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_874_, 0, v_a_868_);
v___x_873_ = v_reuseFailAlloc_874_;
goto v_reusejp_872_;
}
v_reusejp_872_:
{
return v___x_873_;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_saveEventMemory_x3f___boxed(lean_object* v_path_876_, lean_object* v_memory_877_, lean_object* v_a_878_){
_start:
{
lean_object* v_res_879_; 
v_res_879_ = lp_loam_Loam_Persistence_saveEventMemory_x3f(v_path_876_, v_memory_877_);
return v_res_879_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_loadEventMemory_x3f(lean_object* v_path_880_){
_start:
{
lean_object* v___x_882_; 
v___x_882_ = l_IO_FS_readFile(v_path_880_);
if (lean_obj_tag(v___x_882_) == 0)
{
lean_object* v_a_883_; lean_object* v___x_885_; uint8_t v_isShared_886_; uint8_t v_isSharedCheck_891_; 
v_a_883_ = lean_ctor_get(v___x_882_, 0);
v_isSharedCheck_891_ = !lean_is_exclusive(v___x_882_);
if (v_isSharedCheck_891_ == 0)
{
v___x_885_ = v___x_882_;
v_isShared_886_ = v_isSharedCheck_891_;
goto v_resetjp_884_;
}
else
{
lean_inc(v_a_883_);
lean_dec(v___x_882_);
v___x_885_ = lean_box(0);
v_isShared_886_ = v_isSharedCheck_891_;
goto v_resetjp_884_;
}
v_resetjp_884_:
{
lean_object* v___x_887_; lean_object* v___x_889_; 
v___x_887_ = lp_loam_Loam_Persistence_decodeEventMemory_x3f(v_a_883_);
lean_dec(v_a_883_);
if (v_isShared_886_ == 0)
{
lean_ctor_set(v___x_885_, 0, v___x_887_);
v___x_889_ = v___x_885_;
goto v_reusejp_888_;
}
else
{
lean_object* v_reuseFailAlloc_890_; 
v_reuseFailAlloc_890_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_890_, 0, v___x_887_);
v___x_889_ = v_reuseFailAlloc_890_;
goto v_reusejp_888_;
}
v_reusejp_888_:
{
return v___x_889_;
}
}
}
else
{
lean_object* v_a_892_; lean_object* v___x_894_; uint8_t v_isShared_895_; uint8_t v_isSharedCheck_899_; 
v_a_892_ = lean_ctor_get(v___x_882_, 0);
v_isSharedCheck_899_ = !lean_is_exclusive(v___x_882_);
if (v_isSharedCheck_899_ == 0)
{
v___x_894_ = v___x_882_;
v_isShared_895_ = v_isSharedCheck_899_;
goto v_resetjp_893_;
}
else
{
lean_inc(v_a_892_);
lean_dec(v___x_882_);
v___x_894_ = lean_box(0);
v_isShared_895_ = v_isSharedCheck_899_;
goto v_resetjp_893_;
}
v_resetjp_893_:
{
lean_object* v___x_897_; 
if (v_isShared_895_ == 0)
{
v___x_897_ = v___x_894_;
goto v_reusejp_896_;
}
else
{
lean_object* v_reuseFailAlloc_898_; 
v_reuseFailAlloc_898_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_898_, 0, v_a_892_);
v___x_897_ = v_reuseFailAlloc_898_;
goto v_reusejp_896_;
}
v_reusejp_896_:
{
return v___x_897_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_loadEventMemory_x3f___boxed(lean_object* v_path_900_, lean_object* v_a_901_){
_start:
{
lean_object* v_res_902_; 
v_res_902_ = lp_loam_Loam_Persistence_loadEventMemory_x3f(v_path_900_);
lean_dec_ref(v_path_900_);
return v_res_902_;
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Persistence_0__Loam_Persistence_eventCorrectionMemoryStagePath(lean_object* v_path_903_){
_start:
{
lean_object* v___x_904_; lean_object* v___x_905_; 
v___x_904_ = ((lean_object*)(lp_loam___private_Loam_Persistence_0__Loam_Persistence_eventMemoryStagePath___closed__0));
v___x_905_ = lean_string_append(v_path_903_, v___x_904_);
return v___x_905_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_saveEventCorrectionMemory_x3f(lean_object* v_path_906_, lean_object* v_memory_907_){
_start:
{
lean_object* v___x_909_; 
v___x_909_ = lp_loam_Loam_Persistence_encodeEventCorrectionMemory_x3f(v_memory_907_);
if (lean_obj_tag(v___x_909_) == 0)
{
uint8_t v___x_910_; lean_object* v___x_911_; lean_object* v___x_912_; 
lean_dec_ref(v_path_906_);
v___x_910_ = 0;
v___x_911_ = lean_box(v___x_910_);
v___x_912_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v___x_912_, 0, v___x_911_);
return v___x_912_;
}
else
{
lean_object* v_val_913_; lean_object* v_stagePath_914_; lean_object* v___x_915_; 
v_val_913_ = lean_ctor_get(v___x_909_, 0);
lean_inc(v_val_913_);
lean_dec_ref_known(v___x_909_, 1);
lean_inc_ref(v_path_906_);
v_stagePath_914_ = lp_loam___private_Loam_Persistence_0__Loam_Persistence_eventCorrectionMemoryStagePath(v_path_906_);
v___x_915_ = l_IO_FS_writeFile(v_stagePath_914_, v_val_913_);
lean_dec(v_val_913_);
if (lean_obj_tag(v___x_915_) == 0)
{
lean_object* v___x_916_; 
lean_dec_ref_known(v___x_915_, 1);
v___x_916_ = lean_io_rename(v_stagePath_914_, v_path_906_);
lean_dec_ref(v_path_906_);
lean_dec_ref(v_stagePath_914_);
if (lean_obj_tag(v___x_916_) == 0)
{
lean_object* v___x_918_; uint8_t v_isShared_919_; uint8_t v_isSharedCheck_925_; 
v_isSharedCheck_925_ = !lean_is_exclusive(v___x_916_);
if (v_isSharedCheck_925_ == 0)
{
lean_object* v_unused_926_; 
v_unused_926_ = lean_ctor_get(v___x_916_, 0);
lean_dec(v_unused_926_);
v___x_918_ = v___x_916_;
v_isShared_919_ = v_isSharedCheck_925_;
goto v_resetjp_917_;
}
else
{
lean_dec(v___x_916_);
v___x_918_ = lean_box(0);
v_isShared_919_ = v_isSharedCheck_925_;
goto v_resetjp_917_;
}
v_resetjp_917_:
{
uint8_t v___x_920_; lean_object* v___x_921_; lean_object* v___x_923_; 
v___x_920_ = 1;
v___x_921_ = lean_box(v___x_920_);
if (v_isShared_919_ == 0)
{
lean_ctor_set(v___x_918_, 0, v___x_921_);
v___x_923_ = v___x_918_;
goto v_reusejp_922_;
}
else
{
lean_object* v_reuseFailAlloc_924_; 
v_reuseFailAlloc_924_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_924_, 0, v___x_921_);
v___x_923_ = v_reuseFailAlloc_924_;
goto v_reusejp_922_;
}
v_reusejp_922_:
{
return v___x_923_;
}
}
}
else
{
lean_object* v_a_927_; lean_object* v___x_929_; uint8_t v_isShared_930_; uint8_t v_isSharedCheck_934_; 
v_a_927_ = lean_ctor_get(v___x_916_, 0);
v_isSharedCheck_934_ = !lean_is_exclusive(v___x_916_);
if (v_isSharedCheck_934_ == 0)
{
v___x_929_ = v___x_916_;
v_isShared_930_ = v_isSharedCheck_934_;
goto v_resetjp_928_;
}
else
{
lean_inc(v_a_927_);
lean_dec(v___x_916_);
v___x_929_ = lean_box(0);
v_isShared_930_ = v_isSharedCheck_934_;
goto v_resetjp_928_;
}
v_resetjp_928_:
{
lean_object* v___x_932_; 
if (v_isShared_930_ == 0)
{
v___x_932_ = v___x_929_;
goto v_reusejp_931_;
}
else
{
lean_object* v_reuseFailAlloc_933_; 
v_reuseFailAlloc_933_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_933_, 0, v_a_927_);
v___x_932_ = v_reuseFailAlloc_933_;
goto v_reusejp_931_;
}
v_reusejp_931_:
{
return v___x_932_;
}
}
}
}
else
{
lean_object* v_a_935_; lean_object* v___x_937_; uint8_t v_isShared_938_; uint8_t v_isSharedCheck_942_; 
lean_dec_ref(v_stagePath_914_);
lean_dec_ref(v_path_906_);
v_a_935_ = lean_ctor_get(v___x_915_, 0);
v_isSharedCheck_942_ = !lean_is_exclusive(v___x_915_);
if (v_isSharedCheck_942_ == 0)
{
v___x_937_ = v___x_915_;
v_isShared_938_ = v_isSharedCheck_942_;
goto v_resetjp_936_;
}
else
{
lean_inc(v_a_935_);
lean_dec(v___x_915_);
v___x_937_ = lean_box(0);
v_isShared_938_ = v_isSharedCheck_942_;
goto v_resetjp_936_;
}
v_resetjp_936_:
{
lean_object* v___x_940_; 
if (v_isShared_938_ == 0)
{
v___x_940_ = v___x_937_;
goto v_reusejp_939_;
}
else
{
lean_object* v_reuseFailAlloc_941_; 
v_reuseFailAlloc_941_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_941_, 0, v_a_935_);
v___x_940_ = v_reuseFailAlloc_941_;
goto v_reusejp_939_;
}
v_reusejp_939_:
{
return v___x_940_;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_saveEventCorrectionMemory_x3f___boxed(lean_object* v_path_943_, lean_object* v_memory_944_, lean_object* v_a_945_){
_start:
{
lean_object* v_res_946_; 
v_res_946_ = lp_loam_Loam_Persistence_saveEventCorrectionMemory_x3f(v_path_943_, v_memory_944_);
return v_res_946_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_loadEventCorrectionMemory_x3f(lean_object* v_path_947_){
_start:
{
lean_object* v___x_949_; 
v___x_949_ = l_IO_FS_readFile(v_path_947_);
if (lean_obj_tag(v___x_949_) == 0)
{
lean_object* v_a_950_; lean_object* v___x_952_; uint8_t v_isShared_953_; uint8_t v_isSharedCheck_958_; 
v_a_950_ = lean_ctor_get(v___x_949_, 0);
v_isSharedCheck_958_ = !lean_is_exclusive(v___x_949_);
if (v_isSharedCheck_958_ == 0)
{
v___x_952_ = v___x_949_;
v_isShared_953_ = v_isSharedCheck_958_;
goto v_resetjp_951_;
}
else
{
lean_inc(v_a_950_);
lean_dec(v___x_949_);
v___x_952_ = lean_box(0);
v_isShared_953_ = v_isSharedCheck_958_;
goto v_resetjp_951_;
}
v_resetjp_951_:
{
lean_object* v___x_954_; lean_object* v___x_956_; 
v___x_954_ = lp_loam_Loam_Persistence_decodeEventCorrectionMemory_x3f(v_a_950_);
lean_dec(v_a_950_);
if (v_isShared_953_ == 0)
{
lean_ctor_set(v___x_952_, 0, v___x_954_);
v___x_956_ = v___x_952_;
goto v_reusejp_955_;
}
else
{
lean_object* v_reuseFailAlloc_957_; 
v_reuseFailAlloc_957_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_957_, 0, v___x_954_);
v___x_956_ = v_reuseFailAlloc_957_;
goto v_reusejp_955_;
}
v_reusejp_955_:
{
return v___x_956_;
}
}
}
else
{
lean_object* v_a_959_; lean_object* v___x_961_; uint8_t v_isShared_962_; uint8_t v_isSharedCheck_966_; 
v_a_959_ = lean_ctor_get(v___x_949_, 0);
v_isSharedCheck_966_ = !lean_is_exclusive(v___x_949_);
if (v_isSharedCheck_966_ == 0)
{
v___x_961_ = v___x_949_;
v_isShared_962_ = v_isSharedCheck_966_;
goto v_resetjp_960_;
}
else
{
lean_inc(v_a_959_);
lean_dec(v___x_949_);
v___x_961_ = lean_box(0);
v_isShared_962_ = v_isSharedCheck_966_;
goto v_resetjp_960_;
}
v_resetjp_960_:
{
lean_object* v___x_964_; 
if (v_isShared_962_ == 0)
{
v___x_964_ = v___x_961_;
goto v_reusejp_963_;
}
else
{
lean_object* v_reuseFailAlloc_965_; 
v_reuseFailAlloc_965_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_965_, 0, v_a_959_);
v___x_964_ = v_reuseFailAlloc_965_;
goto v_reusejp_963_;
}
v_reusejp_963_:
{
return v___x_964_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Persistence_loadEventCorrectionMemory_x3f___boxed(lean_object* v_path_967_, lean_object* v_a_968_){
_start:
{
lean_object* v_res_969_; 
v_res_969_ = lp_loam_Loam_Persistence_loadEventCorrectionMemory_x3f(v_path_967_);
lean_dec_ref(v_path_967_);
return v_res_969_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_loam_Loam_Core_EventCorrectionMemory(uint8_t builtin);
lean_object* initialize_loam_Loam_Core_EventMemory(uint8_t builtin);
lean_object* initialize_Std(uint8_t builtin);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_loam_Loam_Persistence(uint8_t builtin) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_loam_Loam_Core_EventCorrectionMemory(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_loam_Loam_Core_EventMemory(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_Std(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
