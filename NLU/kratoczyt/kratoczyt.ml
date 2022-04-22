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
open SubsyntaxTypes
open LatTypes

let spec_list = [
  "-i", Arg.Unit (fun () -> comm_stdio:=true), "Communication using stdio (default)";
  "-p", Arg.Int (fun p -> comm_stdio:=false; port:=p), "<port> Communication using sockets on given port number";
  "-c", Arg.String (fun s -> corpus_mode:=true; corpus_path:=s), "<filename> Process corpus given as an argument";
  ]

let usage_msg =
  "Usage: kratoczyt <options>\nOptions are:"
  
let anon_fun s = raise (Arg.Bad ("invalid argument: " ^ s))

   
(* ENIAM *)

open Xjson

let id = string_of_int (Unix.getpid ())

type output = Text | (*Marked |*) Xml | Html | Marsh | (*FStruct |*) JSON (*| Graphviz*) | Worker

let output = ref (*Html*)JSON
let subsyntax_built_in = ref true
let subsyntax_host = ref "localhost"
let subsyntax_port = ref 5739
(*let morphology_built_in = ref true
let morphology_host = ref "localhost"
let morphology_port = ref 5440*)
let verbosity = ref (*1*)2
let img = ref 1
let timeout = ref 30.
let select_sentence_modes_flag = ref false
let select_sentences_flag = ref true
let semantic_processing_flag = ref true
let inference_flag = ref true
let discontinuous_parsing_flag = ref false
let correct_spelling_flag = ref false
let disambiguate_flag = ref (*true*)false
let select_not_parsed_flag = ref false
let output_dir = ref "results/"
let name_length = ref 20
let split_pattern = ref ""
let max_cost = ref 2
let internet_mode = ref true
let line_mode = ref false
let statistics_flag = ref false

let jnumber_of_float x = 
  let s = string_of_float x in
  if Xstring.check_sufix "." s then Xstring.cut_sufix "." s else s

let rec create_sem_set path found = function
    JObject["and",JArray l] -> Xlist.fold l found (create_sem_set path)
  | JObject["or",JArray l] -> Xlist.fold l found (create_sem_set path)
  | JObject["with",JArray l] -> Xlist.fold l found (create_sem_set path)
  | JObject["and-tuple",JArray l] -> Xlist.fold l found (create_sem_set path)
  | JObject[_,JArray _] as t -> failwith ("create_sem_set: " ^ json_to_string t);
  | JObject l -> Xlist.fold l found (fun found (e,t) -> 
      if e = "text" then found else create_sem_set (e :: path) found t)
  | JString s | JNumber s -> StringSet.add found (String.concat "#" (List.rev (s :: path)))
  | JArray _ as t -> failwith ("create_sem_set: " ^ json_to_string t);
  | json -> found

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

(*let rec split_json_entry2 = function
    JObject["and",JArray (t :: l)] -> 
      let text,t = split_json_entry2 t in 
      text, JObject["and",JArray (t :: l)]
  | JObject["and-tuple",JArray (t :: l)] -> 
      let text,t = split_json_entry2 t in 
      text, JObject["and",JArray (t :: l)]
  | JObject l -> 
        let text,l = Xlist.fold l ("",[]) (fun (text,l) -> function
            "text", JString s -> if text = "" then s,l else failwith "split_json_entry2 1"
          | e,t -> text, (e,t) :: l) in
(*         if text = "" then failwith ("split_json_entry2 2: " ^ json_to_string (JObject l)) else *)
        Xstring.remove_spaces text, JObject (List.rev l)
  | _ -> failwith "split_json_entry2 3"*)

let rec remove_text = function
    JObject l -> 
      let l = List.rev (Xlist.fold l [] (fun l (e,t) -> if e = "text" then l else (e, remove_text t) :: l)) in
      if l = [] then JEmpty else JObject l
  | JArray l -> JArray(List.rev (Xlist.rev_map l remove_text))
  | t -> t

