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
 
type t = 
    And of t list
  | Or of t list
  | With of t list
  | Selector of t * int * t (* element * index * set *)
  | SelectorAny of t * t (* element * set *)
  | Minute
  | Hour
  | Day
  | Month
  | Week
  | Year
  | Future
  | Past
  | Time
  | Not of t
  | Begin of t
  | End of t
  | Aprox of t
  | Before of t
  | After of t
  | At of t
  | Unspecified
  | Selected of t
  | Sort of t * dir
  | Any of t
  | Only of t
  | Other of t
  | Exactly of t
  | Somewhat of t

and dir = 
    Ascending 
  | Descending
  | Towards of t
  | UnspecifiedDir
   

let rec string_of_t = function
    And l -> "and[" ^ String.concat ";" (Xlist.map l string_of_t) ^ "]"
  | Or l -> "or[" ^ String.concat ";" (Xlist.map l string_of_t) ^ "]"
  | With l -> "with[" ^ String.concat ";" (Xlist.map l string_of_t) ^ "]"
  | Selector(e,i,s) -> "{" ^ string_of_int i ^ ":" ^ string_of_t e ^ "/" ^ string_of_t s ^ "}"
  | SelectorAny(e,s) -> "{" ^ string_of_t e ^ "/" ^ string_of_t s ^ "}"
  | Minute -> "minute"
  | Hour -> "hour"
  | Day -> "day"
  | Month -> "month"
  | Week -> "week"
  | Year -> "year"
  | Future -> "future"
  | Past -> "past"
  | Time -> "time"
  | Not t -> "not(" ^ string_of_t t ^ ")"
  | Begin t -> "begin(" ^ string_of_t t ^ ")"
  | End t -> "end(" ^ string_of_t t ^ ")"
  | Aprox t -> "aprox(" ^ string_of_t t ^ ")"
  | Before t -> "before(" ^ string_of_t t ^ ")"
  | After t -> "after(" ^ string_of_t t ^ ")"
  | At t -> "at(" ^ string_of_t t ^ ")"
  | Unspecified -> "unspecified"
  | Selected t -> "selected(" ^ string_of_t t ^ ")"
  | Sort(t,dir) -> "sort("^ string_of_t t ^ "," ^ string_of_dir dir ^ ")"
  | Any t -> "any(" ^ string_of_t t ^ ")"
  | Only t -> "only(" ^ string_of_t t ^ ")"
  | Other t -> "other(" ^ string_of_t t ^ ")"
  | Exactly t -> "exactly(" ^ string_of_t t ^ ")"
  | Somewhat t -> "somewhat(" ^ string_of_t t ^ ")"

and string_of_dir = function
    Ascending -> "ascending"
  | Descending -> "descending"
  | UnspecifiedDir -> "unspecified"
  | Towards t -> "towards(" ^ string_of_t t ^ ")"

let start_year = 2017
  
let debug = ref false
