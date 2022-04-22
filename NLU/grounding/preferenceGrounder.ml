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
open Xstd
open TimeGrounderTypes


type pref_val =
    Earlier
  | Later
  | Anyy
  | Onlyy
  
type preference = 
    HourPreference of pref_val
  | TimePreference of pref_val
  | DatePreference of pref_val
  
let json_of_pref_val = function
    Earlier -> JString "earlier"
  | Later -> JString "later"
  | Anyy -> JString "any"
  | Onlyy -> JString "only"
  
let json_of_preferences l =
  let map = Xlist.fold l StringMap.empty (fun map -> function
      HourPreference dir -> StringMap.add_inc map "hour-preference" [dir] (fun l -> dir :: l)
    | TimePreference dir -> StringMap.add_inc map "time-preference" [dir] (fun l -> dir :: l)
    | DatePreference dir -> StringMap.add_inc map "date-preference" [dir] (fun l -> dir :: l)) in
  StringMap.fold map [] (fun l e dirs ->
    match Xlist.rev_map dirs json_of_pref_val with
      [] -> failwith "json_of_preferences"
    | [t] -> (e, t) :: l
    | dirs -> (e, JArray dirs) :: l)
 
let groud_pref_val = function
    Ascending -> Earlier
  | Descending -> Later
  | _ -> failwith "groud_pref_val"
  
let rec ground_preference = function
    And l | Or l | With l -> List.flatten (Xlist.rev_map l ground_preference)
  | Sort(Hour,dir) -> [HourPreference (groud_pref_val dir)]
  | Sort(Minute,dir) -> if !debug then failwith "ground_preference: Minute" else [HourPreference (groud_pref_val dir)]
  | Sort(Day,dir) -> [DatePreference (groud_pref_val dir)]
  | Sort(Time,dir) -> [TimePreference (groud_pref_val dir)]
  | Sort(Month,dir) -> if !debug then failwith "ground_preference: Month" else [DatePreference (groud_pref_val dir)]
  | Sort(Year,dir) -> if !debug then failwith "ground_preference: Year" else [DatePreference (groud_pref_val dir)]
  | Any Day -> [DatePreference Anyy]
  | Any Hour -> [HourPreference Anyy]
  | Any Time -> [TimePreference Anyy]
  | Only Day -> [DatePreference Onlyy]
  | Only Hour -> [HourPreference Onlyy]
  | Only Time -> [TimePreference Onlyy]
  | Unspecified -> []
  | t -> failwith ("ground_preference: " ^ string_of_t t)

let select_earlier selector_fun cats =
  let map = Xlist.fold cats StringMap.empty (fun map cat -> 
    StringMap.add_inc map (selector_fun cat) [cat] (fun l -> cat :: l)) in
  let l = StringMap.fold map [] (fun l k v -> (k,v) :: l) in
  snd (List.hd (Xlist.sort l (fun (a,_) (b,_) -> compare a b)))
  
let select_later selector_fun cats =
  let map = Xlist.fold cats StringMap.empty (fun map cat -> 
    StringMap.add_inc map (selector_fun cat) [cat] (fun l -> cat :: l)) in
  let l = StringMap.fold map [] (fun l k v -> (k,v) :: l) in
  snd (List.hd (Xlist.sort l (fun (a,_) (b,_) -> - (compare a b))))
  
let select_preference cats preferences =
  if cats = []  then [] else
  Xlist.fold preferences cats (fun cats -> function
      TimePreference Earlier -> [List.hd (Xlist.sort cats compare)]
    | TimePreference Later -> [List.hd (List.rev (Xlist.sort cats compare))]
    | DatePreference Earlier -> select_earlier (fun cat -> String.sub cat 0 10) cats
    | DatePreference Later -> select_later (fun cat -> String.sub cat 0 10) cats
    | HourPreference Earlier -> select_earlier (fun cat -> String.sub cat 11 5) cats
    | HourPreference Later -> select_later (fun cat -> String.sub cat 11 5) cats
    | _ -> cats)
        
