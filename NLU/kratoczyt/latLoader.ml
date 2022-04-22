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
 
open LatTypes
open Xstd
open SubsyntaxTypes

(*let dirs = [
  "../../ASR/lats";
(*  "../../ASR/lats/clarin_default";*)
  "../../ASR/lats/clarin_mixed_grammar";
  "../../ASR/lats/clarin_mixed_grammar_2";
  "../../ASR/lats/clarin_mixed_grammar_2/L1";
  "../../ASR/lats/clarin_mixed_grammar_2/L1a";
  "../../ASR/lats/clarin_mixed_grammar_2/L1a/kazimierz";
  "../../ASR/lats/clarin_mixed_grammar_2/L2";
  "../../ASR/lats/clarin_mixed_grammar_2/L2a";
  "../../ASR/lats/clarin_mixed_grammar_2/L2a/marta";
  "../../ASR/lats/clarin_mixed_grammar_2/rafal";
  "../../ASR/lats/clarin_mixed_grammar_2/rafal/beam14";
  "../../ASR/lats/clarin_mixed_grammar_2/rafal/beam8";
  "../../ASR/lats/clarin_simple_large_grammar";
  "../../ASR/lats/parl_selidor_clarin_phone_luz_tdnnf12";
  "../../ASR/lats/tdnnf_mixed_grammar_2";
  "../../ASR/lats/tdnnf_mixed_grammar_2/lats_L1a_Lukasz";
  "../../ASR/lats/tdnnf_mixed_grammar_2/lats_L2a_Marta";
  "../../ASR/lats/tdnnf_mixed_grammar_2/lats_L2_corpus_time";
  ]*)

type t = 
    Sentence of string * string * string * string
  | Best of string * string * string
  | Lat of string * string * g list * float
  | LatBest of string * string * g list * string * float
  | LatBestTimes of string * string * g list * string * float * float * float
  
let merge_filename base_dir path filename =
  String.concat "/" (base_dir :: List.rev (filename :: path))
  
let make_sentence_record path filename filename2 sentence =
  Sentence(String.concat "/" (List.rev path),filename,filename2,String.concat " " sentence)
  
let make_best_record path filename best =
  Best(String.concat "/" (List.rev path),filename,best)

let make_lat_record path filename lat qm =
  Lat(String.concat "/" (List.rev path),filename,lat,qm)
  
let make_lat_best_record path filename lat best qm =
  LatBest(String.concat "/" (List.rev path),filename,lat,best,qm)
  
let make_lat_best_time_record path filename lat best qm start_time end_time =
  LatBestTimes(String.concat "/" (List.rev path),filename,lat,best,qm,start_time,end_time)
    
let load_sentence_list found base_dir path filename = 
  if path = ["clarin_mixed_grammar_2"] then 
    File.fold_tab (merge_filename base_dir path filename) found (fun found -> function
        [filename2;sentence] -> make_sentence_record path filename filename2 [sentence] :: found
      | line -> failwith ("load_sentence_list: " ^ String.concat "\t" line))
  else if filename = "zdania.txt" then
    let lines = File.load_lines (merge_filename base_dir path filename) in
    Xlist.fold lines found (fun found s ->
      if s = "" then found else
        match Xstring.split ".wav: " s with
          [filename2;sentence] -> make_sentence_record path filename filename2 [sentence] :: found
        | _ -> failwith ("load_sentence_list 2: " ^ s))
  else if filename = "text" || path = ["tdnnf_mixed_grammar_2"] then
    let lines = File.load_lines (merge_filename base_dir path filename) in
    Xlist.fold lines found (fun found s ->
      if s = "" then found else
        match Xstring.split " " s with
          filename2 :: sentence -> make_sentence_record path filename filename2 sentence :: found
        | _ -> failwith ("load_sentence_list 3: " ^ s))
  else if path = ["parl_selidor_clarin_phone_luz_tdnnf12"] then 
    let sentence = File.load_file (merge_filename base_dir path filename) in
    make_sentence_record path "korpus.txt" (Xstring.cut_sufix ".korpus.txt" filename) [sentence] :: found
  else if List.tl path = ["parl_selidor_clarin_phone_luz_tdnnf12_v2"] then 
    let sentence = File.load_file (merge_filename base_dir path filename) in
    make_sentence_record path "ref.txt" (Xstring.cut_sufix ".ref.txt" filename) [sentence] :: found
  else (    
  print_endline ("\nload_sentence_list: " ^ merge_filename base_dir path filename);
  let lines = File.load_lines (merge_filename base_dir path filename) in
  Xlist.iter lines print_endline;
  found)
  
