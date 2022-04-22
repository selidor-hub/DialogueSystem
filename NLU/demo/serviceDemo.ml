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
  "Usage: service_demo <options>\nOptions are:"
  
let anon_fun s = raise (Arg.Bad ("invalid argument: " ^ s))

let load_id_service filename =
  File.fold_tab filename IntMap.empty (fun map -> function
    | ["";_;_;_] -> failwith "load_id_service"
    | [_;"";_;""] -> failwith "load_id_service"
    | [usluga1;id1;"";""] -> IntMap.add_inc map (int_of_string id1) usluga1 (fun x -> x ^ " | " ^ usluga1)
    | [usluga1;id1;usluga2;id2] -> 
        let u = usluga1 ^ " -> " ^ usluga2 in
        IntMap.add_inc map (int_of_string id2) u (fun x -> x ^ " | " ^ u)
    | line -> failwith ("load_id_service: " ^ String.concat "\t" line))
 
type t = F of string | T of string | NL | TAB

(*type r = {levels: string list;usluga: string;id: string;popularity: string}

let empty_record =
  {levels=[]; usluga=""; id=""; popularity=""}*)
  
let rec parse_separators rev = function
    "\"" :: "\"" :: _ -> failwith "parse_separators: ni"
  | "\"" :: s :: "\"" :: "\"" :: "\"" :: l -> failwith "parse_separators: ni"
  | "\"" :: s :: "\"" :: "\"" :: t :: l -> parse_separators rev ("\"" :: (s^"\""^t) :: l)
  | "\"" :: s :: "\"" :: l -> parse_separators (F s :: rev) l
  | "\"" :: _ -> failwith "parse_separators: ni"
  | s :: l -> parse_separators (T s :: rev) l
  | [] -> List.rev rev
  
let rec split_into_lines rev rev2 = function
    NL :: l -> split_into_lines [] ((List.rev rev) :: rev2) l
  | t :: l -> split_into_lines (t :: rev) rev2 l
  | [] -> if rev = [] then List.rev rev2 else List.rev ((List.rev rev) :: rev2)

let rec split_into_fields rev = function
    NL :: _ -> failwith "split_into_fields"
  | T _ :: _ -> failwith "split_into_fields"
  | TAB :: l -> split_into_fields ("" :: rev) l
  | F s :: TAB :: l -> split_into_fields (s :: rev) l
  | [F s] -> split_into_fields (s :: rev) []
  | F s :: _ -> failwith "split_into_fields+"
  | [] -> List.rev rev

let rec print_service_tree spaces = function
    L(usluga,id,populariny) -> Printf.printf "%s[%s : %d]\n" spaces usluga id
  | N map -> StringMap.iter map (fun a tree ->
      Printf.printf "%s%s\n" spaces a;
      print_service_tree (spaces ^ "  ") tree)
  | E -> Printf.printf "%sEMPTY\n" spaces
  
let rec create_service_tree l =
  if l = [] then failwith "create_service_tree 1" else
  let levels,usluga,id,populariny = List.hd l in
  if levels = [] then 
    if Xlist.size l > 1 then (
      Xlist.iter l (fun (levels,usluga,id,populariny) -> print_endline usluga);
      failwith "create_service_tree 2") else
    L(usluga,id,populariny) else
  let map,_ = Xlist.fold l (StringMap.empty,"") (fun (map,a) (levels,usluga,id,populariny) ->
    let a = if List.hd levels = "" then a else List.hd levels in 
    StringMap.add_inc map a [List.tl levels,usluga,id,populariny] (fun l -> (List.tl levels,usluga,id,populariny) :: l), a) in
  let map = StringMap.map map (fun l -> create_service_tree (List.rev l)) in
  N map
  
let rec remove_x_from_service_tree = function
    L _ as t -> t
  | N map -> 
      if StringMap.mem map "x" then
        if StringMap.size map = 1 then 
          remove_x_from_service_tree (StringMap.find map "x") 
        else (
          print_service_tree "" (N map);
          failwith "remove_x_from_service_tree")
      else N(StringMap.map map remove_x_from_service_tree)
  | E -> failwith "remove_x_from_service_tree"
        
let rec select_subtree ids = function
    L(_,id,_) as t -> if IntSet.mem ids id then t else E
  | N map -> 
      let map = StringMap.fold map StringMap.empty (fun map a tree ->
        let tree = select_subtree ids tree in
        if tree = E then map else
        StringMap.add map a tree) in
      if StringMap.is_empty map then E else
      if StringMap.size map = 1 then StringMap.fold map E (fun _ _ t -> t) else
      N map
  | E -> failwith "select_subtree"
          
