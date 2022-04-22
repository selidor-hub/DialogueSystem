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

let compare_fst a b = compare (fst a) (fst b)

let single_objects = StringSet.of_list [
  "minute"; "monthday"; "weekday"; "month"; "week"; "year"; 
  "not"; "begin"; "end"; "aprox"; "before"; "after"; "at"; "sort";
  "selected";"any";"only";"other";"exactly";"somewhat";"some";"towards";"such";"this";
  "greater-eq";"greater";"less";"less-eq";"attitude"]
  
let rec split_jobjects = function
    JObject[s,JArray l] when s="and" || s="or" || s="with" ->
      let l = Xlist.rev_map l split_jobjects in
      JObject[s,JArray l]
  | JObject l ->
      let single,time_of_day,selector,hour = Xlist.fold l ([],[],[],[]) (fun (single,time_of_day,selector,hour) -> function
          e,t when StringSet.mem single_objects e -> (e,split_jobjects t) :: single,time_of_day,selector,hour
        | e,t when e="time-of-day" || e="time-of-day-mod" -> single,(e,split_jobjects t) :: time_of_day,selector,hour
        | e,t when e="element" || e="index" || e="set" -> single,time_of_day,(e,split_jobjects t) :: selector,hour
        | e,t when e="hour" || e="hour-mod" -> single,time_of_day,selector,(e,split_jobjects t) :: hour
        | e,t -> if !debug then failwith ("split_jobjects: " ^ json_to_string (JObject[e,t])) else single,time_of_day,selector,hour) in
      JObject["and",JArray(
        (if time_of_day = [] then [] else [JObject (List.sort compare_fst time_of_day)]) @
        (if selector = [] then [] else [JObject (List.sort compare_fst selector)]) @
        (if hour = [] then [] else [JObject (List.sort compare_fst hour)]) @
        (Xlist.rev_map single (fun (e,t) -> JObject[e,t])))]
  | JString s -> JString s
  | JNumber n -> JNumber n
  | JEmpty -> JEmpty
  | t -> if !debug then failwith ("split_jobjects: " ^ json_to_string_fmt2 "" t) else JEmpty

   
(* FIXME: należałoby uwzględnić wąskie i szerokie zakresy i zmienić rozszerzalność na both *)  
let make_time_of_day a b =
  And[Begin(Selector(Hour,a,Day));End(Selector(Hour,b,Day))]
  
let rec translate_index i =
  try int_of_string i with _ -> failwith "translate_index"
  
let apply_hour_mod i m = 
  if i > 12 then i else
  match m with
    "night" -> if i >= 8 then i + 12 else i
  | "pre-morning" -> i
  | "morning" -> i
  | "before-noon" -> i
  | "noon" -> if i <= 4 then i + 12 else i
  | "afternoon" -> if i <= 7 then i + 12 else i
  | "evening" -> i + 12
  | s -> failwith ("apply_hour_mod: " ^ s)
    
  
let remove_unspecified l f =
  let l = Xlist.fold l [] (fun l t -> if t = Unspecified then l else t :: l) in
  match l with 
    [] -> Unspecified
  | [t] -> t
  | l -> f l
  
