(*
 *  service grounder
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
open Xjson

let corpus_mode = ref false
let corpus_filename = ref ""
let comm_stdio = ref true
let port = ref 9761

let spec_list = [
  "-i", Arg.Unit (fun () -> comm_stdio:=true), "Communication using stdio (default)";
  "-p", Arg.Int (fun p -> comm_stdio:=false; port:=p), "<port> Communication using sockets on given port number";
  "-c", Arg.String (fun s -> corpus_mode:=true; corpus_filename:=s), "<filename> Process corpus given as an argument";
  ]

let usage_msg =
  "Usage: service_grounder <options>\nOptions are:"
  
let anon_fun s = raise (Arg.Bad ("invalid argument: " ^ s))

let rec split_json_entry = function
    JObject["and",JArray (t :: l)] -> 
      let text,t = split_json_entry t in 
      text, JObject["and",JArray (t :: l)]
  | JObject l -> 
        let text,l = Xlist.fold l ("",[]) (fun (text,l) -> function
            "text", JString s -> if text = "" then s,l else failwith "split_json_entry 1"
          | e,t -> text, (e,t) :: l) in
        if text = "" then failwith ("split_json_entry 2: " ^ json_to_string (JObject l)) else
        Xstring.remove_spaces text, JObject (List.rev l)
  | _ -> failwith "split_json_entry 3"


(*let load_translate_table name =
  let data = List.rev (File.fold_tab ("data/" ^ name ^ ".tab") [] (fun data -> function
      service :: id :: l -> (service, int_of_string id,l) :: data
    | line -> failwith ("load_translate_table: " ^ String.concat "\t" line))) in
  let json = Xjson.json_of_string (File.load_file ("../../corpus/examples/beauty_" ^ name ^ "_parsed.json")) in
  let l = match json with JArray l -> l | _ -> failwith "load_translate_table 1" in
  let map = Xlist.fold l StringMap.empty (fun map t -> 
    let text, t = split_json_entry t in
    StringMap.add_inc map text t (fun t2 -> if t = t2 then t else failwith ("load_translate_table 2: " ^ text))) in
  List.rev (Xlist.rev_map data (fun (service, id, l) ->
    service, id, Xlist.fold l [] (fun l s ->
      try StringMap.find map s :: l with Not_found -> (*print_endline ("load_translate_table: interpretation of phrase „" ^ s ^ "” not found in " ^ name);*) l)))*)

let attributes = StringSet.of_list ["service";"patient";"name";"param";"flaw";"organization";"type";"part";"part-param";"effect";"artefact";"part-colour";"instrument";"part-length";"person";"doer";"profession";"domain";
"action";"attitude";"greetings";"client-data";"gender";"instance";"instance-param";"time";"after";"element";"index";"set";"hour";"time-of-day";"weekday";"state";"part-quantity";"quantity";"confirmation";"text";"";"";""]

let operators = StringSet.of_list [
  "begin";"end";"aprox";"before";"after";"from";"at";"center";
  "selected";"any";"only";"other";"exactly";"somewhat";"some";"towards";"such";"this";
  "greater-eq";"greater";"less";"less-eq";"not"]

let conversion_list = [
  "wykonawca",["doer#profession"];
  "typ_organizacji",["organization#type"];
  "ulomnosc",["patient#flaw"];
  "czesc_klienta",["patient#part"];
  "podrzednik_czesci_klienta",["patient#part-length";"patient#part-param";"patient#part-quantity"];
  "podtyp_klienta",["patient#person"];
(*  "patient#state#attitude";
  "patient#state#param";
  "patient#state#service#name";
  "quantity";*)
  "dziedzina",["service#domain"];
  "efekt",["service#effect"];
(*  "service#effect#param";
  "service#effect#quantity";*)
  "instrument",["service#instrument"];
  "czesc_glowna",["service#name"];
  "podrzednik_czesci_glownej",["service#param";"service#quantity"]
  ]
   
let add_data conversion (name,paths) =
  let data = List.rev (File.fold_tab ("data/" ^ name ^ ".tab") [] (fun data -> function
      service :: id :: l -> (service, int_of_string id,l) :: data
    | line -> failwith ("add_data: " ^ String.concat "\t" line))) in
  Xlist.fold data conversion (fun conversion (service,id,l) ->
    Xlist.fold l conversion (fun conversion s ->
      Xlist.fold paths conversion (fun conversion path ->
        StringMap.add_inc conversion (path ^ "#" ^ s) [service,id] (fun l -> (service,id) :: l))))
  
let rec add_data2_rec paths conversion = function
    [] -> conversion 
  | (service,id1,l1) :: data -> 
      Printf.printf "%d %!" id1;
      let conversion = Xlist.fold data conversion (fun conversion (_,id2,l2) ->
        let id = (1000000*id1)+id2 in
        Xlist.fold (l1 @ l2) conversion (fun conversion s ->
          Xlist.fold paths conversion (fun conversion path ->
            StringMap.add_inc conversion (path ^ "#" ^ s) (IntSet.singleton id) (fun set -> IntSet.add set id)))) in
      add_data2_rec paths conversion data
  
let add_data2 conversion (name,paths) =
  print_endline ("add_data2: " ^ name);
  let data = List.rev (File.fold_tab ("data/" ^ name ^ ".tab") [] (fun data -> function
      service :: id :: l -> (service, int_of_string id,l) :: data
    | line -> failwith ("add_data: " ^ String.concat "\t" line))) in
  add_data2_rec paths conversion data
  

(*let rec add_data_rec service path conversion = function
    JObject["and",JArray l] -> Xlist.fold l conversion (add_data_rec service path)
  | JObject["or",JArray l] -> Xlist.fold l conversion (add_data_rec service path)
  | JObject["with",JArray l] -> Xlist.fold l conversion (add_data_rec service path)
  | JObject l ->
      Xlist.fold l conversion (fun conversion (e,t) ->
        if StringSet.mem attributes e then add_data_rec service (e :: path) conversion t else
        ((*print_endline ("add_data_rec 1: " ^ json_to_string_fmt2 "" (JObject l));*) conversion))
  | JString "client" -> conversion
  | JString s -> StringMap.add_inc conversion (String.concat "#" (List.rev (s :: path))) [service] (fun l -> service :: l)
  | JNumber s -> StringMap.add_inc conversion (String.concat "#" (List.rev (s :: path))) [service] (fun l -> service :: l)
  | json -> (*print_endline ("add_data_rec 2: " ^ json_to_string_fmt2 "" json);*) conversion
      
let add_data conversion data =
  Xlist.fold data conversion (fun conversion (service,id,l) ->
    Xlist.fold l conversion (add_data_rec (service,id) []))*)
 
let remap_conversion conversion =
  let id_service = StringMap.fold conversion IntMap.empty (fun id_service _ l ->
    Xlist.fold l id_service (fun id_service (service,id) ->
      IntMap.add_inc id_service id service (fun service2 -> if service = service2 then service else service ^ " | " ^ service2(*failwith ("remap_conversion: " ^ service ^ " vs. " ^ service2)*)))) in
  let conversion = StringMap.map conversion (fun l ->
    Xlist.fold l IntSet.empty (fun set (_,id) -> IntSet.add set id)) in
  id_service, conversion
 
let load_corpus filename =
  let json = Xjson.json_of_string (File.load_file filename) in
  let l = match json with JArray l -> l | _ -> failwith "load_corpus" in
  List.rev (Xlist.rev_map l split_json_entry)
 
let rec find_services conversion path found = function
    JObject["and",JArray l] -> Xlist.fold l found (find_services conversion path)
  | JObject["or",JArray l] -> Xlist.fold l found (find_services conversion path)
  | JObject["with",JArray l] -> Xlist.fold l found (find_services conversion path)
  | JObject l ->
      Xlist.fold l found (fun found (e,t) ->
        if StringSet.mem operators e then find_services conversion path found t else        
        if StringSet.mem attributes e then find_services conversion (e :: path) found t else
        ((*print_endline ("find_services 1: " ^ json_to_string_fmt2 "" (JObject l));*) found))
  | JString "client" -> found
  | JString s | JNumber s -> 
      let any_set = 
        if String.concat "#" (List.rev path) = "patient#part" then 
          try StringMap.find conversion (String.concat "#" (List.rev ("dowolna partia ciała" :: path)))
          with Not_found -> ((*print_endline "find_services: not found";*) IntSet.empty)
        else IntSet.empty in
(*       Printf.printf "find_services: |any_set|=%d path=%s\n%!" (IntSet.size any_set) (String.concat "#" path); *)
      (try 
        let set = StringMap.find conversion (String.concat "#" (List.rev (s :: path))) in
        let set = IntSet.union set any_set in
        if IntSet.mem found (-1) then set else
        IntSet.intersection found set
      with Not_found -> found)
  | json -> (*print_endline ("find_services 2: " ^ json_to_string_fmt2 "" json);*) found
 
let rec expand_with = function
    JObject["and",JArray l] -> Xlist.map (Xlist.multiply_list (Xlist.map l expand_with)) (fun l -> JObject["and",JArray l])
  | JObject["or",JArray l] -> Xlist.map (Xlist.multiply_list (Xlist.map l expand_with)) (fun l -> JObject["or",JArray l])
  | JObject["with",JArray l] -> List.flatten (Xlist.multiply_list (Xlist.map l expand_with))
  | JObject l -> 
      Xlist.map (Xlist.multiply_list (Xlist.map l (fun (e,t) -> 
        Xlist.map (expand_with t) (fun t -> e,t)))) (fun l -> JObject l)
  | JString s -> [JString s]
  | JNumber n -> [JNumber n]
  | json -> (*print_endline ("expand_with: " ^ json_to_string_fmt2 "" json);*) [json]

let rec get_value path t =
  match path,t with
    [], JString s -> s
  | path, JObject["and",JArray l] -> 
      Xlist.fold l "" (fun found t ->
        let s = get_value path t in
        if s = "" then found else s)        
  | e :: path, JObject l -> 
      Xlist.fold l "" (fun found (e2,t) ->
        if e <> e2 then found else
        let s = get_value path t in
        if s = "" then found else s)
  | _ -> ""
  
let transfer_gender t =
    let gender = get_value ["client-data";"gender"] t in
    let person = get_value ["patient";"person"] t in
    if person = "client" && gender <> "" then 
      JObject["and",JArray[t;JObject["patient",JObject["gender",JString gender]]]]
    else t
    
let test_corpus id_service conversion (*conversion2*) corpus =
  Xlist.iter corpus (fun (text,t) ->
    print_endline (
      "\n=================================================================\n\n" ^ 
      text ^ "\n\n" ^ json_to_string_fmt2 "" t);
    Xlist.iter (expand_with t) (fun t ->
      print_endline "";
      let t = transfer_gender t in
      let services = find_services conversion [] (IntSet.singleton (-1)) t in
      if IntSet.mem services (-1) then print_endline "No information about service provided" else
      if not (IntSet.is_empty services) then 
      IntSet.iter services (fun id ->
        Printf.printf "%5d %s\n" id (IntMap.find id_service id))
      else
        (*let services2 = find_services conversion2 [] (IntSet.singleton (-1)) t in
        if IntSet.is_empty services2 then*) print_endline "Contradictory information concerning service" (*else
        IntSet.iter services2 (fun id ->
          let id1 = id/1000000 in
          let id2 = id mod 1000000 in
          Printf.printf "%5d %s | %d %s\n" id1 (IntMap.find id_service id1) id2 (IntMap.find id_service id2))*)))
 
let load_id_service filename =
  File.fold_tab filename IntMap.empty (fun map -> function
    | ["";_;_;_] -> failwith "load_id_service"
    | [_;"";_;""] -> failwith "load_id_service"
    | [usluga1;id1;"";""] -> IntMap.add_inc map (int_of_string id1) usluga1 (fun x -> x ^ " | " ^ usluga1)
    | [usluga1;id1;usluga2;id2] -> 
        let u = usluga1 ^ " -> " ^ usluga2 in
        IntMap.add_inc map (int_of_string id2) u (fun x -> x ^ " | " ^ u)
    | line -> failwith ("load_id_service: " ^ String.concat "\t" line))
 
let input_text channel =
  let s = ref (try input_line channel with End_of_file -> "") in
  let lines = ref [] in
  while !s <> "" do
    lines := !s :: !lines;
    s := try input_line channel with End_of_file -> ""
  done;
  String.concat "\n" (List.rev !lines)
  
let rec main_loop conversion (*conversion2*) in_chan out_chan =
  let text = input_text in_chan in
  try
    let t = json_of_string text in
    let l = List.rev (Xlist.rev_map (expand_with t) (fun t ->
      let t2 = transfer_gender t in
      let services = find_services conversion [] (IntSet.singleton (-1)) t2 in
      if IntSet.mem services (-1) then JObject["and",JArray[t;JObject["service",JObject["id",JString "no data"]]]] else
      if not (IntSet.is_empty services) then 
        JObject["and",JArray[t;JObject["service",JObject["id",JObject["with",JArray (Xlist.rev_map (IntSet.to_list services) (fun id -> JNumber (string_of_int id)))]]]]]
      else
        (*let services2 = find_services conversion2 [] (IntSet.singleton (-1)) t in
        if IntSet.is_empty services2 then*) JObject["and",JArray[t;JObject["service",JObject["id",JString "contradiction"]]]] (*else
        JObject["and",JArray[t;JObject["service",JObject["id",JObject["with",JArray (Xlist.rev_map (IntSet.to_list services2) (fun id ->
          let id1 = id/1000000 in
          let id2 = id mod 1000000 in
          JObject["and-tuple",JArray[JNumber (string_of_int id1); JNumber (string_of_int id2)]]))]]]]]*))) in
    let t = Json.normalize (JObject["with",JArray l]) in
    Printf.fprintf out_chan "%s\n\n%!" (json_to_string_fmt2 "" t)
  with e -> 
    let t = JObject["error", JString (Printexc.to_string e)] in
    Printf.fprintf out_chan "%s\n\n%!" (json_to_string_fmt2 "" t)

let _ =
(*   prerr_endline message; *)
  Arg.parse spec_list anon_fun usage_msg;
(*  let conversion = StringMap.empty in
  let conversion = add_data conversion (load_translate_table "usluga1") in
  let conversion = add_data conversion (load_translate_table "usluga2") in
  let conversion = add_data conversion (load_translate_table "kategoria") in
  let conversion = add_data conversion (load_translate_table "synonimy") in
  let conversion = add_data conversion (load_translate_table "podtyp_klienta") in*)
  let conversion = Xlist.fold conversion_list StringMap.empty add_data in
  (*let conversion2 = Xlist.fold conversion_list StringMap.empty add_data2 in*) (* wyłączone wykrywanie par usług *)
  let id_service = load_id_service "data/usluga1_usluga2.tab" in
  let (*id_service*)_, conversion = remap_conversion conversion in
  Gc.compact ();
  prerr_endline "Ready!";
  if !corpus_mode then 
    let corpus = load_corpus !corpus_filename in
    test_corpus id_service conversion (*conversion2*) corpus else
  if !comm_stdio then main_loop conversion (*conversion2*) stdin stdout
  else
    let sockaddr = Unix.ADDR_INET(Unix.inet_addr_any,!port) in
    Unix.establish_server (main_loop conversion (*conversion2*)) sockaddr
  
(*
./service_grounder -c ../../corpus/examples/L2_parsed.json >eff.txt

./service_grounder -p 9761 &
cat ex1.json | netcat localhost 9761
*)

