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
open DemoEngine

let spec_list = [
  "-v", Arg.Int (fun v -> verbosity:=v), "<val> Sets verbosity level\n     0 - print only contents of dialog\n     1 - print contents of dialog and dialog state (default)\n     2 - print all data structures";
  ]

let usage_msg =
  "Usage: time_demo <options>\nOptions are:"
  
let anon_fun s = raise (Arg.Bad ("invalid argument: " ^ s))

let create_now () =
  let tm = Unix.localtime (Unix.gettimeofday ()) in
  Printf.sprintf "%d-%02d-%02d %02d:%02d:00" 
    (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday 
    tm.Unix.tm_hour tm.Unix.tm_min
    
let create_horizon () =
  let tm = Unix.localtime (Unix.gettimeofday () +. (30. *. 24. *. 60. *. 60.)) in
  Printf.sprintf "%d-%02d-%02d %02d:%02d:00" 
    (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday 
    tm.Unix.tm_hour tm.Unix.tm_min
   
let parse_grounded_time = function
    JObject["error", JString s] -> Error s
  | t -> 
     (try
       match get_json_key ["date"] t with
         JArray [] -> Contradiction
       | JString "unspecified" -> Unspecified
       | t -> JSON t
     with _ -> Error ("invalid json format: " ^ json_to_string t))
   
let select_dates horizon = function
    JArray l -> List.rev (Xlist.fold l [] (fun rev -> function
        JObject["begin",JString s;"end",JString t] -> 
          if s > horizon then rev else 
          if t > horizon then (JObject["begin",JString s;"end",JString horizon]) :: rev else
          (JObject["begin",JString s;"end",JString t]) :: rev
      | JObject["at",JString s] -> if s > horizon then rev else (JObject["at",JString s]) :: rev
      | _ -> failwith "select_dates 2"))
  | _ -> failwith "select_dates 1"
  
let select_first_date = function
    JArray l -> Xlist.fold l "" (fun found -> function
        JObject["begin",JString s;"end",_] | JObject["at",JString s] -> 
          if found = "" then s else min found s
      | _ -> failwith "select_first_date 2")
  | _ -> failwith "select_first_date 1"
 
 
let states = Xlist.fold [
  "init", (fun _ t ->
    std_output 0 "Podaj termin";
    t), Next "input and process";
  "again", (fun _ t ->
    std_output 0 "Podaj inny termin";
    t), Next "input and process";
  "input and process", (fun env _ ->
    let s = std_input () in
    std_output 1 ("Napisałeś: " ^ s);
    Printf.fprintf env.eniam_out "%s\n\n%!" s;
    let s = input_text env.eniam_in in
    std_output 1 ("Zrozumiałem: " ^ s);
    std_output 1 ("Teraz jest: " ^ env.now);
    let t = json_of_string s in
    let t = JObject["now", JString env.now; "horizon", JNumber "10000"; "query", t] in
    std_output 2 ("Uziemiam: " ^ (json_to_string_fmt2 "" t));
    let time_grounder_in,time_grounder_out = Unix.open_connection (get_sock_addr "localhost" 9763) in
    Printf.fprintf time_grounder_out "%s\n\n%!" (json_to_string t);
    let s = input_text time_grounder_in in
    Unix.shutdown_connection time_grounder_in;
    std_output 1 ("Uziemiłem jako: " ^ s);  
    {empty_slots with date=parse_grounded_time (json_of_string s)}),Split[
      (fun _ t -> t.date = Contradiction), "nonexistant date";
      (fun _ t -> t.date = Unspecified), "unspecified date";
      (fun _ t -> is_error t.date), "error";
      (fun env t -> select_dates env.horizon (get_json t.date) = []), "distant date";
      (fun env t -> select_dates env.horizon (get_json t.date) <> []), "proper date"];
  "nonexistant date", (fun _ t ->
    std_output 0 "Podana data nie istnieje";
    t), Next "again";
  "unspecified date", (fun _ t ->
    std_output 0 "Nie znalazłem daty w podanym wyrażeniu";
    std_output 0 "Podaj datę";
    t), Next "input and process";
  "distant date", (fun _ t ->
    std_output 0 ("Podany termin " ^ select_first_date (get_json t.date) ^ " jest zbyt odległy");
    t), Next "again";
  "proper date", (fun _ t ->
    let dates = select_dates (create_horizon ()) (get_json t.date) in
    std_output 0 ("Znalezione terminy to: " ^ json_to_string_fmt2 "" (JArray dates));
    t), Finish;
  "error", (fun _ t ->
    std_output 0 ("Napotkałem na błąd: " ^ get_error t.date);
    t), Finish;
  ] StringMap.empty (fun map (s,f,next) -> StringMap.add map s (f,next))
  
let _ =
  Arg.parse spec_list anon_fun usage_msg;
  check_states_consistency states;
  let eniam_in,eniam_out = Unix.open_connection (get_sock_addr "localhost" 9760) in
  let env = {empty_env with eniam_in; eniam_out; now=create_now (); horizon=create_horizon ()} in
  execute states "init" env empty_slots;
  ()
  
