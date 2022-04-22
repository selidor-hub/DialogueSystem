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
 
open Xstd

type date_interval = (int * Unix.tm) list
(* type interval = int list *)
type interval = int * int
type left_interval = int
type right_interval = int
    
(*let minutes = List.rev (Int.fold 0 (24 * 60 - 1) [] (fun l i -> (i,i) :: l))
let hours = List.rev (Int.fold 0 23 [] (fun l i -> (i * 60, i * 60 + 59) :: l))
let day = [0, 24 * 60 - 1]
let make_day_future hour minute = [hour * 60 + minute, 24 * 60 - 1]
let make_day_past hour minute = [0, hour * 60 + minute]*)

let empty_date_interval = []
(* let empty_interval = [] *)

let check_interval l =
  if l = [] then failwith "check_interval" else
  let i = Xlist.fold (List.tl l) (List.hd l) (fun i t ->
    if i + 1 = t then t else 0) in
  i <> 0

(*let interval_of_date_interval l =
  List.rev (Xlist.rev_map l fst)*)
  
let interval_of_date_interval l =
  let l = List.rev (Xlist.rev_map l fst) in
  if not (check_interval l) then failwith "interval_of_date_interval" else
  let t1 = List.hd l in
  let t2 = List.hd (List.rev l) in
  t1, t2
  
let left_interval_of_interval (s,t) = s
let left_interval_of_interval2 (s,t) = t
let right_interval_of_interval (s,t) = t
let right_interval_of_interval2 (s,t) = s
  
let get_tm t = 
  Unix.localtime (float (t * 60 * 60 * 24))
  
let create_date_interval start length =
  List.rev (Int.fold 0 length [] (fun time i ->
      let t = (*now*)start + i in
      let tm = get_tm t in
      (t,tm) :: time))
    
let make_days time =
  List.rev (Xlist.rev_map time (fun (t,tm) -> [t,tm]))
    
let rec make_weeks rev rev2 = function
    (t,tm) :: future -> 
      if tm.Unix.tm_wday = 1 && rev <> [] then 
        make_weeks [t,tm] ((List.rev rev) :: rev2) future
      else make_weeks ((t,tm) :: rev) rev2 future
  | [] -> if rev = [] then List.rev rev2 else List.rev ((List.rev rev) :: rev2)
  
let rec make_months rev rev2 = function
    (t,tm) :: future -> 
      if tm.Unix.tm_mday = 1 && rev <> [] then 
        make_months [t,tm] ((List.rev rev) :: rev2) future
      else make_months ((t,tm) :: rev) rev2 future
  | [] -> if rev = [] then List.rev rev2 else List.rev ((List.rev rev) :: rev2)
  
let rec make_years rev rev2 = function
    (t,tm) :: future -> 
      if tm.Unix.tm_yday = 0 && rev <> [] then 
        make_years [t,tm] ((List.rev rev) :: rev2) future
      else make_years ((t,tm) :: rev) rev2 future
  | [] -> if rev = [] then List.rev rev2 else List.rev ((List.rev rev) :: rev2)
    
(*let get_subsets interval l =
  let set = Xlist.fold interval IntSet.empty (fun set t -> IntSet.add set t) in
  List.rev (Xlist.fold l [] (fun l i ->
    let i = List.rev (Xlist.fold i [] (fun i t -> if IntSet.mem set t then t :: i else i)) in
    if i = [] then l else i :: l))*)
    
let intersect (s1,t1) (s2,t2) =
  if t1 < s2 || t2 < s1 then [] else
  [max s1 s2, min t1 t2]
    
let get_subsets interval l =
  List.flatten (List.rev (Xlist.rev_map l (fun i ->
    intersect interval i)))
    
(*let get_min ll =
  Xlist.fold ll max_int (fun n l ->
    Xlist.fold l n (fun n t -> min n t))*)
    
let get_min ll =
  Xlist.fold ll max_int (fun n (s,t) -> min n s)
    
(*let is_empty_interval s = 
  s = []*)
    
(*let get_greater_equal n l =
  List.rev (Xlist.fold l [] (fun l t -> 
    if t >= n then t :: l else l))
  
let get_lesser_equal n l =
  List.rev (Xlist.fold l [] (fun l t -> 
    if t <= n then t :: l else l))*)
    
let get_greater_equal n (s,t) =
  if n < s then [s,t] else
  if n > t then [] else
  [n,t]