let load_best found base_dir path filename = 
  let lines = File.load_lines (merge_filename base_dir path filename) in
  match lines with
    [line] -> make_best_record path filename line :: found
  | [] -> make_best_record path filename "" :: found
  | _ ->
    print_endline ("\nload_best: " ^ merge_filename base_dir path filename);
    let lines = File.load_lines (merge_filename base_dir path filename) in
    Xlist.iter lines print_endline;
    found

let parse_edge s =
  match Xstring.split " " s with
      [start;en;word;weight] -> 
        (try 
          [Edge(int_of_string start, int_of_string en, word, float_of_string weight)]
        with _ -> failwith ("parse_edge 2: " ^ s))
    | [en;weight] -> 
        (try 
          [Leaf(int_of_string en, float_of_string weight)]
        with _ -> failwith ("parse_edge 3: " ^ s))
    | [en] -> 
        (try 
          [Leaf(int_of_string en, 0.)]
        with _ -> failwith ("parse_edge 3: " ^ s))
    | [] -> []
    | l -> failwith ("parse_edge 1: " ^ s)
    
let extract_qm = function
    Edge(x,y,"?",v) :: l -> if x <> y then failwith "extract_qm" else List.rev l, v
  | l -> List.rev l, -1.
    
let load_lat found base_dir path filename = 
(*   print_endline ("load_lat: " ^ merge_filename base_dir path filename); *)
  match path with
    ["parl_selidor_clarin_phone_luz_tdnnf12"] -> 
      let json = Xjson.json_of_string (File.load_file (merge_filename base_dir path filename)) in
      (match json with
        Xjson.JObject["text",Xjson.JString best;"grid",Xjson.JString grid;"session",Xjson.JString session] -> 
          let lat,qm = extract_qm (List.flatten (Xlist.rev_map (Xstring.split "\n" grid) parse_edge)) in
          make_lat_best_record path filename lat best qm :: found 
      | _ -> failwith "load_lat") 
  | [_;"parl_selidor_clarin_phone_luz_tdnnf12_v2"] -> 
      let json = Xjson.json_of_string (File.load_file (merge_filename base_dir path filename)) in
      (match json with
        Xjson.JObject["text",Xjson.JString best;"start_time",Xjson.JString start_time;"end_time",Xjson.JString end_time;"grid",Xjson.JString grid;"session",Xjson.JString session] -> 
          let lat,qm = extract_qm (List.flatten (Xlist.rev_map (Xstring.split "\n" grid) parse_edge)) in
          let start_time = try float_of_string start_time with _ -> failwith "load_lat" in
          let end_time = try float_of_string end_time with _ -> failwith "load_lat" in
          make_lat_best_time_record path filename lat best qm start_time end_time :: found 
      | _ -> failwith "load_lat") 
  | _ ->
      let lines = File.load_lines (merge_filename base_dir path filename) in
      let lat,qm = extract_qm (List.flatten (Xlist.rev_map lines parse_edge)) in
      make_lat_record path filename lat qm :: found
  
(*let load_x found base_dir path filename = 
    print_endline ("\n" ^ merge_filename base_dir path filename);
    let lines = File.load_lines (merge_filename base_dir path filename) in
    Xlist.iter lines print_endline;
    found*)
  
