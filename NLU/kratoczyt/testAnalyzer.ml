(*
 *  kratoczyt: semantic interpreter for ARS lattices
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

type r = {pp: string; beam: string; sel: string; mode: string; measure: string; value: string;}

let empty_record = {pp=""; beam=""; sel=""; mode=""; measure=""; value="";}

let parse_filename s =
  if not (Xstring.check_sufix ".txt" s) then failwith "parse_filename 1" else
  let s = Xstring.cut_sufix ".txt" s in
  let pp,beam,sel = match Xstring.split "-" s with
      ["test";pp;beam;"sel95"] -> pp,beam,"95"
    | ["test";pp;beam] -> pp,beam,"100"
    | _ -> failwith "parse_filename 2" in
  let beam = 
    if Xstring.check_prefix "beam" beam then 
      Xstring.cut_prefix "beam" beam 
    else failwith "parse_filename 3" in
  {empty_record with pp; beam; sel}

let parse_line r s =
  let a,b,c = match Xstring.split " = " s with
    [a;b;c] -> a,b,c | _ -> failwith "parse_line" in
  let s = Xstring.cut_prefix "average " a in
  let mode = String.sub s 0 7 in
  let mode = if mode = "       " then "lat    " else mode in
  let measure = String.sub s 8 9 in
  let value = c in
  {r with mode; measure; value}
  
let load_tests () =
  let l = Array.to_list (Sys.readdir "tests") in
  let l = Xlist.fold l [] (fun l filename ->
    let lines = File.load_lines ("tests/" ^ filename) in
    let r = parse_filename filename in
    Xlist.fold lines l (fun l line ->
      if Xstring.check_prefix "average " line then
        let r = parse_line r line in
        r :: l else l)) in
  l

let _ =
  let l = load_tests () in
  let map = Xlist.fold l StringMap.empty (fun map r ->
    StringMap.add_inc map r.measure [r] (fun l -> r :: l)) in
  let map = StringMap.map map (fun l ->
    let map2 = Xlist.fold l StringMap.empty (fun map2 r ->
      StringMap.add_inc map2 r.sel [r] (fun l -> r :: l)) in
    StringMap.map map2 (fun l ->
      let map3 = Xlist.fold l StringMap.empty (fun map3 r ->
        StringMap.add_inc map3 r.mode [r] (fun l -> r :: l)) in
      StringMap.map map3 (fun l ->
        Xlist.fold l StringMap.empty (fun map4 r ->
          StringMap.add_inc map4 r.pp [r] (fun l -> r :: l))))) in
  StringMap.iter map (fun measure map2 ->
    StringMap.iter map2 (fun sel map3 -> 
      StringMap.iter map3 (fun mode map4 -> 
        Printf.printf "%s %s sel%s\n" measure mode sel;
        StringMap.iter map4 (fun pp l -> 
          let set = Xlist.fold l StringSet.empty (fun set r -> StringSet.add set r.value) in
          if StringSet.size set = 1 then Printf.printf "%s %s\n" pp (StringSet.max_elt set) else
          let l = Xlist.sort l (fun r1 r2 -> compare r1.beam r2.beam) in
          Printf.printf "%s %s\n" pp (String.concat " " (Xlist.map l (fun r -> "      " ^ r.beam)));
          Printf.printf "%s %s\n" pp (String.concat " " (Xlist.map l (fun r -> r.value)))))));
(*         Xlist.iter l (fun r -> Printf.printf "%s beam%s sel%s „%s”  „%s” „%s” \n" r.pp r.beam r.sel r.mode r.measure r.value))))); *)
  
  ()
  