let get_lesser_equal n (s,t) =
  if n < s then [] else
  if n > t then [s,t] else
  [s,n]

let shift (s,t) n = 
  s+n, t+n
  
let shift_left s n = 
  s+n
  
let shift_right s n = 
  s+n
  
let is_member_left (s,t) x =
(*   Xlist.fold l false (fun b (s,t) -> *)
    if s <= x && x <= t then true else false
    
let is_member_right (s,t) x =
(*   Xlist.fold l false (fun b (s,t) -> *)
    if s <= x && x <= t then true else false

let rec merge_rec rev = function
    (s1,t1) :: (s2,t2) :: l -> if s2 <= t1+1 then merge_rec rev ((s1, max t1 t2) :: l) else merge_rec ((s1,t1) :: rev) ((s2,t2) :: l)
  | [s,t] -> merge_rec ((s,t) :: rev) []
  | [] -> List.rev rev
  
let merge l = merge_rec [] l
    
let merge_left l =
  if l = [] then [] else
  [Xlist.fold l max_int (fun n s -> min n s)]
  
let merge_right l =
  if l = [] then [] else
  [Xlist.fold l max_int (fun n t -> min n t)]
  
let intersect_left (s,t) l =
  List.flatten (List.rev (Xlist.rev_map l (fun x -> 
    if s <= x && x <= t then [x,t] else [])))
  
let intersect_right (s,t) l =
  List.flatten (List.rev (Xlist.rev_map l (fun x -> 
    if s <= x && x <= t then [s,x] else [])))
  
let smallest_intersect s l =
  if l = [] then [] else
  let t = Xlist.fold l max_int (fun n t ->
    if t >= s then min n t else n) in
  [s,t]
  
let compare_fst a b = compare (fst a) (fst b)

let sort l =
  List.sort compare_fst l
  
let rec revert_rec rev = function
    (s1,t1) :: (s2,t2) :: l -> revert_rec ((t1+1,s2-1) :: rev) ((s2,t2) :: l)
  | [s,t] -> List.rev ((t+1,max_int) :: rev)
  | [] -> failwith "revert_rec"
  
let revert l =
  if l = [] then failwith "revert" else
  let s,_ = List.hd l in
  revert_rec [min_int,s-1] l
  
let revert_left l =
  List.rev (Xlist.rev_map l (fun s -> s-1))
  
let revert_right l =
  List.rev (Xlist.rev_map l (fun s -> s+1))
  
let string_of_date tm =
  Printf.sprintf "%d-%02d-%02d" (1900+tm.Unix.tm_year) (tm.Unix.tm_mon+1) tm.Unix.tm_mday
    
let string_of_hour i =
  Printf.sprintf "%02d:%02d:00" (i/60) (i mod 60)
    
open Xjson
  
(*let json_of_interval = function
          [] -> JString "EMPTY INTERVAL"
        | [t] -> JObject["at",JString (string_of_date (get_tm t))]
        | l2 -> 
            if check_interval l2 then 
              let t1 = List.hd l2 in
              let t2 = List.hd (List.rev l2) in
              JObject["begin",JString (string_of_date (get_tm t1));"end",JString (string_of_date (get_tm t2))]
            else 
              JObject["INVALID INTERVAL",JArray(
                Xlist.map l2 (fun t ->
                  JString (string_of_date (get_tm t))))]*)
                  
let json_of_interval (s,t) = 
  if s = t then JObject["at",JString (string_of_date (get_tm t))] else
  if s < t then JObject["begin",JString (string_of_date (get_tm s));"end",JString (string_of_date (get_tm t))] else
  JObject["INVALID INTERVAL",JObject["begin",JString (string_of_date (get_tm s));"end",JString (string_of_date (get_tm t))]]
                  
let json_of_left_interval s = 
  JObject["begin",JString (string_of_date (get_tm s))]
  
let json_of_right_interval s = 
  JObject["end",JString (string_of_date (get_tm s))]
  
(*let json_of_hour_interval (s,t) = 
  if s = t then JObject["at",JString (string_of_hour t)] else
  if s < t then JObject["begin",JString (string_of_hour s);"end",JString (string_of_hour t)] else
  JObject["INVALID INTERVAL",JObject["begin",JString (string_of_hour s);"end",JString (string_of_hour t)]]
                  
let json_of_hour_left_interval s = 
  JObject["begin",JString (string_of_hour s)]
  
let json_of_hour_right_interval s = 
  JObject["end",JString (string_of_hour s)]*)
                  
                  
                  
