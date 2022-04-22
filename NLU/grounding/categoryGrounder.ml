(*
 *  grounder for service categories
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

let category_filenames = ref []
let comm_stdio = ref true
let port = ref 9761

let spec_list = [
  "-i", Arg.Unit (fun () -> comm_stdio:=true), "Communication using stdio (default)";
  "-p", Arg.Int (fun p -> comm_stdio:=false; port:=p), "<port> Communication using sockets on given port number";
  "-c", Arg.String (fun s -> category_filenames:=s :: !category_filenames), "<filename> Known categories";
  ]

let usage_msg =
  "Usage: category_grounder <options>\nOptions are:"
  
let anon_fun s = raise (Arg.Bad ("invalid argument: " ^ s))

let rec split_json_entry = function
    JObject["and",JArray (t :: l)] -> 
      let text,t = split_json_entry t in 
      text, JObject["and",JArray (t :: l)]
  | JObject l -> 
        let text,l = Xlist.fold l ("",[]) (fun (text,l) -> function
            "text", JString s -> if text = "" then s,l else failwith "split_json_entry 1"
          | e,t -> text, (e,t) :: l) in
        if text = "" then failwith ("split_json_entry 2: " ^ json_to_string (JObject l)) else
        Xstring.remove_spaces text, JObject (List.rev l)
  | _ -> failwith "split_json_entry 3"


let load_corpus map filename =
  let json = Xjson.json_of_string (File.load_file filename) in
  let l = match json with JArray l -> l | _ -> failwith "load_corpus" in
  Xlist.fold l map (fun map t -> 
    let c,t = split_json_entry t in 
    StringMap.add map c t)
 
let rec match_category = function (* category, query *)
    JObject["and",JArray l], t -> Xlist.fold l true (fun b s -> b && match_category (s,t))
  | JObject["or",JArray l], t -> Xlist.fold l false (fun b s -> b || match_category (s,t))
  | JObject["with",JArray l], t -> Xlist.fold l false (fun b s -> b || match_category (s,t))
  | s, JObject["and",JArray l] -> Xlist.fold l false (fun b t -> b || match_category (s,t))
  | s, JObject["or",JArray l] -> Xlist.fold l true (fun b t -> b && match_category (s,t))
  | s, JObject["with",JArray l] -> Xlist.fold l false (fun b t -> b || match_category (s,t))
  | JObject l, t when Xlist.size l > 1 -> Xlist.fold l true (fun b (e,s) -> b && match_category (JObject[e,s],t))
  | s, JObject l when Xlist.size l > 1 -> Xlist.fold l false (fun b (e,t) -> b || match_category (s,JObject[e,t]))
  | JObject[e1,s], JObject[e2,t] -> if e1 = e2 then match_category (s,t) else false
  | JObject _, _ -> false
  | _, JObject _ -> false
  | JString s, JString t -> s = t
  | JString _, _ -> false
  | _, JString _ -> false
  | JNumber s, JNumber t -> s = t
  | JNumber _, _ -> false
  | _, JNumber _ -> false
  | _ -> failwith "match_category"
 
let rec set_of_json path found = function
    JObject["and",JArray l] -> Xlist.fold l found (set_of_json path)
  | JObject["or",JArray l] -> Xlist.fold l found (set_of_json path)
  | JObject["with",JArray l] -> Xlist.fold l found (set_of_json path)
  | JObject l -> Xlist.fold l found (fun found (e,t) -> set_of_json (e :: path) found t)
  | JString s | JNumber s -> StringSet.add found (String.concat "#" (List.rev (s :: path)))
  | json -> (*print_endline ("set_of_json 2: " ^ json_to_string_fmt2 "" json);*) found

 
let process_query = function 
    JObject["categories",JArray l;"query",t] | JObject["query",t;"categories",JArray l] ->
      let l = Xlist.map l (function 
          JString s -> s
        | _ -> failwith "Invalid query") in
      l,t
  | q -> failwith "Invalid query"
 
let input_text channel =
  let s = ref (try input_line channel with End_of_file -> "") in
  let lines = ref [] in
  while !s <> "" do
    lines := !s :: !lines;
    s := try input_line channel with End_of_file -> ""
  done;
  String.concat "\n" (List.rev !lines)
  
let rec main_loop known_categories in_chan out_chan =
  let text = input_text in_chan in
  try
    let categories, t = process_query (json_of_string text) in
    let matched = Xlist.fold categories [] (fun matched cat ->
(*       print_endline ("main_loop 4: " ^ cat); *)
      let c = try StringMap.find known_categories (Xstring.remove_spaces cat) with Not_found -> failwith ("Unknown category: " ^ cat) in
(*       print_endline ("main_loop 5: " ^ json_to_string c); *)
      if match_category (c,t) then (JString cat) :: matched else matched) in
    let matched = if matched <> [] then matched else
      let query_set = set_of_json [] StringSet.empty t in
      let best,matched = Xlist.fold categories (-1,[]) (fun (best,matched) cat ->
        let c = try StringMap.find known_categories (Xstring.remove_spaces cat) with Not_found -> failwith ("Unknown category: " ^ cat) in
        let quality = StringSet.size (StringSet.intersection query_set (set_of_json [] StringSet.empty c)) in
        if best > quality then best,matched else
        if best < quality then quality,[JString cat] else
        best, (JString cat) :: matched) in
      if best = 0 then [] else matched in
    let matched = match matched with 
      [] -> JString "not found"
    | [c] -> c
    | l -> JObject["with",JArray l] in
(*     print_endline ("main_loop 9: " ^ json_to_string matched); *)
    let t = JObject["category", matched;"query",t] in
    Printf.fprintf out_chan "%s\n\n%!" (json_to_string_fmt2 "" t)
  with e -> 
    let t = JObject["error", JString (Printexc.to_string e)] in
    Printf.fprintf out_chan "%s\n\n%!" (json_to_string_fmt2 "" t)

(* Korzystam ze statycznej listy kategorii zawartej w pliku ....json,
alternatywnie można by parsować przekazywane kategorie *)
    
let _ =
(*   prerr_endline message; *)
  Arg.parse spec_list anon_fun usage_msg;
  let known_categories = Xlist.fold !category_filenames StringMap.empty load_corpus in
  prerr_endline "Ready!";
  if !comm_stdio then main_loop known_categories stdin stdout
  else
    let sockaddr = Unix.ADDR_INET(Unix.inet_addr_any,!port) in
    Unix.establish_server (main_loop known_categories) sockaddr
  