let rec translate = function
    JObject["and",JArray l] -> remove_unspecified (Xlist.rev_map l translate) (fun l -> And l)
  | JObject["or",JArray l] -> Or(Xlist.rev_map l translate)
  | JObject["with",JArray l] -> With(Xlist.rev_map l translate)
  | JObject["element",e;"index",JObject[op,JArray l];"set",s] when op = "and" || op = "or" || op = "with" -> 
      translate (JObject[op,JArray(Xlist.rev_map l (fun t -> JObject["element",e;"index",t;"set",s]))])
  | JObject["element",e;"index",JNumber i;"set",s]  -> Selector(translate e,translate_index i,translate s)
  | JObject["element",e;"set",s]  -> SelectorAny(translate e,translate s)
  | JObject[s,JObject[op,JArray l]] when (op = "and" || op = "or" || op = "with") &&
    (s = "minute" || s = "hour" || s = "monthday" || s = "weekday" || s = "month" || s = "year" || s = "time-of-day" || s = "sort") -> 
      translate (JObject[op,JArray(Xlist.rev_map l (fun t -> JObject[s,t]))])
  | JObject[s,JObject[op,t]] when (op = "not" || op = "begin" || op = "end" || op = "aprox" || 
     op = "before" || op = "after" || op = "at" || op = "greater-eq" || op = "less-eq" || op = "less" || op = "greater" || op = "any" || op = "only" || op = "other" || op = "exactly" || op = "somewhat" || op = "some" || op = "this" || op = "such") &&
    (s = "minute" || s = "hour" || s = "monthday" || s = "weekday" || s = "month" || s = "year" || s = "time-of-day") -> 
      translate (JObject[op,JObject[s,t]])
  | JObject[s,JObject["attitude",t]] when (s = "minute" || s = "hour" || s = "monthday" || s = "weekday" || s = "month" || s = "year" || s = "time-of-day") -> Unspecified
  | JObject["minute",JObject["sort", t]] -> Sort(Minute,translate_dir t)
  | JObject["hour",JObject["sort", t]] -> Sort(Hour,translate_dir t)
  | JObject["monthday",JObject["sort", t]] -> Sort(Day,translate_dir t)
  | JObject["weekday",JObject["sort", t]] -> Sort(Day,translate_dir t)
  | JObject["month",JObject["sort", t]] -> Sort(Month,translate_dir t)
  | JObject["year",JObject["sort", t]] -> Sort(Year,translate_dir t)
  | JObject["minute",JObject["selected",JString "slot"]] -> Selected Minute
  | JObject["hour",JObject["selected",JString "slot"]] -> Selected Hour
  | JObject["monthday",JObject["selected",JString "slot"]] -> Selected Day
  | JObject["weekday",JObject["selected",JString "slot"]] -> Selected Day
  | JObject["month",JObject["selected",JString "slot"]] -> Selected Month
  | JObject["year",JObject["selected",JString "slot"]] -> Selected Year
  | JObject["minute",JNumber i] -> Selector(Minute,translate_index i,Hour)
  | JObject["hour",JNumber i;"hour-mod",JString hour_mod] -> Selector(Hour,apply_hour_mod (translate_index i) hour_mod,Day)
  | JObject["hour",JNumber i] -> Selector(Hour,translate_index i,Day)
  | JObject["monthday",JNumber i] -> Selector(Day,translate_index i,Month)
  | JObject["weekday",JNumber i] -> Selector(Day,translate_index i,Week)
  | JObject["month",JNumber i] -> Selector(Month,translate_index i,Year)
  | JObject["year",JNumber i] -> Selector(Year,translate_index i,Time)
  | JObject["time-of-day",JString "pre-morning"] -> make_time_of_day 3 7
  | JObject["time-of-day",JString "morning"] -> make_time_of_day 6 10
  | JObject["time-of-day",JString "morning"; "time-of-day-mod",JString "early"] -> make_time_of_day 6 8
  | JObject["time-of-day",JString "morning"; "time-of-day-mod",JString "late"] -> make_time_of_day 9 12
  | JObject["time-of-day",JString "before-noon"] -> make_time_of_day 8 12
  | JObject["time-of-day",JString "before-noon"; "time-of-day-mod",JString "early"] -> make_time_of_day 8 10
  | JObject["time-of-day",JString "before-noon"; "time-of-day-mod",JString "late"] -> make_time_of_day 10 12
  | JObject["time-of-day",JString "afternoon"] -> make_time_of_day 12 18
  | JObject["time-of-day",JString "afternoon"; "time-of-day-mod",JString "early"] -> make_time_of_day 12 15
  | JObject["time-of-day",JString "afternoon"; "time-of-day-mod",JString "late"] -> make_time_of_day 15 19
  | JObject["time-of-day",JString "after-work"] -> make_time_of_day 17 23
  | JObject["time-of-day",JString "evening"] -> make_time_of_day 18 22
  | JObject["time-of-day",JString "evening"; "time-of-day-mod",JString "early"] -> make_time_of_day 18 20
  | JObject["time-of-day",JString "evening"; "time-of-day-mod",JString "late"] -> make_time_of_day 20 23
  | JObject["time-of-day",JString "night"] -> make_time_of_day 22 6 (* FIXME *)
  | JObject["not",t] -> Not(translate t)
  | JObject["begin",t] -> Begin(translate t)
  | JObject["end",t] -> End(translate t)
  | JObject["aprox",t] -> Aprox(translate t)
  | JObject["before",t] -> Before(translate t)
  | JObject["after",t] -> After(translate t)
  | JObject["at",t] -> At(translate t)
  | JObject["greater-eq",t] -> Begin(translate t)
  | JObject["less-eq",t] -> End(translate t)
  | JObject["less",t] -> Before(translate t)
  | JObject["greater",t] -> After(translate t)
  | JObject["sort", t] -> Sort(Time,translate_dir t)
  | JObject["selected",JString "slot"] -> Selected Time
  | JObject["any",t] -> Any(translate t)
  | JObject["only",t] -> Only(translate t)
  | JObject["other",t] -> Other(translate t)
  | JObject["exactly",t] -> Exactly(translate t)
  | JObject["somewhat",t] -> Somewhat(translate t)
  | JObject["some",t] -> translate t
  | JObject["such",t] -> translate t
  | JObject["this",t] -> translate t
  | JString "minute" -> Minute
  | JString "hour" -> Hour
  | JString "day" -> Day
  | JString "week" -> Week
  | JString "month" -> Month
  | JString "year" -> Year
  | JString "future" -> Future
  | JString "past" -> Past
  | JString "slot" -> Time
  | JObject[_,JString "?"] -> Unspecified
  | JObject["attitude",_] -> Unspecified
  | JString "?" -> Unspecified
  | JEmpty -> Unspecified
  | t -> if !debug then failwith ("translate: " ^ json_to_string t) else Unspecified
 
