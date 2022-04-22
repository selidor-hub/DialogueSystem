(*
 *  time expresion grounder
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
open TimeGrounderTypes

type hour_term =
    Left
  | Right
  | Both
  | None
  | M of int
  | H of int
  | Empty
  | U
  
type hour_t = {
  term: hour_term;
  strict: int * int;
  loose: int * int;
  day: int;
  }
  
let empty_hour_t = {term=U; strict=(1,0); loose=(1,0); day=0}

let rec string_of_hour i =
  if i < 0 then string_of_hour (i + 24*60) else
  if i >= 24*60 then string_of_hour (i - 24*60) else
  Printf.sprintf "%02d:%02d:00" (i/60) (i mod 60)

let json_of_hour_int (i,j) =
  if i = j then JObject["at",JString (string_of_hour i)] else
  JObject["begin",JString (string_of_hour i); "end",JString (string_of_hour j)]

let json_of_hour_intervals l =
  let l = List.flatten (List.rev (Xlist.rev_map l (fun t ->
    match t.term with
        Left -> [JObject["extension",JString "later";"strict",json_of_hour_int t.strict; "loose",json_of_hour_int t.loose]]
      | Right -> [JObject["extension",JString "earlier";"strict",json_of_hour_int t.strict; "loose",json_of_hour_int t.loose]]
      | Both -> [JObject["extension",JString "both";"strict",json_of_hour_int t.strict; "loose",json_of_hour_int t.loose]]
      | None -> [JObject["extension",JString "none";"strict",json_of_hour_int t.strict; "loose",json_of_hour_int t.loose]]
      | M _ -> if !debug then failwith "json_of_hour_intervals" else [JString "unspecified"]
      | H _ -> [JObject["extension",JString "both";"strict",json_of_hour_int t.strict; "loose",json_of_hour_int t.loose]]
      | Empty -> []
      | U -> [JString "unspecified"]))) in
  match l with 
    [t] -> t
  | _ -> JArray l

let intersection (i1,i2) (j1,j2) =
  max i1 j1,min i2 j2
  
(* FIXME: zanegowane przedziały dwustrone np. „oprócz godzin od 15 do 17” są przetwarzane jak suma negacji przedziałów jednostronnych. Żeby to poprawić trzeba na poziomie ENIAM'a wprowadzić reprezentację przedziałów dwustronych dla konstrukcji x-y, między x a y, od x do y *)
    
let rec ground now_hour now_minute pp_hour pp_minute = function
    And l -> 
      let ll = Xlist.multiply_list (Xlist.rev_map l (ground now_hour now_minute pp_hour pp_minute)) in 
      Xlist.fold  ll []  (fun ll l -> 
        if l = [] then ll else
        Xlist.fold (List.tl l) (List.hd l) (fun a b ->
(*       print_endline ("ground_hour And 1: " ^ string_of_t b); *)
(*       let b = ground_hour now_hour now_minute pp_hour pp_minute b in *)
(*       print_endline ("ground_hour And 2: " ^ json_to_string (json_of_hour_intervals b)); *)
          match a.term,b.term with
            U,_ -> b
          | _,U -> a
          | Empty,_ -> a
          | _,Empty -> b
          | H i,M j | M j,H i -> {a with term=Both; strict=(i+j,i+j); loose=(i+j,i+j)}
          | M _,_ | _,M _ -> if !debug then failwith "ground_hour: And[M _;M _]" else {a with term=Empty}
          | H i,H j -> if i = j then a else {a with term=Empty}
          | Left,Right -> {a with term=None; strict=(fst a.strict,snd b.strict); loose=(fst a.loose,snd b.loose)}
          | Right,Left -> {b with term=None; strict=(fst b.strict,snd a.strict); loose=(fst b.loose,snd a.loose)}
          | _ -> 
              let i,j = intersection a.strict b.strict in
              if i > j then {a with term=Empty} else
              {a with term=Both; strict=intersection a.strict b.strict; loose=intersection a.loose b.loose}
         (* | _ -> failwith ("ground_hour 1: " ^ json_to_string (json_of_hour_intervals [a]) ^ " " ^ json_to_string (json_of_hour_intervals [b]))*)) :: ll)
  | Or l | With l -> List.flatten (Xlist.rev_map l (ground now_hour now_minute pp_hour pp_minute))
  | Selector(Minute,i,Hour) -> [{empty_hour_t with term=M i}]
  | Selector(Hour,i,Day) -> [{empty_hour_t with term=H (i*60); strict=(i*60,i*60+15); loose=(i*60,i*60+59)}]
  | Selector(Minute,i,Future) -> 
      let x = now_hour*60+now_minute+i in
      [{empty_hour_t with term=Left; strict=(x,x+15); loose=(x,x+15)}] (* FIXME: kwestia przewijania dnia *)
  | Selector(Hour,i,Future) -> 
      let x = now_hour*60+now_minute+i*60 in
      [{empty_hour_t with term=Left; strict=(x,x+60); loose=(x,x+120)}] (* FIXME: kwestia przewijania dnia *)
  | Selector(Minute,i,Past) -> 
      let x = now_hour*60+now_minute-i in
      [{empty_hour_t with term=Left; strict=(x,x+15); loose=(x,x+15)}] (* FIXME: kwestia przewijania dnia *)
  | Selector(Hour,i,Past) -> 
      let x = now_hour*60+now_minute-i*60 in
      [{empty_hour_t with term=Left; strict=(x,x+15); loose=(x,x+15)}] (* FIXME: kwestia przewijania dnia *)
  | Selected _ -> 
     if pp_hour = -1 then [] else
     let x = pp_hour*60+pp_minute in
     [{empty_hour_t with term=Both; strict=(x,x); loose=(x,x)}]
  | At t -> ground now_hour now_minute pp_hour pp_minute t
  | Aprox t -> 
      let l = ground now_hour now_minute pp_hour pp_minute t in
      Xlist.rev_map l (fun t -> match t.term with
        Left | Right -> if !debug then failwith "ground_hour: Aprox" else t
      | Both | None -> 
          let i,j = t.strict in
          {t with term=Both; strict=(i-15,j+15); loose=(i-60,j+60)}
      | M _ -> if !debug then failwith "ground_hour: Aprox(M _)" else t
      | H i -> {t with term=Both; strict=(i-15,i+15); loose=(i-60,i+60)}
      | U | Empty -> t)        
  | Begin t -> 
      let l = ground now_hour now_minute pp_hour pp_minute t in
      Xlist.rev_map l (fun t -> match t.term with
        Left -> t
      | Right -> if !debug then failwith "ground_hour: Begin" else t
      | Both | None -> 
          let i,j = t.strict in
          {t with term=Left; strict=(i,max (i+180) j); loose=(i,max (i+300) j)}
      | M _ -> if !debug then failwith "ground_hour: Begin(M _)" else t
      | H i -> {t with term=Left; strict=(i,i+180); loose=(i,i+300)}
      | U | Empty -> t)        
  | End t -> 
      let l = ground now_hour now_minute pp_hour pp_minute t in
      Xlist.rev_map l (fun t -> match t.term with
        Left -> if !debug then failwith "ground_hour: End" else t
      | Right -> t
      | Both | None -> 
          let i,j = t.strict in
          {t with term=Right; strict=(min i (j-120),j); loose=(min i (j-240),j)}
      | M _ -> if !debug then failwith "ground_hour: End(M _)" else t
      | H i -> {t with term=Right; strict=(i-120,i); loose=(i-240,i)}
      | U | Empty -> t)        
  | Before t -> 
      let l = ground now_hour now_minute pp_hour pp_minute t in
      Xlist.rev_map l (fun t -> match t.term with
        Left | Right -> if !debug then failwith "ground_hour: Before" else t
      | Both | None -> 
          let i,_ = t.strict in
          {t with term=Right; strict=(i-60,i-1); loose=(i-180,i-1)}
      | M _ -> if !debug then failwith "ground_hour: Before(M _)" else t
      | H i -> {t with term=Right; strict=(i-60,i-1); loose=(i-180,i-1)}
      | U | Empty -> t)        
  | After t -> 
      let l = ground now_hour now_minute pp_hour pp_minute t in
      Xlist.rev_map l (fun t -> match t.term with
        Left | Right -> if !debug then failwith "ground_hour: After" else t
      | Both | None -> 
          let i,j = t.strict in
          {t with term=Left; strict=(j+5,j+120); loose=(j+5,j+300)}
      | M _ -> if !debug then failwith "ground_hour: After(M _)" else t
      | H i -> {t with term=Left; strict=(i+5,i+120); loose=(i+5,i+300)}
      | U | Empty -> t)  
  | Not (And l) -> ground now_hour now_minute pp_hour pp_minute (Or (Xlist.rev_map l (fun t -> Not t)))
  | Not (Or l) -> ground now_hour now_minute pp_hour pp_minute (And (Xlist.rev_map l (fun t -> Not t)))
  | Not (With l) -> ground now_hour now_minute pp_hour pp_minute (With (Xlist.rev_map l (fun t -> Not t)))
  | Not (Begin t) -> ground now_hour now_minute pp_hour pp_minute (Before t)
  | Not (End t) -> ground now_hour now_minute pp_hour pp_minute (After t)
  | Not (Before t) -> ground now_hour now_minute pp_hour pp_minute (Begin t)
  | Not (After t) -> ground now_hour now_minute pp_hour pp_minute (End t)
  | Not t ->
      let l = ground now_hour now_minute pp_hour pp_minute t in
      List.flatten (Xlist.rev_map l (fun t -> match t.term with (* Listę możliwości interpretuję jako with a nie or *)
        Left | Right -> if !debug then failwith "ground_hour: Not" else [{empty_hour_t with term=U}]
      | Both -> [
          {t with term=Both; strict=(0,fst t.loose-1); loose=(0,fst t.strict-1)};
          {t with term=Both; strict=(snd t.loose+1,60*24-1); loose=(snd t.strict+1,60*24-1)}]
      | None -> [
          {t with term=None; strict=(0,fst t.loose-1); loose=(0,fst t.strict-1)};
          {t with term=None; strict=(snd t.loose+1,60*24-1); loose=(snd t.strict+1,60*24-1)}]
      | M _ -> if !debug then failwith "ground_hour: Not(M _)" else [{empty_hour_t with term=U}]
      | H i -> [
          {t with term=Both; strict=(0,fst t.loose-1); loose=(0,fst t.strict-1)};
          {t with term=Both; strict=(snd t.loose+1,60*24-1); loose=(snd t.strict+1,60*24-1)}]
      | Empty -> if !debug then failwith "ground_hour: Not Empty" else [{empty_hour_t with term=U}]
      | U -> [t]))
  | Hour -> [{empty_hour_t with term=U}]
  | Minute -> [{empty_hour_t with term=U}]
  | Time -> [{empty_hour_t with term=U}]
  | Other t -> ground now_hour now_minute pp_hour pp_minute (And[t;Not(Selected Hour)])
  | Somewhat t -> 
      let l = ground now_hour now_minute pp_hour pp_minute t in
      Xlist.rev_map l (fun t -> match t.term with
        Left -> 
(*           print_endline ("ground_hour Somewhat: " ^ json_to_string_fmt2 "" (json_of_hour_intervals [t]));  *)
          let x = min (fst t.strict + 60) (snd t.strict) in
          {t with strict=(fst t.strict,x); loose = t.strict}
      | Right -> 
(*           print_endline ("ground_hour Somewhat: " ^ json_to_string_fmt2 "" (json_of_hour_intervals [t]));  *)
          let x = max (snd t.strict - 30) (fst t.strict) in
          {t with strict=(x,snd t.strict); loose = t.strict}
      | Both | None | M _ | H _ -> if !debug then failwith "ground_hour: Somewhat" else t
      | U | Empty -> t)  
  | Unspecified -> [{empty_hour_t with term=U}]
  | t -> if !debug then failwith ("ground_hour: " ^ string_of_t t) else [{empty_hour_t with term=U}]
      
let merge l = 
  Xlist.sort l (fun a b -> 
    let c = compare (fst a.strict) (fst b.strict) in
    if c = 0 then compare (snd a.strict) (snd b.strict) else c)

let select_hour cats hour =
  List.rev (Xlist.fold cats [] (fun cats cat ->
(*     print_endline (String.sub cat 11 2); *)
    let h = try int_of_string (String.sub cat 11 2) with _ -> failwith "Invalid query: categories format 2" in
(*     print_endline (String.sub cat 14 2); *)
    let m = try int_of_string (String.sub cat 14 2) with _ -> failwith "Invalid query: categories format 3" in
    let v = 60 * h + m in
    let b = Xlist.fold hour false (fun b -> function
        {term=Empty} -> b
      | {term=U} -> true 
      | t -> if fst t.strict <= v && snd t.strict >= v then true else b) in
    if b then cat :: cats else cats))
  