(*   print_endline (json_to_string_fmt2 "" t); *)
(*   snd (split_json_entry2 t) *)
  
(* 
TP = element lat_set ^ gold_set
TN = nie występują
FP = elementy lat_set / gold_set
FN = elementy gold_set / lat_set 

Precision = TP/TP+FP = |lat_set ^ gold_set| / |lat_set|
Recall = TP/TP+FN = |lat_set ^ gold_set| / |gold_set|
Accuracy = TP+TN/TP+FP+FN+TN = |lat_set ^ gold_set| / |lat_set v gold_set|
*)

let calculate_precision lat_set gold_set =
(*  print_endline ("calculate_precision lat: " ^ String.concat " " (StringSet.to_list lat_set));
  print_endline ("calculate_precision gold: " ^ String.concat " " (StringSet.to_list gold_set));
  print_endline ("calculate_precision int: " ^ String.concat " " (StringSet.to_list (StringSet.intersection lat_set gold_set)));*)
  if StringSet.size lat_set = 0 then -1. else
  float (StringSet.size (StringSet.intersection lat_set gold_set)) /. float (StringSet.size lat_set)
  
let calculate_recall lat_set gold_set =
  if StringSet.size gold_set = 0 then -1. else
  float (StringSet.size (StringSet.intersection lat_set gold_set)) /. float (StringSet.size gold_set)

let calculate_accuracy lat_set gold_set =
  if StringSet.size gold_set = 0 && StringSet.size lat_set = 0 then -1. else
  float (StringSet.size (StringSet.intersection lat_set gold_set)) /. float (StringSet.size (StringSet.union lat_set gold_set))

let calculate_measures gold_set p =
  let sem_set = create_sem_set [] StringSet.empty p.sem in
  {p with 
    precision=calculate_precision sem_set gold_set; 
    recall=calculate_recall sem_set gold_set; 
    accuracy=calculate_accuracy sem_set gold_set}

let add_statistics2 p =
  JObject["and",JArray(
    (if p.sem = JNull then [] else [JObject["sem",remove_text p.sem]]) @
    (if p.accuracy = -1. then [] else [JObject["accuracy",JNumber (jnumber_of_float p.accuracy)]]) @
    (if p.precision = -1. then [] else [JObject["precision",JNumber (jnumber_of_float p.precision)]]) @
    (if p.recall = -1. then [] else [JObject["recall",JNumber (jnumber_of_float p.recall)]]) @
    (if p.cost = nan then [] else [JObject["cost",JNumber (jnumber_of_float p.cost)]]) @
    (if p.text = "" then [] else [JObject["text",JString p.text]]))]
   
 
let add_statistics turn turn_sem p = 
   JObject["and",JArray([
     JObject["lat",add_statistics2 p.lat]; 
     JObject["best",add_statistics2 p.best]; 
     JObject["best2",add_statistics2 p.best2]; 
     JObject["oracle",add_statistics2 p.oracle]; 
     JObject["oracle2",add_statistics2 p.oracle2]; 
     JObject["turn-sem",remove_text turn_sem]; 
     JObject["turn",JString turn]] @
    (if p.oracle.cost = nan || p.best.cost = nan then [] else [JObject["cost-quotient",JNumber (jnumber_of_float (p.oracle.cost/.p.best.cost))]]))]

let process sentence text tokens =
(*   print_endline ("process 1: „" ^ sentence ^ "”"); *)
  let lex_sems,msg = DomainLexSemantics.catch_assign2 tokens text in
    (* print_endline (LexSemanticsStringOf.string_of_lex_sems tokens lex_sems); *)
(*    print_endline "process 3";  *)
  let text = if msg <> "" then AltText[Raw,RawText sentence;Error,ErrorText ("lexsemantics_error: " ^ msg)] else text in
(*    print_endline "process 4";  *)
  let text = Exec.translate_text text in
