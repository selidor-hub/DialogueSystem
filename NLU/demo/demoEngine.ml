(*
 *  NLU module demo
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
open Xstd
open Types

let std_output verb s =
  if verb <= !verbosity then print_endline s

let rec std_input () =
  let s = read_line () in
  if s = "" then std_input () else s

let get_sock_addr host_name port =
  let he = Unix.gethostbyname host_name in
  let addr = he.Unix.h_addr_list in
  Unix.ADDR_INET(addr.(0),port)

let input_text channel =
  let s = ref (try input_line channel with End_of_file -> "") in
  let lines = ref [] in
  while !s <> "" do
    lines := !s :: !lines;
    s := try input_line channel with End_of_file -> ""
  done;
  String.concat "\n" (List.rev !lines)

let rec get_json_key_rec path found t = 
  if path = [] then t :: found else
  match t with
    JObject[s,JArray l] when s="and" || s="or" || s="with" -> Xlist.fold l found (get_json_key_rec path)
  | JObject l ->
      Xlist.fold l found (fun found (e,t) -> 
        if e = List.hd path then get_json_key_rec (List.tl path) found t else found)
  | _ -> found
  
let get_json_key path t =
  match get_json_key_rec path [] t with
    [] -> failwith ("get_json_key: key " ^ String.concat "#" path ^ " not found")
  | [t] -> t
  | l -> failwith ("get_json_key: multiple key found for path " ^ String.concat "#" path)
  
let rec execute states state env s =
  std_output 1 ("STATE:" ^ state);
  let f, next = try StringMap.find states state with Not_found -> failwith ("execute: state '" ^ state ^ "' not found") in
  let s2 = f env s in
  match next with
      Next state2 -> execute states state2 env s2
    | Split l -> execute_split states state env s2 l
    | Finish -> ()
  
and execute_split states state env s2 = function
    (f, state2) :: l -> 
      if f env s2 then execute states state2 env s2 else execute_split states state env s2 l
  | [] -> failwith ("execute_split: " ^ state)
  
let check_states_consistency states =
  let names,nexts = StringMap.fold states (StringSet.empty,StringSet.empty) (fun (names,nexts) name (_,next) ->
    let names = StringSet.add names name in
    let nexts = match next with
        Next s -> StringSet.add nexts s
      | Split l -> Xlist.fold l nexts (fun nexts (_,s) -> StringSet.add nexts s)
      | Finish -> nexts in
    names, nexts) in
  let set = StringSet.difference nexts names in
  StringSet.iter set (fun s -> print_endline ("missing state: " ^ s))
    
    