let load_service_tree filename =
  let l = parse_separators [] (Xstring.full_split "\"" (File.load_file filename)) in
  let l = List.rev (List.flatten (Xlist.rev_map l (function 
      NL -> [NL] 
    | TAB -> [TAB] 
    | F s -> [F s] 
    | T s -> Xlist.rev_map (Xstring.full_split "\n\\|\t" s) (function "\n" -> NL | "\t" -> TAB | s -> F s)))) in
  let l = split_into_lines [] [] l in
  let l = List.rev (Xlist.rev_map l (split_into_fields [])) in
  let l = List.rev (Xlist.rev_map l (fun fields -> List.rev (Xlist.rev_map fields Xstring.remove_white))) in  
  let l = List.tl l in
  let l = List.rev (Xlist.fold l [] (fun l -> function
      ["";"";"";"";"";"";"";"";"";"";""] -> l
    | ["";"";"";"";"";"";"";"";"";""] -> l
    | ["";"";"";"";"";"";"";"";""] -> l
    | ["";"";"";"";"";"";"";""] -> l
    | ["";"";"";"";"";"";""] -> l
    | ["";"";"";"";"";""] -> l
    | ["";"";"";"";""] -> l
    | [level0;level1;level2;level3;level4;level5;level6;level7;usluga;id;popularity] ->
        if level7 = "" then failwith "load_service_tree 2" else
        let id = try int_of_string id with _ -> failwith "load_service_tree 3" in
        let popularity = try int_of_string popularity with _ -> failwith "load_service_tree 4" in
        ([level0;level1;level2;level3;level4;level5;level6;level7],usluga,id,popularity) :: l
    | line -> failwith ("load_service_tree: " ^ String.concat "'\t'" line))) in
  let tree = create_service_tree l in
(*   print_service_tree "" tree; *)
  let tree = remove_x_from_service_tree tree in
(*   print_service_tree "" tree; *)
  tree
 
let rec parse_service_ids set = function
    JObject[op,JArray l] -> Xlist.fold l set parse_service_ids
  | JObject l -> failwith "parse_service_ids"
  | JNumber n -> IntSet.add set (try int_of_string n with _ -> failwith "parse_service_ids")
  | _ -> set
  
let parse_grounded_service = function
    JObject["error", JString s] -> Error s
  | t -> 
     (try
       let l = get_json_key_rec ["service";"id"] [] t in
       let set,is_con,is_uns = Xlist.fold l (IntSet.empty,false,false) (fun (set,is_con,is_uns) -> function
           JString "contradiction" -> set,true,is_uns
         | JString "no data" -> set,is_con,true
         | t -> parse_service_ids set t,is_con,is_uns) in
       if IntSet.size set > 0 then IntSet set else
       if is_con then Contradiction else
       if is_uns then Unspecified else
       failwith "parse_grounded_service"
     with _ -> Error("invalid json format: " ^ json_to_string t))
   
let parse_grounded_cat = function
    JObject["error", JString s] -> Error s
  | t -> 
     (try
       match get_json_key ["category"] t with
         JString "not found" -> Unspecified
       | JString s -> StringList [s]
       | JObject["with",JArray l] -> StringList(Xlist.map l (function JString s -> s | _ -> failwith "parse_grounded_cat"))
       | _ -> failwith "parse_grounded_cat"
     with _ -> Error ("invalid json format: " ^ json_to_string t))
   
