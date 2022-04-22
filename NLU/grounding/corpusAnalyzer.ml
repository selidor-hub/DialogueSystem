(*
 *  corpus analyzer
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

let load_json_list filename =
  match json_of_string (File.load_file filename) with
    JArray l -> l
  | _ -> failwith "load_json_list"
  
let parsed_path = "../../corpus/examples/"

let parsed_names = [
  "beauty_branza";"beauty_kategoria";"beauty_synonimy";"beauty_usluga1";"beauty_usluga2";"E1";"E2";"E3";"L2";"rafal";"commands"]

let attributes = StringSet.of_list ["service";"patient";"name";"param";"flaw";"organization";"type";"part";"part-param";"effect";"artefact";"part-colour";"instrument";"part-length";"person";"doer";"profession";"domain";
"action";"attitude";"greetings";"client-data";"gender";"instance";"instance-param";"time";"after";"element";"index";"set";"hour";"time-of-day";"weekday";"state";"command";"confirmation";"duration";"minute";"monthday";"month";"first-name";"part-quantity";"quantity";"";"";""]
      
let rec process_parsed path map = function
    JObject["and",JArray l] -> Xlist.fold l map (process_parsed path)
  | JObject["or",JArray l] -> Xlist.fold l map (process_parsed path)
  | JObject["with",JArray l] -> Xlist.fold l map (process_parsed path)
  | JObject["at",t] -> process_parsed path map t
  | JObject l ->
      Xlist.fold l map (fun map (e,t) ->
        if e = "text" || e = "alias" then map else
        if StringSet.mem attributes e then process_parsed (e :: path) map t else
        (print_endline ("process_parsed 1: " ^ json_to_string_fmt2 "" (JObject l)); map))
(*   | JNumber _ -> map *)
  | JString "client" -> map
  | JString "?" -> map
  | JNumber s | JString s -> 
      let p = String.concat "." (List.rev path) in
      StringMap.add_inc map s (StringSet.singleton p) (fun set -> StringSet.add set p)
  | json -> print_endline ("process_parsed 2: " ^ json_to_string_fmt2 "" json); map

let load_parsed () =
  Xlist.fold parsed_names StringMap.empty (fun map name ->
    let parsed = load_json_list (parsed_path ^ name ^ "_parsed.json") in 
    Xlist.fold parsed map (process_parsed []))

let _ =
  let map = load_parsed () in
  let set = StringMap.fold map StringSet.empty (fun set _ paths ->
    StringSet.union set paths) in
  StringSet.iter set print_endline;
  let map = StringMap.fold map StringMap.empty (fun map s set ->
    let path = String.concat ":" (Xlist.sort (StringSet.to_list set) compare) in
    StringMap.add_inc map path [s] (fun l -> s :: l)) in
  StringMap.iter map (fun name l ->
    File.file_out ("results/path_" ^ name ^ ".tab") (fun file ->
      Xlist.iter (Xlist.sort l compare) (fun s ->
        Printf.fprintf file "%s\n" s)));
  ()
