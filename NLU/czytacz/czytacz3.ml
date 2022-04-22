(*
 *  czytacz3: dialogue format converter
 *  Copyright (C) 2022 SELIDOR - T. Puza, Ł. Wasilewski Sp.J.
 *
 *  This library is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *)
 
open Xstd 
 
let path = "../../corpus/dialogi3/"

type t = C of string | W of string

let string_of_turn = function
    C s -> "C: " ^ s
  | W s -> "W: " ^ s

let process_line s =
  if s = "" || s = " " then [] else
  if Xstring.check_prefix "K: " s then [C (Xstring.cut_prefix "K: " s)] else
  if Xstring.check_prefix "Klientka: " s then [C (Xstring.cut_prefix "Klientka: " s)] else
  if Xstring.check_prefix "Klient: " s then [C (Xstring.cut_prefix "Klient: " s)] else
  if Xstring.check_prefix "AR: " s then [W (Xstring.cut_prefix "AR: " s)] else 
  if Xstring.check_prefix "Asystent rezerwacji: " s then [W (Xstring.cut_prefix "Asystent rezerwacji: " s)] else (
  print_endline s;
  [])
  
let load_dialogi3 () = 
  Xlist.map (Array.to_list (Sys.readdir path)) (fun filename ->
    let text = File.load_lines (path ^ filename) in
    let name = 
      if Xstring.check_sufix "_transkrypcja.txt" filename then 
        Xstring.cut_sufix "_transkrypcja.txt" filename 
      else failwith "load_dialogi3" in
    let text = List.flatten (Xlist.map text process_line) in
(*     print_endline name; *)
    name,text)

let rec split_into_turns rev = function
    [] -> List.rev rev
  | C c :: W w :: l -> split_into_turns (("",c) :: rev) (W w :: l)
  | W w :: C c :: W x :: l -> split_into_turns ((w,c) :: rev) (W x :: l)
  | [W w; C c] -> split_into_turns ((w,c) :: rev) []
  | [W w] -> split_into_turns ((w,"") :: rev) []
  | l -> print_endline "==========================================="; Xlist.iter l (fun s -> print_endline (string_of_turn s)); []
  
open Trie
open SubsyntaxTypes 

module ENIAMtoken2 = struct

  type t = string
  
  let compare = compare
  
  let to_string s = s
  
  let simplify s = s
  
  let rec tokenize_rec rev = function
      [] -> List.rev rev
    | Token t :: l -> 
        let orth = Xunicode.lowercase_utf8_string t.orth in
        if orth = "" || orth = "?" || orth = "," || orth = "." || orth = ":" || orth = "„" || orth = "”" || orth = "..." || orth = "-" || orth = ";" || orth = "1" || orth = "2" || orth = "3" then tokenize_rec rev l else 
(*        if orth = "1" then tokenize_rec  ("jeden" :: rev) l else
        if orth = "2" then tokenize_rec  ("dwa" :: rev) l else*)
        tokenize_rec  (orth :: rev) l
    | Variant [] :: _ -> failwith "tokenize_rec 1"
    | Variant l0 :: l -> 
        let l1 = Xlist.fold l0 [] (fun l0 -> function 
            Token t -> Token t :: l0
          | Seq _ -> l0
          | Variant _ -> failwith "tokenize_rec 2") in
        if l1 = [] then tokenize_rec rev (List.hd l0 :: l) else tokenize_rec rev (List.hd l1 :: l)
    | t :: l -> prerr_endline ("tokenize_rec: " ^ SubsyntaxStringOf.string_of_tokens_simple t); tokenize_rec rev l
  
  let tokenize s = 
    let l = Xunicode.classified_chars_of_utf8_string s in
    let l = Tokenizer.tokenize l in
    let l = Patterns.normalize_tokens [] l in
    tokenize_rec [] l

end

module Token2Trie = Make(ENIAMtoken2)
    
let frame_tree = ref Token2Trie.empty
let frames_path = "../frames/data/wizard3/"

let get_table_names filename =
  Xlist.fold (File.load_lines filename) [] (fun l s ->
    if Xstring.check_prefix "include-lemmata=" s then
      let s = Xstring.cut_prefix "include-lemmata=" s in
      match Xstring.split ",pos2=fixed:" s with
        [t;_] -> t :: l
      | _ -> failwith ("get_table_names: " ^ s)
    else l)

let initialize () = 
  let frames_filenames = [frames_path, get_table_names (frames_path ^ "valence.dic")] in
  frame_tree := Token2Trie.load_multipath frames_filenames;
  ()
  
let classify_segment s =
(*   print_endline ("classify_segment 1: " ^ s); *)
  let parsed = Token2Trie.find !frame_tree s in
  let l = Xlist.fold parsed [] (fun l (tokens,prods) ->
    let prods = StringSet.to_list (StringSet.of_list prods) in
    let s = String.concat "" tokens in
    if s = "" || s = " " || s = "  " || s = "¶" then l else
    match prods with
      [] -> print_endline ("classify_segment 2: „" ^ s ^ "”"); "X" :: l
    | [prod] -> (*print_endline ("classify_segment 4: ⟨" ^ prod ^ "⟩ " ^ s);*) prod :: l
    | prods -> print_endline ("classify_segment 3: ⟨" ^ String.concat "⟩ ⟨" prods ^ "⟩ " ^ s); (String.concat "|^" prods) :: l) in
  if l = [] then "" else List.hd l
(*   String.concat " " (List.rev l) *)
  
let _ = 
  initialize ();
  let dialogi = load_dialogi3 () in
  let turns = List.flatten (List.rev (Xlist.rev_map dialogi (fun (n,l) -> split_into_turns [] l))) in
  let turns = List.rev (Xlist.rev_map turns (fun (w,c) -> 
    (if w = "" then w else classify_segment w), c)) in
  Xlist.iter turns (fun (w,c) -> 
    let w = if w = "" then "empty" else w in
    Printf.printf "%s: %s\n" w c);
  ()