(*     print_endline "process 5";   *)
  let text = Exec.parse !timeout !verbosity !max_cost !LCGlexiconTypes.rules !LCGlexiconTypes.dep_rules tokens lex_sems text in
(*    print_endline "process 6";  *)
(*          File.file_out (!output_dir ^ "parsed_text.html") (fun file ->
            Printf.fprintf file "%s\n" Visualization.html_header;
              if text <> ExecTypes.AltText [] then
              Printf.fprintf file "%s<BR>\n%!" (Visualization.html_of_text_as_paragraph !output_dir ExecTypes.Struct !img !verbosity tokens text);
            Printf.fprintf file "%s\n" Visualization.html_trailer);*)
  let text = if !disambiguate_flag then Exec.disambiguate text else text in (* przy !output = Text || !output = Marked poniższych nie ma *)
  let text = Exec.sort_arguments tokens text in
  let text = Exec.merge_mwe tokens text in
(*    print_endline "process 7";  *)
  let text = if !select_sentence_modes_flag then SelectSent.select_sentence_modes_text text else text in
  let text = if !select_sentences_flag then SelectSent.select_sentences_text ExecTypes.Struct text else text in
(*    print_endline "process 8";  *)
  let text = if !semantic_processing_flag then DomExec.semantic_processing !verbosity tokens lex_sems text else text in
  let text = if !semantic_processing_flag then DomExec.semantic_processing2 !verbosity tokens lex_sems text else text in
  let text = if !inference_flag then DomExec.merge_graph text else text in
(*   print_endline (String.concat "\n" (Visualization.to_string_text !verbosity tokens text)); *)
  let text = if !inference_flag then Exec.apply_rules_text text else text in
(*   let text = if !inference_flag (*&& !output = JSON*) then Exec.validate text else text in *) (* FIXME: empty sense in JString *)
  let text = if !select_not_parsed_flag then Exec.select_not_parsed text else text in
  let text = Exec.aggregate_stats text in
  try
    if not !semantic_processing_flag then Exec.Json2.convert !statistics_flag text else Exec.Json2.convert !statistics_flag text
  with e -> 
    JObject["and-tuple",JArray[JObject["error",JString (Printexc.to_string e)];JObject["text",JString sentence]]]
  
(*
Uruchamianie zewnętrznego parsera
cd ~/Dokumenty/Selidor/DialogueSystem/NLU/lexemes
eniam --debug -p 9760 -a --def-cat --no-disamb -u base -u beauty -u fixed -e aux -e time -e numbers --partial -j
*)

let get_sock_addr host_name port =
  let he = Unix.gethostbyname host_name in
  let addr = he.Unix.h_addr_list in
  Unix.ADDR_INET(addr.(0),port)

let input_text channel =
  let s = ref (try input_line channel with End_of_file -> "") in
  let lines = ref [] in
  while !s <> "" do
    lines := !s :: !lines;
    s := try input_line channel with End_of_file -> ""
  done;
  String.concat "\n" (List.rev !lines)

let process_external eniam_in eniam_out phrase =
  Printf.fprintf eniam_out "%s\n\n%!" phrase;
(*         print_endline ("A :" ^ phrase); *)
  let s = input_text eniam_in in
(*         print_endline ("Q :" ^ s); *)
  Xjson.json_of_string s

let create_sem p =
  let text,tokens = p.paths2 in
  {p with sem=process p.text text tokens}
  
let create_sem_external eniam_in eniam_out p =
  {p with sem=process_external eniam_in eniam_out p.text}
  
