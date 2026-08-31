// Lean compiler output
// Module: Loam.Cli
// Imports: public import Init public meta import Init public import Loam.Persistence public import Std
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
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
lean_object* l_Nat_reprFast(lean_object*);
lean_object* lean_string_append(lean_object*, lean_object*);
lean_object* lp_loam___private_Loam_Core_EventMemory_0__Loam_Core_EventMemory_findEventById_x3f(lean_object*, lean_object*);
lean_object* lean_nat_sub(lean_object*, lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
uint8_t l_System_FilePath_pathExists(lean_object*);
lean_object* lp_loam_Loam_Core_EventMemory_ofEvents_x3f(lean_object*);
lean_object* lp_loam_Loam_Persistence_loadEventMemory_x3f(lean_object*);
lean_object* lp_loam_Loam_Persistence_loadEvent_x3f(lean_object*);
lean_object* l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(lean_object*);
lean_object* lp_loam_Loam_Core_Event_quantityAt(lean_object*, lean_object*, lean_object*);
lean_object* l_Int_repr(lean_object*);
lean_object* lean_string_push(lean_object*, uint32_t);
lean_object* lean_get_stdout();
lean_object* lean_get_stdin();
lean_object* lean_string_utf8_byte_size(lean_object*);
lean_object* l_String_Slice_Pos_revSkipWhile___at___00__private_Std_Http_Protocol_H1_Parser_0__Std_Http_Protocol_H1_parseFieldLine_spec__0(lean_object*, lean_object*);
lean_object* l_String_Slice_toString(lean_object*);
uint8_t lp_loam_Loam_Persistence_validToken(lean_object*);
lean_object* l_String_Slice_toInt_x3f(lean_object*);
lean_object* lean_nat_to_int(lean_object*);
uint8_t lean_int_dec_lt(lean_object*, lean_object*);
lean_object* l_List_lengthTR___redArg(lean_object*);
lean_object* lean_int_neg(lean_object*);
lean_object* lp_loam_Loam_Core_Effect_ofQuantity(lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* lp_loam_Loam_Core_Event_ofEffects_x3f(lean_object*, lean_object*);
lean_object* lp_loam_Loam_Core_EventMemory_add_x3f(lean_object*, lean_object*);
lean_object* lp_loam_Loam_Persistence_saveEventMemory_x3f(lean_object*, lean_object*);
uint8_t lean_string_dec_eq(lean_object*, lean_object*);
lean_object* lp_loam_Loam_Core_EventMemory_quantityAtRecorded(lean_object*, lean_object*, lean_object*);
lean_object* lp_loam_Loam_Persistence_encodeEvent_x3f(lean_object*);
lean_object* lp_loam_Loam_Persistence_saveEvent_x3f(lean_object*, lean_object*);
lean_object* lp_loam_Loam_Persistence_load_x3f(lean_object*);
static const lean_string_object lp_loam_Loam_Cli_renderAmount___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "\t"};
static const lean_object* lp_loam_Loam_Cli_renderAmount___closed__0 = (const lean_object*)&lp_loam_Loam_Cli_renderAmount___closed__0_value;
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_renderAmount(lean_object*);
static const lean_string_object lp_loam___private_Loam_Cli_0__Loam_Cli_usage___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 288, .m_capacity = 288, .m_length = 287, .m_data = "usage:\n  loam spend MEMORY_FILE\n  loam amount show FILE\n  loam event create FILE EVENT [KEY LOCUS MEASURE QUANTA]...\n  loam event quantity FILE LOCUS MEASURE\n  loam event-memory get FILE EVENT\n  loam event-memory quantity FILE LOCUS MEASURE\n  loam event-memory add MEMORY_FILE EVENT_FILE"};
static const lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_usage___closed__0 = (const lean_object*)&lp_loam___private_Loam_Cli_0__Loam_Cli_usage___closed__0_value;
LEAN_EXPORT const lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_usage = (const lean_object*)&lp_loam___private_Loam_Cli_0__Loam_Cli_usage___closed__0_value;
static const lean_ctor_object lp_loam___private_Loam_Cli_0__Loam_Cli_parseEffects___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 1}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1))}};
static const lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_parseEffects___closed__0 = (const lean_object*)&lp_loam___private_Loam_Cli_0__Loam_Cli_parseEffects___closed__0_value;
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_parseEffects(lean_object*);
LEAN_EXPORT lean_object* lp_loam_IO_print___at___00IO_println___at___00Loam_Cli_showAmount_spec__0_spec__0(lean_object*);
LEAN_EXPORT lean_object* lp_loam_IO_print___at___00IO_println___at___00Loam_Cli_showAmount_spec__0_spec__0___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_IO_println___at___00Loam_Cli_showAmount_spec__0(lean_object*);
LEAN_EXPORT lean_object* lp_loam_IO_println___at___00Loam_Cli_showAmount_spec__0___boxed(lean_object*, lean_object*);
static const lean_string_object lp_loam_Loam_Cli_showAmount___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 43, .m_capacity = 43, .m_length = 42, .m_data = "loam: malformed or unsupported amount file"};
static const lean_object* lp_loam_Loam_Cli_showAmount___closed__0 = (const lean_object*)&lp_loam_Loam_Cli_showAmount___closed__0_value;
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showAmount___boxed__const__1;
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showAmount___boxed__const__2;
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showAmount(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showAmount___boxed(lean_object*, lean_object*);
static const lean_string_object lp_loam_Loam_Cli_createEvent___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 60, .m_capacity = 60, .m_length = 59, .m_data = "loam: event effects must be KEY LOCUS MEASURE QUANTA tuples"};
static const lean_object* lp_loam_Loam_Cli_createEvent___closed__0 = (const lean_object*)&lp_loam_Loam_Cli_createEvent___closed__0_value;
static const lean_string_object lp_loam_Loam_Cli_createEvent___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 36, .m_capacity = 36, .m_length = 35, .m_data = "loam: duplicate effect key in event"};
static const lean_object* lp_loam_Loam_Cli_createEvent___closed__1 = (const lean_object*)&lp_loam_Loam_Cli_createEvent___closed__1_value;
static const lean_string_object lp_loam_Loam_Cli_createEvent___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 55, .m_capacity = 55, .m_length = 54, .m_data = "loam: event contains an unrepresentable identity token"};
static const lean_object* lp_loam_Loam_Cli_createEvent___closed__2 = (const lean_object*)&lp_loam_Loam_Cli_createEvent___closed__2_value;
static const lean_string_object lp_loam_Loam_Cli_createEvent___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 39, .m_capacity = 39, .m_length = 38, .m_data = "loam: target event file already exists"};
static const lean_object* lp_loam_Loam_Cli_createEvent___closed__3 = (const lean_object*)&lp_loam_Loam_Cli_createEvent___closed__3_value;
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_createEvent(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_createEvent___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
static const lean_string_object lp_loam_Loam_Cli_showEventQuantity___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 42, .m_capacity = 42, .m_length = 41, .m_data = "loam: malformed or unsupported event file"};
static const lean_object* lp_loam_Loam_Cli_showEventQuantity___closed__0 = (const lean_object*)&lp_loam_Loam_Cli_showEventQuantity___closed__0_value;
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showEventQuantity(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showEventQuantity___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
static const lean_string_object lp_loam_Loam_Cli_showRememberedEvent___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 49, .m_capacity = 49, .m_length = 48, .m_data = "loam: malformed or unsupported event-memory file"};
static const lean_object* lp_loam_Loam_Cli_showRememberedEvent___closed__0 = (const lean_object*)&lp_loam_Loam_Cli_showRememberedEvent___closed__0_value;
static const lean_string_object lp_loam_Loam_Cli_showRememberedEvent___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 32, .m_capacity = 32, .m_length = 31, .m_data = "loam: event not found in memory"};
static const lean_object* lp_loam_Loam_Cli_showRememberedEvent___closed__1 = (const lean_object*)&lp_loam_Loam_Cli_showRememberedEvent___closed__1_value;
static const lean_string_object lp_loam_Loam_Cli_showRememberedEvent___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 45, .m_capacity = 45, .m_length = 44, .m_data = "loam: remembered event cannot be represented"};
static const lean_object* lp_loam_Loam_Cli_showRememberedEvent___closed__2 = (const lean_object*)&lp_loam_Loam_Cli_showRememberedEvent___closed__2_value;
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showRememberedEvent___boxed__const__1;
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showRememberedEvent(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showRememberedEvent___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showRememberedQuantity(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showRememberedQuantity___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
static const lean_string_object lp_loam_Loam_Cli_addRememberedEvent___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 40, .m_capacity = 40, .m_length = 39, .m_data = "loam: event identity already remembered"};
static const lean_object* lp_loam_Loam_Cli_addRememberedEvent___closed__0 = (const lean_object*)&lp_loam_Loam_Cli_addRememberedEvent___closed__0_value;
static const lean_string_object lp_loam_Loam_Cli_addRememberedEvent___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 70, .m_capacity = 70, .m_length = 69, .m_data = "loam: updated event memory contains an unrepresentable identity token"};
static const lean_object* lp_loam_Loam_Cli_addRememberedEvent___closed__1 = (const lean_object*)&lp_loam_Loam_Cli_addRememberedEvent___closed__1_value;
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_addRememberedEvent(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_addRememberedEvent___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_promptLine(lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_promptLine___boxed(lean_object*, lean_object*);
static const lean_string_object lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventIdFrom___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "record-"};
static const lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventIdFrom___closed__0 = (const lean_object*)&lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventIdFrom___closed__0_value;
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventIdFrom(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventIdFrom___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventId_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventId_x3f___boxed(lean_object*);
static lean_once_cell_t lp_loam___private_Loam_Cli_0__Loam_Cli_loadEventMemoryForEntry_x3f___closed__0_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_loadEventMemoryForEntry_x3f___closed__0;
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_loadEventMemoryForEntry_x3f(lean_object*);
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_loadEventMemoryForEntry_x3f___boxed(lean_object*, lean_object*);
static const lean_string_object lp_loam_Loam_Cli_spendJpy___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 12, .m_capacity = 12, .m_length = 11, .m_data = "Paid from\? "};
static const lean_object* lp_loam_Loam_Cli_spendJpy___closed__0 = (const lean_object*)&lp_loam_Loam_Cli_spendJpy___closed__0_value;
static const lean_string_object lp_loam_Loam_Cli_spendJpy___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 58, .m_capacity = 58, .m_length = 57, .m_data = "loam: payment source must be a nonempty single-line token"};
static const lean_object* lp_loam_Loam_Cli_spendJpy___closed__1 = (const lean_object*)&lp_loam_Loam_Cli_spendJpy___closed__1_value;
static const lean_string_object lp_loam_Loam_Cli_spendJpy___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 9, .m_capacity = 9, .m_length = 8, .m_data = "Amount\? "};
static const lean_object* lp_loam_Loam_Cli_spendJpy___closed__2 = (const lean_object*)&lp_loam_Loam_Cli_spendJpy___closed__2_value;
static const lean_string_object lp_loam_Loam_Cli_spendJpy___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 40, .m_capacity = 40, .m_length = 39, .m_data = "loam: amount must be a positive integer"};
static const lean_object* lp_loam_Loam_Cli_spendJpy___closed__3 = (const lean_object*)&lp_loam_Loam_Cli_spendJpy___closed__3_value;
static lean_once_cell_t lp_loam_Loam_Cli_spendJpy___closed__4_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_loam_Loam_Cli_spendJpy___closed__4;
static const lean_string_object lp_loam_Loam_Cli_spendJpy___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 48, .m_capacity = 48, .m_length = 47, .m_data = "loam: could not generate a fresh event identity"};
static const lean_object* lp_loam_Loam_Cli_spendJpy___closed__5 = (const lean_object*)&lp_loam_Loam_Cli_spendJpy___closed__5_value;
static const lean_string_object lp_loam_Loam_Cli_spendJpy___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 9, .m_capacity = 9, .m_length = 8, .m_data = "effect-1"};
static const lean_object* lp_loam_Loam_Cli_spendJpy___closed__6 = (const lean_object*)&lp_loam_Loam_Cli_spendJpy___closed__6_value;
static const lean_string_object lp_loam_Loam_Cli_spendJpy___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 4, .m_capacity = 4, .m_length = 3, .m_data = "jpy"};
static const lean_object* lp_loam_Loam_Cli_spendJpy___closed__7 = (const lean_object*)&lp_loam_Loam_Cli_spendJpy___closed__7_value;
static const lean_string_object lp_loam_Loam_Cli_spendJpy___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 38, .m_capacity = 38, .m_length = 37, .m_data = "loam: could not admit generated event"};
static const lean_object* lp_loam_Loam_Cli_spendJpy___closed__8 = (const lean_object*)&lp_loam_Loam_Cli_spendJpy___closed__8_value;
static const lean_string_object lp_loam_Loam_Cli_spendJpy___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 50, .m_capacity = 50, .m_length = 49, .m_data = "loam: generated event identity already remembered"};
static const lean_object* lp_loam_Loam_Cli_spendJpy___closed__9 = (const lean_object*)&lp_loam_Loam_Cli_spendJpy___closed__9_value;
static const lean_string_object lp_loam_Loam_Cli_spendJpy___closed__10_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 64, .m_capacity = 64, .m_length = 63, .m_data = "loam: recorded event contains an unrepresentable identity token"};
static const lean_object* lp_loam_Loam_Cli_spendJpy___closed__10 = (const lean_object*)&lp_loam_Loam_Cli_spendJpy___closed__10_value;
static const lean_string_object lp_loam_Loam_Cli_spendJpy___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 17, .m_capacity = 17, .m_length = 16, .m_data = "Recorded: spent "};
static const lean_object* lp_loam_Loam_Cli_spendJpy___closed__11 = (const lean_object*)&lp_loam_Loam_Cli_spendJpy___closed__11_value;
static const lean_string_object lp_loam_Loam_Cli_spendJpy___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 11, .m_capacity = 11, .m_length = 10, .m_data = " jpy from "};
static const lean_object* lp_loam_Loam_Cli_spendJpy___closed__12 = (const lean_object*)&lp_loam_Loam_Cli_spendJpy___closed__12_value;
static const lean_string_object lp_loam_Loam_Cli_spendJpy___closed__13_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "."};
static const lean_object* lp_loam_Loam_Cli_spendJpy___closed__13 = (const lean_object*)&lp_loam_Loam_Cli_spendJpy___closed__13_value;
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_spendJpy(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_spendJpy___boxed(lean_object*, lean_object*);
static const lean_string_object lp_loam_Loam_Cli_run___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 6, .m_capacity = 6, .m_length = 5, .m_data = "spend"};
static const lean_object* lp_loam_Loam_Cli_run___closed__0 = (const lean_object*)&lp_loam_Loam_Cli_run___closed__0_value;
static const lean_string_object lp_loam_Loam_Cli_run___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "amount"};
static const lean_object* lp_loam_Loam_Cli_run___closed__1 = (const lean_object*)&lp_loam_Loam_Cli_run___closed__1_value;
static const lean_string_object lp_loam_Loam_Cli_run___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 6, .m_capacity = 6, .m_length = 5, .m_data = "event"};
static const lean_object* lp_loam_Loam_Cli_run___closed__2 = (const lean_object*)&lp_loam_Loam_Cli_run___closed__2_value;
static const lean_string_object lp_loam_Loam_Cli_run___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 13, .m_capacity = 13, .m_length = 12, .m_data = "event-memory"};
static const lean_object* lp_loam_Loam_Cli_run___closed__3 = (const lean_object*)&lp_loam_Loam_Cli_run___closed__3_value;
static const lean_string_object lp_loam_Loam_Cli_run___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 4, .m_capacity = 4, .m_length = 3, .m_data = "get"};
static const lean_object* lp_loam_Loam_Cli_run___closed__4 = (const lean_object*)&lp_loam_Loam_Cli_run___closed__4_value;
static const lean_string_object lp_loam_Loam_Cli_run___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 9, .m_capacity = 9, .m_length = 8, .m_data = "quantity"};
static const lean_object* lp_loam_Loam_Cli_run___closed__5 = (const lean_object*)&lp_loam_Loam_Cli_run___closed__5_value;
static const lean_string_object lp_loam_Loam_Cli_run___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 4, .m_capacity = 4, .m_length = 3, .m_data = "add"};
static const lean_object* lp_loam_Loam_Cli_run___closed__6 = (const lean_object*)&lp_loam_Loam_Cli_run___closed__6_value;
static const lean_string_object lp_loam_Loam_Cli_run___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "create"};
static const lean_object* lp_loam_Loam_Cli_run___closed__7 = (const lean_object*)&lp_loam_Loam_Cli_run___closed__7_value;
static const lean_string_object lp_loam_Loam_Cli_run___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 5, .m_capacity = 5, .m_length = 4, .m_data = "show"};
static const lean_object* lp_loam_Loam_Cli_run___closed__8 = (const lean_object*)&lp_loam_Loam_Cli_run___closed__8_value;
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_run(lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_run___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* _lean_main(lean_object*);
LEAN_EXPORT lean_object* lp_loam_main___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_renderAmount(lean_object* v_amount_2_){
_start:
{
lean_object* v_fst_3_; lean_object* v_snd_4_; lean_object* v___x_5_; lean_object* v___x_6_; lean_object* v___x_7_; lean_object* v___x_8_; 
v_fst_3_ = lean_ctor_get(v_amount_2_, 0);
lean_inc(v_fst_3_);
v_snd_4_ = lean_ctor_get(v_amount_2_, 1);
lean_inc(v_snd_4_);
lean_dec_ref(v_amount_2_);
v___x_5_ = ((lean_object*)(lp_loam_Loam_Cli_renderAmount___closed__0));
v___x_6_ = lean_string_append(v_fst_3_, v___x_5_);
v___x_7_ = l_Int_repr(v_snd_4_);
lean_dec(v_snd_4_);
v___x_8_ = lean_string_append(v___x_6_, v___x_7_);
lean_dec_ref(v___x_7_);
return v___x_8_;
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_parseEffects(lean_object* v_x_13_){
_start:
{
if (lean_obj_tag(v_x_13_) == 0)
{
lean_object* v___x_14_; 
v___x_14_ = ((lean_object*)(lp_loam___private_Loam_Cli_0__Loam_Cli_parseEffects___closed__0));
return v___x_14_;
}
else
{
lean_object* v_tail_15_; 
v_tail_15_ = lean_ctor_get(v_x_13_, 1);
lean_inc(v_tail_15_);
if (lean_obj_tag(v_tail_15_) == 1)
{
lean_object* v_tail_16_; 
v_tail_16_ = lean_ctor_get(v_tail_15_, 1);
lean_inc(v_tail_16_);
if (lean_obj_tag(v_tail_16_) == 1)
{
lean_object* v_tail_17_; 
v_tail_17_ = lean_ctor_get(v_tail_16_, 1);
lean_inc(v_tail_17_);
if (lean_obj_tag(v_tail_17_) == 1)
{
lean_object* v_head_18_; lean_object* v_head_19_; lean_object* v_head_20_; lean_object* v_head_21_; lean_object* v_tail_22_; lean_object* v___x_24_; uint8_t v_isShared_25_; uint8_t v_isSharedCheck_45_; 
v_head_18_ = lean_ctor_get(v_x_13_, 0);
lean_inc(v_head_18_);
lean_dec_ref_known(v_x_13_, 2);
v_head_19_ = lean_ctor_get(v_tail_15_, 0);
lean_inc(v_head_19_);
lean_dec_ref_known(v_tail_15_, 2);
v_head_20_ = lean_ctor_get(v_tail_16_, 0);
lean_inc(v_head_20_);
lean_dec_ref_known(v_tail_16_, 2);
v_head_21_ = lean_ctor_get(v_tail_17_, 0);
v_tail_22_ = lean_ctor_get(v_tail_17_, 1);
v_isSharedCheck_45_ = !lean_is_exclusive(v_tail_17_);
if (v_isSharedCheck_45_ == 0)
{
v___x_24_ = v_tail_17_;
v_isShared_25_ = v_isSharedCheck_45_;
goto v_resetjp_23_;
}
else
{
lean_inc(v_tail_22_);
lean_inc(v_head_21_);
lean_dec(v_tail_17_);
v___x_24_ = lean_box(0);
v_isShared_25_ = v_isSharedCheck_45_;
goto v_resetjp_23_;
}
v_resetjp_23_:
{
lean_object* v___x_26_; lean_object* v___x_27_; lean_object* v___x_28_; lean_object* v___x_29_; 
v___x_26_ = lean_unsigned_to_nat(0u);
v___x_27_ = lean_string_utf8_byte_size(v_head_21_);
v___x_28_ = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(v___x_28_, 0, v_head_21_);
lean_ctor_set(v___x_28_, 1, v___x_26_);
lean_ctor_set(v___x_28_, 2, v___x_27_);
v___x_29_ = l_String_Slice_toInt_x3f(v___x_28_);
if (lean_obj_tag(v___x_29_) == 0)
{
lean_object* v___x_30_; 
lean_del_object(v___x_24_);
lean_dec(v_tail_22_);
lean_dec(v_head_20_);
lean_dec(v_head_19_);
lean_dec(v_head_18_);
v___x_30_ = lean_box(0);
return v___x_30_;
}
else
{
lean_object* v_val_31_; lean_object* v___x_32_; 
v_val_31_ = lean_ctor_get(v___x_29_, 0);
lean_inc(v_val_31_);
lean_dec_ref_known(v___x_29_, 1);
v___x_32_ = lp_loam___private_Loam_Cli_0__Loam_Cli_parseEffects(v_tail_22_);
if (lean_obj_tag(v___x_32_) == 0)
{
lean_dec(v_val_31_);
lean_del_object(v___x_24_);
lean_dec(v_head_20_);
lean_dec(v_head_19_);
lean_dec(v_head_18_);
return v___x_32_;
}
else
{
lean_object* v_val_33_; lean_object* v___x_35_; uint8_t v_isShared_36_; uint8_t v_isSharedCheck_44_; 
v_val_33_ = lean_ctor_get(v___x_32_, 0);
v_isSharedCheck_44_ = !lean_is_exclusive(v___x_32_);
if (v_isSharedCheck_44_ == 0)
{
v___x_35_ = v___x_32_;
v_isShared_36_ = v_isSharedCheck_44_;
goto v_resetjp_34_;
}
else
{
lean_inc(v_val_33_);
lean_dec(v___x_32_);
v___x_35_ = lean_box(0);
v_isShared_36_ = v_isSharedCheck_44_;
goto v_resetjp_34_;
}
v_resetjp_34_:
{
lean_object* v___x_37_; lean_object* v___x_39_; 
v___x_37_ = lp_loam_Loam_Core_Effect_ofQuantity(v_head_18_, v_head_19_, v_head_20_, v_val_31_);
if (v_isShared_25_ == 0)
{
lean_ctor_set(v___x_24_, 1, v_val_33_);
lean_ctor_set(v___x_24_, 0, v___x_37_);
v___x_39_ = v___x_24_;
goto v_reusejp_38_;
}
else
{
lean_object* v_reuseFailAlloc_43_; 
v_reuseFailAlloc_43_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_43_, 0, v___x_37_);
lean_ctor_set(v_reuseFailAlloc_43_, 1, v_val_33_);
v___x_39_ = v_reuseFailAlloc_43_;
goto v_reusejp_38_;
}
v_reusejp_38_:
{
lean_object* v___x_41_; 
if (v_isShared_36_ == 0)
{
lean_ctor_set(v___x_35_, 0, v___x_39_);
v___x_41_ = v___x_35_;
goto v_reusejp_40_;
}
else
{
lean_object* v_reuseFailAlloc_42_; 
v_reuseFailAlloc_42_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_42_, 0, v___x_39_);
v___x_41_ = v_reuseFailAlloc_42_;
goto v_reusejp_40_;
}
v_reusejp_40_:
{
return v___x_41_;
}
}
}
}
}
}
}
else
{
lean_object* v___x_46_; 
lean_dec(v_tail_17_);
lean_dec_ref_known(v_tail_16_, 2);
lean_dec_ref_known(v_tail_15_, 2);
lean_dec_ref_known(v_x_13_, 2);
v___x_46_ = lean_box(0);
return v___x_46_;
}
}
else
{
lean_object* v___x_47_; 
lean_dec_ref_known(v_tail_15_, 2);
lean_dec(v_tail_16_);
lean_dec_ref_known(v_x_13_, 2);
v___x_47_ = lean_box(0);
return v___x_47_;
}
}
else
{
lean_object* v___x_48_; 
lean_dec_ref_known(v_x_13_, 2);
lean_dec(v_tail_15_);
v___x_48_ = lean_box(0);
return v___x_48_;
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_IO_print___at___00IO_println___at___00Loam_Cli_showAmount_spec__0_spec__0(lean_object* v_s_49_){
_start:
{
lean_object* v___x_51_; lean_object* v_putStr_52_; lean_object* v___x_53_; 
v___x_51_ = lean_get_stdout();
v_putStr_52_ = lean_ctor_get(v___x_51_, 4);
lean_inc_ref(v_putStr_52_);
lean_dec_ref(v___x_51_);
v___x_53_ = lean_apply_2(v_putStr_52_, v_s_49_, lean_box(0));
return v___x_53_;
}
}
LEAN_EXPORT lean_object* lp_loam_IO_print___at___00IO_println___at___00Loam_Cli_showAmount_spec__0_spec__0___boxed(lean_object* v_s_54_, lean_object* v_a_55_){
_start:
{
lean_object* v_res_56_; 
v_res_56_ = lp_loam_IO_print___at___00IO_println___at___00Loam_Cli_showAmount_spec__0_spec__0(v_s_54_);
return v_res_56_;
}
}
LEAN_EXPORT lean_object* lp_loam_IO_println___at___00Loam_Cli_showAmount_spec__0(lean_object* v_s_57_){
_start:
{
uint32_t v___x_59_; lean_object* v___x_60_; lean_object* v___x_61_; 
v___x_59_ = 10;
v___x_60_ = lean_string_push(v_s_57_, v___x_59_);
v___x_61_ = lp_loam_IO_print___at___00IO_println___at___00Loam_Cli_showAmount_spec__0_spec__0(v___x_60_);
return v___x_61_;
}
}
LEAN_EXPORT lean_object* lp_loam_IO_println___at___00Loam_Cli_showAmount_spec__0___boxed(lean_object* v_s_62_, lean_object* v_a_63_){
_start:
{
lean_object* v_res_64_; 
v_res_64_ = lp_loam_IO_println___at___00Loam_Cli_showAmount_spec__0(v_s_62_);
return v_res_64_;
}
}
static lean_object* _init_lp_loam_Loam_Cli_showAmount___boxed__const__1(void){
_start:
{
uint32_t v___x_66_; lean_object* v___x_67_; 
v___x_66_ = 2;
v___x_67_ = lean_box_uint32(v___x_66_);
return v___x_67_;
}
}
static lean_object* _init_lp_loam_Loam_Cli_showAmount___boxed__const__2(void){
_start:
{
uint32_t v___x_68_; lean_object* v___x_69_; 
v___x_68_ = 0;
v___x_69_ = lean_box_uint32(v___x_68_);
return v___x_69_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showAmount(lean_object* v_path_70_){
_start:
{
lean_object* v___x_72_; 
v___x_72_ = lp_loam_Loam_Persistence_load_x3f(v_path_70_);
if (lean_obj_tag(v___x_72_) == 0)
{
lean_object* v_a_73_; 
v_a_73_ = lean_ctor_get(v___x_72_, 0);
lean_inc(v_a_73_);
lean_dec_ref_known(v___x_72_, 1);
if (lean_obj_tag(v_a_73_) == 0)
{
lean_object* v___x_74_; lean_object* v___x_75_; 
v___x_74_ = ((lean_object*)(lp_loam_Loam_Cli_showAmount___closed__0));
v___x_75_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_74_);
if (lean_obj_tag(v___x_75_) == 0)
{
lean_object* v___x_77_; uint8_t v_isShared_78_; uint8_t v_isSharedCheck_83_; 
v_isSharedCheck_83_ = !lean_is_exclusive(v___x_75_);
if (v_isSharedCheck_83_ == 0)
{
lean_object* v_unused_84_; 
v_unused_84_ = lean_ctor_get(v___x_75_, 0);
lean_dec(v_unused_84_);
v___x_77_ = v___x_75_;
v_isShared_78_ = v_isSharedCheck_83_;
goto v_resetjp_76_;
}
else
{
lean_dec(v___x_75_);
v___x_77_ = lean_box(0);
v_isShared_78_ = v_isSharedCheck_83_;
goto v_resetjp_76_;
}
v_resetjp_76_:
{
lean_object* v___x_79_; lean_object* v___x_81_; 
v___x_79_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_78_ == 0)
{
lean_ctor_set(v___x_77_, 0, v___x_79_);
v___x_81_ = v___x_77_;
goto v_reusejp_80_;
}
else
{
lean_object* v_reuseFailAlloc_82_; 
v_reuseFailAlloc_82_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_82_, 0, v___x_79_);
v___x_81_ = v_reuseFailAlloc_82_;
goto v_reusejp_80_;
}
v_reusejp_80_:
{
return v___x_81_;
}
}
}
else
{
lean_object* v_a_85_; lean_object* v___x_87_; uint8_t v_isShared_88_; uint8_t v_isSharedCheck_92_; 
v_a_85_ = lean_ctor_get(v___x_75_, 0);
v_isSharedCheck_92_ = !lean_is_exclusive(v___x_75_);
if (v_isSharedCheck_92_ == 0)
{
v___x_87_ = v___x_75_;
v_isShared_88_ = v_isSharedCheck_92_;
goto v_resetjp_86_;
}
else
{
lean_inc(v_a_85_);
lean_dec(v___x_75_);
v___x_87_ = lean_box(0);
v_isShared_88_ = v_isSharedCheck_92_;
goto v_resetjp_86_;
}
v_resetjp_86_:
{
lean_object* v___x_90_; 
if (v_isShared_88_ == 0)
{
v___x_90_ = v___x_87_;
goto v_reusejp_89_;
}
else
{
lean_object* v_reuseFailAlloc_91_; 
v_reuseFailAlloc_91_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_91_, 0, v_a_85_);
v___x_90_ = v_reuseFailAlloc_91_;
goto v_reusejp_89_;
}
v_reusejp_89_:
{
return v___x_90_;
}
}
}
}
else
{
lean_object* v_val_93_; lean_object* v___x_94_; lean_object* v___x_95_; 
v_val_93_ = lean_ctor_get(v_a_73_, 0);
lean_inc(v_val_93_);
lean_dec_ref_known(v_a_73_, 1);
v___x_94_ = lp_loam_Loam_Cli_renderAmount(v_val_93_);
v___x_95_ = lp_loam_IO_println___at___00Loam_Cli_showAmount_spec__0(v___x_94_);
if (lean_obj_tag(v___x_95_) == 0)
{
lean_object* v___x_97_; uint8_t v_isShared_98_; uint8_t v_isSharedCheck_103_; 
v_isSharedCheck_103_ = !lean_is_exclusive(v___x_95_);
if (v_isSharedCheck_103_ == 0)
{
lean_object* v_unused_104_; 
v_unused_104_ = lean_ctor_get(v___x_95_, 0);
lean_dec(v_unused_104_);
v___x_97_ = v___x_95_;
v_isShared_98_ = v_isSharedCheck_103_;
goto v_resetjp_96_;
}
else
{
lean_dec(v___x_95_);
v___x_97_ = lean_box(0);
v_isShared_98_ = v_isSharedCheck_103_;
goto v_resetjp_96_;
}
v_resetjp_96_:
{
lean_object* v___x_99_; lean_object* v___x_101_; 
v___x_99_ = lp_loam_Loam_Cli_showAmount___boxed__const__2;
if (v_isShared_98_ == 0)
{
lean_ctor_set(v___x_97_, 0, v___x_99_);
v___x_101_ = v___x_97_;
goto v_reusejp_100_;
}
else
{
lean_object* v_reuseFailAlloc_102_; 
v_reuseFailAlloc_102_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_102_, 0, v___x_99_);
v___x_101_ = v_reuseFailAlloc_102_;
goto v_reusejp_100_;
}
v_reusejp_100_:
{
return v___x_101_;
}
}
}
else
{
lean_object* v_a_105_; lean_object* v___x_107_; uint8_t v_isShared_108_; uint8_t v_isSharedCheck_112_; 
v_a_105_ = lean_ctor_get(v___x_95_, 0);
v_isSharedCheck_112_ = !lean_is_exclusive(v___x_95_);
if (v_isSharedCheck_112_ == 0)
{
v___x_107_ = v___x_95_;
v_isShared_108_ = v_isSharedCheck_112_;
goto v_resetjp_106_;
}
else
{
lean_inc(v_a_105_);
lean_dec(v___x_95_);
v___x_107_ = lean_box(0);
v_isShared_108_ = v_isSharedCheck_112_;
goto v_resetjp_106_;
}
v_resetjp_106_:
{
lean_object* v___x_110_; 
if (v_isShared_108_ == 0)
{
v___x_110_ = v___x_107_;
goto v_reusejp_109_;
}
else
{
lean_object* v_reuseFailAlloc_111_; 
v_reuseFailAlloc_111_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_111_, 0, v_a_105_);
v___x_110_ = v_reuseFailAlloc_111_;
goto v_reusejp_109_;
}
v_reusejp_109_:
{
return v___x_110_;
}
}
}
}
}
else
{
lean_object* v_a_113_; lean_object* v___x_115_; uint8_t v_isShared_116_; uint8_t v_isSharedCheck_120_; 
v_a_113_ = lean_ctor_get(v___x_72_, 0);
v_isSharedCheck_120_ = !lean_is_exclusive(v___x_72_);
if (v_isSharedCheck_120_ == 0)
{
v___x_115_ = v___x_72_;
v_isShared_116_ = v_isSharedCheck_120_;
goto v_resetjp_114_;
}
else
{
lean_inc(v_a_113_);
lean_dec(v___x_72_);
v___x_115_ = lean_box(0);
v_isShared_116_ = v_isSharedCheck_120_;
goto v_resetjp_114_;
}
v_resetjp_114_:
{
lean_object* v___x_118_; 
if (v_isShared_116_ == 0)
{
v___x_118_ = v___x_115_;
goto v_reusejp_117_;
}
else
{
lean_object* v_reuseFailAlloc_119_; 
v_reuseFailAlloc_119_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_119_, 0, v_a_113_);
v___x_118_ = v_reuseFailAlloc_119_;
goto v_reusejp_117_;
}
v_reusejp_117_:
{
return v___x_118_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showAmount___boxed(lean_object* v_path_121_, lean_object* v_a_122_){
_start:
{
lean_object* v_res_123_; 
v_res_123_ = lp_loam_Loam_Cli_showAmount(v_path_121_);
lean_dec_ref(v_path_121_);
return v_res_123_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_createEvent(lean_object* v_path_128_, lean_object* v_eventToken_129_, lean_object* v_effectArgs_130_){
_start:
{
lean_object* v___x_132_; 
v___x_132_ = lp_loam___private_Loam_Cli_0__Loam_Cli_parseEffects(v_effectArgs_130_);
if (lean_obj_tag(v___x_132_) == 0)
{
lean_object* v___x_133_; lean_object* v___x_134_; 
lean_dec_ref(v_eventToken_129_);
v___x_133_ = ((lean_object*)(lp_loam_Loam_Cli_createEvent___closed__0));
v___x_134_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_133_);
if (lean_obj_tag(v___x_134_) == 0)
{
lean_object* v___x_136_; uint8_t v_isShared_137_; uint8_t v_isSharedCheck_142_; 
v_isSharedCheck_142_ = !lean_is_exclusive(v___x_134_);
if (v_isSharedCheck_142_ == 0)
{
lean_object* v_unused_143_; 
v_unused_143_ = lean_ctor_get(v___x_134_, 0);
lean_dec(v_unused_143_);
v___x_136_ = v___x_134_;
v_isShared_137_ = v_isSharedCheck_142_;
goto v_resetjp_135_;
}
else
{
lean_dec(v___x_134_);
v___x_136_ = lean_box(0);
v_isShared_137_ = v_isSharedCheck_142_;
goto v_resetjp_135_;
}
v_resetjp_135_:
{
lean_object* v___x_138_; lean_object* v___x_140_; 
v___x_138_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_137_ == 0)
{
lean_ctor_set(v___x_136_, 0, v___x_138_);
v___x_140_ = v___x_136_;
goto v_reusejp_139_;
}
else
{
lean_object* v_reuseFailAlloc_141_; 
v_reuseFailAlloc_141_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_141_, 0, v___x_138_);
v___x_140_ = v_reuseFailAlloc_141_;
goto v_reusejp_139_;
}
v_reusejp_139_:
{
return v___x_140_;
}
}
}
else
{
lean_object* v_a_144_; lean_object* v___x_146_; uint8_t v_isShared_147_; uint8_t v_isSharedCheck_151_; 
v_a_144_ = lean_ctor_get(v___x_134_, 0);
v_isSharedCheck_151_ = !lean_is_exclusive(v___x_134_);
if (v_isSharedCheck_151_ == 0)
{
v___x_146_ = v___x_134_;
v_isShared_147_ = v_isSharedCheck_151_;
goto v_resetjp_145_;
}
else
{
lean_inc(v_a_144_);
lean_dec(v___x_134_);
v___x_146_ = lean_box(0);
v_isShared_147_ = v_isSharedCheck_151_;
goto v_resetjp_145_;
}
v_resetjp_145_:
{
lean_object* v___x_149_; 
if (v_isShared_147_ == 0)
{
v___x_149_ = v___x_146_;
goto v_reusejp_148_;
}
else
{
lean_object* v_reuseFailAlloc_150_; 
v_reuseFailAlloc_150_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_150_, 0, v_a_144_);
v___x_149_ = v_reuseFailAlloc_150_;
goto v_reusejp_148_;
}
v_reusejp_148_:
{
return v___x_149_;
}
}
}
}
else
{
lean_object* v_val_152_; lean_object* v___x_153_; 
v_val_152_ = lean_ctor_get(v___x_132_, 0);
lean_inc(v_val_152_);
lean_dec_ref_known(v___x_132_, 1);
v___x_153_ = lp_loam_Loam_Core_Event_ofEffects_x3f(v_eventToken_129_, v_val_152_);
if (lean_obj_tag(v___x_153_) == 0)
{
lean_object* v___x_154_; lean_object* v___x_155_; 
v___x_154_ = ((lean_object*)(lp_loam_Loam_Cli_createEvent___closed__1));
v___x_155_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_154_);
if (lean_obj_tag(v___x_155_) == 0)
{
lean_object* v___x_157_; uint8_t v_isShared_158_; uint8_t v_isSharedCheck_163_; 
v_isSharedCheck_163_ = !lean_is_exclusive(v___x_155_);
if (v_isSharedCheck_163_ == 0)
{
lean_object* v_unused_164_; 
v_unused_164_ = lean_ctor_get(v___x_155_, 0);
lean_dec(v_unused_164_);
v___x_157_ = v___x_155_;
v_isShared_158_ = v_isSharedCheck_163_;
goto v_resetjp_156_;
}
else
{
lean_dec(v___x_155_);
v___x_157_ = lean_box(0);
v_isShared_158_ = v_isSharedCheck_163_;
goto v_resetjp_156_;
}
v_resetjp_156_:
{
lean_object* v___x_159_; lean_object* v___x_161_; 
v___x_159_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_158_ == 0)
{
lean_ctor_set(v___x_157_, 0, v___x_159_);
v___x_161_ = v___x_157_;
goto v_reusejp_160_;
}
else
{
lean_object* v_reuseFailAlloc_162_; 
v_reuseFailAlloc_162_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_162_, 0, v___x_159_);
v___x_161_ = v_reuseFailAlloc_162_;
goto v_reusejp_160_;
}
v_reusejp_160_:
{
return v___x_161_;
}
}
}
else
{
lean_object* v_a_165_; lean_object* v___x_167_; uint8_t v_isShared_168_; uint8_t v_isSharedCheck_172_; 
v_a_165_ = lean_ctor_get(v___x_155_, 0);
v_isSharedCheck_172_ = !lean_is_exclusive(v___x_155_);
if (v_isSharedCheck_172_ == 0)
{
v___x_167_ = v___x_155_;
v_isShared_168_ = v_isSharedCheck_172_;
goto v_resetjp_166_;
}
else
{
lean_inc(v_a_165_);
lean_dec(v___x_155_);
v___x_167_ = lean_box(0);
v_isShared_168_ = v_isSharedCheck_172_;
goto v_resetjp_166_;
}
v_resetjp_166_:
{
lean_object* v___x_170_; 
if (v_isShared_168_ == 0)
{
v___x_170_ = v___x_167_;
goto v_reusejp_169_;
}
else
{
lean_object* v_reuseFailAlloc_171_; 
v_reuseFailAlloc_171_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_171_, 0, v_a_165_);
v___x_170_ = v_reuseFailAlloc_171_;
goto v_reusejp_169_;
}
v_reusejp_169_:
{
return v___x_170_;
}
}
}
}
else
{
lean_object* v_val_173_; uint8_t v___x_174_; 
v_val_173_ = lean_ctor_get(v___x_153_, 0);
lean_inc(v_val_173_);
lean_dec_ref_known(v___x_153_, 1);
v___x_174_ = l_System_FilePath_pathExists(v_path_128_);
if (v___x_174_ == 0)
{
lean_object* v___x_175_; 
v___x_175_ = lp_loam_Loam_Persistence_saveEvent_x3f(v_path_128_, v_val_173_);
if (lean_obj_tag(v___x_175_) == 0)
{
lean_object* v_a_176_; lean_object* v___x_178_; uint8_t v_isShared_179_; uint8_t v_isSharedCheck_204_; 
v_a_176_ = lean_ctor_get(v___x_175_, 0);
v_isSharedCheck_204_ = !lean_is_exclusive(v___x_175_);
if (v_isSharedCheck_204_ == 0)
{
v___x_178_ = v___x_175_;
v_isShared_179_ = v_isSharedCheck_204_;
goto v_resetjp_177_;
}
else
{
lean_inc(v_a_176_);
lean_dec(v___x_175_);
v___x_178_ = lean_box(0);
v_isShared_179_ = v_isSharedCheck_204_;
goto v_resetjp_177_;
}
v_resetjp_177_:
{
uint8_t v___x_180_; 
v___x_180_ = lean_unbox(v_a_176_);
lean_dec(v_a_176_);
if (v___x_180_ == 0)
{
lean_object* v___x_181_; lean_object* v___x_182_; 
lean_del_object(v___x_178_);
v___x_181_ = ((lean_object*)(lp_loam_Loam_Cli_createEvent___closed__2));
v___x_182_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_181_);
if (lean_obj_tag(v___x_182_) == 0)
{
lean_object* v___x_184_; uint8_t v_isShared_185_; uint8_t v_isSharedCheck_190_; 
v_isSharedCheck_190_ = !lean_is_exclusive(v___x_182_);
if (v_isSharedCheck_190_ == 0)
{
lean_object* v_unused_191_; 
v_unused_191_ = lean_ctor_get(v___x_182_, 0);
lean_dec(v_unused_191_);
v___x_184_ = v___x_182_;
v_isShared_185_ = v_isSharedCheck_190_;
goto v_resetjp_183_;
}
else
{
lean_dec(v___x_182_);
v___x_184_ = lean_box(0);
v_isShared_185_ = v_isSharedCheck_190_;
goto v_resetjp_183_;
}
v_resetjp_183_:
{
lean_object* v___x_186_; lean_object* v___x_188_; 
v___x_186_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_185_ == 0)
{
lean_ctor_set(v___x_184_, 0, v___x_186_);
v___x_188_ = v___x_184_;
goto v_reusejp_187_;
}
else
{
lean_object* v_reuseFailAlloc_189_; 
v_reuseFailAlloc_189_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_189_, 0, v___x_186_);
v___x_188_ = v_reuseFailAlloc_189_;
goto v_reusejp_187_;
}
v_reusejp_187_:
{
return v___x_188_;
}
}
}
else
{
lean_object* v_a_192_; lean_object* v___x_194_; uint8_t v_isShared_195_; uint8_t v_isSharedCheck_199_; 
v_a_192_ = lean_ctor_get(v___x_182_, 0);
v_isSharedCheck_199_ = !lean_is_exclusive(v___x_182_);
if (v_isSharedCheck_199_ == 0)
{
v___x_194_ = v___x_182_;
v_isShared_195_ = v_isSharedCheck_199_;
goto v_resetjp_193_;
}
else
{
lean_inc(v_a_192_);
lean_dec(v___x_182_);
v___x_194_ = lean_box(0);
v_isShared_195_ = v_isSharedCheck_199_;
goto v_resetjp_193_;
}
v_resetjp_193_:
{
lean_object* v___x_197_; 
if (v_isShared_195_ == 0)
{
v___x_197_ = v___x_194_;
goto v_reusejp_196_;
}
else
{
lean_object* v_reuseFailAlloc_198_; 
v_reuseFailAlloc_198_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_198_, 0, v_a_192_);
v___x_197_ = v_reuseFailAlloc_198_;
goto v_reusejp_196_;
}
v_reusejp_196_:
{
return v___x_197_;
}
}
}
}
else
{
lean_object* v___x_200_; lean_object* v___x_202_; 
v___x_200_ = lp_loam_Loam_Cli_showAmount___boxed__const__2;
if (v_isShared_179_ == 0)
{
lean_ctor_set(v___x_178_, 0, v___x_200_);
v___x_202_ = v___x_178_;
goto v_reusejp_201_;
}
else
{
lean_object* v_reuseFailAlloc_203_; 
v_reuseFailAlloc_203_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_203_, 0, v___x_200_);
v___x_202_ = v_reuseFailAlloc_203_;
goto v_reusejp_201_;
}
v_reusejp_201_:
{
return v___x_202_;
}
}
}
}
else
{
lean_object* v_a_205_; lean_object* v___x_207_; uint8_t v_isShared_208_; uint8_t v_isSharedCheck_212_; 
v_a_205_ = lean_ctor_get(v___x_175_, 0);
v_isSharedCheck_212_ = !lean_is_exclusive(v___x_175_);
if (v_isSharedCheck_212_ == 0)
{
v___x_207_ = v___x_175_;
v_isShared_208_ = v_isSharedCheck_212_;
goto v_resetjp_206_;
}
else
{
lean_inc(v_a_205_);
lean_dec(v___x_175_);
v___x_207_ = lean_box(0);
v_isShared_208_ = v_isSharedCheck_212_;
goto v_resetjp_206_;
}
v_resetjp_206_:
{
lean_object* v___x_210_; 
if (v_isShared_208_ == 0)
{
v___x_210_ = v___x_207_;
goto v_reusejp_209_;
}
else
{
lean_object* v_reuseFailAlloc_211_; 
v_reuseFailAlloc_211_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_211_, 0, v_a_205_);
v___x_210_ = v_reuseFailAlloc_211_;
goto v_reusejp_209_;
}
v_reusejp_209_:
{
return v___x_210_;
}
}
}
}
else
{
lean_object* v___x_213_; lean_object* v___x_214_; 
lean_dec(v_val_173_);
v___x_213_ = ((lean_object*)(lp_loam_Loam_Cli_createEvent___closed__3));
v___x_214_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_213_);
if (lean_obj_tag(v___x_214_) == 0)
{
lean_object* v___x_216_; uint8_t v_isShared_217_; uint8_t v_isSharedCheck_222_; 
v_isSharedCheck_222_ = !lean_is_exclusive(v___x_214_);
if (v_isSharedCheck_222_ == 0)
{
lean_object* v_unused_223_; 
v_unused_223_ = lean_ctor_get(v___x_214_, 0);
lean_dec(v_unused_223_);
v___x_216_ = v___x_214_;
v_isShared_217_ = v_isSharedCheck_222_;
goto v_resetjp_215_;
}
else
{
lean_dec(v___x_214_);
v___x_216_ = lean_box(0);
v_isShared_217_ = v_isSharedCheck_222_;
goto v_resetjp_215_;
}
v_resetjp_215_:
{
lean_object* v___x_218_; lean_object* v___x_220_; 
v___x_218_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_217_ == 0)
{
lean_ctor_set(v___x_216_, 0, v___x_218_);
v___x_220_ = v___x_216_;
goto v_reusejp_219_;
}
else
{
lean_object* v_reuseFailAlloc_221_; 
v_reuseFailAlloc_221_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_221_, 0, v___x_218_);
v___x_220_ = v_reuseFailAlloc_221_;
goto v_reusejp_219_;
}
v_reusejp_219_:
{
return v___x_220_;
}
}
}
else
{
lean_object* v_a_224_; lean_object* v___x_226_; uint8_t v_isShared_227_; uint8_t v_isSharedCheck_231_; 
v_a_224_ = lean_ctor_get(v___x_214_, 0);
v_isSharedCheck_231_ = !lean_is_exclusive(v___x_214_);
if (v_isSharedCheck_231_ == 0)
{
v___x_226_ = v___x_214_;
v_isShared_227_ = v_isSharedCheck_231_;
goto v_resetjp_225_;
}
else
{
lean_inc(v_a_224_);
lean_dec(v___x_214_);
v___x_226_ = lean_box(0);
v_isShared_227_ = v_isSharedCheck_231_;
goto v_resetjp_225_;
}
v_resetjp_225_:
{
lean_object* v___x_229_; 
if (v_isShared_227_ == 0)
{
v___x_229_ = v___x_226_;
goto v_reusejp_228_;
}
else
{
lean_object* v_reuseFailAlloc_230_; 
v_reuseFailAlloc_230_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_230_, 0, v_a_224_);
v___x_229_ = v_reuseFailAlloc_230_;
goto v_reusejp_228_;
}
v_reusejp_228_:
{
return v___x_229_;
}
}
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_createEvent___boxed(lean_object* v_path_232_, lean_object* v_eventToken_233_, lean_object* v_effectArgs_234_, lean_object* v_a_235_){
_start:
{
lean_object* v_res_236_; 
v_res_236_ = lp_loam_Loam_Cli_createEvent(v_path_232_, v_eventToken_233_, v_effectArgs_234_);
lean_dec_ref(v_path_232_);
return v_res_236_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showEventQuantity(lean_object* v_path_238_, lean_object* v_locusToken_239_, lean_object* v_measureToken_240_){
_start:
{
lean_object* v___x_242_; 
v___x_242_ = lp_loam_Loam_Persistence_loadEvent_x3f(v_path_238_);
if (lean_obj_tag(v___x_242_) == 0)
{
lean_object* v_a_243_; 
v_a_243_ = lean_ctor_get(v___x_242_, 0);
lean_inc(v_a_243_);
lean_dec_ref_known(v___x_242_, 1);
if (lean_obj_tag(v_a_243_) == 0)
{
lean_object* v___x_244_; lean_object* v___x_245_; 
lean_dec_ref(v_measureToken_240_);
lean_dec_ref(v_locusToken_239_);
v___x_244_ = ((lean_object*)(lp_loam_Loam_Cli_showEventQuantity___closed__0));
v___x_245_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_244_);
if (lean_obj_tag(v___x_245_) == 0)
{
lean_object* v___x_247_; uint8_t v_isShared_248_; uint8_t v_isSharedCheck_253_; 
v_isSharedCheck_253_ = !lean_is_exclusive(v___x_245_);
if (v_isSharedCheck_253_ == 0)
{
lean_object* v_unused_254_; 
v_unused_254_ = lean_ctor_get(v___x_245_, 0);
lean_dec(v_unused_254_);
v___x_247_ = v___x_245_;
v_isShared_248_ = v_isSharedCheck_253_;
goto v_resetjp_246_;
}
else
{
lean_dec(v___x_245_);
v___x_247_ = lean_box(0);
v_isShared_248_ = v_isSharedCheck_253_;
goto v_resetjp_246_;
}
v_resetjp_246_:
{
lean_object* v___x_249_; lean_object* v___x_251_; 
v___x_249_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_248_ == 0)
{
lean_ctor_set(v___x_247_, 0, v___x_249_);
v___x_251_ = v___x_247_;
goto v_reusejp_250_;
}
else
{
lean_object* v_reuseFailAlloc_252_; 
v_reuseFailAlloc_252_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_252_, 0, v___x_249_);
v___x_251_ = v_reuseFailAlloc_252_;
goto v_reusejp_250_;
}
v_reusejp_250_:
{
return v___x_251_;
}
}
}
else
{
lean_object* v_a_255_; lean_object* v___x_257_; uint8_t v_isShared_258_; uint8_t v_isSharedCheck_262_; 
v_a_255_ = lean_ctor_get(v___x_245_, 0);
v_isSharedCheck_262_ = !lean_is_exclusive(v___x_245_);
if (v_isSharedCheck_262_ == 0)
{
v___x_257_ = v___x_245_;
v_isShared_258_ = v_isSharedCheck_262_;
goto v_resetjp_256_;
}
else
{
lean_inc(v_a_255_);
lean_dec(v___x_245_);
v___x_257_ = lean_box(0);
v_isShared_258_ = v_isSharedCheck_262_;
goto v_resetjp_256_;
}
v_resetjp_256_:
{
lean_object* v___x_260_; 
if (v_isShared_258_ == 0)
{
v___x_260_ = v___x_257_;
goto v_reusejp_259_;
}
else
{
lean_object* v_reuseFailAlloc_261_; 
v_reuseFailAlloc_261_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_261_, 0, v_a_255_);
v___x_260_ = v_reuseFailAlloc_261_;
goto v_reusejp_259_;
}
v_reusejp_259_:
{
return v___x_260_;
}
}
}
}
else
{
lean_object* v_val_263_; lean_object* v___x_264_; lean_object* v___x_265_; lean_object* v___x_266_; 
v_val_263_ = lean_ctor_get(v_a_243_, 0);
lean_inc(v_val_263_);
lean_dec_ref_known(v_a_243_, 1);
v___x_264_ = lp_loam_Loam_Core_Event_quantityAt(v_val_263_, v_locusToken_239_, v_measureToken_240_);
v___x_265_ = l_Int_repr(v___x_264_);
lean_dec(v___x_264_);
v___x_266_ = lp_loam_IO_println___at___00Loam_Cli_showAmount_spec__0(v___x_265_);
if (lean_obj_tag(v___x_266_) == 0)
{
lean_object* v___x_268_; uint8_t v_isShared_269_; uint8_t v_isSharedCheck_274_; 
v_isSharedCheck_274_ = !lean_is_exclusive(v___x_266_);
if (v_isSharedCheck_274_ == 0)
{
lean_object* v_unused_275_; 
v_unused_275_ = lean_ctor_get(v___x_266_, 0);
lean_dec(v_unused_275_);
v___x_268_ = v___x_266_;
v_isShared_269_ = v_isSharedCheck_274_;
goto v_resetjp_267_;
}
else
{
lean_dec(v___x_266_);
v___x_268_ = lean_box(0);
v_isShared_269_ = v_isSharedCheck_274_;
goto v_resetjp_267_;
}
v_resetjp_267_:
{
lean_object* v___x_270_; lean_object* v___x_272_; 
v___x_270_ = lp_loam_Loam_Cli_showAmount___boxed__const__2;
if (v_isShared_269_ == 0)
{
lean_ctor_set(v___x_268_, 0, v___x_270_);
v___x_272_ = v___x_268_;
goto v_reusejp_271_;
}
else
{
lean_object* v_reuseFailAlloc_273_; 
v_reuseFailAlloc_273_ = lean_alloc_ctor(0, 1, 0);
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
else
{
lean_object* v_a_276_; lean_object* v___x_278_; uint8_t v_isShared_279_; uint8_t v_isSharedCheck_283_; 
v_a_276_ = lean_ctor_get(v___x_266_, 0);
v_isSharedCheck_283_ = !lean_is_exclusive(v___x_266_);
if (v_isSharedCheck_283_ == 0)
{
v___x_278_ = v___x_266_;
v_isShared_279_ = v_isSharedCheck_283_;
goto v_resetjp_277_;
}
else
{
lean_inc(v_a_276_);
lean_dec(v___x_266_);
v___x_278_ = lean_box(0);
v_isShared_279_ = v_isSharedCheck_283_;
goto v_resetjp_277_;
}
v_resetjp_277_:
{
lean_object* v___x_281_; 
if (v_isShared_279_ == 0)
{
v___x_281_ = v___x_278_;
goto v_reusejp_280_;
}
else
{
lean_object* v_reuseFailAlloc_282_; 
v_reuseFailAlloc_282_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_282_, 0, v_a_276_);
v___x_281_ = v_reuseFailAlloc_282_;
goto v_reusejp_280_;
}
v_reusejp_280_:
{
return v___x_281_;
}
}
}
}
}
else
{
lean_object* v_a_284_; lean_object* v___x_286_; uint8_t v_isShared_287_; uint8_t v_isSharedCheck_291_; 
lean_dec_ref(v_measureToken_240_);
lean_dec_ref(v_locusToken_239_);
v_a_284_ = lean_ctor_get(v___x_242_, 0);
v_isSharedCheck_291_ = !lean_is_exclusive(v___x_242_);
if (v_isSharedCheck_291_ == 0)
{
v___x_286_ = v___x_242_;
v_isShared_287_ = v_isSharedCheck_291_;
goto v_resetjp_285_;
}
else
{
lean_inc(v_a_284_);
lean_dec(v___x_242_);
v___x_286_ = lean_box(0);
v_isShared_287_ = v_isSharedCheck_291_;
goto v_resetjp_285_;
}
v_resetjp_285_:
{
lean_object* v___x_289_; 
if (v_isShared_287_ == 0)
{
v___x_289_ = v___x_286_;
goto v_reusejp_288_;
}
else
{
lean_object* v_reuseFailAlloc_290_; 
v_reuseFailAlloc_290_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_290_, 0, v_a_284_);
v___x_289_ = v_reuseFailAlloc_290_;
goto v_reusejp_288_;
}
v_reusejp_288_:
{
return v___x_289_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showEventQuantity___boxed(lean_object* v_path_292_, lean_object* v_locusToken_293_, lean_object* v_measureToken_294_, lean_object* v_a_295_){
_start:
{
lean_object* v_res_296_; 
v_res_296_ = lp_loam_Loam_Cli_showEventQuantity(v_path_292_, v_locusToken_293_, v_measureToken_294_);
lean_dec_ref(v_path_292_);
return v_res_296_;
}
}
static lean_object* _init_lp_loam_Loam_Cli_showRememberedEvent___boxed__const__1(void){
_start:
{
uint32_t v___x_300_; lean_object* v___x_301_; 
v___x_300_ = 1;
v___x_301_ = lean_box_uint32(v___x_300_);
return v___x_301_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showRememberedEvent(lean_object* v_path_302_, lean_object* v_eventToken_303_){
_start:
{
lean_object* v___x_305_; 
v___x_305_ = lp_loam_Loam_Persistence_loadEventMemory_x3f(v_path_302_);
if (lean_obj_tag(v___x_305_) == 0)
{
lean_object* v_a_306_; 
v_a_306_ = lean_ctor_get(v___x_305_, 0);
lean_inc(v_a_306_);
lean_dec_ref_known(v___x_305_, 1);
if (lean_obj_tag(v_a_306_) == 0)
{
lean_object* v___x_307_; lean_object* v___x_308_; 
v___x_307_ = ((lean_object*)(lp_loam_Loam_Cli_showRememberedEvent___closed__0));
v___x_308_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_307_);
if (lean_obj_tag(v___x_308_) == 0)
{
lean_object* v___x_310_; uint8_t v_isShared_311_; uint8_t v_isSharedCheck_316_; 
v_isSharedCheck_316_ = !lean_is_exclusive(v___x_308_);
if (v_isSharedCheck_316_ == 0)
{
lean_object* v_unused_317_; 
v_unused_317_ = lean_ctor_get(v___x_308_, 0);
lean_dec(v_unused_317_);
v___x_310_ = v___x_308_;
v_isShared_311_ = v_isSharedCheck_316_;
goto v_resetjp_309_;
}
else
{
lean_dec(v___x_308_);
v___x_310_ = lean_box(0);
v_isShared_311_ = v_isSharedCheck_316_;
goto v_resetjp_309_;
}
v_resetjp_309_:
{
lean_object* v___x_312_; lean_object* v___x_314_; 
v___x_312_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_311_ == 0)
{
lean_ctor_set(v___x_310_, 0, v___x_312_);
v___x_314_ = v___x_310_;
goto v_reusejp_313_;
}
else
{
lean_object* v_reuseFailAlloc_315_; 
v_reuseFailAlloc_315_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_315_, 0, v___x_312_);
v___x_314_ = v_reuseFailAlloc_315_;
goto v_reusejp_313_;
}
v_reusejp_313_:
{
return v___x_314_;
}
}
}
else
{
lean_object* v_a_318_; lean_object* v___x_320_; uint8_t v_isShared_321_; uint8_t v_isSharedCheck_325_; 
v_a_318_ = lean_ctor_get(v___x_308_, 0);
v_isSharedCheck_325_ = !lean_is_exclusive(v___x_308_);
if (v_isSharedCheck_325_ == 0)
{
v___x_320_ = v___x_308_;
v_isShared_321_ = v_isSharedCheck_325_;
goto v_resetjp_319_;
}
else
{
lean_inc(v_a_318_);
lean_dec(v___x_308_);
v___x_320_ = lean_box(0);
v_isShared_321_ = v_isSharedCheck_325_;
goto v_resetjp_319_;
}
v_resetjp_319_:
{
lean_object* v___x_323_; 
if (v_isShared_321_ == 0)
{
v___x_323_ = v___x_320_;
goto v_reusejp_322_;
}
else
{
lean_object* v_reuseFailAlloc_324_; 
v_reuseFailAlloc_324_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_324_, 0, v_a_318_);
v___x_323_ = v_reuseFailAlloc_324_;
goto v_reusejp_322_;
}
v_reusejp_322_:
{
return v___x_323_;
}
}
}
}
else
{
lean_object* v_val_326_; lean_object* v___x_327_; 
v_val_326_ = lean_ctor_get(v_a_306_, 0);
lean_inc(v_val_326_);
lean_dec_ref_known(v_a_306_, 1);
v___x_327_ = lp_loam___private_Loam_Core_EventMemory_0__Loam_Core_EventMemory_findEventById_x3f(v_val_326_, v_eventToken_303_);
lean_dec(v_val_326_);
if (lean_obj_tag(v___x_327_) == 0)
{
lean_object* v___x_328_; lean_object* v___x_329_; 
v___x_328_ = ((lean_object*)(lp_loam_Loam_Cli_showRememberedEvent___closed__1));
v___x_329_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_328_);
if (lean_obj_tag(v___x_329_) == 0)
{
lean_object* v___x_331_; uint8_t v_isShared_332_; uint8_t v_isSharedCheck_337_; 
v_isSharedCheck_337_ = !lean_is_exclusive(v___x_329_);
if (v_isSharedCheck_337_ == 0)
{
lean_object* v_unused_338_; 
v_unused_338_ = lean_ctor_get(v___x_329_, 0);
lean_dec(v_unused_338_);
v___x_331_ = v___x_329_;
v_isShared_332_ = v_isSharedCheck_337_;
goto v_resetjp_330_;
}
else
{
lean_dec(v___x_329_);
v___x_331_ = lean_box(0);
v_isShared_332_ = v_isSharedCheck_337_;
goto v_resetjp_330_;
}
v_resetjp_330_:
{
lean_object* v___x_333_; lean_object* v___x_335_; 
v___x_333_ = lp_loam_Loam_Cli_showRememberedEvent___boxed__const__1;
if (v_isShared_332_ == 0)
{
lean_ctor_set(v___x_331_, 0, v___x_333_);
v___x_335_ = v___x_331_;
goto v_reusejp_334_;
}
else
{
lean_object* v_reuseFailAlloc_336_; 
v_reuseFailAlloc_336_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_336_, 0, v___x_333_);
v___x_335_ = v_reuseFailAlloc_336_;
goto v_reusejp_334_;
}
v_reusejp_334_:
{
return v___x_335_;
}
}
}
else
{
lean_object* v_a_339_; lean_object* v___x_341_; uint8_t v_isShared_342_; uint8_t v_isSharedCheck_346_; 
v_a_339_ = lean_ctor_get(v___x_329_, 0);
v_isSharedCheck_346_ = !lean_is_exclusive(v___x_329_);
if (v_isSharedCheck_346_ == 0)
{
v___x_341_ = v___x_329_;
v_isShared_342_ = v_isSharedCheck_346_;
goto v_resetjp_340_;
}
else
{
lean_inc(v_a_339_);
lean_dec(v___x_329_);
v___x_341_ = lean_box(0);
v_isShared_342_ = v_isSharedCheck_346_;
goto v_resetjp_340_;
}
v_resetjp_340_:
{
lean_object* v___x_344_; 
if (v_isShared_342_ == 0)
{
v___x_344_ = v___x_341_;
goto v_reusejp_343_;
}
else
{
lean_object* v_reuseFailAlloc_345_; 
v_reuseFailAlloc_345_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_345_, 0, v_a_339_);
v___x_344_ = v_reuseFailAlloc_345_;
goto v_reusejp_343_;
}
v_reusejp_343_:
{
return v___x_344_;
}
}
}
}
else
{
lean_object* v_val_347_; lean_object* v___x_348_; 
v_val_347_ = lean_ctor_get(v___x_327_, 0);
lean_inc(v_val_347_);
lean_dec_ref_known(v___x_327_, 1);
v___x_348_ = lp_loam_Loam_Persistence_encodeEvent_x3f(v_val_347_);
if (lean_obj_tag(v___x_348_) == 0)
{
lean_object* v___x_349_; lean_object* v___x_350_; 
v___x_349_ = ((lean_object*)(lp_loam_Loam_Cli_showRememberedEvent___closed__2));
v___x_350_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_349_);
if (lean_obj_tag(v___x_350_) == 0)
{
lean_object* v___x_352_; uint8_t v_isShared_353_; uint8_t v_isSharedCheck_358_; 
v_isSharedCheck_358_ = !lean_is_exclusive(v___x_350_);
if (v_isSharedCheck_358_ == 0)
{
lean_object* v_unused_359_; 
v_unused_359_ = lean_ctor_get(v___x_350_, 0);
lean_dec(v_unused_359_);
v___x_352_ = v___x_350_;
v_isShared_353_ = v_isSharedCheck_358_;
goto v_resetjp_351_;
}
else
{
lean_dec(v___x_350_);
v___x_352_ = lean_box(0);
v_isShared_353_ = v_isSharedCheck_358_;
goto v_resetjp_351_;
}
v_resetjp_351_:
{
lean_object* v___x_354_; lean_object* v___x_356_; 
v___x_354_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_353_ == 0)
{
lean_ctor_set(v___x_352_, 0, v___x_354_);
v___x_356_ = v___x_352_;
goto v_reusejp_355_;
}
else
{
lean_object* v_reuseFailAlloc_357_; 
v_reuseFailAlloc_357_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_357_, 0, v___x_354_);
v___x_356_ = v_reuseFailAlloc_357_;
goto v_reusejp_355_;
}
v_reusejp_355_:
{
return v___x_356_;
}
}
}
else
{
lean_object* v_a_360_; lean_object* v___x_362_; uint8_t v_isShared_363_; uint8_t v_isSharedCheck_367_; 
v_a_360_ = lean_ctor_get(v___x_350_, 0);
v_isSharedCheck_367_ = !lean_is_exclusive(v___x_350_);
if (v_isSharedCheck_367_ == 0)
{
v___x_362_ = v___x_350_;
v_isShared_363_ = v_isSharedCheck_367_;
goto v_resetjp_361_;
}
else
{
lean_inc(v_a_360_);
lean_dec(v___x_350_);
v___x_362_ = lean_box(0);
v_isShared_363_ = v_isSharedCheck_367_;
goto v_resetjp_361_;
}
v_resetjp_361_:
{
lean_object* v___x_365_; 
if (v_isShared_363_ == 0)
{
v___x_365_ = v___x_362_;
goto v_reusejp_364_;
}
else
{
lean_object* v_reuseFailAlloc_366_; 
v_reuseFailAlloc_366_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_366_, 0, v_a_360_);
v___x_365_ = v_reuseFailAlloc_366_;
goto v_reusejp_364_;
}
v_reusejp_364_:
{
return v___x_365_;
}
}
}
}
else
{
lean_object* v_val_368_; lean_object* v___x_369_; 
v_val_368_ = lean_ctor_get(v___x_348_, 0);
lean_inc(v_val_368_);
lean_dec_ref_known(v___x_348_, 1);
v___x_369_ = lp_loam_IO_print___at___00IO_println___at___00Loam_Cli_showAmount_spec__0_spec__0(v_val_368_);
if (lean_obj_tag(v___x_369_) == 0)
{
lean_object* v___x_371_; uint8_t v_isShared_372_; uint8_t v_isSharedCheck_377_; 
v_isSharedCheck_377_ = !lean_is_exclusive(v___x_369_);
if (v_isSharedCheck_377_ == 0)
{
lean_object* v_unused_378_; 
v_unused_378_ = lean_ctor_get(v___x_369_, 0);
lean_dec(v_unused_378_);
v___x_371_ = v___x_369_;
v_isShared_372_ = v_isSharedCheck_377_;
goto v_resetjp_370_;
}
else
{
lean_dec(v___x_369_);
v___x_371_ = lean_box(0);
v_isShared_372_ = v_isSharedCheck_377_;
goto v_resetjp_370_;
}
v_resetjp_370_:
{
lean_object* v___x_373_; lean_object* v___x_375_; 
v___x_373_ = lp_loam_Loam_Cli_showAmount___boxed__const__2;
if (v_isShared_372_ == 0)
{
lean_ctor_set(v___x_371_, 0, v___x_373_);
v___x_375_ = v___x_371_;
goto v_reusejp_374_;
}
else
{
lean_object* v_reuseFailAlloc_376_; 
v_reuseFailAlloc_376_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_376_, 0, v___x_373_);
v___x_375_ = v_reuseFailAlloc_376_;
goto v_reusejp_374_;
}
v_reusejp_374_:
{
return v___x_375_;
}
}
}
else
{
lean_object* v_a_379_; lean_object* v___x_381_; uint8_t v_isShared_382_; uint8_t v_isSharedCheck_386_; 
v_a_379_ = lean_ctor_get(v___x_369_, 0);
v_isSharedCheck_386_ = !lean_is_exclusive(v___x_369_);
if (v_isSharedCheck_386_ == 0)
{
v___x_381_ = v___x_369_;
v_isShared_382_ = v_isSharedCheck_386_;
goto v_resetjp_380_;
}
else
{
lean_inc(v_a_379_);
lean_dec(v___x_369_);
v___x_381_ = lean_box(0);
v_isShared_382_ = v_isSharedCheck_386_;
goto v_resetjp_380_;
}
v_resetjp_380_:
{
lean_object* v___x_384_; 
if (v_isShared_382_ == 0)
{
v___x_384_ = v___x_381_;
goto v_reusejp_383_;
}
else
{
lean_object* v_reuseFailAlloc_385_; 
v_reuseFailAlloc_385_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_385_, 0, v_a_379_);
v___x_384_ = v_reuseFailAlloc_385_;
goto v_reusejp_383_;
}
v_reusejp_383_:
{
return v___x_384_;
}
}
}
}
}
}
}
else
{
lean_object* v_a_387_; lean_object* v___x_389_; uint8_t v_isShared_390_; uint8_t v_isSharedCheck_394_; 
v_a_387_ = lean_ctor_get(v___x_305_, 0);
v_isSharedCheck_394_ = !lean_is_exclusive(v___x_305_);
if (v_isSharedCheck_394_ == 0)
{
v___x_389_ = v___x_305_;
v_isShared_390_ = v_isSharedCheck_394_;
goto v_resetjp_388_;
}
else
{
lean_inc(v_a_387_);
lean_dec(v___x_305_);
v___x_389_ = lean_box(0);
v_isShared_390_ = v_isSharedCheck_394_;
goto v_resetjp_388_;
}
v_resetjp_388_:
{
lean_object* v___x_392_; 
if (v_isShared_390_ == 0)
{
v___x_392_ = v___x_389_;
goto v_reusejp_391_;
}
else
{
lean_object* v_reuseFailAlloc_393_; 
v_reuseFailAlloc_393_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_393_, 0, v_a_387_);
v___x_392_ = v_reuseFailAlloc_393_;
goto v_reusejp_391_;
}
v_reusejp_391_:
{
return v___x_392_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showRememberedEvent___boxed(lean_object* v_path_395_, lean_object* v_eventToken_396_, lean_object* v_a_397_){
_start:
{
lean_object* v_res_398_; 
v_res_398_ = lp_loam_Loam_Cli_showRememberedEvent(v_path_395_, v_eventToken_396_);
lean_dec_ref(v_eventToken_396_);
lean_dec_ref(v_path_395_);
return v_res_398_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showRememberedQuantity(lean_object* v_path_399_, lean_object* v_locusToken_400_, lean_object* v_measureToken_401_){
_start:
{
lean_object* v___x_403_; 
v___x_403_ = lp_loam_Loam_Persistence_loadEventMemory_x3f(v_path_399_);
if (lean_obj_tag(v___x_403_) == 0)
{
lean_object* v_a_404_; 
v_a_404_ = lean_ctor_get(v___x_403_, 0);
lean_inc(v_a_404_);
lean_dec_ref_known(v___x_403_, 1);
if (lean_obj_tag(v_a_404_) == 0)
{
lean_object* v___x_405_; lean_object* v___x_406_; 
lean_dec_ref(v_measureToken_401_);
lean_dec_ref(v_locusToken_400_);
v___x_405_ = ((lean_object*)(lp_loam_Loam_Cli_showRememberedEvent___closed__0));
v___x_406_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_405_);
if (lean_obj_tag(v___x_406_) == 0)
{
lean_object* v___x_408_; uint8_t v_isShared_409_; uint8_t v_isSharedCheck_414_; 
v_isSharedCheck_414_ = !lean_is_exclusive(v___x_406_);
if (v_isSharedCheck_414_ == 0)
{
lean_object* v_unused_415_; 
v_unused_415_ = lean_ctor_get(v___x_406_, 0);
lean_dec(v_unused_415_);
v___x_408_ = v___x_406_;
v_isShared_409_ = v_isSharedCheck_414_;
goto v_resetjp_407_;
}
else
{
lean_dec(v___x_406_);
v___x_408_ = lean_box(0);
v_isShared_409_ = v_isSharedCheck_414_;
goto v_resetjp_407_;
}
v_resetjp_407_:
{
lean_object* v___x_410_; lean_object* v___x_412_; 
v___x_410_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_409_ == 0)
{
lean_ctor_set(v___x_408_, 0, v___x_410_);
v___x_412_ = v___x_408_;
goto v_reusejp_411_;
}
else
{
lean_object* v_reuseFailAlloc_413_; 
v_reuseFailAlloc_413_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_413_, 0, v___x_410_);
v___x_412_ = v_reuseFailAlloc_413_;
goto v_reusejp_411_;
}
v_reusejp_411_:
{
return v___x_412_;
}
}
}
else
{
lean_object* v_a_416_; lean_object* v___x_418_; uint8_t v_isShared_419_; uint8_t v_isSharedCheck_423_; 
v_a_416_ = lean_ctor_get(v___x_406_, 0);
v_isSharedCheck_423_ = !lean_is_exclusive(v___x_406_);
if (v_isSharedCheck_423_ == 0)
{
v___x_418_ = v___x_406_;
v_isShared_419_ = v_isSharedCheck_423_;
goto v_resetjp_417_;
}
else
{
lean_inc(v_a_416_);
lean_dec(v___x_406_);
v___x_418_ = lean_box(0);
v_isShared_419_ = v_isSharedCheck_423_;
goto v_resetjp_417_;
}
v_resetjp_417_:
{
lean_object* v___x_421_; 
if (v_isShared_419_ == 0)
{
v___x_421_ = v___x_418_;
goto v_reusejp_420_;
}
else
{
lean_object* v_reuseFailAlloc_422_; 
v_reuseFailAlloc_422_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_422_, 0, v_a_416_);
v___x_421_ = v_reuseFailAlloc_422_;
goto v_reusejp_420_;
}
v_reusejp_420_:
{
return v___x_421_;
}
}
}
}
else
{
lean_object* v_val_424_; lean_object* v___x_425_; lean_object* v___x_426_; lean_object* v___x_427_; 
v_val_424_ = lean_ctor_get(v_a_404_, 0);
lean_inc(v_val_424_);
lean_dec_ref_known(v_a_404_, 1);
v___x_425_ = lp_loam_Loam_Core_EventMemory_quantityAtRecorded(v_val_424_, v_locusToken_400_, v_measureToken_401_);
v___x_426_ = l_Int_repr(v___x_425_);
lean_dec(v___x_425_);
v___x_427_ = lp_loam_IO_println___at___00Loam_Cli_showAmount_spec__0(v___x_426_);
if (lean_obj_tag(v___x_427_) == 0)
{
lean_object* v___x_429_; uint8_t v_isShared_430_; uint8_t v_isSharedCheck_435_; 
v_isSharedCheck_435_ = !lean_is_exclusive(v___x_427_);
if (v_isSharedCheck_435_ == 0)
{
lean_object* v_unused_436_; 
v_unused_436_ = lean_ctor_get(v___x_427_, 0);
lean_dec(v_unused_436_);
v___x_429_ = v___x_427_;
v_isShared_430_ = v_isSharedCheck_435_;
goto v_resetjp_428_;
}
else
{
lean_dec(v___x_427_);
v___x_429_ = lean_box(0);
v_isShared_430_ = v_isSharedCheck_435_;
goto v_resetjp_428_;
}
v_resetjp_428_:
{
lean_object* v___x_431_; lean_object* v___x_433_; 
v___x_431_ = lp_loam_Loam_Cli_showAmount___boxed__const__2;
if (v_isShared_430_ == 0)
{
lean_ctor_set(v___x_429_, 0, v___x_431_);
v___x_433_ = v___x_429_;
goto v_reusejp_432_;
}
else
{
lean_object* v_reuseFailAlloc_434_; 
v_reuseFailAlloc_434_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_434_, 0, v___x_431_);
v___x_433_ = v_reuseFailAlloc_434_;
goto v_reusejp_432_;
}
v_reusejp_432_:
{
return v___x_433_;
}
}
}
else
{
lean_object* v_a_437_; lean_object* v___x_439_; uint8_t v_isShared_440_; uint8_t v_isSharedCheck_444_; 
v_a_437_ = lean_ctor_get(v___x_427_, 0);
v_isSharedCheck_444_ = !lean_is_exclusive(v___x_427_);
if (v_isSharedCheck_444_ == 0)
{
v___x_439_ = v___x_427_;
v_isShared_440_ = v_isSharedCheck_444_;
goto v_resetjp_438_;
}
else
{
lean_inc(v_a_437_);
lean_dec(v___x_427_);
v___x_439_ = lean_box(0);
v_isShared_440_ = v_isSharedCheck_444_;
goto v_resetjp_438_;
}
v_resetjp_438_:
{
lean_object* v___x_442_; 
if (v_isShared_440_ == 0)
{
v___x_442_ = v___x_439_;
goto v_reusejp_441_;
}
else
{
lean_object* v_reuseFailAlloc_443_; 
v_reuseFailAlloc_443_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_443_, 0, v_a_437_);
v___x_442_ = v_reuseFailAlloc_443_;
goto v_reusejp_441_;
}
v_reusejp_441_:
{
return v___x_442_;
}
}
}
}
}
else
{
lean_object* v_a_445_; lean_object* v___x_447_; uint8_t v_isShared_448_; uint8_t v_isSharedCheck_452_; 
lean_dec_ref(v_measureToken_401_);
lean_dec_ref(v_locusToken_400_);
v_a_445_ = lean_ctor_get(v___x_403_, 0);
v_isSharedCheck_452_ = !lean_is_exclusive(v___x_403_);
if (v_isSharedCheck_452_ == 0)
{
v___x_447_ = v___x_403_;
v_isShared_448_ = v_isSharedCheck_452_;
goto v_resetjp_446_;
}
else
{
lean_inc(v_a_445_);
lean_dec(v___x_403_);
v___x_447_ = lean_box(0);
v_isShared_448_ = v_isSharedCheck_452_;
goto v_resetjp_446_;
}
v_resetjp_446_:
{
lean_object* v___x_450_; 
if (v_isShared_448_ == 0)
{
v___x_450_ = v___x_447_;
goto v_reusejp_449_;
}
else
{
lean_object* v_reuseFailAlloc_451_; 
v_reuseFailAlloc_451_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_451_, 0, v_a_445_);
v___x_450_ = v_reuseFailAlloc_451_;
goto v_reusejp_449_;
}
v_reusejp_449_:
{
return v___x_450_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_showRememberedQuantity___boxed(lean_object* v_path_453_, lean_object* v_locusToken_454_, lean_object* v_measureToken_455_, lean_object* v_a_456_){
_start:
{
lean_object* v_res_457_; 
v_res_457_ = lp_loam_Loam_Cli_showRememberedQuantity(v_path_453_, v_locusToken_454_, v_measureToken_455_);
lean_dec_ref(v_path_453_);
return v_res_457_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_addRememberedEvent(lean_object* v_memoryPath_460_, lean_object* v_eventPath_461_){
_start:
{
lean_object* v___x_463_; 
v___x_463_ = lp_loam_Loam_Persistence_loadEventMemory_x3f(v_memoryPath_460_);
if (lean_obj_tag(v___x_463_) == 0)
{
lean_object* v_a_464_; 
v_a_464_ = lean_ctor_get(v___x_463_, 0);
lean_inc(v_a_464_);
lean_dec_ref_known(v___x_463_, 1);
if (lean_obj_tag(v_a_464_) == 0)
{
lean_object* v___x_465_; lean_object* v___x_466_; 
lean_dec_ref(v_memoryPath_460_);
v___x_465_ = ((lean_object*)(lp_loam_Loam_Cli_showRememberedEvent___closed__0));
v___x_466_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_465_);
if (lean_obj_tag(v___x_466_) == 0)
{
lean_object* v___x_468_; uint8_t v_isShared_469_; uint8_t v_isSharedCheck_474_; 
v_isSharedCheck_474_ = !lean_is_exclusive(v___x_466_);
if (v_isSharedCheck_474_ == 0)
{
lean_object* v_unused_475_; 
v_unused_475_ = lean_ctor_get(v___x_466_, 0);
lean_dec(v_unused_475_);
v___x_468_ = v___x_466_;
v_isShared_469_ = v_isSharedCheck_474_;
goto v_resetjp_467_;
}
else
{
lean_dec(v___x_466_);
v___x_468_ = lean_box(0);
v_isShared_469_ = v_isSharedCheck_474_;
goto v_resetjp_467_;
}
v_resetjp_467_:
{
lean_object* v___x_470_; lean_object* v___x_472_; 
v___x_470_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_469_ == 0)
{
lean_ctor_set(v___x_468_, 0, v___x_470_);
v___x_472_ = v___x_468_;
goto v_reusejp_471_;
}
else
{
lean_object* v_reuseFailAlloc_473_; 
v_reuseFailAlloc_473_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_473_, 0, v___x_470_);
v___x_472_ = v_reuseFailAlloc_473_;
goto v_reusejp_471_;
}
v_reusejp_471_:
{
return v___x_472_;
}
}
}
else
{
lean_object* v_a_476_; lean_object* v___x_478_; uint8_t v_isShared_479_; uint8_t v_isSharedCheck_483_; 
v_a_476_ = lean_ctor_get(v___x_466_, 0);
v_isSharedCheck_483_ = !lean_is_exclusive(v___x_466_);
if (v_isSharedCheck_483_ == 0)
{
v___x_478_ = v___x_466_;
v_isShared_479_ = v_isSharedCheck_483_;
goto v_resetjp_477_;
}
else
{
lean_inc(v_a_476_);
lean_dec(v___x_466_);
v___x_478_ = lean_box(0);
v_isShared_479_ = v_isSharedCheck_483_;
goto v_resetjp_477_;
}
v_resetjp_477_:
{
lean_object* v___x_481_; 
if (v_isShared_479_ == 0)
{
v___x_481_ = v___x_478_;
goto v_reusejp_480_;
}
else
{
lean_object* v_reuseFailAlloc_482_; 
v_reuseFailAlloc_482_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_482_, 0, v_a_476_);
v___x_481_ = v_reuseFailAlloc_482_;
goto v_reusejp_480_;
}
v_reusejp_480_:
{
return v___x_481_;
}
}
}
}
else
{
lean_object* v_val_484_; lean_object* v___x_485_; 
v_val_484_ = lean_ctor_get(v_a_464_, 0);
lean_inc(v_val_484_);
lean_dec_ref_known(v_a_464_, 1);
v___x_485_ = lp_loam_Loam_Persistence_loadEvent_x3f(v_eventPath_461_);
if (lean_obj_tag(v___x_485_) == 0)
{
lean_object* v_a_486_; 
v_a_486_ = lean_ctor_get(v___x_485_, 0);
lean_inc(v_a_486_);
lean_dec_ref_known(v___x_485_, 1);
if (lean_obj_tag(v_a_486_) == 0)
{
lean_object* v___x_487_; lean_object* v___x_488_; 
lean_dec(v_val_484_);
lean_dec_ref(v_memoryPath_460_);
v___x_487_ = ((lean_object*)(lp_loam_Loam_Cli_showEventQuantity___closed__0));
v___x_488_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_487_);
if (lean_obj_tag(v___x_488_) == 0)
{
lean_object* v___x_490_; uint8_t v_isShared_491_; uint8_t v_isSharedCheck_496_; 
v_isSharedCheck_496_ = !lean_is_exclusive(v___x_488_);
if (v_isSharedCheck_496_ == 0)
{
lean_object* v_unused_497_; 
v_unused_497_ = lean_ctor_get(v___x_488_, 0);
lean_dec(v_unused_497_);
v___x_490_ = v___x_488_;
v_isShared_491_ = v_isSharedCheck_496_;
goto v_resetjp_489_;
}
else
{
lean_dec(v___x_488_);
v___x_490_ = lean_box(0);
v_isShared_491_ = v_isSharedCheck_496_;
goto v_resetjp_489_;
}
v_resetjp_489_:
{
lean_object* v___x_492_; lean_object* v___x_494_; 
v___x_492_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_491_ == 0)
{
lean_ctor_set(v___x_490_, 0, v___x_492_);
v___x_494_ = v___x_490_;
goto v_reusejp_493_;
}
else
{
lean_object* v_reuseFailAlloc_495_; 
v_reuseFailAlloc_495_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_495_, 0, v___x_492_);
v___x_494_ = v_reuseFailAlloc_495_;
goto v_reusejp_493_;
}
v_reusejp_493_:
{
return v___x_494_;
}
}
}
else
{
lean_object* v_a_498_; lean_object* v___x_500_; uint8_t v_isShared_501_; uint8_t v_isSharedCheck_505_; 
v_a_498_ = lean_ctor_get(v___x_488_, 0);
v_isSharedCheck_505_ = !lean_is_exclusive(v___x_488_);
if (v_isSharedCheck_505_ == 0)
{
v___x_500_ = v___x_488_;
v_isShared_501_ = v_isSharedCheck_505_;
goto v_resetjp_499_;
}
else
{
lean_inc(v_a_498_);
lean_dec(v___x_488_);
v___x_500_ = lean_box(0);
v_isShared_501_ = v_isSharedCheck_505_;
goto v_resetjp_499_;
}
v_resetjp_499_:
{
lean_object* v___x_503_; 
if (v_isShared_501_ == 0)
{
v___x_503_ = v___x_500_;
goto v_reusejp_502_;
}
else
{
lean_object* v_reuseFailAlloc_504_; 
v_reuseFailAlloc_504_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_504_, 0, v_a_498_);
v___x_503_ = v_reuseFailAlloc_504_;
goto v_reusejp_502_;
}
v_reusejp_502_:
{
return v___x_503_;
}
}
}
}
else
{
lean_object* v_val_506_; lean_object* v___x_507_; 
v_val_506_ = lean_ctor_get(v_a_486_, 0);
lean_inc(v_val_506_);
lean_dec_ref_known(v_a_486_, 1);
v___x_507_ = lp_loam_Loam_Core_EventMemory_add_x3f(v_val_484_, v_val_506_);
if (lean_obj_tag(v___x_507_) == 0)
{
lean_object* v___x_508_; lean_object* v___x_509_; 
lean_dec_ref(v_memoryPath_460_);
v___x_508_ = ((lean_object*)(lp_loam_Loam_Cli_addRememberedEvent___closed__0));
v___x_509_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_508_);
if (lean_obj_tag(v___x_509_) == 0)
{
lean_object* v___x_511_; uint8_t v_isShared_512_; uint8_t v_isSharedCheck_517_; 
v_isSharedCheck_517_ = !lean_is_exclusive(v___x_509_);
if (v_isSharedCheck_517_ == 0)
{
lean_object* v_unused_518_; 
v_unused_518_ = lean_ctor_get(v___x_509_, 0);
lean_dec(v_unused_518_);
v___x_511_ = v___x_509_;
v_isShared_512_ = v_isSharedCheck_517_;
goto v_resetjp_510_;
}
else
{
lean_dec(v___x_509_);
v___x_511_ = lean_box(0);
v_isShared_512_ = v_isSharedCheck_517_;
goto v_resetjp_510_;
}
v_resetjp_510_:
{
lean_object* v___x_513_; lean_object* v___x_515_; 
v___x_513_ = lp_loam_Loam_Cli_showRememberedEvent___boxed__const__1;
if (v_isShared_512_ == 0)
{
lean_ctor_set(v___x_511_, 0, v___x_513_);
v___x_515_ = v___x_511_;
goto v_reusejp_514_;
}
else
{
lean_object* v_reuseFailAlloc_516_; 
v_reuseFailAlloc_516_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_516_, 0, v___x_513_);
v___x_515_ = v_reuseFailAlloc_516_;
goto v_reusejp_514_;
}
v_reusejp_514_:
{
return v___x_515_;
}
}
}
else
{
lean_object* v_a_519_; lean_object* v___x_521_; uint8_t v_isShared_522_; uint8_t v_isSharedCheck_526_; 
v_a_519_ = lean_ctor_get(v___x_509_, 0);
v_isSharedCheck_526_ = !lean_is_exclusive(v___x_509_);
if (v_isSharedCheck_526_ == 0)
{
v___x_521_ = v___x_509_;
v_isShared_522_ = v_isSharedCheck_526_;
goto v_resetjp_520_;
}
else
{
lean_inc(v_a_519_);
lean_dec(v___x_509_);
v___x_521_ = lean_box(0);
v_isShared_522_ = v_isSharedCheck_526_;
goto v_resetjp_520_;
}
v_resetjp_520_:
{
lean_object* v___x_524_; 
if (v_isShared_522_ == 0)
{
v___x_524_ = v___x_521_;
goto v_reusejp_523_;
}
else
{
lean_object* v_reuseFailAlloc_525_; 
v_reuseFailAlloc_525_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_525_, 0, v_a_519_);
v___x_524_ = v_reuseFailAlloc_525_;
goto v_reusejp_523_;
}
v_reusejp_523_:
{
return v___x_524_;
}
}
}
}
else
{
lean_object* v_val_527_; lean_object* v___x_528_; 
v_val_527_ = lean_ctor_get(v___x_507_, 0);
lean_inc(v_val_527_);
lean_dec_ref_known(v___x_507_, 1);
v___x_528_ = lp_loam_Loam_Persistence_saveEventMemory_x3f(v_memoryPath_460_, v_val_527_);
if (lean_obj_tag(v___x_528_) == 0)
{
lean_object* v_a_529_; lean_object* v___x_531_; uint8_t v_isShared_532_; uint8_t v_isSharedCheck_557_; 
v_a_529_ = lean_ctor_get(v___x_528_, 0);
v_isSharedCheck_557_ = !lean_is_exclusive(v___x_528_);
if (v_isSharedCheck_557_ == 0)
{
v___x_531_ = v___x_528_;
v_isShared_532_ = v_isSharedCheck_557_;
goto v_resetjp_530_;
}
else
{
lean_inc(v_a_529_);
lean_dec(v___x_528_);
v___x_531_ = lean_box(0);
v_isShared_532_ = v_isSharedCheck_557_;
goto v_resetjp_530_;
}
v_resetjp_530_:
{
uint8_t v___x_533_; 
v___x_533_ = lean_unbox(v_a_529_);
lean_dec(v_a_529_);
if (v___x_533_ == 0)
{
lean_object* v___x_534_; lean_object* v___x_535_; 
lean_del_object(v___x_531_);
v___x_534_ = ((lean_object*)(lp_loam_Loam_Cli_addRememberedEvent___closed__1));
v___x_535_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_534_);
if (lean_obj_tag(v___x_535_) == 0)
{
lean_object* v___x_537_; uint8_t v_isShared_538_; uint8_t v_isSharedCheck_543_; 
v_isSharedCheck_543_ = !lean_is_exclusive(v___x_535_);
if (v_isSharedCheck_543_ == 0)
{
lean_object* v_unused_544_; 
v_unused_544_ = lean_ctor_get(v___x_535_, 0);
lean_dec(v_unused_544_);
v___x_537_ = v___x_535_;
v_isShared_538_ = v_isSharedCheck_543_;
goto v_resetjp_536_;
}
else
{
lean_dec(v___x_535_);
v___x_537_ = lean_box(0);
v_isShared_538_ = v_isSharedCheck_543_;
goto v_resetjp_536_;
}
v_resetjp_536_:
{
lean_object* v___x_539_; lean_object* v___x_541_; 
v___x_539_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_538_ == 0)
{
lean_ctor_set(v___x_537_, 0, v___x_539_);
v___x_541_ = v___x_537_;
goto v_reusejp_540_;
}
else
{
lean_object* v_reuseFailAlloc_542_; 
v_reuseFailAlloc_542_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_542_, 0, v___x_539_);
v___x_541_ = v_reuseFailAlloc_542_;
goto v_reusejp_540_;
}
v_reusejp_540_:
{
return v___x_541_;
}
}
}
else
{
lean_object* v_a_545_; lean_object* v___x_547_; uint8_t v_isShared_548_; uint8_t v_isSharedCheck_552_; 
v_a_545_ = lean_ctor_get(v___x_535_, 0);
v_isSharedCheck_552_ = !lean_is_exclusive(v___x_535_);
if (v_isSharedCheck_552_ == 0)
{
v___x_547_ = v___x_535_;
v_isShared_548_ = v_isSharedCheck_552_;
goto v_resetjp_546_;
}
else
{
lean_inc(v_a_545_);
lean_dec(v___x_535_);
v___x_547_ = lean_box(0);
v_isShared_548_ = v_isSharedCheck_552_;
goto v_resetjp_546_;
}
v_resetjp_546_:
{
lean_object* v___x_550_; 
if (v_isShared_548_ == 0)
{
v___x_550_ = v___x_547_;
goto v_reusejp_549_;
}
else
{
lean_object* v_reuseFailAlloc_551_; 
v_reuseFailAlloc_551_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_551_, 0, v_a_545_);
v___x_550_ = v_reuseFailAlloc_551_;
goto v_reusejp_549_;
}
v_reusejp_549_:
{
return v___x_550_;
}
}
}
}
else
{
lean_object* v___x_553_; lean_object* v___x_555_; 
v___x_553_ = lp_loam_Loam_Cli_showAmount___boxed__const__2;
if (v_isShared_532_ == 0)
{
lean_ctor_set(v___x_531_, 0, v___x_553_);
v___x_555_ = v___x_531_;
goto v_reusejp_554_;
}
else
{
lean_object* v_reuseFailAlloc_556_; 
v_reuseFailAlloc_556_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_556_, 0, v___x_553_);
v___x_555_ = v_reuseFailAlloc_556_;
goto v_reusejp_554_;
}
v_reusejp_554_:
{
return v___x_555_;
}
}
}
}
else
{
lean_object* v_a_558_; lean_object* v___x_560_; uint8_t v_isShared_561_; uint8_t v_isSharedCheck_565_; 
v_a_558_ = lean_ctor_get(v___x_528_, 0);
v_isSharedCheck_565_ = !lean_is_exclusive(v___x_528_);
if (v_isSharedCheck_565_ == 0)
{
v___x_560_ = v___x_528_;
v_isShared_561_ = v_isSharedCheck_565_;
goto v_resetjp_559_;
}
else
{
lean_inc(v_a_558_);
lean_dec(v___x_528_);
v___x_560_ = lean_box(0);
v_isShared_561_ = v_isSharedCheck_565_;
goto v_resetjp_559_;
}
v_resetjp_559_:
{
lean_object* v___x_563_; 
if (v_isShared_561_ == 0)
{
v___x_563_ = v___x_560_;
goto v_reusejp_562_;
}
else
{
lean_object* v_reuseFailAlloc_564_; 
v_reuseFailAlloc_564_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_564_, 0, v_a_558_);
v___x_563_ = v_reuseFailAlloc_564_;
goto v_reusejp_562_;
}
v_reusejp_562_:
{
return v___x_563_;
}
}
}
}
}
}
else
{
lean_object* v_a_566_; lean_object* v___x_568_; uint8_t v_isShared_569_; uint8_t v_isSharedCheck_573_; 
lean_dec(v_val_484_);
lean_dec_ref(v_memoryPath_460_);
v_a_566_ = lean_ctor_get(v___x_485_, 0);
v_isSharedCheck_573_ = !lean_is_exclusive(v___x_485_);
if (v_isSharedCheck_573_ == 0)
{
v___x_568_ = v___x_485_;
v_isShared_569_ = v_isSharedCheck_573_;
goto v_resetjp_567_;
}
else
{
lean_inc(v_a_566_);
lean_dec(v___x_485_);
v___x_568_ = lean_box(0);
v_isShared_569_ = v_isSharedCheck_573_;
goto v_resetjp_567_;
}
v_resetjp_567_:
{
lean_object* v___x_571_; 
if (v_isShared_569_ == 0)
{
v___x_571_ = v___x_568_;
goto v_reusejp_570_;
}
else
{
lean_object* v_reuseFailAlloc_572_; 
v_reuseFailAlloc_572_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_572_, 0, v_a_566_);
v___x_571_ = v_reuseFailAlloc_572_;
goto v_reusejp_570_;
}
v_reusejp_570_:
{
return v___x_571_;
}
}
}
}
}
else
{
lean_object* v_a_574_; lean_object* v___x_576_; uint8_t v_isShared_577_; uint8_t v_isSharedCheck_581_; 
lean_dec_ref(v_memoryPath_460_);
v_a_574_ = lean_ctor_get(v___x_463_, 0);
v_isSharedCheck_581_ = !lean_is_exclusive(v___x_463_);
if (v_isSharedCheck_581_ == 0)
{
v___x_576_ = v___x_463_;
v_isShared_577_ = v_isSharedCheck_581_;
goto v_resetjp_575_;
}
else
{
lean_inc(v_a_574_);
lean_dec(v___x_463_);
v___x_576_ = lean_box(0);
v_isShared_577_ = v_isSharedCheck_581_;
goto v_resetjp_575_;
}
v_resetjp_575_:
{
lean_object* v___x_579_; 
if (v_isShared_577_ == 0)
{
v___x_579_ = v___x_576_;
goto v_reusejp_578_;
}
else
{
lean_object* v_reuseFailAlloc_580_; 
v_reuseFailAlloc_580_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_580_, 0, v_a_574_);
v___x_579_ = v_reuseFailAlloc_580_;
goto v_reusejp_578_;
}
v_reusejp_578_:
{
return v___x_579_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_addRememberedEvent___boxed(lean_object* v_memoryPath_582_, lean_object* v_eventPath_583_, lean_object* v_a_584_){
_start:
{
lean_object* v_res_585_; 
v_res_585_ = lp_loam_Loam_Cli_addRememberedEvent(v_memoryPath_582_, v_eventPath_583_);
lean_dec_ref(v_eventPath_583_);
return v_res_585_;
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_promptLine(lean_object* v_prompt_586_){
_start:
{
lean_object* v___x_588_; 
v___x_588_ = lp_loam_IO_print___at___00IO_println___at___00Loam_Cli_showAmount_spec__0_spec__0(v_prompt_586_);
if (lean_obj_tag(v___x_588_) == 0)
{
lean_object* v___x_589_; lean_object* v_flush_590_; lean_object* v___x_591_; 
lean_dec_ref_known(v___x_588_, 1);
v___x_589_ = lean_get_stdout();
v_flush_590_ = lean_ctor_get(v___x_589_, 0);
lean_inc_ref(v_flush_590_);
lean_dec_ref(v___x_589_);
v___x_591_ = lean_apply_1(v_flush_590_, lean_box(0));
if (lean_obj_tag(v___x_591_) == 0)
{
lean_object* v___x_592_; lean_object* v_getLine_593_; lean_object* v___x_594_; 
lean_dec_ref_known(v___x_591_, 1);
v___x_592_ = lean_get_stdin();
v_getLine_593_ = lean_ctor_get(v___x_592_, 3);
lean_inc_ref(v_getLine_593_);
lean_dec_ref(v___x_592_);
v___x_594_ = lean_apply_1(v_getLine_593_, lean_box(0));
if (lean_obj_tag(v___x_594_) == 0)
{
lean_object* v_a_595_; lean_object* v___x_597_; uint8_t v_isShared_598_; uint8_t v_isSharedCheck_608_; 
v_a_595_ = lean_ctor_get(v___x_594_, 0);
v_isSharedCheck_608_ = !lean_is_exclusive(v___x_594_);
if (v_isSharedCheck_608_ == 0)
{
v___x_597_ = v___x_594_;
v_isShared_598_ = v_isSharedCheck_608_;
goto v_resetjp_596_;
}
else
{
lean_inc(v_a_595_);
lean_dec(v___x_594_);
v___x_597_ = lean_box(0);
v_isShared_598_ = v_isSharedCheck_608_;
goto v_resetjp_596_;
}
v_resetjp_596_:
{
lean_object* v___x_599_; lean_object* v___x_600_; lean_object* v___x_601_; lean_object* v___x_602_; lean_object* v___x_603_; lean_object* v___x_604_; lean_object* v___x_606_; 
v___x_599_ = lean_unsigned_to_nat(0u);
v___x_600_ = lean_string_utf8_byte_size(v_a_595_);
lean_inc(v_a_595_);
v___x_601_ = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(v___x_601_, 0, v_a_595_);
lean_ctor_set(v___x_601_, 1, v___x_599_);
lean_ctor_set(v___x_601_, 2, v___x_600_);
v___x_602_ = l_String_Slice_Pos_revSkipWhile___at___00__private_Std_Http_Protocol_H1_Parser_0__Std_Http_Protocol_H1_parseFieldLine_spec__0(v___x_601_, v___x_600_);
lean_dec_ref_known(v___x_601_, 3);
v___x_603_ = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(v___x_603_, 0, v_a_595_);
lean_ctor_set(v___x_603_, 1, v___x_599_);
lean_ctor_set(v___x_603_, 2, v___x_602_);
v___x_604_ = l_String_Slice_toString(v___x_603_);
lean_dec_ref_known(v___x_603_, 3);
if (v_isShared_598_ == 0)
{
lean_ctor_set(v___x_597_, 0, v___x_604_);
v___x_606_ = v___x_597_;
goto v_reusejp_605_;
}
else
{
lean_object* v_reuseFailAlloc_607_; 
v_reuseFailAlloc_607_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_607_, 0, v___x_604_);
v___x_606_ = v_reuseFailAlloc_607_;
goto v_reusejp_605_;
}
v_reusejp_605_:
{
return v___x_606_;
}
}
}
else
{
return v___x_594_;
}
}
else
{
lean_object* v_a_609_; lean_object* v___x_611_; uint8_t v_isShared_612_; uint8_t v_isSharedCheck_616_; 
v_a_609_ = lean_ctor_get(v___x_591_, 0);
v_isSharedCheck_616_ = !lean_is_exclusive(v___x_591_);
if (v_isSharedCheck_616_ == 0)
{
v___x_611_ = v___x_591_;
v_isShared_612_ = v_isSharedCheck_616_;
goto v_resetjp_610_;
}
else
{
lean_inc(v_a_609_);
lean_dec(v___x_591_);
v___x_611_ = lean_box(0);
v_isShared_612_ = v_isSharedCheck_616_;
goto v_resetjp_610_;
}
v_resetjp_610_:
{
lean_object* v___x_614_; 
if (v_isShared_612_ == 0)
{
v___x_614_ = v___x_611_;
goto v_reusejp_613_;
}
else
{
lean_object* v_reuseFailAlloc_615_; 
v_reuseFailAlloc_615_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_615_, 0, v_a_609_);
v___x_614_ = v_reuseFailAlloc_615_;
goto v_reusejp_613_;
}
v_reusejp_613_:
{
return v___x_614_;
}
}
}
}
else
{
lean_object* v_a_617_; lean_object* v___x_619_; uint8_t v_isShared_620_; uint8_t v_isSharedCheck_624_; 
v_a_617_ = lean_ctor_get(v___x_588_, 0);
v_isSharedCheck_624_ = !lean_is_exclusive(v___x_588_);
if (v_isSharedCheck_624_ == 0)
{
v___x_619_ = v___x_588_;
v_isShared_620_ = v_isSharedCheck_624_;
goto v_resetjp_618_;
}
else
{
lean_inc(v_a_617_);
lean_dec(v___x_588_);
v___x_619_ = lean_box(0);
v_isShared_620_ = v_isSharedCheck_624_;
goto v_resetjp_618_;
}
v_resetjp_618_:
{
lean_object* v___x_622_; 
if (v_isShared_620_ == 0)
{
v___x_622_ = v___x_619_;
goto v_reusejp_621_;
}
else
{
lean_object* v_reuseFailAlloc_623_; 
v_reuseFailAlloc_623_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_623_, 0, v_a_617_);
v___x_622_ = v_reuseFailAlloc_623_;
goto v_reusejp_621_;
}
v_reusejp_621_:
{
return v___x_622_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_promptLine___boxed(lean_object* v_prompt_625_, lean_object* v_a_626_){
_start:
{
lean_object* v_res_627_; 
v_res_627_ = lp_loam___private_Loam_Cli_0__Loam_Cli_promptLine(v_prompt_625_);
return v_res_627_;
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventIdFrom(lean_object* v_memory_629_, lean_object* v_x_630_, lean_object* v_x_631_){
_start:
{
lean_object* v_zero_632_; uint8_t v_isZero_633_; 
v_zero_632_ = lean_unsigned_to_nat(0u);
v_isZero_633_ = lean_nat_dec_eq(v_x_631_, v_zero_632_);
if (v_isZero_633_ == 1)
{
lean_object* v___x_634_; 
lean_dec(v_x_631_);
lean_dec(v_x_630_);
v___x_634_ = lean_box(0);
return v___x_634_;
}
else
{
lean_object* v___x_635_; lean_object* v___x_636_; lean_object* v_candidate_637_; lean_object* v___x_638_; 
v___x_635_ = ((lean_object*)(lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventIdFrom___closed__0));
lean_inc(v_x_630_);
v___x_636_ = l_Nat_reprFast(v_x_630_);
v_candidate_637_ = lean_string_append(v___x_635_, v___x_636_);
lean_dec_ref(v___x_636_);
v___x_638_ = lp_loam___private_Loam_Core_EventMemory_0__Loam_Core_EventMemory_findEventById_x3f(v_memory_629_, v_candidate_637_);
if (lean_obj_tag(v___x_638_) == 0)
{
lean_object* v___x_639_; 
lean_dec(v_x_631_);
lean_dec(v_x_630_);
v___x_639_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_639_, 0, v_candidate_637_);
return v___x_639_;
}
else
{
lean_object* v_one_640_; lean_object* v_n_641_; lean_object* v___x_642_; 
lean_dec_ref_known(v___x_638_, 1);
lean_dec_ref(v_candidate_637_);
v_one_640_ = lean_unsigned_to_nat(1u);
v_n_641_ = lean_nat_sub(v_x_631_, v_one_640_);
lean_dec(v_x_631_);
v___x_642_ = lean_nat_add(v_x_630_, v_one_640_);
lean_dec(v_x_630_);
v_x_630_ = v___x_642_;
v_x_631_ = v_n_641_;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventIdFrom___boxed(lean_object* v_memory_644_, lean_object* v_x_645_, lean_object* v_x_646_){
_start:
{
lean_object* v_res_647_; 
v_res_647_ = lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventIdFrom(v_memory_644_, v_x_645_, v_x_646_);
lean_dec(v_memory_644_);
return v_res_647_;
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventId_x3f(lean_object* v_memory_648_){
_start:
{
lean_object* v___x_649_; lean_object* v___x_650_; lean_object* v___x_651_; lean_object* v___x_652_; 
v___x_649_ = lean_unsigned_to_nat(1u);
v___x_650_ = l_List_lengthTR___redArg(v_memory_648_);
v___x_651_ = lean_nat_add(v___x_650_, v___x_649_);
lean_dec(v___x_650_);
v___x_652_ = lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventIdFrom(v_memory_648_, v___x_649_, v___x_651_);
return v___x_652_;
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventId_x3f___boxed(lean_object* v_memory_653_){
_start:
{
lean_object* v_res_654_; 
v_res_654_ = lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventId_x3f(v_memory_653_);
lean_dec(v_memory_653_);
return v_res_654_;
}
}
static lean_object* _init_lp_loam___private_Loam_Cli_0__Loam_Cli_loadEventMemoryForEntry_x3f___closed__0(void){
_start:
{
lean_object* v___x_655_; lean_object* v___x_656_; 
v___x_655_ = lean_box(0);
v___x_656_ = lp_loam_Loam_Core_EventMemory_ofEvents_x3f(v___x_655_);
return v___x_656_;
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_loadEventMemoryForEntry_x3f(lean_object* v_path_657_){
_start:
{
uint8_t v___x_659_; 
v___x_659_ = l_System_FilePath_pathExists(v_path_657_);
if (v___x_659_ == 0)
{
lean_object* v___x_660_; lean_object* v___x_661_; 
v___x_660_ = lean_obj_once(&lp_loam___private_Loam_Cli_0__Loam_Cli_loadEventMemoryForEntry_x3f___closed__0, &lp_loam___private_Loam_Cli_0__Loam_Cli_loadEventMemoryForEntry_x3f___closed__0_once, _init_lp_loam___private_Loam_Cli_0__Loam_Cli_loadEventMemoryForEntry_x3f___closed__0);
v___x_661_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v___x_661_, 0, v___x_660_);
return v___x_661_;
}
else
{
lean_object* v___x_662_; 
v___x_662_ = lp_loam_Loam_Persistence_loadEventMemory_x3f(v_path_657_);
return v___x_662_;
}
}
}
LEAN_EXPORT lean_object* lp_loam___private_Loam_Cli_0__Loam_Cli_loadEventMemoryForEntry_x3f___boxed(lean_object* v_path_663_, lean_object* v_a_664_){
_start:
{
lean_object* v_res_665_; 
v_res_665_ = lp_loam___private_Loam_Cli_0__Loam_Cli_loadEventMemoryForEntry_x3f(v_path_663_);
lean_dec_ref(v_path_663_);
return v_res_665_;
}
}
static lean_object* _init_lp_loam_Loam_Cli_spendJpy___closed__4(void){
_start:
{
lean_object* v___x_670_; lean_object* v___x_671_; 
v___x_670_ = lean_unsigned_to_nat(0u);
v___x_671_ = lean_nat_to_int(v___x_670_);
return v___x_671_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_spendJpy(lean_object* v_memoryPath_681_){
_start:
{
lean_object* v___x_683_; 
v___x_683_ = lp_loam___private_Loam_Cli_0__Loam_Cli_loadEventMemoryForEntry_x3f(v_memoryPath_681_);
if (lean_obj_tag(v___x_683_) == 0)
{
lean_object* v_a_684_; 
v_a_684_ = lean_ctor_get(v___x_683_, 0);
lean_inc(v_a_684_);
lean_dec_ref_known(v___x_683_, 1);
if (lean_obj_tag(v_a_684_) == 0)
{
lean_object* v___x_685_; lean_object* v___x_686_; 
lean_dec_ref(v_memoryPath_681_);
v___x_685_ = ((lean_object*)(lp_loam_Loam_Cli_showRememberedEvent___closed__0));
v___x_686_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_685_);
if (lean_obj_tag(v___x_686_) == 0)
{
lean_object* v___x_688_; uint8_t v_isShared_689_; uint8_t v_isSharedCheck_694_; 
v_isSharedCheck_694_ = !lean_is_exclusive(v___x_686_);
if (v_isSharedCheck_694_ == 0)
{
lean_object* v_unused_695_; 
v_unused_695_ = lean_ctor_get(v___x_686_, 0);
lean_dec(v_unused_695_);
v___x_688_ = v___x_686_;
v_isShared_689_ = v_isSharedCheck_694_;
goto v_resetjp_687_;
}
else
{
lean_dec(v___x_686_);
v___x_688_ = lean_box(0);
v_isShared_689_ = v_isSharedCheck_694_;
goto v_resetjp_687_;
}
v_resetjp_687_:
{
lean_object* v___x_690_; lean_object* v___x_692_; 
v___x_690_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_689_ == 0)
{
lean_ctor_set(v___x_688_, 0, v___x_690_);
v___x_692_ = v___x_688_;
goto v_reusejp_691_;
}
else
{
lean_object* v_reuseFailAlloc_693_; 
v_reuseFailAlloc_693_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_693_, 0, v___x_690_);
v___x_692_ = v_reuseFailAlloc_693_;
goto v_reusejp_691_;
}
v_reusejp_691_:
{
return v___x_692_;
}
}
}
else
{
lean_object* v_a_696_; lean_object* v___x_698_; uint8_t v_isShared_699_; uint8_t v_isSharedCheck_703_; 
v_a_696_ = lean_ctor_get(v___x_686_, 0);
v_isSharedCheck_703_ = !lean_is_exclusive(v___x_686_);
if (v_isSharedCheck_703_ == 0)
{
v___x_698_ = v___x_686_;
v_isShared_699_ = v_isSharedCheck_703_;
goto v_resetjp_697_;
}
else
{
lean_inc(v_a_696_);
lean_dec(v___x_686_);
v___x_698_ = lean_box(0);
v_isShared_699_ = v_isSharedCheck_703_;
goto v_resetjp_697_;
}
v_resetjp_697_:
{
lean_object* v___x_701_; 
if (v_isShared_699_ == 0)
{
v___x_701_ = v___x_698_;
goto v_reusejp_700_;
}
else
{
lean_object* v_reuseFailAlloc_702_; 
v_reuseFailAlloc_702_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_702_, 0, v_a_696_);
v___x_701_ = v_reuseFailAlloc_702_;
goto v_reusejp_700_;
}
v_reusejp_700_:
{
return v___x_701_;
}
}
}
}
else
{
lean_object* v_val_704_; lean_object* v___x_705_; lean_object* v___x_706_; 
v_val_704_ = lean_ctor_get(v_a_684_, 0);
lean_inc(v_val_704_);
lean_dec_ref_known(v_a_684_, 1);
v___x_705_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__0));
v___x_706_ = lp_loam___private_Loam_Cli_0__Loam_Cli_promptLine(v___x_705_);
if (lean_obj_tag(v___x_706_) == 0)
{
lean_object* v_a_707_; uint8_t v___x_708_; 
v_a_707_ = lean_ctor_get(v___x_706_, 0);
lean_inc_n(v_a_707_, 2);
lean_dec_ref_known(v___x_706_, 1);
v___x_708_ = lp_loam_Loam_Persistence_validToken(v_a_707_);
if (v___x_708_ == 0)
{
lean_object* v___x_709_; lean_object* v___x_710_; 
lean_dec(v_a_707_);
lean_dec(v_val_704_);
lean_dec_ref(v_memoryPath_681_);
v___x_709_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__1));
v___x_710_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_709_);
if (lean_obj_tag(v___x_710_) == 0)
{
lean_object* v___x_712_; uint8_t v_isShared_713_; uint8_t v_isSharedCheck_718_; 
v_isSharedCheck_718_ = !lean_is_exclusive(v___x_710_);
if (v_isSharedCheck_718_ == 0)
{
lean_object* v_unused_719_; 
v_unused_719_ = lean_ctor_get(v___x_710_, 0);
lean_dec(v_unused_719_);
v___x_712_ = v___x_710_;
v_isShared_713_ = v_isSharedCheck_718_;
goto v_resetjp_711_;
}
else
{
lean_dec(v___x_710_);
v___x_712_ = lean_box(0);
v_isShared_713_ = v_isSharedCheck_718_;
goto v_resetjp_711_;
}
v_resetjp_711_:
{
lean_object* v___x_714_; lean_object* v___x_716_; 
v___x_714_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_713_ == 0)
{
lean_ctor_set(v___x_712_, 0, v___x_714_);
v___x_716_ = v___x_712_;
goto v_reusejp_715_;
}
else
{
lean_object* v_reuseFailAlloc_717_; 
v_reuseFailAlloc_717_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_717_, 0, v___x_714_);
v___x_716_ = v_reuseFailAlloc_717_;
goto v_reusejp_715_;
}
v_reusejp_715_:
{
return v___x_716_;
}
}
}
else
{
lean_object* v_a_720_; lean_object* v___x_722_; uint8_t v_isShared_723_; uint8_t v_isSharedCheck_727_; 
v_a_720_ = lean_ctor_get(v___x_710_, 0);
v_isSharedCheck_727_ = !lean_is_exclusive(v___x_710_);
if (v_isSharedCheck_727_ == 0)
{
v___x_722_ = v___x_710_;
v_isShared_723_ = v_isSharedCheck_727_;
goto v_resetjp_721_;
}
else
{
lean_inc(v_a_720_);
lean_dec(v___x_710_);
v___x_722_ = lean_box(0);
v_isShared_723_ = v_isSharedCheck_727_;
goto v_resetjp_721_;
}
v_resetjp_721_:
{
lean_object* v___x_725_; 
if (v_isShared_723_ == 0)
{
v___x_725_ = v___x_722_;
goto v_reusejp_724_;
}
else
{
lean_object* v_reuseFailAlloc_726_; 
v_reuseFailAlloc_726_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_726_, 0, v_a_720_);
v___x_725_ = v_reuseFailAlloc_726_;
goto v_reusejp_724_;
}
v_reusejp_724_:
{
return v___x_725_;
}
}
}
}
else
{
lean_object* v___x_728_; lean_object* v___x_729_; 
v___x_728_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__2));
v___x_729_ = lp_loam___private_Loam_Cli_0__Loam_Cli_promptLine(v___x_728_);
if (lean_obj_tag(v___x_729_) == 0)
{
lean_object* v_a_730_; lean_object* v___x_731_; lean_object* v___x_732_; lean_object* v___x_733_; lean_object* v___x_734_; 
v_a_730_ = lean_ctor_get(v___x_729_, 0);
lean_inc(v_a_730_);
lean_dec_ref_known(v___x_729_, 1);
v___x_731_ = lean_unsigned_to_nat(0u);
v___x_732_ = lean_string_utf8_byte_size(v_a_730_);
v___x_733_ = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(v___x_733_, 0, v_a_730_);
lean_ctor_set(v___x_733_, 1, v___x_731_);
lean_ctor_set(v___x_733_, 2, v___x_732_);
v___x_734_ = l_String_Slice_toInt_x3f(v___x_733_);
if (lean_obj_tag(v___x_734_) == 0)
{
lean_object* v___x_735_; lean_object* v___x_736_; 
lean_dec(v_a_707_);
lean_dec(v_val_704_);
lean_dec_ref(v_memoryPath_681_);
v___x_735_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__3));
v___x_736_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_735_);
if (lean_obj_tag(v___x_736_) == 0)
{
lean_object* v___x_738_; uint8_t v_isShared_739_; uint8_t v_isSharedCheck_744_; 
v_isSharedCheck_744_ = !lean_is_exclusive(v___x_736_);
if (v_isSharedCheck_744_ == 0)
{
lean_object* v_unused_745_; 
v_unused_745_ = lean_ctor_get(v___x_736_, 0);
lean_dec(v_unused_745_);
v___x_738_ = v___x_736_;
v_isShared_739_ = v_isSharedCheck_744_;
goto v_resetjp_737_;
}
else
{
lean_dec(v___x_736_);
v___x_738_ = lean_box(0);
v_isShared_739_ = v_isSharedCheck_744_;
goto v_resetjp_737_;
}
v_resetjp_737_:
{
lean_object* v___x_740_; lean_object* v___x_742_; 
v___x_740_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_739_ == 0)
{
lean_ctor_set(v___x_738_, 0, v___x_740_);
v___x_742_ = v___x_738_;
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
v_a_746_ = lean_ctor_get(v___x_736_, 0);
v_isSharedCheck_753_ = !lean_is_exclusive(v___x_736_);
if (v_isSharedCheck_753_ == 0)
{
v___x_748_ = v___x_736_;
v_isShared_749_ = v_isSharedCheck_753_;
goto v_resetjp_747_;
}
else
{
lean_inc(v_a_746_);
lean_dec(v___x_736_);
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
else
{
lean_object* v_val_754_; lean_object* v___x_755_; uint8_t v___x_756_; 
v_val_754_ = lean_ctor_get(v___x_734_, 0);
lean_inc(v_val_754_);
lean_dec_ref_known(v___x_734_, 1);
v___x_755_ = lean_obj_once(&lp_loam_Loam_Cli_spendJpy___closed__4, &lp_loam_Loam_Cli_spendJpy___closed__4_once, _init_lp_loam_Loam_Cli_spendJpy___closed__4);
v___x_756_ = lean_int_dec_lt(v___x_755_, v_val_754_);
if (v___x_756_ == 0)
{
lean_object* v___x_757_; lean_object* v___x_758_; 
lean_dec(v_val_754_);
lean_dec(v_a_707_);
lean_dec(v_val_704_);
lean_dec_ref(v_memoryPath_681_);
v___x_757_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__3));
v___x_758_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_757_);
if (lean_obj_tag(v___x_758_) == 0)
{
lean_object* v___x_760_; uint8_t v_isShared_761_; uint8_t v_isSharedCheck_766_; 
v_isSharedCheck_766_ = !lean_is_exclusive(v___x_758_);
if (v_isSharedCheck_766_ == 0)
{
lean_object* v_unused_767_; 
v_unused_767_ = lean_ctor_get(v___x_758_, 0);
lean_dec(v_unused_767_);
v___x_760_ = v___x_758_;
v_isShared_761_ = v_isSharedCheck_766_;
goto v_resetjp_759_;
}
else
{
lean_dec(v___x_758_);
v___x_760_ = lean_box(0);
v_isShared_761_ = v_isSharedCheck_766_;
goto v_resetjp_759_;
}
v_resetjp_759_:
{
lean_object* v___x_762_; lean_object* v___x_764_; 
v___x_762_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_761_ == 0)
{
lean_ctor_set(v___x_760_, 0, v___x_762_);
v___x_764_ = v___x_760_;
goto v_reusejp_763_;
}
else
{
lean_object* v_reuseFailAlloc_765_; 
v_reuseFailAlloc_765_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_765_, 0, v___x_762_);
v___x_764_ = v_reuseFailAlloc_765_;
goto v_reusejp_763_;
}
v_reusejp_763_:
{
return v___x_764_;
}
}
}
else
{
lean_object* v_a_768_; lean_object* v___x_770_; uint8_t v_isShared_771_; uint8_t v_isSharedCheck_775_; 
v_a_768_ = lean_ctor_get(v___x_758_, 0);
v_isSharedCheck_775_ = !lean_is_exclusive(v___x_758_);
if (v_isSharedCheck_775_ == 0)
{
v___x_770_ = v___x_758_;
v_isShared_771_ = v_isSharedCheck_775_;
goto v_resetjp_769_;
}
else
{
lean_inc(v_a_768_);
lean_dec(v___x_758_);
v___x_770_ = lean_box(0);
v_isShared_771_ = v_isSharedCheck_775_;
goto v_resetjp_769_;
}
v_resetjp_769_:
{
lean_object* v___x_773_; 
if (v_isShared_771_ == 0)
{
v___x_773_ = v___x_770_;
goto v_reusejp_772_;
}
else
{
lean_object* v_reuseFailAlloc_774_; 
v_reuseFailAlloc_774_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_774_, 0, v_a_768_);
v___x_773_ = v_reuseFailAlloc_774_;
goto v_reusejp_772_;
}
v_reusejp_772_:
{
return v___x_773_;
}
}
}
}
else
{
lean_object* v___x_776_; 
v___x_776_ = lp_loam___private_Loam_Cli_0__Loam_Cli_freshRecordEventId_x3f(v_val_704_);
if (lean_obj_tag(v___x_776_) == 0)
{
lean_object* v___x_777_; lean_object* v___x_778_; 
lean_dec(v_val_754_);
lean_dec(v_a_707_);
lean_dec(v_val_704_);
lean_dec_ref(v_memoryPath_681_);
v___x_777_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__5));
v___x_778_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_777_);
if (lean_obj_tag(v___x_778_) == 0)
{
lean_object* v___x_780_; uint8_t v_isShared_781_; uint8_t v_isSharedCheck_786_; 
v_isSharedCheck_786_ = !lean_is_exclusive(v___x_778_);
if (v_isSharedCheck_786_ == 0)
{
lean_object* v_unused_787_; 
v_unused_787_ = lean_ctor_get(v___x_778_, 0);
lean_dec(v_unused_787_);
v___x_780_ = v___x_778_;
v_isShared_781_ = v_isSharedCheck_786_;
goto v_resetjp_779_;
}
else
{
lean_dec(v___x_778_);
v___x_780_ = lean_box(0);
v_isShared_781_ = v_isSharedCheck_786_;
goto v_resetjp_779_;
}
v_resetjp_779_:
{
lean_object* v___x_782_; lean_object* v___x_784_; 
v___x_782_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_781_ == 0)
{
lean_ctor_set(v___x_780_, 0, v___x_782_);
v___x_784_ = v___x_780_;
goto v_reusejp_783_;
}
else
{
lean_object* v_reuseFailAlloc_785_; 
v_reuseFailAlloc_785_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_785_, 0, v___x_782_);
v___x_784_ = v_reuseFailAlloc_785_;
goto v_reusejp_783_;
}
v_reusejp_783_:
{
return v___x_784_;
}
}
}
else
{
lean_object* v_a_788_; lean_object* v___x_790_; uint8_t v_isShared_791_; uint8_t v_isSharedCheck_795_; 
v_a_788_ = lean_ctor_get(v___x_778_, 0);
v_isSharedCheck_795_ = !lean_is_exclusive(v___x_778_);
if (v_isSharedCheck_795_ == 0)
{
v___x_790_ = v___x_778_;
v_isShared_791_ = v_isSharedCheck_795_;
goto v_resetjp_789_;
}
else
{
lean_inc(v_a_788_);
lean_dec(v___x_778_);
v___x_790_ = lean_box(0);
v_isShared_791_ = v_isSharedCheck_795_;
goto v_resetjp_789_;
}
v_resetjp_789_:
{
lean_object* v___x_793_; 
if (v_isShared_791_ == 0)
{
v___x_793_ = v___x_790_;
goto v_reusejp_792_;
}
else
{
lean_object* v_reuseFailAlloc_794_; 
v_reuseFailAlloc_794_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_794_, 0, v_a_788_);
v___x_793_ = v_reuseFailAlloc_794_;
goto v_reusejp_792_;
}
v_reusejp_792_:
{
return v___x_793_;
}
}
}
}
else
{
lean_object* v_val_796_; lean_object* v___x_797_; lean_object* v___x_798_; lean_object* v___x_799_; lean_object* v___x_800_; lean_object* v___x_801_; lean_object* v___x_802_; lean_object* v___x_803_; 
v_val_796_ = lean_ctor_get(v___x_776_, 0);
lean_inc(v_val_796_);
lean_dec_ref_known(v___x_776_, 1);
v___x_797_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__6));
v___x_798_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__7));
v___x_799_ = lean_int_neg(v_val_754_);
lean_inc(v_a_707_);
v___x_800_ = lp_loam_Loam_Core_Effect_ofQuantity(v___x_797_, v_a_707_, v___x_798_, v___x_799_);
v___x_801_ = lean_box(0);
v___x_802_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v___x_802_, 0, v___x_800_);
lean_ctor_set(v___x_802_, 1, v___x_801_);
v___x_803_ = lp_loam_Loam_Core_Event_ofEffects_x3f(v_val_796_, v___x_802_);
if (lean_obj_tag(v___x_803_) == 0)
{
lean_object* v___x_804_; lean_object* v___x_805_; 
lean_dec(v_val_754_);
lean_dec(v_a_707_);
lean_dec(v_val_704_);
lean_dec_ref(v_memoryPath_681_);
v___x_804_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__8));
v___x_805_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_804_);
if (lean_obj_tag(v___x_805_) == 0)
{
lean_object* v___x_807_; uint8_t v_isShared_808_; uint8_t v_isSharedCheck_813_; 
v_isSharedCheck_813_ = !lean_is_exclusive(v___x_805_);
if (v_isSharedCheck_813_ == 0)
{
lean_object* v_unused_814_; 
v_unused_814_ = lean_ctor_get(v___x_805_, 0);
lean_dec(v_unused_814_);
v___x_807_ = v___x_805_;
v_isShared_808_ = v_isSharedCheck_813_;
goto v_resetjp_806_;
}
else
{
lean_dec(v___x_805_);
v___x_807_ = lean_box(0);
v_isShared_808_ = v_isSharedCheck_813_;
goto v_resetjp_806_;
}
v_resetjp_806_:
{
lean_object* v___x_809_; lean_object* v___x_811_; 
v___x_809_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_808_ == 0)
{
lean_ctor_set(v___x_807_, 0, v___x_809_);
v___x_811_ = v___x_807_;
goto v_reusejp_810_;
}
else
{
lean_object* v_reuseFailAlloc_812_; 
v_reuseFailAlloc_812_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_812_, 0, v___x_809_);
v___x_811_ = v_reuseFailAlloc_812_;
goto v_reusejp_810_;
}
v_reusejp_810_:
{
return v___x_811_;
}
}
}
else
{
lean_object* v_a_815_; lean_object* v___x_817_; uint8_t v_isShared_818_; uint8_t v_isSharedCheck_822_; 
v_a_815_ = lean_ctor_get(v___x_805_, 0);
v_isSharedCheck_822_ = !lean_is_exclusive(v___x_805_);
if (v_isSharedCheck_822_ == 0)
{
v___x_817_ = v___x_805_;
v_isShared_818_ = v_isSharedCheck_822_;
goto v_resetjp_816_;
}
else
{
lean_inc(v_a_815_);
lean_dec(v___x_805_);
v___x_817_ = lean_box(0);
v_isShared_818_ = v_isSharedCheck_822_;
goto v_resetjp_816_;
}
v_resetjp_816_:
{
lean_object* v___x_820_; 
if (v_isShared_818_ == 0)
{
v___x_820_ = v___x_817_;
goto v_reusejp_819_;
}
else
{
lean_object* v_reuseFailAlloc_821_; 
v_reuseFailAlloc_821_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_821_, 0, v_a_815_);
v___x_820_ = v_reuseFailAlloc_821_;
goto v_reusejp_819_;
}
v_reusejp_819_:
{
return v___x_820_;
}
}
}
}
else
{
lean_object* v_val_823_; lean_object* v___x_824_; 
v_val_823_ = lean_ctor_get(v___x_803_, 0);
lean_inc(v_val_823_);
lean_dec_ref_known(v___x_803_, 1);
v___x_824_ = lp_loam_Loam_Core_EventMemory_add_x3f(v_val_704_, v_val_823_);
if (lean_obj_tag(v___x_824_) == 0)
{
lean_object* v___x_825_; lean_object* v___x_826_; 
lean_dec(v_val_754_);
lean_dec(v_a_707_);
lean_dec_ref(v_memoryPath_681_);
v___x_825_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__9));
v___x_826_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_825_);
if (lean_obj_tag(v___x_826_) == 0)
{
lean_object* v___x_828_; uint8_t v_isShared_829_; uint8_t v_isSharedCheck_834_; 
v_isSharedCheck_834_ = !lean_is_exclusive(v___x_826_);
if (v_isSharedCheck_834_ == 0)
{
lean_object* v_unused_835_; 
v_unused_835_ = lean_ctor_get(v___x_826_, 0);
lean_dec(v_unused_835_);
v___x_828_ = v___x_826_;
v_isShared_829_ = v_isSharedCheck_834_;
goto v_resetjp_827_;
}
else
{
lean_dec(v___x_826_);
v___x_828_ = lean_box(0);
v_isShared_829_ = v_isSharedCheck_834_;
goto v_resetjp_827_;
}
v_resetjp_827_:
{
lean_object* v___x_830_; lean_object* v___x_832_; 
v___x_830_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_829_ == 0)
{
lean_ctor_set(v___x_828_, 0, v___x_830_);
v___x_832_ = v___x_828_;
goto v_reusejp_831_;
}
else
{
lean_object* v_reuseFailAlloc_833_; 
v_reuseFailAlloc_833_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_833_, 0, v___x_830_);
v___x_832_ = v_reuseFailAlloc_833_;
goto v_reusejp_831_;
}
v_reusejp_831_:
{
return v___x_832_;
}
}
}
else
{
lean_object* v_a_836_; lean_object* v___x_838_; uint8_t v_isShared_839_; uint8_t v_isSharedCheck_843_; 
v_a_836_ = lean_ctor_get(v___x_826_, 0);
v_isSharedCheck_843_ = !lean_is_exclusive(v___x_826_);
if (v_isSharedCheck_843_ == 0)
{
v___x_838_ = v___x_826_;
v_isShared_839_ = v_isSharedCheck_843_;
goto v_resetjp_837_;
}
else
{
lean_inc(v_a_836_);
lean_dec(v___x_826_);
v___x_838_ = lean_box(0);
v_isShared_839_ = v_isSharedCheck_843_;
goto v_resetjp_837_;
}
v_resetjp_837_:
{
lean_object* v___x_841_; 
if (v_isShared_839_ == 0)
{
v___x_841_ = v___x_838_;
goto v_reusejp_840_;
}
else
{
lean_object* v_reuseFailAlloc_842_; 
v_reuseFailAlloc_842_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_842_, 0, v_a_836_);
v___x_841_ = v_reuseFailAlloc_842_;
goto v_reusejp_840_;
}
v_reusejp_840_:
{
return v___x_841_;
}
}
}
}
else
{
lean_object* v_val_844_; lean_object* v___x_845_; 
v_val_844_ = lean_ctor_get(v___x_824_, 0);
lean_inc(v_val_844_);
lean_dec_ref_known(v___x_824_, 1);
v___x_845_ = lp_loam_Loam_Persistence_saveEventMemory_x3f(v_memoryPath_681_, v_val_844_);
if (lean_obj_tag(v___x_845_) == 0)
{
lean_object* v_a_846_; uint8_t v___x_847_; 
v_a_846_ = lean_ctor_get(v___x_845_, 0);
lean_inc(v_a_846_);
lean_dec_ref_known(v___x_845_, 1);
v___x_847_ = lean_unbox(v_a_846_);
lean_dec(v_a_846_);
if (v___x_847_ == 0)
{
lean_object* v___x_848_; lean_object* v___x_849_; 
lean_dec(v_val_754_);
lean_dec(v_a_707_);
v___x_848_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__10));
v___x_849_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_848_);
if (lean_obj_tag(v___x_849_) == 0)
{
lean_object* v___x_851_; uint8_t v_isShared_852_; uint8_t v_isSharedCheck_857_; 
v_isSharedCheck_857_ = !lean_is_exclusive(v___x_849_);
if (v_isSharedCheck_857_ == 0)
{
lean_object* v_unused_858_; 
v_unused_858_ = lean_ctor_get(v___x_849_, 0);
lean_dec(v_unused_858_);
v___x_851_ = v___x_849_;
v_isShared_852_ = v_isSharedCheck_857_;
goto v_resetjp_850_;
}
else
{
lean_dec(v___x_849_);
v___x_851_ = lean_box(0);
v_isShared_852_ = v_isSharedCheck_857_;
goto v_resetjp_850_;
}
v_resetjp_850_:
{
lean_object* v___x_853_; lean_object* v___x_855_; 
v___x_853_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_852_ == 0)
{
lean_ctor_set(v___x_851_, 0, v___x_853_);
v___x_855_ = v___x_851_;
goto v_reusejp_854_;
}
else
{
lean_object* v_reuseFailAlloc_856_; 
v_reuseFailAlloc_856_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_856_, 0, v___x_853_);
v___x_855_ = v_reuseFailAlloc_856_;
goto v_reusejp_854_;
}
v_reusejp_854_:
{
return v___x_855_;
}
}
}
else
{
lean_object* v_a_859_; lean_object* v___x_861_; uint8_t v_isShared_862_; uint8_t v_isSharedCheck_866_; 
v_a_859_ = lean_ctor_get(v___x_849_, 0);
v_isSharedCheck_866_ = !lean_is_exclusive(v___x_849_);
if (v_isSharedCheck_866_ == 0)
{
v___x_861_ = v___x_849_;
v_isShared_862_ = v_isSharedCheck_866_;
goto v_resetjp_860_;
}
else
{
lean_inc(v_a_859_);
lean_dec(v___x_849_);
v___x_861_ = lean_box(0);
v_isShared_862_ = v_isSharedCheck_866_;
goto v_resetjp_860_;
}
v_resetjp_860_:
{
lean_object* v___x_864_; 
if (v_isShared_862_ == 0)
{
v___x_864_ = v___x_861_;
goto v_reusejp_863_;
}
else
{
lean_object* v_reuseFailAlloc_865_; 
v_reuseFailAlloc_865_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_865_, 0, v_a_859_);
v___x_864_ = v_reuseFailAlloc_865_;
goto v_reusejp_863_;
}
v_reusejp_863_:
{
return v___x_864_;
}
}
}
}
else
{
lean_object* v___x_867_; lean_object* v___x_868_; lean_object* v___x_869_; lean_object* v___x_870_; lean_object* v___x_871_; lean_object* v___x_872_; lean_object* v___x_873_; lean_object* v___x_874_; lean_object* v___x_875_; 
v___x_867_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__11));
v___x_868_ = l_Int_repr(v_val_754_);
lean_dec(v_val_754_);
v___x_869_ = lean_string_append(v___x_867_, v___x_868_);
lean_dec_ref(v___x_868_);
v___x_870_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__12));
v___x_871_ = lean_string_append(v___x_869_, v___x_870_);
v___x_872_ = lean_string_append(v___x_871_, v_a_707_);
lean_dec(v_a_707_);
v___x_873_ = ((lean_object*)(lp_loam_Loam_Cli_spendJpy___closed__13));
v___x_874_ = lean_string_append(v___x_872_, v___x_873_);
v___x_875_ = lp_loam_IO_println___at___00Loam_Cli_showAmount_spec__0(v___x_874_);
if (lean_obj_tag(v___x_875_) == 0)
{
lean_object* v___x_877_; uint8_t v_isShared_878_; uint8_t v_isSharedCheck_883_; 
v_isSharedCheck_883_ = !lean_is_exclusive(v___x_875_);
if (v_isSharedCheck_883_ == 0)
{
lean_object* v_unused_884_; 
v_unused_884_ = lean_ctor_get(v___x_875_, 0);
lean_dec(v_unused_884_);
v___x_877_ = v___x_875_;
v_isShared_878_ = v_isSharedCheck_883_;
goto v_resetjp_876_;
}
else
{
lean_dec(v___x_875_);
v___x_877_ = lean_box(0);
v_isShared_878_ = v_isSharedCheck_883_;
goto v_resetjp_876_;
}
v_resetjp_876_:
{
lean_object* v___x_879_; lean_object* v___x_881_; 
v___x_879_ = lp_loam_Loam_Cli_showAmount___boxed__const__2;
if (v_isShared_878_ == 0)
{
lean_ctor_set(v___x_877_, 0, v___x_879_);
v___x_881_ = v___x_877_;
goto v_reusejp_880_;
}
else
{
lean_object* v_reuseFailAlloc_882_; 
v_reuseFailAlloc_882_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_882_, 0, v___x_879_);
v___x_881_ = v_reuseFailAlloc_882_;
goto v_reusejp_880_;
}
v_reusejp_880_:
{
return v___x_881_;
}
}
}
else
{
lean_object* v_a_885_; lean_object* v___x_887_; uint8_t v_isShared_888_; uint8_t v_isSharedCheck_892_; 
v_a_885_ = lean_ctor_get(v___x_875_, 0);
v_isSharedCheck_892_ = !lean_is_exclusive(v___x_875_);
if (v_isSharedCheck_892_ == 0)
{
v___x_887_ = v___x_875_;
v_isShared_888_ = v_isSharedCheck_892_;
goto v_resetjp_886_;
}
else
{
lean_inc(v_a_885_);
lean_dec(v___x_875_);
v___x_887_ = lean_box(0);
v_isShared_888_ = v_isSharedCheck_892_;
goto v_resetjp_886_;
}
v_resetjp_886_:
{
lean_object* v___x_890_; 
if (v_isShared_888_ == 0)
{
v___x_890_ = v___x_887_;
goto v_reusejp_889_;
}
else
{
lean_object* v_reuseFailAlloc_891_; 
v_reuseFailAlloc_891_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_891_, 0, v_a_885_);
v___x_890_ = v_reuseFailAlloc_891_;
goto v_reusejp_889_;
}
v_reusejp_889_:
{
return v___x_890_;
}
}
}
}
}
else
{
lean_object* v_a_893_; lean_object* v___x_895_; uint8_t v_isShared_896_; uint8_t v_isSharedCheck_900_; 
lean_dec(v_val_754_);
lean_dec(v_a_707_);
v_a_893_ = lean_ctor_get(v___x_845_, 0);
v_isSharedCheck_900_ = !lean_is_exclusive(v___x_845_);
if (v_isSharedCheck_900_ == 0)
{
v___x_895_ = v___x_845_;
v_isShared_896_ = v_isSharedCheck_900_;
goto v_resetjp_894_;
}
else
{
lean_inc(v_a_893_);
lean_dec(v___x_845_);
v___x_895_ = lean_box(0);
v_isShared_896_ = v_isSharedCheck_900_;
goto v_resetjp_894_;
}
v_resetjp_894_:
{
lean_object* v___x_898_; 
if (v_isShared_896_ == 0)
{
v___x_898_ = v___x_895_;
goto v_reusejp_897_;
}
else
{
lean_object* v_reuseFailAlloc_899_; 
v_reuseFailAlloc_899_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_899_, 0, v_a_893_);
v___x_898_ = v_reuseFailAlloc_899_;
goto v_reusejp_897_;
}
v_reusejp_897_:
{
return v___x_898_;
}
}
}
}
}
}
}
}
}
else
{
lean_object* v_a_901_; lean_object* v___x_903_; uint8_t v_isShared_904_; uint8_t v_isSharedCheck_908_; 
lean_dec(v_a_707_);
lean_dec(v_val_704_);
lean_dec_ref(v_memoryPath_681_);
v_a_901_ = lean_ctor_get(v___x_729_, 0);
v_isSharedCheck_908_ = !lean_is_exclusive(v___x_729_);
if (v_isSharedCheck_908_ == 0)
{
v___x_903_ = v___x_729_;
v_isShared_904_ = v_isSharedCheck_908_;
goto v_resetjp_902_;
}
else
{
lean_inc(v_a_901_);
lean_dec(v___x_729_);
v___x_903_ = lean_box(0);
v_isShared_904_ = v_isSharedCheck_908_;
goto v_resetjp_902_;
}
v_resetjp_902_:
{
lean_object* v___x_906_; 
if (v_isShared_904_ == 0)
{
v___x_906_ = v___x_903_;
goto v_reusejp_905_;
}
else
{
lean_object* v_reuseFailAlloc_907_; 
v_reuseFailAlloc_907_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_907_, 0, v_a_901_);
v___x_906_ = v_reuseFailAlloc_907_;
goto v_reusejp_905_;
}
v_reusejp_905_:
{
return v___x_906_;
}
}
}
}
}
else
{
lean_object* v_a_909_; lean_object* v___x_911_; uint8_t v_isShared_912_; uint8_t v_isSharedCheck_916_; 
lean_dec(v_val_704_);
lean_dec_ref(v_memoryPath_681_);
v_a_909_ = lean_ctor_get(v___x_706_, 0);
v_isSharedCheck_916_ = !lean_is_exclusive(v___x_706_);
if (v_isSharedCheck_916_ == 0)
{
v___x_911_ = v___x_706_;
v_isShared_912_ = v_isSharedCheck_916_;
goto v_resetjp_910_;
}
else
{
lean_inc(v_a_909_);
lean_dec(v___x_706_);
v___x_911_ = lean_box(0);
v_isShared_912_ = v_isSharedCheck_916_;
goto v_resetjp_910_;
}
v_resetjp_910_:
{
lean_object* v___x_914_; 
if (v_isShared_912_ == 0)
{
v___x_914_ = v___x_911_;
goto v_reusejp_913_;
}
else
{
lean_object* v_reuseFailAlloc_915_; 
v_reuseFailAlloc_915_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_915_, 0, v_a_909_);
v___x_914_ = v_reuseFailAlloc_915_;
goto v_reusejp_913_;
}
v_reusejp_913_:
{
return v___x_914_;
}
}
}
}
}
else
{
lean_object* v_a_917_; lean_object* v___x_919_; uint8_t v_isShared_920_; uint8_t v_isSharedCheck_924_; 
lean_dec_ref(v_memoryPath_681_);
v_a_917_ = lean_ctor_get(v___x_683_, 0);
v_isSharedCheck_924_ = !lean_is_exclusive(v___x_683_);
if (v_isSharedCheck_924_ == 0)
{
v___x_919_ = v___x_683_;
v_isShared_920_ = v_isSharedCheck_924_;
goto v_resetjp_918_;
}
else
{
lean_inc(v_a_917_);
lean_dec(v___x_683_);
v___x_919_ = lean_box(0);
v_isShared_920_ = v_isSharedCheck_924_;
goto v_resetjp_918_;
}
v_resetjp_918_:
{
lean_object* v___x_922_; 
if (v_isShared_920_ == 0)
{
v___x_922_ = v___x_919_;
goto v_reusejp_921_;
}
else
{
lean_object* v_reuseFailAlloc_923_; 
v_reuseFailAlloc_923_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_923_, 0, v_a_917_);
v___x_922_ = v_reuseFailAlloc_923_;
goto v_reusejp_921_;
}
v_reusejp_921_:
{
return v___x_922_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_spendJpy___boxed(lean_object* v_memoryPath_925_, lean_object* v_a_926_){
_start:
{
lean_object* v_res_927_; 
v_res_927_ = lp_loam_Loam_Cli_spendJpy(v_memoryPath_925_);
return v_res_927_;
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_run(lean_object* v_args_937_){
_start:
{
if (lean_obj_tag(v_args_937_) == 1)
{
lean_object* v_head_959_; lean_object* v_tail_960_; lean_object* v___x_961_; uint8_t v___x_962_; 
v_head_959_ = lean_ctor_get(v_args_937_, 0);
lean_inc(v_head_959_);
v_tail_960_ = lean_ctor_get(v_args_937_, 1);
lean_inc(v_tail_960_);
lean_dec_ref_known(v_args_937_, 2);
v___x_961_ = ((lean_object*)(lp_loam_Loam_Cli_run___closed__0));
v___x_962_ = lean_string_dec_eq(v_head_959_, v___x_961_);
if (v___x_962_ == 0)
{
lean_object* v___x_963_; uint8_t v___x_964_; 
v___x_963_ = ((lean_object*)(lp_loam_Loam_Cli_run___closed__1));
v___x_964_ = lean_string_dec_eq(v_head_959_, v___x_963_);
if (v___x_964_ == 0)
{
lean_object* v___x_965_; uint8_t v___x_966_; 
v___x_965_ = ((lean_object*)(lp_loam_Loam_Cli_run___closed__2));
v___x_966_ = lean_string_dec_eq(v_head_959_, v___x_965_);
if (v___x_966_ == 0)
{
lean_object* v___x_967_; uint8_t v___x_968_; 
v___x_967_ = ((lean_object*)(lp_loam_Loam_Cli_run___closed__3));
v___x_968_ = lean_string_dec_eq(v_head_959_, v___x_967_);
lean_dec(v_head_959_);
if (v___x_968_ == 0)
{
lean_dec(v_tail_960_);
goto v___jp_939_;
}
else
{
if (lean_obj_tag(v_tail_960_) == 1)
{
lean_object* v_head_969_; lean_object* v_tail_970_; lean_object* v___x_971_; uint8_t v___x_972_; 
v_head_969_ = lean_ctor_get(v_tail_960_, 0);
lean_inc(v_head_969_);
v_tail_970_ = lean_ctor_get(v_tail_960_, 1);
lean_inc(v_tail_970_);
lean_dec_ref_known(v_tail_960_, 2);
v___x_971_ = ((lean_object*)(lp_loam_Loam_Cli_run___closed__4));
v___x_972_ = lean_string_dec_eq(v_head_969_, v___x_971_);
if (v___x_972_ == 0)
{
lean_object* v___x_973_; uint8_t v___x_974_; 
v___x_973_ = ((lean_object*)(lp_loam_Loam_Cli_run___closed__5));
v___x_974_ = lean_string_dec_eq(v_head_969_, v___x_973_);
if (v___x_974_ == 0)
{
lean_object* v___x_975_; uint8_t v___x_976_; 
v___x_975_ = ((lean_object*)(lp_loam_Loam_Cli_run___closed__6));
v___x_976_ = lean_string_dec_eq(v_head_969_, v___x_975_);
lean_dec(v_head_969_);
if (v___x_976_ == 0)
{
lean_dec(v_tail_970_);
goto v___jp_939_;
}
else
{
if (lean_obj_tag(v_tail_970_) == 1)
{
lean_object* v_tail_977_; 
v_tail_977_ = lean_ctor_get(v_tail_970_, 1);
lean_inc(v_tail_977_);
if (lean_obj_tag(v_tail_977_) == 1)
{
lean_object* v_tail_978_; 
v_tail_978_ = lean_ctor_get(v_tail_977_, 1);
if (lean_obj_tag(v_tail_978_) == 0)
{
lean_object* v_head_979_; lean_object* v_head_980_; lean_object* v___x_981_; 
v_head_979_ = lean_ctor_get(v_tail_970_, 0);
lean_inc(v_head_979_);
lean_dec_ref_known(v_tail_970_, 2);
v_head_980_ = lean_ctor_get(v_tail_977_, 0);
lean_inc(v_head_980_);
lean_dec_ref_known(v_tail_977_, 2);
v___x_981_ = lp_loam_Loam_Cli_addRememberedEvent(v_head_979_, v_head_980_);
lean_dec(v_head_980_);
return v___x_981_;
}
else
{
lean_dec_ref_known(v_tail_977_, 2);
lean_dec_ref_known(v_tail_970_, 2);
goto v___jp_939_;
}
}
else
{
lean_dec_ref_known(v_tail_970_, 2);
lean_dec(v_tail_977_);
goto v___jp_939_;
}
}
else
{
lean_dec(v_tail_970_);
goto v___jp_939_;
}
}
}
else
{
lean_dec(v_head_969_);
if (lean_obj_tag(v_tail_970_) == 1)
{
lean_object* v_tail_982_; 
v_tail_982_ = lean_ctor_get(v_tail_970_, 1);
lean_inc(v_tail_982_);
if (lean_obj_tag(v_tail_982_) == 1)
{
lean_object* v_tail_983_; 
v_tail_983_ = lean_ctor_get(v_tail_982_, 1);
lean_inc(v_tail_983_);
if (lean_obj_tag(v_tail_983_) == 1)
{
lean_object* v_tail_984_; 
v_tail_984_ = lean_ctor_get(v_tail_983_, 1);
if (lean_obj_tag(v_tail_984_) == 0)
{
lean_object* v_head_985_; lean_object* v_head_986_; lean_object* v_head_987_; lean_object* v___x_988_; 
v_head_985_ = lean_ctor_get(v_tail_970_, 0);
lean_inc(v_head_985_);
lean_dec_ref_known(v_tail_970_, 2);
v_head_986_ = lean_ctor_get(v_tail_982_, 0);
lean_inc(v_head_986_);
lean_dec_ref_known(v_tail_982_, 2);
v_head_987_ = lean_ctor_get(v_tail_983_, 0);
lean_inc(v_head_987_);
lean_dec_ref_known(v_tail_983_, 2);
v___x_988_ = lp_loam_Loam_Cli_showRememberedQuantity(v_head_985_, v_head_986_, v_head_987_);
lean_dec(v_head_985_);
return v___x_988_;
}
else
{
lean_dec_ref_known(v_tail_983_, 2);
lean_dec_ref_known(v_tail_982_, 2);
lean_dec_ref_known(v_tail_970_, 2);
goto v___jp_939_;
}
}
else
{
lean_dec(v_tail_983_);
lean_dec_ref_known(v_tail_982_, 2);
lean_dec_ref_known(v_tail_970_, 2);
goto v___jp_939_;
}
}
else
{
lean_dec_ref_known(v_tail_970_, 2);
lean_dec(v_tail_982_);
goto v___jp_939_;
}
}
else
{
lean_dec(v_tail_970_);
goto v___jp_939_;
}
}
}
else
{
lean_dec(v_head_969_);
if (lean_obj_tag(v_tail_970_) == 1)
{
lean_object* v_tail_989_; 
v_tail_989_ = lean_ctor_get(v_tail_970_, 1);
lean_inc(v_tail_989_);
if (lean_obj_tag(v_tail_989_) == 1)
{
lean_object* v_tail_990_; 
v_tail_990_ = lean_ctor_get(v_tail_989_, 1);
if (lean_obj_tag(v_tail_990_) == 0)
{
lean_object* v_head_991_; lean_object* v_head_992_; lean_object* v___x_993_; 
v_head_991_ = lean_ctor_get(v_tail_970_, 0);
lean_inc(v_head_991_);
lean_dec_ref_known(v_tail_970_, 2);
v_head_992_ = lean_ctor_get(v_tail_989_, 0);
lean_inc(v_head_992_);
lean_dec_ref_known(v_tail_989_, 2);
v___x_993_ = lp_loam_Loam_Cli_showRememberedEvent(v_head_991_, v_head_992_);
lean_dec(v_head_992_);
lean_dec(v_head_991_);
return v___x_993_;
}
else
{
lean_dec_ref_known(v_tail_989_, 2);
lean_dec_ref_known(v_tail_970_, 2);
goto v___jp_939_;
}
}
else
{
lean_dec_ref_known(v_tail_970_, 2);
lean_dec(v_tail_989_);
goto v___jp_939_;
}
}
else
{
lean_dec(v_tail_970_);
goto v___jp_939_;
}
}
}
else
{
lean_dec(v_tail_960_);
goto v___jp_939_;
}
}
}
else
{
lean_dec(v_head_959_);
if (lean_obj_tag(v_tail_960_) == 1)
{
lean_object* v_head_994_; lean_object* v_tail_995_; lean_object* v___x_996_; uint8_t v___x_997_; 
v_head_994_ = lean_ctor_get(v_tail_960_, 0);
lean_inc(v_head_994_);
v_tail_995_ = lean_ctor_get(v_tail_960_, 1);
lean_inc(v_tail_995_);
lean_dec_ref_known(v_tail_960_, 2);
v___x_996_ = ((lean_object*)(lp_loam_Loam_Cli_run___closed__7));
v___x_997_ = lean_string_dec_eq(v_head_994_, v___x_996_);
if (v___x_997_ == 0)
{
lean_object* v___x_998_; uint8_t v___x_999_; 
v___x_998_ = ((lean_object*)(lp_loam_Loam_Cli_run___closed__5));
v___x_999_ = lean_string_dec_eq(v_head_994_, v___x_998_);
lean_dec(v_head_994_);
if (v___x_999_ == 0)
{
lean_dec(v_tail_995_);
goto v___jp_939_;
}
else
{
if (lean_obj_tag(v_tail_995_) == 1)
{
lean_object* v_tail_1000_; 
v_tail_1000_ = lean_ctor_get(v_tail_995_, 1);
lean_inc(v_tail_1000_);
if (lean_obj_tag(v_tail_1000_) == 1)
{
lean_object* v_tail_1001_; 
v_tail_1001_ = lean_ctor_get(v_tail_1000_, 1);
lean_inc(v_tail_1001_);
if (lean_obj_tag(v_tail_1001_) == 1)
{
lean_object* v_tail_1002_; 
v_tail_1002_ = lean_ctor_get(v_tail_1001_, 1);
if (lean_obj_tag(v_tail_1002_) == 0)
{
lean_object* v_head_1003_; lean_object* v_head_1004_; lean_object* v_head_1005_; lean_object* v___x_1006_; 
v_head_1003_ = lean_ctor_get(v_tail_995_, 0);
lean_inc(v_head_1003_);
lean_dec_ref_known(v_tail_995_, 2);
v_head_1004_ = lean_ctor_get(v_tail_1000_, 0);
lean_inc(v_head_1004_);
lean_dec_ref_known(v_tail_1000_, 2);
v_head_1005_ = lean_ctor_get(v_tail_1001_, 0);
lean_inc(v_head_1005_);
lean_dec_ref_known(v_tail_1001_, 2);
v___x_1006_ = lp_loam_Loam_Cli_showEventQuantity(v_head_1003_, v_head_1004_, v_head_1005_);
lean_dec(v_head_1003_);
return v___x_1006_;
}
else
{
lean_dec_ref_known(v_tail_1001_, 2);
lean_dec_ref_known(v_tail_1000_, 2);
lean_dec_ref_known(v_tail_995_, 2);
goto v___jp_939_;
}
}
else
{
lean_dec(v_tail_1001_);
lean_dec_ref_known(v_tail_1000_, 2);
lean_dec_ref_known(v_tail_995_, 2);
goto v___jp_939_;
}
}
else
{
lean_dec(v_tail_1000_);
lean_dec_ref_known(v_tail_995_, 2);
goto v___jp_939_;
}
}
else
{
lean_dec(v_tail_995_);
goto v___jp_939_;
}
}
}
else
{
lean_dec(v_head_994_);
if (lean_obj_tag(v_tail_995_) == 1)
{
lean_object* v_tail_1007_; 
v_tail_1007_ = lean_ctor_get(v_tail_995_, 1);
lean_inc(v_tail_1007_);
if (lean_obj_tag(v_tail_1007_) == 1)
{
lean_object* v_head_1008_; lean_object* v_head_1009_; lean_object* v_tail_1010_; lean_object* v___x_1011_; 
v_head_1008_ = lean_ctor_get(v_tail_995_, 0);
lean_inc(v_head_1008_);
lean_dec_ref_known(v_tail_995_, 2);
v_head_1009_ = lean_ctor_get(v_tail_1007_, 0);
lean_inc(v_head_1009_);
v_tail_1010_ = lean_ctor_get(v_tail_1007_, 1);
lean_inc(v_tail_1010_);
lean_dec_ref_known(v_tail_1007_, 2);
v___x_1011_ = lp_loam_Loam_Cli_createEvent(v_head_1008_, v_head_1009_, v_tail_1010_);
lean_dec(v_head_1008_);
return v___x_1011_;
}
else
{
lean_dec(v_tail_1007_);
lean_dec_ref_known(v_tail_995_, 2);
goto v___jp_939_;
}
}
else
{
lean_dec(v_tail_995_);
goto v___jp_939_;
}
}
}
else
{
lean_dec(v_tail_960_);
goto v___jp_939_;
}
}
}
else
{
lean_dec(v_head_959_);
if (lean_obj_tag(v_tail_960_) == 1)
{
lean_object* v_head_1012_; lean_object* v_tail_1013_; lean_object* v___x_1014_; uint8_t v___x_1015_; 
v_head_1012_ = lean_ctor_get(v_tail_960_, 0);
lean_inc(v_head_1012_);
v_tail_1013_ = lean_ctor_get(v_tail_960_, 1);
lean_inc(v_tail_1013_);
lean_dec_ref_known(v_tail_960_, 2);
v___x_1014_ = ((lean_object*)(lp_loam_Loam_Cli_run___closed__8));
v___x_1015_ = lean_string_dec_eq(v_head_1012_, v___x_1014_);
lean_dec(v_head_1012_);
if (v___x_1015_ == 0)
{
lean_dec(v_tail_1013_);
goto v___jp_939_;
}
else
{
if (lean_obj_tag(v_tail_1013_) == 1)
{
lean_object* v_tail_1016_; 
v_tail_1016_ = lean_ctor_get(v_tail_1013_, 1);
if (lean_obj_tag(v_tail_1016_) == 0)
{
lean_object* v_head_1017_; lean_object* v___x_1018_; 
v_head_1017_ = lean_ctor_get(v_tail_1013_, 0);
lean_inc(v_head_1017_);
lean_dec_ref_known(v_tail_1013_, 2);
v___x_1018_ = lp_loam_Loam_Cli_showAmount(v_head_1017_);
lean_dec(v_head_1017_);
return v___x_1018_;
}
else
{
lean_dec_ref_known(v_tail_1013_, 2);
goto v___jp_939_;
}
}
else
{
lean_dec(v_tail_1013_);
goto v___jp_939_;
}
}
}
else
{
lean_dec(v_tail_960_);
goto v___jp_939_;
}
}
}
else
{
lean_dec(v_head_959_);
if (lean_obj_tag(v_tail_960_) == 1)
{
lean_object* v_tail_1019_; 
v_tail_1019_ = lean_ctor_get(v_tail_960_, 1);
if (lean_obj_tag(v_tail_1019_) == 0)
{
lean_object* v_head_1020_; lean_object* v___x_1021_; 
v_head_1020_ = lean_ctor_get(v_tail_960_, 0);
lean_inc(v_head_1020_);
lean_dec_ref_known(v_tail_960_, 2);
v___x_1021_ = lp_loam_Loam_Cli_spendJpy(v_head_1020_);
return v___x_1021_;
}
else
{
lean_dec_ref_known(v_tail_960_, 2);
goto v___jp_939_;
}
}
else
{
lean_dec(v_tail_960_);
goto v___jp_939_;
}
}
}
else
{
lean_dec(v_args_937_);
goto v___jp_939_;
}
v___jp_939_:
{
lean_object* v___x_940_; lean_object* v___x_941_; 
v___x_940_ = ((lean_object*)(lp_loam___private_Loam_Cli_0__Loam_Cli_usage___closed__0));
v___x_941_ = l_IO_eprintln___at___00__private_Init_System_IO_0__IO_eprintlnAux_spec__0(v___x_940_);
if (lean_obj_tag(v___x_941_) == 0)
{
lean_object* v___x_943_; uint8_t v_isShared_944_; uint8_t v_isSharedCheck_949_; 
v_isSharedCheck_949_ = !lean_is_exclusive(v___x_941_);
if (v_isSharedCheck_949_ == 0)
{
lean_object* v_unused_950_; 
v_unused_950_ = lean_ctor_get(v___x_941_, 0);
lean_dec(v_unused_950_);
v___x_943_ = v___x_941_;
v_isShared_944_ = v_isSharedCheck_949_;
goto v_resetjp_942_;
}
else
{
lean_dec(v___x_941_);
v___x_943_ = lean_box(0);
v_isShared_944_ = v_isSharedCheck_949_;
goto v_resetjp_942_;
}
v_resetjp_942_:
{
lean_object* v___x_945_; lean_object* v___x_947_; 
v___x_945_ = lp_loam_Loam_Cli_showAmount___boxed__const__1;
if (v_isShared_944_ == 0)
{
lean_ctor_set(v___x_943_, 0, v___x_945_);
v___x_947_ = v___x_943_;
goto v_reusejp_946_;
}
else
{
lean_object* v_reuseFailAlloc_948_; 
v_reuseFailAlloc_948_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_948_, 0, v___x_945_);
v___x_947_ = v_reuseFailAlloc_948_;
goto v_reusejp_946_;
}
v_reusejp_946_:
{
return v___x_947_;
}
}
}
else
{
lean_object* v_a_951_; lean_object* v___x_953_; uint8_t v_isShared_954_; uint8_t v_isSharedCheck_958_; 
v_a_951_ = lean_ctor_get(v___x_941_, 0);
v_isSharedCheck_958_ = !lean_is_exclusive(v___x_941_);
if (v_isSharedCheck_958_ == 0)
{
v___x_953_ = v___x_941_;
v_isShared_954_ = v_isSharedCheck_958_;
goto v_resetjp_952_;
}
else
{
lean_inc(v_a_951_);
lean_dec(v___x_941_);
v___x_953_ = lean_box(0);
v_isShared_954_ = v_isSharedCheck_958_;
goto v_resetjp_952_;
}
v_resetjp_952_:
{
lean_object* v___x_956_; 
if (v_isShared_954_ == 0)
{
v___x_956_ = v___x_953_;
goto v_reusejp_955_;
}
else
{
lean_object* v_reuseFailAlloc_957_; 
v_reuseFailAlloc_957_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_957_, 0, v_a_951_);
v___x_956_ = v_reuseFailAlloc_957_;
goto v_reusejp_955_;
}
v_reusejp_955_:
{
return v___x_956_;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_loam_Loam_Cli_run___boxed(lean_object* v_args_1022_, lean_object* v_a_1023_){
_start:
{
lean_object* v_res_1024_; 
v_res_1024_ = lp_loam_Loam_Cli_run(v_args_1022_);
return v_res_1024_;
}
}
LEAN_EXPORT lean_object* _lean_main(lean_object* v_args_1025_){
_start:
{
lean_object* v___x_1027_; 
v___x_1027_ = lp_loam_Loam_Cli_run(v_args_1025_);
return v___x_1027_;
}
}
LEAN_EXPORT lean_object* lp_loam_main___boxed(lean_object* v_args_1028_, lean_object* v_a_1029_){
_start:
{
lean_object* v_res_1030_; 
v_res_1030_ = _lean_main(v_args_1028_);
return v_res_1030_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_loam_Loam_Persistence(uint8_t builtin);
lean_object* initialize_Std(uint8_t builtin);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_loam_Loam_Cli(uint8_t builtin) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_loam_Loam_Persistence(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_Std(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
lp_loam_Loam_Cli_showAmount___boxed__const__1 = _init_lp_loam_Loam_Cli_showAmount___boxed__const__1();
lean_mark_persistent(lp_loam_Loam_Cli_showAmount___boxed__const__1);
lp_loam_Loam_Cli_showAmount___boxed__const__2 = _init_lp_loam_Loam_Cli_showAmount___boxed__const__2();
lean_mark_persistent(lp_loam_Loam_Cli_showAmount___boxed__const__2);
lp_loam_Loam_Cli_showRememberedEvent___boxed__const__1 = _init_lp_loam_Loam_Cli_showRememberedEvent___boxed__const__1();
lean_mark_persistent(lp_loam_Loam_Cli_showRememberedEvent___boxed__const__1);
return lean_io_result_mk_ok(lean_box(0));
}
char ** lean_setup_args(int argc, char ** argv);
void lean_initialize_runtime_module();
#if defined(WIN32) || defined(_WIN32)
#include <windows.h>
#endif
lean_object* run_main(int argc, char ** argv) {
    lean_object* in = lean_box(0);
    int i = argc;
    while (i > 1) {
      lean_object* n;
      i--;
      n = lean_alloc_ctor(1,2,0); lean_ctor_set(n, 0, lean_mk_string(argv[i])); lean_ctor_set(n, 1, in);
      in = n;
    }
    return _lean_main(in);
}
int main(int argc, char ** argv) {
#if defined(WIN32) || defined(_WIN32)
  SetErrorMode(SEM_FAILCRITICALERRORS);
  SetConsoleOutputCP(CP_UTF8);
#endif
  lean_object* res;
  argv = lean_setup_args(argc, argv);
  lean_initialize_runtime_module();
  res = initialize_loam_Loam_Cli(1 /* builtin */);
  lean_io_mark_end_initialization();
  if (lean_io_result_is_ok(res)) {
    lean_dec_ref(res);
    lean_init_task_manager();
    res = lean_run_main(&run_main, argc, argv);
  }
  lean_finalize_task_manager();
  if (lean_io_result_is_ok(res)) {
    int ret = lean_unbox_uint32(lean_io_result_get_value(res));
    lean_dec_ref(res);
    return ret;
  } else {
    lean_io_result_show_error(res);
    lean_dec_ref(res);
    return 1;
  }
}
#ifdef __cplusplus
}
#endif