let rec load_corpora found base_dir path =
  let filenames = Array.to_list (Sys.readdir (merge_filename base_dir path "")) in
  Xlist.fold filenames found (fun found filename ->
    if Sys.is_directory (merge_filename base_dir path filename) then load_corpora found base_dir (filename :: path) else
    if Xstring.check_sufix "zdania.txt" filename then load_sentence_list found base_dir path filename else
    if filename = "text" then load_sentence_list found base_dir path filename else
    if Xstring.check_prefix "lats_" filename && Xstring.check_sufix ".txt" filename then load_sentence_list found base_dir path filename else
    if Xstring.check_sufix ".best.txt" filename then load_best found base_dir path filename else
    if Xstring.check_sufix ".lat.fst.txt" filename then load_lat found base_dir path filename else
    if Xstring.check_sufix ".korpus.txt" filename then load_sentence_list found base_dir path filename else
    if Xstring.check_sufix ".ref.txt" filename then load_sentence_list found base_dir path filename else
    if Xstring.check_sufix ".lat.1" filename then found else
    if Xstring.check_sufix ".lat.1.gz" filename then found else
    if Xstring.check_sufix ".lat.1.pdf" filename then found else
    if Xstring.check_sufix ".lat.1.txt" filename then found else
    if Xstring.check_sufix ".lat.1.words.txt" filename then found else
    if Xstring.check_sufix ".lat.1.words.fst.txt" filename then load_lat found base_dir path filename else
    if filename = "words.txt" then found else
    if path = ["clarin_default"] && Xstring.check_sufix ".txt" filename then load_best found base_dir path filename else
    if filename = "README.md" then found else
    if filename = "make_lats_online.sh" then found else
    if filename = "per_utt" then found else
    if filename = "corpus.txt" then found else
    if filename = "corpus" then found else
    if filename = "kraty.xlsx" then found else
    if filename = "WER.txt" then found else
    (print_endline ("load_corpora: " ^ merge_filename base_dir path filename); found))
    
let split_speaker s =
  match Xstring.split "-" s with
    [speaker;s] -> speaker,s
  | _ -> failwith ("split_speaker: " ^ s)
  
let split_speaker2 s = 
  match String.sub s 0 (Xstring.size s - 1) with
    "Filip" -> "Filip"
  | "Hania" -> "Hania"
  | "Dominika" -> "Dominika"
  | _ -> failwith ("split_speaker2: " ^ s)
    
let split_speaker3 s =
  if Xstring.check_prefix "Dialog_" s then 
    let s = Xstring.cut_prefix "Dialog_" s in
    if Xstring.size s = 2 then "?" else
    if Xstring.size s = 5 then 
      match String.sub s 2 3 with
        "_BZ" -> "BZ"
      | "_ZB" -> "ZB"
      | "_ZK" -> "ZK"
      | "_ZV" -> "ZV"
      | "_ZF" -> "ZF"
      | "_BV" -> "BV"
      | "_BF" -> "BF"
      | _ -> failwith ("split_speaker2 3: " ^ s) else
    failwith ("split_speaker3 2: " ^ s)
  else failwith ("split_speaker3 1: " ^ s)
    
let extract_speaker = function
    "clarin_mixed_grammar_2","L1_zdania.txt",s -> (*split_speaker s*)"?",s
  | "clarin_mixed_grammar_2","L2_zdania.txt",s -> (*split_speaker s*)"?",s
  | "clarin_mixed_grammar_2","rafal_zdania.txt",s -> 
      "rafal",if Xstring.check_sufix ".wav" s then Xstring.cut_sufix ".wav" s else failwith "extract_speaker"
  | "clarin_mixed_grammar_2/L1a","text",s -> split_speaker s
  | "clarin_mixed_grammar_2/L2a","text",s -> split_speaker s
  | "","zdania.txt",s -> "rafal",s
  | "tdnnf_mixed_grammar_2","lats_L1a_Lukasz.txt",s -> split_speaker s
  | "tdnnf_mixed_grammar_2","lats_L2a_Marta.txt",s -> split_speaker s
  | "tdnnf_mixed_grammar_2","lats_L2_corpus_time.txt",s -> split_speaker s
  | "parl_selidor_clarin_phone_luz_tdnnf12","korpus.txt",s -> split_speaker2 s, s
  | "parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty","ref.txt",s -> split_speaker3 s, s
  | "parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty_v1","ref.txt",s -> split_speaker3 s, s
  | "parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty_v2","ref.txt",s -> split_speaker3 s, s
  | dir,filename,s -> failwith ("extract_speaker: " ^ dir ^ " " ^ filename ^ " " ^ s)
    