let process_lattices3 data =
  let eniam_in,eniam_out = Unix.open_connection (get_sock_addr "localhost" 9760) in
  List.rev (Xlist.rev_map data (fun r ->
    (*if r.name = "fryzjer1" then *)
    (print_endline ("process_lattices3: " ^ r.dir ^ " " ^ r.name);
    let gold_set = create_sem_set [] StringSet.empty r.turn_sem in
    let paths = List.rev (Xlist.rev_map r.paths (fun (n,p) ->
(*       if n = 0 then failwith "process_lattices3: 0" else *)
      let p = {p with
        lat=create_sem p.lat;
        best=create_sem p.best;
        best2=create_sem_external eniam_in eniam_out p.best2;
        oracle=create_sem p.oracle;
        oracle2=create_sem_external eniam_in eniam_out p.oracle2} in
      n, {p with 
        lat=calculate_measures gold_set p.lat;
        best=calculate_measures gold_set p.best;
        best2=calculate_measures gold_set p.best2;
        oracle=calculate_measures gold_set p.oracle;
        oracle2=calculate_measures gold_set p.oracle2})) in
    {r with paths})))

let aggregate_sem_path p1 p2 =
  {empty_p with 
    text=p1.text ^ " | " ^ p2.text;
    cost=p1.cost +. p2.cost;
    sem=JObject["and",JArray[p1.sem;p2.sem]]}
    
let aggregate_sem data =
  List.rev (Xlist.rev_map data (fun r ->
    let p = Xlist.fold (List.tl r.paths) (snd (List.hd r.paths)) (fun paths (_,p) ->
      {paths with 
        lat=aggregate_sem_path paths.lat p.lat;
        best=aggregate_sem_path paths.best p.best;
        best2=aggregate_sem_path paths.best2 p.best2;
        oracle=aggregate_sem_path paths.oracle p.oracle;
        oracle2=aggregate_sem_path paths.oracle2 p.oracle2}) in
    let gold_set = create_sem_set [] StringSet.empty r.turn_sem in
    let p = {p with 
        lat=calculate_measures gold_set p.lat;
        best=calculate_measures gold_set p.best;
        best2=calculate_measures gold_set p.best2;
        oracle=calculate_measures gold_set p.oracle;
        oracle2=calculate_measures gold_set p.oracle2} in
    {r with paths=[0,p]}))
    
let print_result out_chan data =
  Xlist.iter data (fun r -> 
    Xlist.iter r.paths (fun (n,p) ->
      let sem = Json.normalize (add_statistics r.turn r.turn_sem p) in
      if p.best.precision < p.best2.precision then  Printf.fprintf out_chan "BEST PRECISION\n";
      if p.best.recall < p.best2.recall then  Printf.fprintf out_chan "BEST RECALL\n";
      if p.best.accuracy < p.best2.accuracy then  Printf.fprintf out_chan "BEST ACCURACY\n";
      if p.oracle.precision < p.oracle2.precision then  Printf.fprintf out_chan "ORACLE PRECISION\n";
      if p.oracle.recall < p.oracle2.recall then  Printf.fprintf out_chan "ORACLE RECALL\n";
      if p.oracle.accuracy < p.oracle2.accuracy then  Printf.fprintf out_chan "ORACLE ACCURACY\n";
      Printf.fprintf out_chan "%s\n\n%!" (json_to_string_fmt2 "" sem)))
      
let print_avg_measure data name selector = 
  let sum,quant = Xlist.fold data (0.,0) (fun (sum,quant) r ->
    Xlist.fold r.paths (sum,quant) (fun (sum,quant) (_,p) ->
(*       if p.best.accuracy > 0.95 || p.best2.accuracy > 0.95 then sum,quant else *)
      if selector p = -1. then sum,quant else
      sum +. selector p, quant+1)) in
  if quant = 0 then print_endline ("average " ^ name ^ " undefined")
  else Printf.printf "average %s = %f/%d = %f\n" name sum quant (sum /. float quant)
  