and translate_dir = function
    JString "ascending" -> Ascending
  | JString "descending" -> Descending
  | JObject["towards",t] -> Towards(translate t)
  | t -> if !debug then failwith ("translate_dir: " ^ json_to_string t) else UnspecifiedDir
  

let rec normalize = function
    And l -> remove_unspecified l (fun l -> And l)
  | Or l -> remove_unspecified l (fun l -> Or l)
  | With l -> remove_unspecified l (fun l -> With l) (* FIXME: likwidowanie Unspecified zmienia semantykę *)
  | Selector(Unspecified,i,s) -> Unspecified
  | SelectorAny(Unspecified,s) -> Unspecified
  | Not Unspecified -> Unspecified
  | Begin Unspecified -> Unspecified
  | End Unspecified -> Unspecified
  | Aprox Unspecified -> Unspecified
  | Before Unspecified -> Unspecified
  | After Unspecified -> Unspecified
  | At Unspecified -> Unspecified
  | Sort(_,UnspecifiedDir) -> Unspecified
  | Any Unspecified -> Unspecified
  | Only Unspecified -> Unspecified
  | Other Unspecified -> Unspecified
  | Exactly Unspecified -> Unspecified
  | Somewhat Unspecified -> Unspecified
  | Selected Unspecified -> Unspecified
  | t -> t
  
let rec select_date = function
    And l -> normalize (And(Xlist.rev_map l select_date))
  | Or l -> normalize (Or(Xlist.rev_map l select_date))
  | With l -> normalize (With(Xlist.rev_map l select_date))
  | Selector(e,i,s) -> normalize (Selector(select_date e,i,s))
  | SelectorAny(e,s) -> normalize (SelectorAny(select_date e,s))
  | Unspecified -> Unspecified
  | Not t -> normalize (Not(select_date t))
  | Begin t -> normalize (Begin(select_date t))
  | End t -> normalize (End(select_date t))
  | Aprox t -> select_date t
  | Before t -> normalize (Before(select_date t))
  | After t -> normalize (After(select_date t))
  | At t -> select_date t
  | Any t -> select_date t
  | Only t -> select_date t
  | Other t -> normalize (Other(select_date t))
  | Exactly t -> select_date t
  | Somewhat t -> select_date t
  | Selected t -> normalize (Selected(select_date t))
  | Minute -> Unspecified
  | Hour -> Unspecified
  | Day as t -> t
  | Week as t -> t
  | Month as t -> t
  | Year as t -> t
  | Time -> Unspecified
  | Sort(_,Towards t) -> select_date t
  | Sort _ -> Unspecified
  | t -> if !debug then failwith ("select_date: " ^ string_of_t t) else Unspecified
  