let states = Xlist.fold [
  "init", (fun _ t ->
    std_output 0 "Jaką usługę chcesz zarezerwować?";
    t), Next "input and process";
  "input and process", (fun env _ ->
    let s = std_input () in
    std_output 1 ("Napisałeś: " ^ s);
    Printf.fprintf env.eniam_out "%s\n\n%!" s;
    let s = input_text env.eniam_in in
    std_output 1 ("Zrozumiałem: " ^ s);
    let service_grounder_in,service_grounder_out = Unix.open_connection (get_sock_addr "localhost" 9761) in
    Printf.fprintf service_grounder_out "%s\n\n%!" s;
    let s = input_text service_grounder_in in
    Unix.shutdown_connection service_grounder_in;
    std_output 2 ("Uziemiłem jako: " ^ s);  
    let ids = parse_grounded_service (json_of_string s) in
    {empty_slots with service_ids=ids}), Split[
      (fun _ t -> is_error t.service_ids), "error";
      (fun _ t -> t.service_ids = Contradiction), "nonexistant service";
      (fun _ t -> t.service_ids = Unspecified), "unspecified service";
      (fun _ t -> IntSet.size (get_intset t.service_ids) = 1), "single service";
      (fun _ t -> IntSet.size (get_intset t.service_ids) > 1), "multiple service"];
  "nonexistant service", (fun _ t ->
    std_output 0 "Z twojej wypowiedzi wnioskuję, że chcesz zarezerwować więcej niż jedną usługę, ale ta opcja nie jest jeszcze dostępna";
    t), Finish;
  "unspecified service", (fun _ t ->
    std_output 0 "Nie znalazłem nazwy usługi w podanym wyrażeniu";
    std_output 0 "Podaj usługę";
    t), Next "input and process";
  "single service", (fun env t ->
    let id = IntSet.min_elt (get_intset t.service_ids) in
    std_output 0 ("Wybrana usługa to: " ^ string_of_int id ^ ": " ^ IntMap.find env.id_service id);
    t), Finish;
  "multiple service", (fun env t ->
    std_output 1 "Lista usług pasujących do zapytania:";
    IntSet.iter (get_intset t.service_ids) (fun id -> std_output 1 ("  " ^ string_of_int id ^ ": " ^ IntMap.find env.id_service id));        
    let tree = select_subtree (get_intset t.service_ids) env.service_tree in
(*     print_service_tree "" tree; *)
    {t with current_service_tree=tree}), Next "node cat";
  "multiple cat", (fun env t ->
    std_output 1 "Lista pasujących kategorii:";
    Xlist.iter (get_stringlist t.category) (fun cat -> std_output 1 ("  " ^ cat));       
    let selected_categories = StringSet.of_list (get_stringlist t.category) in
    let tree = match t.current_service_tree with
        N map -> N(StringMap.fold map StringMap.empty (fun map c t ->
          if StringSet.mem selected_categories c then StringMap.add map c t else map))
      | _ -> failwith "states: multiple cat" in
(*     print_service_tree "" tree; *)
    {t with current_service_tree=tree}), Next "node cat";
  "single cat", (fun env t ->
    let selected_category =  List.hd(get_stringlist t.category) in
    std_output 1 ("Pasująca kategoria: " ^ selected_category);       
    let tree = match t.current_service_tree with
        N map -> (try StringMap.find map selected_category with Not_found -> E)
      | _ -> failwith "states: single cat" in
(*     print_service_tree "" tree; *)
    {t with current_service_tree=tree}), Split[
      (fun _ t -> t.current_service_tree=E), "error";
      (fun env t -> match t.current_service_tree with L _ -> true | _ -> false), "leaf cat";
      (fun env t -> match t.current_service_tree with N _ -> true | _ -> false), "node cat"];
  "node cat", (fun env t ->
    match t.current_service_tree with
      N map -> 
        let l = StringMap.fold map [] (fun l e _ -> e :: l) in
        std_output 0 ("Dostępne usługi to: " ^ String.concat ", " (Xlist.sort l compare));
        let s = std_input () in
        std_output 1 ("Napisałeś: " ^ s);
        Printf.fprintf env.eniam_out "%s\n\n%!" s;
        let s = input_text env.eniam_in in
        std_output 1 ("Zrozumiałem: " ^ s);
        let q = JObject["categories",JArray(Xlist.map l (fun s -> JString s)); "query", json_of_string s] in
        let cat_grounder_in,cat_grounder_out = Unix.open_connection (get_sock_addr "localhost" 9762) in
        Printf.fprintf cat_grounder_out "%s\n\n%!" (json_to_string q);
        let s = input_text cat_grounder_in in
        Unix.shutdown_connection cat_grounder_in;
        std_output 1 ("Uziemiłem jako: " ^ s); 
        {t with category=parse_grounded_cat (json_of_string s)}
    | _ -> failwith "states: node cat"), Split[
      (fun _ t -> is_error t.category), "error";
      (fun _ t -> t.category = Unspecified), "unspecified cat";
      (fun env t -> Xlist.size (get_stringlist t.category) = 1), "single cat";
      (fun env t -> Xlist.size (get_stringlist t.category) > 1), "multiple cat"];
  "leaf cat", (fun env t ->
    match t.current_service_tree with
      L(_,id,_) ->
        std_output 0 ("Wybrana usługa to: " ^ string_of_int id ^ ": " ^ IntMap.find env.id_service id);
        t
    | _ -> failwith "states: leaf cat"), Finish;
  "unspecified cat", (fun _ t ->
    std_output 0 "Nie znalazłem nazwy usługi w podanym wyrażeniu";
    t), Next "node cat";
  "error", (fun _ t ->
    std_output 0 "error";
    if is_error t.service_ids then std_output 0 ("Napotkałem na błąd: " ^ get_error t.service_ids);
    if is_error t.category then std_output 0 ("Napotkałem na błąd: " ^ get_error t.category);
    t), Finish;
  ] StringMap.empty (fun map (s,f,next) -> StringMap.add map s (f,next))
      
let _ =
  Arg.parse spec_list anon_fun usage_msg;
  check_states_consistency states;
  let eniam_in,eniam_out = Unix.open_connection (get_sock_addr "localhost" 9760) in
  let env = {empty_env with eniam_in; eniam_out; 
    id_service=load_id_service "../grounding/data/usluga1_usluga2.tab";
    service_tree=load_service_tree "../../corpus/sharepoint/tabela-2022-03-07.csv"} in
  execute states "init" env empty_slots;
  ()
  