let map_dir = function
    "clarin_mixed_grammar_2","L1_zdania.txt" -> ["clarin_mixed_grammar_2/L1"]
  | "clarin_mixed_grammar_2","L2_zdania.txt" -> ["clarin_mixed_grammar_2/L2"]
  | "clarin_mixed_grammar_2","rafal_zdania.txt" -> ["clarin_mixed_grammar_2/rafal/beam8";"clarin_mixed_grammar_2/rafal/beam14"]
  | "clarin_mixed_grammar_2/L1a","text" -> ["clarin_mixed_grammar_2/L1a/kazimierz"]
  | "clarin_mixed_grammar_2/L2a","text" -> ["clarin_mixed_grammar_2/L2a/marta"]
  | "","zdania.txt" -> ["clarin_default";"clarin_mixed_grammar";"clarin_simple_large_grammar"]
  | "tdnnf_mixed_grammar_2","lats_L1a_Lukasz.txt" -> ["tdnnf_mixed_grammar_2/lats_L1a_Lukasz"]
  | "tdnnf_mixed_grammar_2","lats_L2a_Marta.txt" -> ["tdnnf_mixed_grammar_2/lats_L2a_Marta"]
  | "tdnnf_mixed_grammar_2","lats_L2_corpus_time.txt" -> ["tdnnf_mixed_grammar_2/lats_L2_corpus_time"]
  | "parl_selidor_clarin_phone_luz_tdnnf12","korpus.txt" -> ["parl_selidor_clarin_phone_luz_tdnnf12"]
  | "parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty","ref.txt" -> ["parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty"]
  | "parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty_v1","ref.txt" -> ["parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty_v1"]
  | "parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty_v2","ref.txt" -> ["parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty_v2"]
  | dir,filename -> failwith ("map_dir: " ^ dir ^ " " ^ filename)
    
let split_best_filename filename = 
  match Xstring.split "\\." filename with
    [name;id;"best";"txt"] -> name, id
  | [name;"txt"] -> name, "1"
  | _ -> print_endline ("split_best_filename: " ^ filename); filename, ""
    
let split_lat_filename filename = 
  match Xstring.split "\\." filename with
    [name;id;"lat";"fst";"txt"] -> name, id
  | [name;"lat";id;"words";"fst";"txt"] -> name, id
  | _ -> print_endline ("split_lat_filename: " ^ filename); filename, ""

let join_best dir name id best1 best2 = 
  if best1 = best2 then best1 else
  let best1,best2 = if Xstring.size best1 < Xstring.size best2 then best1,best2 else best2,best1 in
  if Xstring.check_prefix best1 best2 then
    let suf = Xstring.cut_prefix best1 best2 in
    if suf = "?" then best2 else (
    Printf.printf "join_best multiple best 2: %s %s %d\n„%s”\n„%s”\n%!" dir name id best1 best2; best2)
  else (Printf.printf "join_best multiple best 1: %s %s %d\n„%s”\n„%s”\n%!" dir name id best1 best2; best2)

let join_sentence dir name l = 
(*   print_endline (dir ^ " " ^ name); *)
  let map,sentences = Xlist.fold l (StringMap.empty,[]) (fun (map,sentences) -> function
        Sentence(_,speaker,_,s) -> map, (speaker,s) :: sentences
      | Best(_,id,best) -> 
          StringMap.add_inc map id ([],[best],[],[]) (fun (lats,bests,qms,ts) -> lats, best :: bests, qms, ts), sentences
      | Lat(_,id,lat,qm) -> 
          StringMap.add_inc map id ([lat],[],[qm],[]) (fun (lats,bests,qms,ts) -> lat :: lats, bests, qm :: qms, ts), sentences
      | LatBest(_,id,lat,best,qm) -> 
          StringMap.add_inc map id ([lat],[best],[qm],[]) (fun (lats,bests,qms,ts) -> lat :: lats, best :: bests, qm :: qms, ts), sentences
      | LatBestTimes(_,id,lat,best,qm,st,et) -> 
          StringMap.add_inc map id ([lat],[best],[qm],[st,et]) (fun (lats,bests,qms,ts) -> lat :: lats, best :: bests, qm :: qms, (st,et) :: ts), sentences) in
  let l = StringMap.fold map [] (fun l id (lats,bests,qms,ts) ->
    let id = try int_of_string id with _ -> failwith "join_sentence" in
    let lat = match lats with
        [] -> Printf.printf "join_sentence no lat: %s %s %d\n%!" dir name id; []
      | [lat] -> lat
      | _ -> Printf.printf "join_sentence multiple lat: %s %s %d\n%!" dir name id; List.hd lats in
    let best = match bests with
        [] -> Printf.printf "join_sentence no best: %s %s %d\n%!" dir name id; ""
      | [best] -> best
      | [best1;best2] -> join_best dir name id best1 best2
      | _ -> Printf.printf "join_sentence multiple best: %s %s %d\n%!" dir name id; List.hd bests in
    let qm = match qms with
        [] -> Printf.printf "join_sentence no qms: %s %s %d\n%!" dir name id; -2.
      | [qm] -> qm
      | _ -> Printf.printf "join_sentence multiple qm: %s %s %d\n%!" dir name id; List.hd qms in
    let st,et = match ts with
        [] -> nan,nan
      | [st,et] -> st,et
      | _ -> Printf.printf "join_sentence multiple times: %s %s %d\n%!" dir name id; List.hd ts in
    (id,lat,best,qm,st,et) :: l) in
  let sentence = match sentences with 
        [] -> Printf.printf "join_sentence no sentence: %s %s\n%!" dir name; "",""
      | [s] -> s
      | _ -> Printf.printf "join_sentence multiple sentence: %s %s\n%!" dir name; List.hd sentences in
