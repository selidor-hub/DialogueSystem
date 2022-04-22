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

type date_interval 
type interval 
type left_interval
type right_interval
    
(*val minutes : interval list
val hours : interval list
val day : interval list
val make_day_future : int -> int -> interval list
val make_day_past : int -> int -> interval list*)
    
val empty_date_interval : date_interval
(* val empty_interval : interval *)

val interval_of_date_interval : date_interval -> interval

val left_interval_of_interval : interval -> left_interval
val left_interval_of_interval2 : interval -> left_interval
val right_interval_of_interval : interval -> right_interval
val right_interval_of_interval2 : interval -> right_interval

val create_date_interval : int -> int -> date_interval

val make_days : date_interval -> date_interval list
    
val make_weeks : date_interval -> date_interval list -> date_interval -> date_interval list
  
val make_months : date_interval -> date_interval list -> date_interval -> date_interval list
  
val make_years : date_interval -> date_interval list -> date_interval -> date_interval list

    
val get_subsets : interval -> interval list -> interval list
    
val get_min : interval list -> int
    
(* val is_empty_interval : interval -> bool *)
    
val get_greater_equal : int ->  interval -> interval list 
  
val get_lesser_equal : int ->  interval -> interval list

val shift : interval -> int -> interval
val shift_left : left_interval -> int -> left_interval
val shift_right : right_interval -> int -> right_interval

val is_member_left : interval -> left_interval -> bool
val is_member_right : interval -> right_interval -> bool

val merge : interval list -> interval list
val merge_left : left_interval list -> left_interval list
val merge_right : right_interval list -> right_interval list

val intersect_left : interval -> left_interval list -> interval list
val intersect_right : interval -> right_interval list -> interval list

val smallest_intersect : left_interval -> right_interval list -> interval list

val sort : interval list -> interval list

val revert : interval list -> interval list
val revert_left : left_interval list -> right_interval list
val revert_right : right_interval list -> left_interval list

val json_of_interval : interval -> Xjson.json
val json_of_left_interval : left_interval -> Xjson.json
val json_of_right_interval : right_interval -> Xjson.json

(*val json_of_hour_interval : interval -> Xjson.json
val json_of_hour_left_interval : left_interval -> Xjson.json
val json_of_hour_right_interval : right_interval -> Xjson.json*)