let print_avg_measures data = 
  print_avg_measure data "        precision" (fun p -> p.lat.precision);
  print_avg_measure data "        recall   " (fun p -> p.lat.recall);
  print_avg_measure data "        accuracy " (fun p -> p.lat.accuracy);
  print_avg_measure data "best    precision" (fun p -> p.best.precision);
  print_avg_measure data "best    recall   " (fun p -> p.best.recall);
  print_avg_measure data "best    accuracy " (fun p -> p.best.accuracy);
  print_avg_measure data "best2   precision" (fun p -> p.best2.precision);
  print_avg_measure data "best2   recall   " (fun p -> p.best2.recall);
  print_avg_measure data "best2   accuracy " (fun p -> p.best2.accuracy);
  print_avg_measure data "oracle  precision" (fun p -> p.oracle.precision);
  print_avg_measure data "oracle  recall   " (fun p -> p.oracle.recall);
  print_avg_measure data "oracle  accuracy " (fun p -> p.oracle.accuracy);
  print_avg_measure data "oracle2 precision" (fun p -> p.oracle2.precision);
  print_avg_measure data "oracle2 recall   " (fun p -> p.oracle2.recall);
  print_avg_measure data "oracle2 accuracy " (fun p -> p.oracle2.accuracy);
  ()
        
let rec main_loop in_chan out_chan =
  let text = input_text in_chan in
  if text = "" then () else (
    print_endline "main_loop 1";
    let lines = Xstring.split "\n" text in
    let paths0 = List.flatten (Xlist.rev_map lines LatLoader.parse_edge) in
    let paths0,qm = LatLoader.extract_qm paths0 in
    let paths1 = Xlist.map paths0 LatSubsyntax.parse_lattice, 1000000 in
(*    let paths1 = parse_lattice "" lines, 1000000 in
    let paths1 = if !has_question_marker then 
       match paths1 with
         {token=AllSmall("?","?","?"); weight=w} :: paths1, last -> paths1, last (* FIXME: dodać obsługę w *)
       | _ -> failwith "load_lattices2_rec: question marker" else paths1 in      *)
    let data = [{empty_record with paths=[0,{empty_paths with lat={empty_p with paths0; paths1; question_marker=qm}}]}] in
    print_endline "main_loop 2";
    let data = LatSubsyntax.process_lattices 20 data in
    print_endline "main_loop 3";
    let data = LatSubsyntax.process_lattices2 data in
    print_endline "main_loop 4";
    let data = process_lattices3 data in
    print_endline "main_loop 5";
    print_result out_chan data;
    print_endline "main_loop 6";
    flush out_chan;
    main_loop in_chan out_chan)
    