let rec select_hour = function
    And l -> normalize (And(Xlist.rev_map l select_hour))
  | Or l -> normalize (Or(Xlist.rev_map l select_hour))
  | With l -> normalize (With(Xlist.rev_map l select_hour))
  | Selector(e,i,s) -> normalize (Selector(select_hour e,i,s))
  | SelectorAny(e,s) -> normalize (SelectorAny(select_hour e,s))
  | Unspecified -> Unspecified
  | Not t -> normalize (Not(select_hour t))
  | Begin t -> normalize (Begin(select_hour t))
  | End t -> normalize (End(select_hour t))
  | Aprox t -> normalize (Aprox(select_hour t))
  | Before t -> normalize (Before(select_hour t))
  | After t -> normalize (After(select_hour t))
  | At t -> normalize (At(select_hour t))
  | Any t -> select_hour t
  | Only t -> select_hour t
  | Other t -> normalize (Other(select_hour t))
  | Exactly t -> select_hour t
  | Somewhat t -> normalize (Somewhat(select_hour t))
  | Selected t -> normalize (Selected(select_hour t))
  | Minute as t -> t
  | Hour as t -> t
  | Day -> Unspecified
  | Week -> Unspecified
  | Month -> Unspecified
  | Year -> Unspecified
  | Time as t -> t
  | Sort(_,Towards t) -> select_hour (Aprox t)
  | Sort _ -> Unspecified
  | t -> if !debug then failwith ("select_hour: " ^ string_of_t t) else Unspecified

let rec select_preference = function
    And l -> normalize (And(Xlist.rev_map l select_preference))
  | Or l -> normalize (Or(Xlist.rev_map l select_preference))
  | With l -> normalize (With(Xlist.rev_map l select_preference))
  | Selector _ -> Unspecified
  | SelectorAny _ -> Unspecified
  | Unspecified -> Unspecified
  | Not _ -> Unspecified
  | Begin _ -> Unspecified
  | End _ -> Unspecified
  | Aprox _ -> Unspecified
  | Before _ -> Unspecified
  | After _ -> Unspecified
  | At _ -> Unspecified
  | Selected _ -> Unspecified
  | Any Time -> Any Time
  | Any t -> (*print_endline ("select_preference 1: " ^ string_of_t t);*)
      (match select_date t, select_hour t with
        Unspecified,Unspecified -> (*print_endline "select_preference 2";*) Any Time
      | Unspecified,_ -> (*print_endline "select_preference 3";*) Any Hour
      | _,Unspecified -> (*print_endline "select_preference 4";*) Any Day
      | _,_ -> (*print_endline "select_preference 5";*) Any Time)
  | Only t | Exactly t -> 
      (match select_date t, select_hour t with
        Unspecified,Unspecified -> Only Time
      | Unspecified,_ -> Only Hour
      | _,Unspecified -> Only Day
      | _,_ -> Only Time)
  | Other t -> select_preference t
  | Somewhat t -> select_preference t
  | Sort(_,Towards _) -> Unspecified
  | Sort(t,dir) -> Sort(t,dir)
  | Minute -> Unspecified
  | Hour -> Unspecified
  | Day -> Unspecified
  | Week -> Unspecified
  | Month -> Unspecified
  | Year -> Unspecified
  | Time -> Unspecified
  | t -> if !debug then failwith ("select_preference: " ^ string_of_t t) else Unspecified
