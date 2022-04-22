(*
 *  czytacz2: dialogue format converter
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
open Trie

let path = "../../corpus/sharepoint/"
let filenames = [
  "Transkrypcje z nagrań dialogów z voicebotem_E1.txt";
  "Transkrypcje z nagrań dialogów z voicebotem_E2.txt";
  "Transkrypcje z nagrań dialogów z voicebotem_E3.txt";
  ]
  
type t = C of string | W of string | Name of string

let string_of_turn = function
    C s -> "C: " ^ s
  | W s -> "W: " ^ s
  | Name s -> "Name: " ^ s

let process_line s =
  if s = "" || s = " " then [] else
  if Xstring.check_prefix "[uwaga od badacza]" s then [] else 
  if Xstring.check_prefix "H: " s then [C (Xstring.cut_prefix "H: " s)] else
  if Xstring.check_prefix "K: " s then [C (Xstring.cut_prefix "K: " s)] else
  if Xstring.check_prefix "D: " s then [C (Xstring.cut_prefix "D: " s)] else
  if Xstring.check_prefix "V: " s then [W (Xstring.cut_prefix "V: " s)] else 
  if Xstring.check_prefix "Dialog" s then [Name s] else (
  print_endline s;
  [])
  
let rec split_texts name rev = function
    C s :: l -> split_texts name (C s :: rev) l
  | W s :: l -> split_texts name (W s :: rev) l
  | Name s :: l -> 
      if name = "" && rev = [] then split_texts s rev l else
      if name = "" || rev = [] then failwith "split_texts" else
      (name, List.rev rev) :: (split_texts s [] l)
  | [] ->
      if name = "" && rev = [] then [] else
      if name = "" || rev = [] then failwith "split_texts" else
      [name, List.rev rev]
  
let load_dialogi2 () = 
  List.flatten (Xlist.map filenames (fun filename ->
    let text = File.load_lines (path ^ filename) in
    let texts = List.flatten (Xlist.map text process_line) in
    split_texts "" [] texts(*
(*     print_endline name; *)
    (*name*)["",text]*)))

let rec split_into_turns rev = function
    [] -> List.rev rev
  | C c :: W w :: l -> split_into_turns (("",c) :: rev) (W w :: l)
  | W w :: C c :: W x :: l -> split_into_turns ((w,c) :: rev) (W x :: l)
  | [W w; C c] -> split_into_turns ((w,c) :: rev) []
  | [W w] -> split_into_turns ((w,"") :: rev) []
  | l -> print_endline "==========================================="; Xlist.iter l (fun s -> print_endline (string_of_turn s)); []
  
  
let frame_tree = ref Patterns.TokenTrie.empty
let frames_path = "../frames/data/wizard2/"

let get_table_names filename =
  Xlist.fold (File.load_lines filename) [] (fun l s ->
    if Xstring.check_prefix "include-lemmata=" s then
      let s = Xstring.cut_prefix "include-lemmata=" s in
      match Xstring.split ",pos2=fixed:" s with
        [t;_] -> t :: l
      | _ -> failwith ("get_table_names: " ^ s)
    else l)

let initialize () = 
  let paths_filenames = [frames_path, get_table_names (frames_path ^ "valence.dic")] in
  frame_tree := Patterns.TokenTrie.load_multipath paths_filenames;
  ()
  
let classify_segment s =
(*   print_endline ("classify_segment 1: " ^ s); *)
  let parsed = Patterns.TokenTrie.find !frame_tree s in
  let l = Xlist.fold parsed [] (fun l (tokens,prods) ->
    let prods = StringSet.to_list (StringSet.of_list prods) in
    let s = String.concat "" tokens in
    if s = "" || s = " " || s = "¶" then l else
    match prods with
      [] -> print_endline ("classify_segment 2: " ^ s); "X" :: l
    | [prod] -> (*print_endline ("classify_segment 4: " ^ prod ^ " " ^ s);*) prod :: l
    | prods -> print_endline ("classify_segment2 3: " ^ String.concat " " prods ^ " | " ^ s); (String.concat "|^" prods) :: l) in
  if l = [] then "" else List.hd l
(*   String.concat " " (List.rev l) *)
    
let _ = 
  initialize ();
  let dialogi = load_dialogi2 () in
  let turns = List.flatten (List.rev (Xlist.rev_map dialogi (fun (n,l) -> split_into_turns [] l))) in
  let turns = List.rev (Xlist.rev_map turns (fun (w,c) -> 
    (if w = "" then w else classify_segment w), c)) in
  Xlist.iter turns (fun (w,c) -> 
    let w = if w = "" then "empty" else w in
    Printf.printf "%s: %s\n" w c);
  ()