(*  Xlist.iter (Xlist.sort l compare) (function
        Sentence(_,speaker,id,s) -> print_endline ("Sentence " ^ id)
      | Best(_,id,best) -> print_endline ("Best " ^ id)
      | Lat(_,id,lat) -> print_endline ("Lat " ^ id)
      | LatBest(_,id,lat,best) -> print_endline ("LatBest " ^ id));*)
  sentence,l
        
let join_dir dir l =
(*   print_endline dir; *)
  let map = Xlist.fold l StringMap.empty (fun map t ->
    let name, t = match t with 
        Sentence(_,speaker,filename,s) -> filename, Sentence("",speaker,"",s)
      | Best(_,filename,best) -> 
          let name,id = split_best_filename filename in 
          name, Best("",id,best)
      | Lat(_,filename,lat,qm) -> 
          let name,id = split_lat_filename filename in 
          name, Lat("",id,lat,qm)
      | LatBest(_,filename,lat,best,qm) -> 
          let name,id = split_lat_filename filename in 
          name, LatBest("",id,lat,best,qm)
      | LatBestTimes(_,filename,lat,best,qm,st,et) -> 
          let name,id = split_lat_filename filename in 
          name, LatBestTimes("",id,lat,best,qm,st,et) in
    StringMap.add_inc map name [t] (fun l -> t :: l)) in
  StringMap.mapi map (join_sentence dir)
    
let join_corpora corpora =
  let corpora = List.flatten (Xlist.rev_map corpora (function
      Sentence(dir,filename,filename2,s) -> 
        let speaker,filename2 = extract_speaker (dir,filename,filename2) in
        Xlist.map (map_dir (dir,filename)) (fun dir -> 
          Sentence(dir, speaker, filename2, s))
    | t -> [t])) in 
  let corpora = Xlist.fold corpora StringMap.empty (fun corpora t -> 
    let dir,t = match t with 
        Sentence(dir,filename,filename2,s) -> dir, Sentence("",filename,filename2,s)
      | Best(dir,filename,best) -> dir, Best("",filename,best)
      | Lat(dir,filename,lat,qm) -> dir, Lat("",filename,lat,qm)
      | LatBest(dir,filename,lat,best,qm) -> dir, LatBest("",filename,lat,best,qm)
      | LatBestTimes(dir,filename,lat,best,qm,st,et) -> dir, LatBestTimes("",filename,lat,best,qm,st,et) in
    StringMap.add_inc corpora dir [t] (fun l -> t :: l)) in
  let corpora = StringMap.mapi corpora join_dir in
  corpora
  
let translate_corpora corpora =
  StringMap.fold corpora [] (fun l dir turns ->
    StringMap.fold turns l (fun l name ((speaker,turn),lats) ->
      let paths = Xlist.rev_map lats (fun (id,lat,best,qm,start_time,end_time) ->
        id, {empty_paths with start_time; end_time;
          best={empty_p with text=Xstring.remove_trailing_spaces best}; 
          lat={empty_p with paths0=lat; question_marker=qm}}) in
      {empty_record with dir; name; speaker; turn; paths=Xlist.sort paths (fun (a,_) (b,_) -> compare a b)} :: l))
 
