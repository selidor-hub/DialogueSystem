(*
 *  name parser
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
open Xjson

(* let category_filenames = ref [] *)
let comm_stdio = ref true
let port = ref 9761
let line_mode_flag = ref false

let spec_list = [
  "-i", Arg.Unit (fun () -> comm_stdio:=true), "Communication using stdio (default)";
  "-p", Arg.Int (fun p -> comm_stdio:=false; port:=p), "<port> Communication using sockets on given port number";
  "--line-mode", Arg.Unit (fun () -> line_mode_flag:=true), "Line mode";
  ]

let usage_msg =
  "Usage: time_parser <options>\nOptions are:"
  
let anon_fun s = raise (Arg.Bad ("invalid argument: " ^ s))

let get_table_names path =
  Xlist.fold (Array.to_list (Sys.readdir path)) [] (fun l s ->
    if Xstring.check_sufix ".tab" s then (Xstring.cut_sufix ".tab" s) :: l else l)

let map_prods = function
    "FirstName.f" -> "FirstName"
  | "FirstName.m" -> "FirstName"
  | "LastName.f" -> "LastName"
  | "LastName.m" -> "LastName"
  | "meta" -> "meta"
  | s -> failwith ("map_prods: " ^ s)
    
let classify_segment verbose frame_tree s =
(*   print_endline ("classify_segment 1: " ^ s); *)
  let parsed = Patterns.TokenTranslatedTrieCI.find frame_tree s in
  let l = Xlist.fold parsed [] (fun l (tokens,prods) ->
    let prods = Xlist.rev_map prods map_prods in
    let prods = StringSet.to_list (StringSet.of_list prods) in
    let s = String.concat "" tokens in
    if s = "" || s = " " || s = "  " then l else
    match prods with
      [] -> if verbose then print_endline ("classify_segment 2: „" ^ s ^ "”"); ("X",Xstring.remove_spaces s) :: l
    | ["meta"] -> l
    | [prod] -> (prod,s) :: l
    | ["LastName";"FirstName"] | ["FirstName";"LastName"] -> ("Name",s) :: l
    | prods -> if verbose then print_endline ("classify_segment 3: ⟨" ^ String.concat "⟩ ⟨" prods ^ "⟩ " ^ s); (String.concat "|^" prods,s) :: l) in
(*   if l = [] then "" else List.hd l *)
(*    String.concat " " (List.rev l)  *)
  List.rev l
  
exception Not_recognized
  
let parse_name text l =
  match l with
    ["FirstName",i] -> (i,"","")
  | ["LastName",n] | ["Name",n] -> ("","",n)
  | ["FirstName",i;"LastName",n] | ["FirstName",i;"Name",n] | ["FirstName",i;"X",n] | 
    ["Name",i;"LastName",n] | ["X",i;"LastName",n] | 
    ["Name",i;"Name",n] | ["Name",i;"X",n] | ["X",i;"Name",n] | 
    ["LastName",n;"FirstName",i] | ["LastName",n;"Name",i] | ["Name",n;"FirstName",i] | ["X",n;"FirstName",i] -> (i,"",n)
  | ["FirstName",i;"FirstName",s] -> (i,s,"")
  | ["LastName",n1;"LastName",n2] | ["LastName",n1;"X",n2] -> ("","",n1 ^ "-" ^ n2)
  | ["FirstName",i;"LastName",n1;"LastName",n2] | ["FirstName",i;"Name",n1;"LastName",n2] | ["FirstName",i;"X",n1;"LastName",n2] | 
    ["Name",i;"LastName",n1;"LastName",n2] | ["X",i;"LastName",n1;"LastName",n2] | 
    ["Name",i;"Name",n1;"LastName",n2] | ["Name",i;"X",n1;"LastName",n2] | ["X",i;"Name",n1;"LastName",n2] |
    ["FirstName",i;"LastName",n1;"Name",n2] | ["FirstName",i;"Name",n1;"Name",n2] | ["FirstName",i;"X",n1;"Name",n2] | 
    ["Name",i;"LastName",n1;"Name",n2] | ["X",i;"LastName",n1;"Name",n2] | 
    ["Name",i;"Name",n1;"Name",n2] | ["Name",i;"X",n1;"Name",n2] | ["X",i;"Name",n1;"Name",n2] | 
    ["FirstName",i;"LastName",n1;"X",n2] | ["Name",i;"LastName",n1;"X",n2] | ["X",i;"LastName",n1;"X",n2] -> (i,"",n1 ^ "-" ^ n2)
  | ["FirstName",i;"FirstName",s;"LastName",n] | ["FirstName",i;"FirstName",s;"Name",n] | ["FirstName",i;"FirstName",s;"X",n] | 
    ["Name",i;"FirstName",s;"LastName",n] | ["Name",i;"FirstName",s;"Name",n] | ["Name",i;"FirstName",s;"X",n] -> (i,s,n)    
  |_ -> 
(*    print_endline ("parse_name 1: " ^ text);
    print_endline ("parse_name 2: " ^ String.concat " " (Xlist.map l fst));*)
    raise Not_recognized
     
let input_text channel =
  let s = ref (try input_line channel with End_of_file -> "") in
  let lines = ref [] in
  while !s <> "" do
    lines := !s :: !lines;
    s := try input_line channel with End_of_file -> ""
  done;
  String.concat "\n" (List.rev !lines)
  
let rec main_loop lexicon_tree in_chan out_chan =
  let text = input_text in_chan in
  if text = "" then () else (
  let l = if !line_mode_flag then Xstring.split "\n" text else [text] in
  Xlist.iter l (fun text ->
    try
(*       print_endline ("main_loop 1: " ^ text); *)
      let l = classify_segment false lexicon_tree text in
(*       print_endline ("main_loop 2: " ^ String.concat " " (Xlist.map l fst)); *)
      let t = 
        try 
          let i,s,n = parse_name text l in
          JObject["text",JString text; "patient", JObject (
            (if i = "" then [] else ["first-name",JString i]) @
            (if s = "" then [] else ["second-name",JString s]) @
            (if n = "" then [] else ["last-name",JString n]))]
        with Not_recognized -> JObject["text",JString text; "patient", JObject ["name",JString "not-recognized"]] in
      Printf.fprintf out_chan "%s\n\n%!" (json_to_string_fmt "" t)
    with e -> 
      let t = JObject["error", JString (Printexc.to_string e)] in
      Printf.fprintf out_chan "%s\n\n%!" (json_to_string_fmt "" t));
  main_loop lexicon_tree in_chan out_chan)

    
let _ =
(*   prerr_endline message; *)
  Arg.parse spec_list anon_fun usage_msg;
  let lexicon_path = "data/" in
  let lexicon_filenames = [lexicon_path, get_table_names lexicon_path] in
  let lexicon_tree = Patterns.TokenTranslatedTrieCI.load_multipath lexicon_filenames in
  prerr_endline "Ready!";
  if !comm_stdio then main_loop lexicon_tree stdin stdout
  else
    let sockaddr = Unix.ADDR_INET(Unix.inet_addr_any,!port) in
    Unix.establish_server (main_loop lexicon_tree) sockaddr
  