(* kolejność działań przy przetwarzaniu kraty:
wczytanie do ścieżek
sortowanie topologiczne wierzchołków
parsowanie eniamem
wybór najlepszej ścieżki (zważona suma wag, ilość tokenów i niezaaplikowane argumenty
-- wagi można wykorzystać też do dezambiguacji wewnątrz symboli (wybieramy maksymalną wagę przy wstępnym wyborze) 
obliczenie oracle wer i wer wybranej ścieżki
wykorzystanie korpusu do dobrania wagi
*)
   
let load_corpus map filename =
  let json = Xjson.json_of_string (File.load_file filename) in
  let l = match json with JArray l -> l | _ -> failwith "load_corpus" in
  Xlist.fold l map (fun map t -> 
    let c,t = split_json_entry t in 
    StringMap.add map c t)
  
let turn_path = "../../corpus/examples/"
   
let turn_names = [
  "beauty_branza"; "beauty_kategoria"; "beauty_podtyp_klienta"; "beauty_synonimy"; "beauty_usluga1"; "beauty_usluga2";
  "commands"; "declaration"; "E1"; "E2"; "E3"; "L2"; "L3"; 
  "location"; "propositionalQuestion"; "service"; "setQuestion"; "tabela"; "time"; 
  "dialogi3_klient"; "dialogi3_klient_email"; "dialogi3_klient_name"; "dialogi3_klient_telephone"; 
  ]

let rec remove_multiple_spaces = function
    " " :: " " :: l -> remove_multiple_spaces (" " :: l)
  | s :: l -> s :: remove_multiple_spaces l
  | [] -> []
  
let manage_manikiur s =
  String.concat " " (Xlist.map (Xstring.split " " s) (function
      "manikjur" -> "manikiur"
    | "pedikjur" -> "pedikiur"
    | s -> s))
  
let make_transcription s = 
  let l = Xlist.map (Xunicode.classified_chars_of_utf8_string s) (function
      Xunicode.Digit s -> s
    | Xunicode.Sign s -> " "
    | Xunicode.Capital(s,t) -> t
    | Xunicode.ForeignCapital(s,t) -> t
    | Xunicode.Small(s,t) -> t
    | Xunicode.ForeignSmall(s,t) -> t
    | Xunicode.Emoticon s -> failwith "make_transcription"
    | Xunicode.Other(s,x) -> failwith "make_transcription") in
  let l = remove_multiple_spaces l in
  let s = Xstring.remove_spaces (String.concat "" l) in
  let s = manage_manikiur s in
(*   if Xstring.check_prefix "grażyna" s then print_endline ("make_transcription: „" ^ s ^ "”"); *)
  s
  
let make_transcription2 map =
  StringMap.fold map StringMap.empty (fun map s t ->
    StringMap.add map (make_transcription s) t)
  
let load_semantics data =
  let known_turns = Xlist.fold turn_names StringMap.empty (fun map name -> load_corpus map (turn_path ^ name ^ "_parsed.json")) in
  let known_turns2 = StringMap.fold known_turns StringMap.empty (fun map s t ->
    StringMap.add map (make_transcription s) t) in
  let dialogi3_klient = make_transcription2 (load_corpus StringMap.empty  (turn_path ^ "dialogi3_klient_parsed.json")) in
  let dialogi3_klient_email = make_transcription2 (load_corpus StringMap.empty  (turn_path ^ "dialogi3_klient_email_parsed.json")) in
  let dialogi3_klient_name = make_transcription2 (load_corpus StringMap.empty  (turn_path ^ "dialogi3_klient_name_parsed.json")) in
  let dialogi3_klient_telephone = make_transcription2 (load_corpus StringMap.empty  (turn_path ^ "dialogi3_klient_telephone_parsed.json")) in
  let dialogi3_klient_todo = 
    make_transcription2 (Xlist.fold (File.load_lines (turn_path ^ "dialogi3_klient_todo.tab")) StringMap.empty (fun map s ->
      StringMap.add map s JFalse)) in
  let dialogi3_map = Xlist.fold [dialogi3_klient,"STD";dialogi3_klient_email,"EMAIL";
    dialogi3_klient_name,"NAME";dialogi3_klient_telephone,"TELEPHONE";dialogi3_klient_todo,"TODO"] StringMap.empty (fun map (dial,t) ->
      StringMap.fold dial map (fun map k v -> StringMap.add map k (v,t))) in
(*  Xlist.iter data (fun r ->
    let s = Xstring.remove_spaces r.turn in
    if StringMap.mem known_turns s then Printf.printf "AAA %s %s\n" r.name s else
    if StringMap.mem known_turns2 s then Printf.printf "BBB %s %s\n" r.name s
    else Printf.printf "XXX %s %s\n" r.name s);*)
  List.rev (Xlist.rev_map data (fun r -> 
    if r.dir = "parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty_v2" || r.dir = "parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty_v1" || r.dir = "parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty" then 
      if Xlist.size (Xstring.split "\n" r.turn) > 1 then {r with turn_type = "MULTIPLE"} else
      if StringMap.mem dialogi3_map r.turn then 
        let turn_sem,turn_type = StringMap.find dialogi3_map r.turn in
        {r with turn_sem; turn_type}
      else 
        let s = Xstring.remove_spaces (String.concat "" (remove_multiple_spaces (Xunicode.utf8_chars_of_utf8_string r.turn))) in
(*         if Xstring.check_prefix "grażyna" s then print_endline ("load_semantics: „" ^ s ^ "”"); *)
        if StringMap.mem dialogi3_map s then 
          let turn_sem,turn_type = StringMap.find dialogi3_map s in
          {r with turn_sem; turn_type}        
        else {r with turn_type = "UNKNOWN"}
    else
      let s = Xstring.remove_spaces r.turn in
      if StringMap.mem known_turns s then {r with turn_sem=StringMap.find known_turns s} else
      if StringMap.mem known_turns2 s then {r with turn_sem=StringMap.find known_turns2 s}
      else r))
   
let select_subcorpora_gold data =
  Xlist.fold data [] (fun data r ->
    if r.turn_sem = JNull then data else r :: data)
   
let select_subcorpora sel_names data =
  Xlist.fold data [] (fun data r ->
    if Xlist.mem sel_names r.name then r :: data else data)
   
let select_subcorpora_dir sel_dirs data =
  Xlist.fold data [] (fun data r ->
    if Xlist.mem sel_dirs r.dir then r :: data else data)
   
let select_subcorpora_type sel_types data =
  Xlist.fold data [] (fun data r ->
    if Xlist.mem sel_types r.turn_type then r :: data else data)
   
let select_subcorpora_path_num sel_nums data =
  Xlist.fold data [] (fun data r ->
    let b = Xlist.fold r.paths false (fun b (i,p) -> if Xlist.mem sel_nums i then true else b) in
    if b then r :: data else data)
   
let print_corpora_summary data =
  Xlist.iter data (fun r ->
    Printf.printf "DIR: %s NAME: %s\n" r.dir r.name;
(*     let gold = if r.turn_sem = JNull then "" else "GOLD " in *)
(*     let multiple = if Xlist.size (Xstring.split "\n" r.turn) > 1 then "MULTIPLE " else "" in *)
    Printf.printf "%s TURN: %s\n" r.turn_type (*multiple*) r.turn;
    Xlist.iter r.paths (fun (i,p) ->
      Printf.printf "%d: %s\n" i p.best.text);
    ())
   
let process_corpus () =
(*  let map = try StringMap.find !known_lemmata "fryzjera" with Not_found -> failwith "known_lemmata 1" in
  let set = try StringMap.find map "fixed" with Not_found -> failwith "known_lemmata 3" in
  let l = OntSet.fold set [] (fun l a -> 
    print_endline a.ont_cat; a :: l) in
  (try ignore (StringMap.find !known_lemmata "fryzjer") with Not_found -> failwith "known_lemmata 2");
(*   let _,l = (*Lemmatization.*)lemmatize_token [] false false (AllSmall("fryzjera","fryzjera","fryzjera")) in *)
  let _,l = lemmatize_strings [] false false ["fryzjera",(AS : letter_size),(AS : letter_size)] in
  Xlist.iter l (fun (lemma,pos,tags,cat) -> Printf.printf "%s %s %s\n" lemma pos cat);*)
(*   let data = load_sentence_list_rafal () in *)
(*   let data = load_sentence_list_L2a () in *)
  let data = LatLoader.import_corpora () in
  let data = load_semantics data in
  let data = select_subcorpora_dir [(*"parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty_v2";"parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty_v1";*)"parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty"] data in
  let data = select_subcorpora_type ["STD"] data in
(*   let data = select_subcorpora ["Dialog_04"] data in *)
(*   let data = select_subcorpora_path_num [0] data in  *)
  Xlist.iter data (fun r -> 
    print_endline ("FILE: " ^ r.dir ^ " " ^ r.name);
    Printf.printf "TURN: %s\n"   r.turn;
    Xlist.iter r.paths (fun (i,p) -> Printf.printf "ORAC %d: %s\nBEST %d: %s\n" i p.oracle.text i p.best.text));
(*   print_corpora_summary data; *)
(*   let data = select_subcorpora_gold data in *)
(*   let data = select_subcorpora ["strzyżenie1"] data in *)
(*   let data = select_subcorpora ["L2_117";"L2_16";"L2a__139";"L2a__25"] data in *)
(*   let data = LatLoader.load_sentence_list_tdnnf sentence_tdnnf_L2a_filename in *)
(*  let data = load_sentence_list_tdnnf sentence_tdnnf_L2_time_filename in
  let data = load_sentence_list_tdnnf sentence_tdnnf_L1a_filename in*)
(*   let words = load_words () in *)
(*    let data = load_lattices data in (* 1 *)  *)
  let data = LatSubsyntax.load_lattices2 data in (* 2 *) (* załadowanie krat *)   
(*     let data = make_lattices data in (* stworzenie krat na podstawie zdań *)   *)
(*   let data = make_paths words data in   *)
  let data = LatSubsyntax.process_lattices 20 data in
  let data = LatSubsyntax.process_lattices2 data in
  let data = process_lattices3 data in
  let data = aggregate_sem data in
  print_result stdout data;
  print_avg_measures data;
(*    print_graphs data;   *)
  ()
 

let _ =
  Arg.parse spec_list anon_fun usage_msg;
  ExecTypes.partial_parsing_flag:=ExecTypes.(*StdPP*)LatPP;
  default_category_flag := true;
  ExecTypes.is_speech := true;
  LCGlexiconTypes.load_std_lexicon := false;
  SubsyntaxTypes.theories := ["time";"numbers"];
  SubsyntaxTypes.user_theories := ["fixed";"base";"beauty";"time";"location"(*;"inflected"*)];
  Subsyntax.initialize ();
  Printf.printf "|known_lemmata|=%d\n" (StringMap.size !known_lemmata);
  lemma_case_mapping :=  StringMap.fold !known_lemmata StringMap.empty (fun map lemma _ ->
    let lc = Xunicode.lowercase_utf8_string lemma in
    StringMap.add_inc map lc (StringSet.singleton lemma) (fun set -> StringSet.add set lemma));
(*  known_lemmata := StringMap.fold !known_lemmata !known_lemmata (fun map lemma map2a ->
    let lc = Xunicode.lowercase_utf8_string lemma in
    if lc = lemma then map else
    let map2 = try StringMap.find map lc with Not_found -> StringMap.empty in
    let map2 = StringMap.fold map2a map2 (fun map2 pos set ->
        StringMap.add_inc map2 pos set (fun set2 -> OntSet.union set set2)) in
    StringMap.add map lc map2);*)
(*   Printf.printf "|known_lemmata|=%d\n" (StringMap.size !known_lemmata);     *)
  SemTypes.user_ontology_flag := true;
  LCGlexicon.initialize ();
  DomainLexSemantics.initialize2 ();
  DomSemantics.initialize ();
  InferenceRulesParser.initialize ();
  Exec.initialize ();
(*   if !output = Marked then MarkedHTMLof.initialize (); *)
  let application_rules = if !internet_mode then LCGrules.application_rules_ignore_brackets else LCGrules.application_rules in
  if !discontinuous_parsing_flag then ExecTypes.lcg_rules := application_rules @ LCGrules.cross_composition_rules
  else ExecTypes.lcg_rules := application_rules;
  if !subsyntax_built_in (*|| !morphology_built_in*) then Subsyntax.initialize ();
  if !correct_spelling_flag then FuzzyDetector.initialize ();
  Gc.compact ();
  if !output <> Worker then prerr_endline "Ready!";
  if !corpus_mode then process_corpus () else
  if !comm_stdio then main_loop stdin stdout
  else 
    let sockaddr = Unix.ADDR_INET(Unix.inet_addr_any,!port) in
    Unix.establish_server main_loop sockaddr

  
(*wagi się dodaje 
wybieramy najmniejszą wagę.*)
(*
export ENIAM_USER_DATA_PATH=/home/yacheu/Dokumenty/Selidor/DialogueSystem/NLU/lexemes/data
*)