let string_to_array s =
  Array.of_list (Xunicode.Sign "" :: Xunicode.classified_chars_of_utf8_string s)

let string_to_array2 s =
  Array.of_list (Xunicode.Small("**","**") :: Xunicode.Sign "" :: Xunicode.classified_chars_of_utf8_string s)

let rec split_turns rev rev2 = function
    FuzzyDetector.Accept(Xunicode.Sign "|") :: l -> split_turns [] ((List.rev rev) :: rev2) l
  | t :: l -> split_turns (t :: rev) rev2 l
  | [] -> List.rev ((List.rev rev) :: rev2)
  
let extract_turn l =
  let l = List.flatten (Xlist.map l (function 
      FuzzyDetector.Accept t -> [t]
    | FuzzyDetector.Substitute(s,t) -> [t]
    | FuzzyDetector.Delete _ -> []
    | FuzzyDetector.Insert(_,t) -> [t]
    | FuzzyDetector.Transpose(s,t) -> [s;t])) in
  String.concat "" (Xlist.map l (fun t -> Xunicode.char_of_classified_char t))
  
let extract_best l =
  let l = List.flatten (Xlist.map l (function 
      FuzzyDetector.Accept t -> [t]
    | FuzzyDetector.Substitute(s,t) -> [s]
    | FuzzyDetector.Delete(t,_)  -> [t]
    | FuzzyDetector.Insert _ -> []
    | FuzzyDetector.Transpose(s,t) -> [t;s])) in
  String.concat "" (Xlist.map l (fun t -> Xunicode.char_of_classified_char t))
  
let split_turn corpora =
  List.flatten (Xlist.rev_map corpora (fun r ->
    if r.dir = "parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty_v2" || r.dir = "parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty_v1" || r.dir = "parl_selidor_clarin_phone_luz_tdnnf12_v2/kraty" then (
      let best = String.concat "|" (Xlist.map r.paths (fun (i,p) -> (*string_of_int i ^ " " ^*) p.best.text)) in
      let turn = String.concat "|" (Xstring.split "\n" r.turn) in
      let l = FuzzyDetector.count_differences_simple (string_to_array2 best) (string_to_array2 turn) in
      let ll = split_turns [] [] l in
(*       Printf.printf "DIR: %s NAME: %s\n" r.dir r.name; *)
(*      Xlist.iter ll (fun l -> 
        Printf.printf "%s\n" (String.concat " " (Xlist.map l FuzzyDetector.string_of_edit)));*)
      let ll = Xlist.map ll (fun l -> 
        Xstring.split "|" (extract_best l),
        Xstring.split "|" (extract_turn l)) in
      if String.concat "|" (List.flatten (Xlist.map ll fst)) <> best then failwith ("split_turn 1: „" ^ String.concat "|" (List.flatten (Xlist.map ll fst)) ^ "” „" ^ best ^ "”");
      if String.concat "|" (List.flatten (Xlist.map ll snd)) <> turn then failwith ("split_turn 2: „" ^ String.concat "|" (List.flatten (Xlist.map ll snd)) ^ "” „" ^ turn ^ "”");
(*      Xlist.iter ll (fun (bests,turns) -> 
        if (*Xlist.size bests = 1 &&*) Xlist.size turns = 1 then () else (
        let best = String.concat "|" bests in
        let turn = String.concat "|" turns in
        Printf.printf "TURN: %s\n" turn;
        Printf.printf "BEST: %s\n" best));*)
      let l,paths = Xlist.fold ll ([],r.paths) (fun (l,paths) (bests,turns) ->
        let paths, selected = Xlist.fold bests (paths,[]) (fun (paths,selected) best ->
          if paths = [] then failwith "split_turn 3" else
          if (snd (List.hd paths)).best.text <> best then failwith "split_turn 4" else
          List.tl paths, List.hd paths :: selected) in
        {r with turn = String.concat "\n" turns; paths = List.rev selected} :: l, paths) in
      if paths <> [] then failwith "split_turn 5" else (
(*      Printf.printf "TURN2: %s\n" r.turn;
      Printf.printf "BEST2: %s\n" (String.concat " | " (Xlist.map r.paths (fun (i,p) -> (*string_of_int i ^ " " ^*) p.best.text)));*)
      l))
    else [r]))
