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

type g =
    IS of Interval.interval list
  | LS of Interval.left_interval list
  | RS of Interval.right_interval list
  | Uns 
    
let rec json_of_date_intervals limit = function
    IS l -> JArray(Xlist.map (Xlist.prefix limit l) Interval.json_of_interval)
  | LS l -> JArray(Xlist.map (Xlist.prefix limit l) Interval.json_of_left_interval)
  | RS l -> JArray(Xlist.map (Xlist.prefix limit l) Interval.json_of_right_interval)
  | Uns -> JString "unspecified"
  
    
let rec get_nth i = function
    x :: l -> if i = 0 || i = 1 then [x] else get_nth (i-1) l
  | [] -> [](*Interval.empty_interval*)(*failwith "get_nth"*)
    
let rec ground_date days weeks months years future past time pp = function
    And l -> Xlist.fold l Uns (fun a b ->
      let b = ground_date days weeks months years future past time pp b in
      match a,b with
        Uns,_ -> b
      | _,Uns -> a
      | IS a,IS b -> IS(List.flatten (Xlist.map a (fun interval -> Interval.get_subsets interval b)))
      | IS a,LS b | LS b,IS a -> 
          IS(List.flatten (List.rev (Xlist.rev_map a (fun i ->
            let b = List.flatten (Xlist.rev_map b (fun t -> if Interval.is_member_left i t then [t] else [])) in
            Interval.intersect_left i (Interval.merge_left b)))))
      | IS a,RS b | RS b,IS a -> 
          IS(List.flatten (List.rev (Xlist.rev_map a (fun i ->
            let b = List.flatten (Xlist.rev_map b (fun t -> if Interval.is_member_right i t then [t] else [])) in
            Interval.intersect_right i (Interval.merge_right b)))))
      | LS a,RS b | RS b,LS a -> 
          IS(List.flatten (List.rev (Xlist.rev_map a (fun i -> Interval.smallest_intersect i b))))
      | LS a,LS b -> if !debug then failwith "ground_date: And[LS _;LS _]" else LS a
      | RS a,RS b -> if !debug then failwith "ground_date: And[RS _;RS _]" else RS a
(*      | _ -> failwith ("ground_date: ni: " ^ json_to_string (json_of_date_intervals 10000 a) ^ " " ^ json_to_string (json_of_date_intervals 10000 b))*))
  | Or l | With l -> 
     Xlist.fold l Uns (fun a b ->
      let b = ground_date days weeks months years future past time pp b in
      match a,b with
        Uns,_ -> b
      | _,Uns -> a
      | IS a,IS b -> IS(Interval.sort (a @ b))
      | _ -> if !debug then failwith ("ground_date Or: " ^ json_to_string (json_of_date_intervals 10000 a) ^ " " ^ json_to_string (json_of_date_intervals 10000 b)) else Uns)
  | Selector(e,i,s) (*as x*) -> 
      let i = if e = Year && s <> Future && s <> Past then i - start_year + 1 else i in
      let i = if s = Future then i + 1 else i in
      let i = if s = Past then 
        if e = Year || e = Week then -1 - i else 
        -i else i in
      let e = ground_date days weeks months years future past time pp e in
      let s = ground_date days weeks months years future past time pp s in
      (match e,s with
        IS e, IS s ->
          let t = List.rev (Xlist.fold s [] (fun l interval ->
            if i < 0 then (get_nth (-i) (List.rev (Interval.get_subsets interval e))) @ l
            else (get_nth i (Interval.get_subsets interval e)) @ l)) in
          IS t
      | _ -> if !debug then failwith "ground_date: Selector" else Uns)
  | SelectorAny(e,s) -> 
      let e = ground_date days weeks months years future past time pp e in
      let s = ground_date days weeks months years future past time pp s in
      (match e,s with
        IS e, IS s ->
          let t = List.rev (Xlist.fold s [] (fun l interval ->
            let s = Interval.get_subsets interval e in
            (List.rev s) @ l)) in
          IS t
      | _ -> if !debug then failwith "ground_date: SelectorAny" else Uns)
  | Day -> IS days
  | Week -> IS weeks
  | Month -> IS months
  | Year -> IS years
  | Future -> IS future
  | Past -> IS past
  | Time -> IS time
  | Begin t -> 
      (match ground_date days weeks months years future past time pp t with
        IS t -> 
          LS(List.rev (Xlist.rev_map t Interval.left_interval_of_interval))
      | LS t -> LS t
      | RS _ -> if !debug then failwith "ground_date: Begin(RS _)" else Uns
      | Uns -> Uns)
  | End t -> 
      (match ground_date days weeks months years future past time pp t with
        IS t -> 
          RS(List.rev (Xlist.rev_map t Interval.right_interval_of_interval))
      | RS t -> RS t
      | LS _ -> if !debug then failwith "ground_date: End(LS _)" else Uns
      | Uns -> Uns)
  | Before t -> 
      (match ground_date days weeks months years future past time pp t with
        IS t -> 
          RS(List.rev (Xlist.rev_map t (fun t -> 
            Interval.right_interval_of_interval2 (Interval.shift t (-1)))))
      | RS t -> RS(List.rev (Xlist.rev_map t (fun t -> Interval.shift_right t (-1))))
      | LS _ -> if !debug then failwith "ground_date: Before(LS _)" else Uns
      | Uns -> Uns)
  | After t -> 
      (match ground_date days weeks months years future past time pp t with
        IS t -> 
          LS(List.rev (Xlist.rev_map t (fun t -> 
            Interval.left_interval_of_interval2 (Interval.shift t 1))))
      | LS t -> LS(List.rev (Xlist.rev_map t (fun t -> Interval.shift_left t 1)))
      | RS _ -> if !debug then failwith "ground_date: After(RS _)" else Uns
      | Uns -> Uns)
  | Not t -> 
      (match ground_date days weeks months years future past time pp t with
        IS [] -> Uns
      | IS t -> IS(Interval.get_subsets (List.hd time) (Interval.revert (Interval.merge t)))
      | LS t -> RS(Interval.revert_left t)
      | RS t -> LS(Interval.revert_right t)
      | Uns -> Uns)
  | Other t -> ground_date days weeks months years future past time pp (And[t;Not(Selected Day)])
  | Selected Day -> IS pp
  | Selected Week -> if !debug then failwith "ground_date: Selected Week" else IS pp
  | Selected Month -> if !debug then failwith "ground_date: Selected Month" else IS pp
  | Selected Year -> if !debug then failwith "ground_date: Selected Year" else IS pp
  | Unspecified -> Uns
  | t -> if !debug then failwith ("ground_date: " ^ string_of_t t) else Uns

let merge = function
    IS l -> IS(Interval.merge l)
  | LS l -> LS(Interval.merge_left l)
  | RS l -> RS(Interval.merge_right l)
  | Uns -> Uns
  
let is_empty date = 
  match date with 
    IS [] | LS [] | RS [] -> true 
  | _ -> false

let ground days weeks months years future past time pp limit date_query =
  let date = 
    if date_query = Unspecified then Uns 
      else ground_date days weeks months years future past time pp (And[Future;date_query]) in
  let date = 
    if is_empty date then 
      ground_date days weeks months years future past time pp date_query 
    else date in
  let date = merge date in
  let date = json_of_date_intervals limit date in
  date

