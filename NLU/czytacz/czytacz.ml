(*
 *  czytacz: dialogue format converter
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
 
open Xjson
open Trie
open Xstd

let dialogi1_filename = "../../corpus/dialogi1.json"
let dialogi2_filename = "../../corpus/dialogi2.json"

type t = C of string | W of string

let string_of_turn = function
    C s -> "C: " ^ s
  | W s -> "W: " ^ s

let rec get_json_core n t =
  if n = 0 then JString "........." else
  match t with
    JObject l -> JObject(List.rev (Xlist.rev_map l (fun (e,t) -> e, get_json_core (n-1) t)))
  | JArray (a :: b :: c :: _ :: _) -> get_json_core n (JArray[a;b;c])
  | JArray l -> JArray(List.rev (Xlist.rev_map l (get_json_core n)))
  | _ -> t

let load_dialogi filename =
  match Xjson.json_of_string (File.load_file filename) with
    JArray l -> l
  | _ -> failwith "load_dialogi"

let process_dialog2 = function
    JObject["client",JObject["text",JString t]] -> C t
  | JObject["wizard",JObject["text",JString t]] -> W t
  | t -> failwith (json_to_string (get_json_core 2 t))
  
let process_dialog = function
    JObject["filename",_;"contents",JArray l] -> List.rev (Xlist.rev_map l process_dialog2)
  | t -> failwith ("process_dialog: " ^ json_to_string (get_json_core 1 t))
  
let rec split_into_turns rev = function
    [] -> List.rev rev
  | C c :: W w :: l -> split_into_turns (("",c) :: rev) (W w :: l)
  | W w :: C c :: W x :: l -> split_into_turns ((w,c) :: rev) (W x :: l)
  | [W w; C c] -> split_into_turns ((w,c) :: rev) []
  | [W w] -> split_into_turns ((w,"") :: rev) []
  | l -> print_endline "==========================================="; Xlist.iter l (fun s -> print_endline (string_of_turn s)); []
  
let frame_tree = ref Patterns.TokenTrie.empty
let frames_path = "../frames/data/wizard/"

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
  let dialogi1 = load_dialogi dialogi1_filename in
  let dialogi2 = load_dialogi dialogi2_filename in
  let dialogi = dialogi1 @ dialogi2 in
  let dialogi = List.rev (Xlist.rev_map dialogi process_dialog) in
  let turns = List.flatten (List.rev (Xlist.rev_map dialogi (split_into_turns []))) in
  let turns = List.rev (Xlist.rev_map turns (fun (w,c) -> 
    (if w = "" then w else classify_segment w), c)) in
  Xlist.iter turns (fun (w,c) -> 
    let w = if w = "" then "empty" else w in
    Printf.printf "%s: %s\n" w c);
  ()