(*    {r with paths=match r.paths with
      [] -> []
    | [i,p] -> [i,{p with gold={p.gold with text=r.turn}}]
    | l -> *)
(*        Printf.printf "DIR: %s NAME: %s\n" r.dir r.name;        
        Printf.printf "TURN: %s\n" r.turn;
        Printf.printf "BEST: %s\n" (String.concat " | " (Xlist.map l (fun (i,p) -> (*string_of_int i ^ " " ^*) p.best.text)));
        l})*)
      
let import_corpora () = 
  let corpora = load_corpora [] "../../ASR/lats" [] in
  let corpora = join_corpora corpora in
  let corpora = translate_corpora corpora in
  split_turn corpora

(*let sentence_filename = "rafal-subcorpus.tab"
(* let sentence_filename = "../../ASR/lats/zdania.txt" *)
(* let sentence_filename = "../../ASR/lats/clarin_mixed_grammar_2/rafal_zdania.txt" *)

let load_sentence_list_rafal () = 
  let l = File.load_lines sentence_filename in
  List.flatten (Xlist.map l (fun s ->
    if s = "" then [] else
(*     match Xstring.split ".wav: " s with *)
    match Xstring.split ".wav\t" s with
      [filename;sentence] -> [{empty_record with filename; sentence}]
(*       [filename;sentence] -> if filename = "nie" then [{empty_record with filename; sentence}] else [] *)
    | _ -> failwith ("load_sentence_list_rafal: " ^ s)))
    
let load_sentence_list_L2a () = 
  let l = File.load_lines sentence_L2a_filename in
  let l = List.flatten (Xlist.map l (fun s ->
    if s = "" then [] else
    match Xstring.split " " s with
      filename :: sentence -> 
        let filename = 
          if Xstring.check_prefix "marta-" filename then Xstring.cut_prefix "marta-" filename else 
          failwith "load_sentence_list_L2a" in
        [{empty_record with filename; sentence=String.concat " " sentence}]
    | _ -> failwith ("load_sentence_list_L2a: " ^ s))) in
  let selected = StringSet.of_list (Xlist.rev_map (File.load_lines "L2-temp.tab") Xunicode.lowercase_utf8_string) in
  List.flatten (Xlist.map l (fun r ->
    if StringSet.mem selected r.sentence then [r] else []))
    
let load_sentence_list_tdnnf filename = 
  let l = File.load_lines filename in
  let l = List.flatten (Xlist.map l (fun s ->
    if s = "" then [] else
    match Xstring.split " " s with
      filename :: sentence -> 
        let filename = 
          if Xstring.check_prefix "marta-" filename then Xstring.cut_prefix "marta-" filename else 
          if Xstring.check_prefix "lukasz-" filename then Xstring.cut_prefix "lukasz-" filename else 
          if Xstring.check_prefix "beata_time-" filename then Xstring.cut_prefix "beata_time-" filename else 
          failwith "load_sentence_list_tdnnf" in
        [{empty_record with filename; sentence=String.concat " " sentence}]
    | _ -> failwith ("load_sentence_list_tdnnf: " ^ s))) in
  l*)
    
(*let load_words () =
  let l = File.load_lines words_filename in
  Xlist.fold l IntMap.empty (fun map s ->
    match Xstring.split " " s with
      [word;id] -> IntMap.add map (int_of_string id) word
    | _ -> failwith ("load_words: " ^ s))
    
let load_lattices data =
  Xlist.map data (fun r ->
    let lattice = List.rev (File.fold_tab ("../../ASR/lats/" ^ r.name ^ ".lat.1.txt") [] (fun lattice -> function
        [start;en;inp;word;weight] -> (int_of_string start,int_of_string en,inp,int_of_string word,weight) :: lattice
      | ["input "] -> lattice
      | line -> failwith ("load_lattices: " ^ r.name ^ " " ^ (String.concat "\t" line)))) in
    {r with lattice})*)

 
(*let parse_lattice filename lines =
  List.rev (Xlist.rev_map lines (fun line ->
    match Xstring.split " " line with
      [start;en;word;weight] -> int_of_string start,int_of_string en,word,weight 
    | [en;weight] -> -1,int_of_string en,"",weight 
    | [en] -> -1,int_of_string en,"","" 
    | [] -> -1,-1,"",""
    | line -> failwith ("load_lattices: " ^ filename ^ " " ^ (String.concat " " line))))*)
   
