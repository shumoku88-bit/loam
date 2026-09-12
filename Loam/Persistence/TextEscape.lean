namespace Loam.Persistence

set_option autoImplicit false

/-!
# Pure text escaping utilities for text-facing LOAM persistence
-/

/--
Escape text for single-line tab-separated persistence.
Escapes `\`, `\n`, `\r`, `\t`.
-/
def escapeText (s : String) : String :=
  s.foldl (fun acc c =>
    match c with
    | '\\' => acc ++ "\\\\"
    | '\n' => acc ++ "\\n"
    | '\r' => acc ++ "\\r"
    | '\t' => acc ++ "\\t"
    | other => acc.push other) ""

/--
Canonical EventDescription publication refuses U+FFFD because that character is
normally evidence that some earlier Unicode text was already lost. Ordinary
Unicode, spaces, semicolons, punctuation, and empty text remain admissible.
-/
def eventDescriptionTextAdmissible (text : String) : Bool :=
  !(text.toList.contains '\uFFFD')

/--
Decode escaped text.
Returns `none` if an unrecognized escape sequence or dangling trailing backslash is found.
-/
def unescapeText? (s : String) : Option String :=
  let rec loop (chars : List Char) (acc : String) : Option String :=
    match chars with
    | [] => some acc
    | '\\' :: next :: rest =>
        match next with
        | '\\' => loop rest (acc.push '\\')
        | 'n'  => loop rest (acc.push '\n')
        | 'r'  => loop rest (acc.push '\r')
        | 't'  => loop rest (acc.push '\t')
        | _    => none
    | '\\' :: [] => none
    | c :: rest => loop rest (acc.push c)
  loop s.toList ""

end Loam.Persistence
