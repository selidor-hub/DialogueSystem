(*
 *  data preprocessing for service grounder
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
open Trie
open Xjson

let beauty_filename = "../../corpus/sharepoint/beauty_attributes-2022-02-24-1.csv"
let beauty_filename2 = "../../corpus/sharepoint/beauty_attributes-2022-02-24-2.csv"

type t = F of string | T of string | NL | TAB

type r = {branza: string;kategoria: string;usluga1: string;id1: string;usluga2: string;id2: string;typ_klienta: string list;podtyp_klienta: string list;
  (*klient: string;*)cena: string;czas_trwania: string;opis: string;zdjecie: string;synonimy: string list;wykonawca: string list;czesc_klienta: string list;podrzednik_czesci_klienta: string list;ulomnosc: string list;
  czesc_glowna: string list;podrzednik_czesci_glownej: string list;dziedzina: string list;instrument: string list;efekt: string list;typ_organizacji: string list}

let empty_record =
  {branza="";kategoria="";usluga1="";id1="";usluga2="";id2="";typ_klienta=[];podtyp_klienta=[];
   cena="";czas_trwania="";opis="";zdjecie="";synonimy=[];wykonawca=[];czesc_klienta=[];
   podrzednik_czesci_klienta=[];ulomnosc=[];czesc_glowna=[];podrzednik_czesci_glownej=[];
   dziedzina=[];instrument=[];efekt=[];typ_organizacji=[]}
  
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

let split_comma s =
  let l = Xstring.split ",\\|;" s in
  List.rev (Xlist.rev_map l Xstring.remove_white)
  
let load_table filename =
  let l = parse_separators [] (Xstring.full_split "\"" (File.load_file filename)) in
  let l = List.rev (List.flatten (Xlist.rev_map l (function 
      NL -> [NL] 
    | TAB -> [TAB] 
    | F s -> [F s] 
    | T s -> Xlist.rev_map (Xstring.full_split "\n\\|\t" s) (function "\n" -> NL | "\t" -> TAB | s -> F s)))) in
  let l = split_into_lines [] [] l in
  let l = List.rev (Xlist.rev_map l (split_into_fields [])) in
  let l = List.rev (Xlist.rev_map l (fun fields -> List.rev (Xlist.rev_map fields Xstring.remove_white))) in  
  let l = List.tl (List.tl l) in
  let l = List.rev (Xlist.rev_map l (function
      [branza;kategoria;usluga1;id1;usluga2;id2;typ_klienta;podtyp_klienta;cena;czas_trwania;opis;zdjecie;
       synonimy;wykonawca;czesc_klienta;podrzednik_czesci_klienta;ulomnosc;czesc_glowna;podrzednik_czesci_glownej;
       dziedzina;instrument;efekt;typ_organizacji] |
      [branza;kategoria;usluga1;id1;usluga2;id2;typ_klienta;podtyp_klienta;cena;czas_trwania;opis;zdjecie;
       synonimy;wykonawca;czesc_klienta;podrzednik_czesci_klienta;ulomnosc;czesc_glowna;podrzednik_czesci_glownej;
       dziedzina;instrument;efekt;typ_organizacji;_] ->
        let l2 = Xlist.map [typ_klienta;podtyp_klienta;synonimy;wykonawca;czesc_klienta;podrzednik_czesci_klienta;
          ulomnosc;czesc_glowna;podrzednik_czesci_glownej;dziedzina;instrument;efekt;typ_organizacji] split_comma in
        (match l2 with
          [typ_klienta;podtyp_klienta;synonimy;wykonawca;czesc_klienta;podrzednik_czesci_klienta;ulomnosc;
           czesc_glowna;podrzednik_czesci_glownej;dziedzina;instrument;efekt;typ_organizacji] ->
            {branza;kategoria;usluga1;id1;usluga2;id2;typ_klienta;podtyp_klienta;cena;
             czas_trwania;opis;zdjecie;synonimy;wykonawca;czesc_klienta;podrzednik_czesci_klienta;
             ulomnosc;czesc_glowna;podrzednik_czesci_glownej;dziedzina;instrument;efekt;typ_organizacji}
        | _ -> failwith "load_table")
    | line -> failwith ("load_table: " ^ String.concat "'\t'" line))) in
  l
  
let load_synonyms filename =
  let l = parse_separators [] (Xstring.full_split "\"" (File.load_file filename)) in
  let l = List.rev (List.flatten (Xlist.rev_map l (function 
      NL -> [NL] 
    | TAB -> [TAB] 
    | F s -> [F s] 
    | T s -> Xlist.rev_map (Xstring.full_split "\n\\|\t" s) (function "\n" -> NL | "\t" -> TAB | s -> F s)))) in
  let l = split_into_lines [] [] l in
  let l = List.rev (Xlist.rev_map l (split_into_fields [])) in
  let l = List.rev (Xlist.rev_map l (fun fields -> List.rev (Xlist.rev_map fields Xstring.remove_white))) in  
  let l = List.rev (Xlist.fold l [] (fun l -> function
      [s;"";t] -> (s,split_comma t) :: l
    | ["";""] -> l
    | ["Person:";""] -> l
    | ["BodyPart:";""] -> l
    | ["Effect:";""] -> l
    | ["Flaw:";""] -> l
    | ["Instrument:";""] -> l
    | ["Profession:";""] -> l
    | ["Service:";""] -> l
    | ["OrganizationType:";""] -> l
    | [s;""] -> (s,[]) :: l
    | line -> failwith ("load_synonyms: " ^ String.concat "'\t'" line))) in
  l
 
  
let print_prefix r =
  Printf.printf "'%40s' '%30s' '%30s' '%5s' '%30s' '%5s'\n" r.branza r.kategoria r.usluga1 r.id1 r.usluga2 r.id2
   
(*let print_infix r =
  Printf.printf "'%40s' '%30s' '30s' '%5s' '%30s' '%5s'\n" r.typ_klienta r.podtyp_klienta (*r.klient*) r.cena r.czas_trwania r.opis
   
let print_sufix r =
  Printf.printf "'%40s' '%30s' '%30s' '%30s' '%30s'\n" r.synonimy r.wykonawca r.czesc_klienta r.czesc_glowna r.podrzednik_czesci_glownej*)
   
let print_values name data selector_fun =
  let set = Xlist.fold data StringSet.empty (fun set r -> 
    Xlist.fold ((*split_comma*) (selector_fun r)) set StringSet.add) in
  print_endline ("Creating file results/values_" ^ name ^ ".tab");
  File.file_out ("results/values_" ^ name ^ ".tab") (fun file ->
    StringSet.iter set (fun s -> Printf.fprintf file "%s\n" s))
    
let usluga_path = "../../corpus/examples/"
let lexemes_base_path = "../lexemes/data/base/"
let lexemes_fixed_path = "../lexemes/data/fixed/"
let lexemes_beauty_path = "../lexemes/data/beauty/"
   
let recognize_usluga trie s =
(*   print_endline ("recognize_usluga: " ^ s);  *)
  let parsed = Patterns.TokenTrie.find trie s in
(*   print_endline "recognize_usluga 1";  *)
  let l = Xlist.fold parsed [] (fun l (tokens,prods) ->
    let s = String.concat "" tokens in
    let prods = StringSet.to_list (StringSet.of_list prods) in
    match prods,s with
      [],"" -> l
    | [],"/" -> l
    | [],"/ " -> l
    | []," /" -> l
    | []," / " -> l
    | [],"  / " -> l
    | [],_ -> (*print_endline ("recognize_usluga 1: \"" ^ s ^ "\""); l*)raise Not_found
    | ["beauty_usluga1"],_ -> s :: l
    | ["beauty_usluga2"],_ -> s :: l
    | ["beauty_kategoria"],_ -> s :: l
    | ["beauty_branza"],_ -> s :: l
    | ["beauty_synonimy"],_ -> s :: l
    | ["beauty_usluga2";"beauty_usluga1";"beauty_kategoria"],_ -> s :: l
    | ["beauty_usluga1";"beauty_kategoria"],_ -> s :: l
    | ["beauty_usluga2";"beauty_usluga1"],_ -> s :: l
    | ["beauty_usluga1";"beauty_synonimy"],_ -> s :: l
    | ["beauty_usluga2";"beauty_synonimy"],_ -> s :: l
    | ["beauty_kategoria";"beauty_branza"],_ -> s :: l
    | [prod],_ -> print_endline ("recognize_usluga 2: " ^ prod ^ " : " ^ s); l
    | prod :: _,_ -> failwith ("recognize_usluga: " ^ String.concat " " prods)) in
(*   print_endline "recognize_usluga 2";  *)
  List.rev l
  
let load_phrases set path name =
  File.fold_tab (path ^ name ^ ".tab") set (fun set -> function
      s :: _ -> StringSet.add set s
    | line -> failwith ("load_phrases: " ^ String.concat "\t" line))
  
let analyze_usluga name selector l =
  let trie = Patterns.TokenTrie.load usluga_path [name] in
  let set =
    Xlist.fold l StringSet.empty (fun set r ->
      try if selector r <> "" then let _ = recognize_usluga trie (selector r) in set else set
      with Not_found -> StringSet.add set (selector r)) in
  if StringSet.is_empty set then () else (
  print_endline ("Creating file results/add_" ^ name ^ ".tab");
  File.file_out ("results/add_" ^ name ^ ".tab") (fun file -> 
    StringSet.iter set (Printf.fprintf file "%s\n")))
   
let analyze_feature path names selector l =
  let name = if names = [] then "XX" else List.hd names in
  let phrases = Xlist.fold names (StringSet.singleton "") (fun set name ->
    load_phrases set path name) in
  let set = Xlist.fold l StringSet.empty (fun set r ->
    let values = (*split_comma*) (selector r) in
    Xlist.fold values set (fun set s ->
      let t = Xunicode.lowercase_utf8_string s in
      if StringSet.mem phrases s || StringSet.mem phrases t then set else
      StringSet.add set s)) in
  if StringSet.is_empty set then () else (
  print_endline ("Creating file results/add_" ^ name ^ ".tab");
  File.file_out ("results/add_" ^ name ^ ".tab") (fun file -> 
    StringSet.iter set (Printf.fprintf file "%s\n")))
    
let analyze_feature2 paths_names selector l =
  let name = if paths_names = [] then "YY" else snd (List.hd paths_names) in
  let phrases = Xlist.fold paths_names (StringSet.singleton "") (fun set (path,name) ->
    load_phrases set path name) in
  let set = Xlist.fold l StringSet.empty (fun set r ->
    let values = (*split_comma*) (selector r) in
    Xlist.fold values set (fun set s ->
      let t = Xunicode.lowercase_utf8_string s in
      if StringSet.mem phrases s || StringSet.mem phrases t then set else
      StringSet.add set s)) in
  if StringSet.is_empty set then () else (
  print_endline ("Creating file results/add_" ^ name ^ ".tab");
  File.file_out ("results/add_" ^ name ^ ".tab") (fun file -> 
    StringSet.iter set (Printf.fprintf file "%s\n")))
    
let analyze_synonyms l =
  let base_names = ["Person";"BodyPart";"Flaw";] in
  let beauty_names = ["Profession.beauty";"Service.beauty";"Service.beauty.inf";"Domain.beauty";
    "Instrument.beauty";"Effect.beauty";"OrganizationType.beauty"] in
  let phrases = Xlist.fold base_names (StringSet.singleton "") (fun set name ->
    load_phrases set lexemes_base_path name) in
  let phrases = Xlist.fold beauty_names phrases (fun set name ->
    load_phrases set lexemes_beauty_path name) in
  let set = Xlist.fold l StringSet.empty (fun set (s,sl) ->
    Xlist.fold (s :: sl) set (fun set s ->
      let t = Xunicode.lowercase_utf8_string s in
      if StringSet.mem phrases s || StringSet.mem phrases t then set else
      StringSet.add set s)) in
  if StringSet.is_empty set then () else (
  print_endline "Creating file results/add_synonyms.tab";
  File.file_out ("results/add_synonyms.tab") (fun file -> 
    StringSet.iter set (Printf.fprintf file "%s\n")))
 
let rec split_json_entry = function
    JObject["and",JArray (t :: l)] -> 
      let text,t = split_json_entry t in 
      text, JObject["and",JArray (t :: l)]
  | JObject l -> 
        let text,l = Xlist.fold l ("",[]) (fun (text,l) -> function
            "text", JString s -> if text = "" then s,l else failwith "split_json_entry 1"
          | e,t -> text, (e,t) :: l) in
        if text = "" then failwith ("split_json_entry 2: " ^ json_to_string (JObject l)) else
        Xstring.remove_white text, JObject (List.rev l)
  | _ -> failwith "split_json_entry 3"

let load_parsed map name =
  let json = json_of_string (File.load_file (usluga_path ^ "beauty_" ^ name ^ "_parsed.json")) in
  let l = match json with JArray l -> l | _ -> failwith "load_parsed 1" in
  Xlist.fold l map (fun map t ->
    let text, t = split_json_entry t in
    StringMap.add_inc map text t (fun t2 -> if t = t2 then t else (*failwith*)(print_endline ("load_parsed 2: " ^ text); t)))

let rec expand_with = function
    JObject["and",JArray l] -> Xlist.rev_map (Xlist.multiply_list (Xlist.map l expand_with)) (fun l -> JObject["and",JArray l])
  | JObject["or",JArray l] -> Xlist.rev_map (Xlist.multiply_list (Xlist.map l expand_with)) (fun l -> JObject["or",JArray l])
  | JObject["with",JArray l] -> List.flatten (Xlist.map l expand_with)
  | JObject l -> Xlist.rev_map (Xlist.multiply_list (Xlist.map l (fun (e,t) -> Xlist.rev_map (expand_with t) (fun t -> e,t)))) (fun l -> JObject l)
  | JString s -> [JString s]
  | JNumber s -> [JNumber s]
  | json -> failwith ("expand_with: " ^ json_to_string_fmt2 "" json)
    
let rec find_attributes path found = function
    JObject["and",JArray l] -> Xlist.fold l found (find_attributes path)
  | JObject["or",JArray l] -> Xlist.fold l found (find_attributes path)
  | JObject["with",JArray l] -> Xlist.fold l found (find_attributes path)
  | JObject["alias",_ ] -> found
  | JObject l ->
      Xlist.fold l found (fun found (e,t) -> find_attributes (e :: path) found t)
  | JString "client" -> found
  | JString s | JNumber s -> (String.concat "#" (List.rev path), s) :: found
  | json -> failwith ("find_attributes 2: " ^ json_to_string_fmt2 "" json)
 
let check_substrings l =
  let parsed_map = Xlist.fold ["usluga1";"usluga2"] StringMap.empty load_parsed in
  let l = Xlist.fold l [] (fun l r ->
    if r.usluga2 = "" then (r.id1, r.usluga1) :: l else (r.id2, r.usluga2) :: l) in
  let l = Xlist.rev_map l (fun (id,usluga) -> 
    id,usluga, try StringMap.find parsed_map usluga with Not_found -> print_endline ("check_substrings: " ^ usluga); JNull) in
  let l = List.flatten (Xlist.rev_map l (fun (id,usluga,parsed) ->
    if parsed = JNull then [] else
    let parsed_list = expand_with parsed in
(*    if Xlist.size parsed_list <> 1 then (
      print_endline (json_to_string parsed);
      Xlist.iter parsed_list (fun t -> print_endline (json_to_string t)));*)
    Xlist.rev_map parsed_list (fun parsed -> id,usluga,parsed))) in
(*   Xlist.iter l (fun (id,usluga,parsed) -> print_endline (id ^ " " ^ usluga ^ " " ^ json_to_string parsed)); *)
  let l = Xlist.rev_map l (fun (id,usluga,parsed) -> 
    id,usluga,StringSet.of_list (Xlist.map (find_attributes [] [] parsed) (fun (a,s) -> a ^ "#" ^ s))) in
(*   Xlist.iter l (fun (id,usluga,attrs) -> print_endline (id ^ " " ^ usluga ^ " " ^ String.concat " " (StringSet.to_list attrs))); *)
  Xlist.iter l (fun (id1,usluga1,attrs1) ->
    Xlist.iter l (fun (id2,usluga2,attrs2) ->
      if id1 = id2 then () else
      if StringSet.is_empty (StringSet.difference attrs1 attrs2) then 
        Printf.printf "SUBSTRINGS: %s %s --- %s %s\n" id1 usluga1 id2 usluga2))
 
let known_multiple_identifiers = StringSet.of_list [
  "Strzyżenie męskie -niezależnie od długości włosów | Strzyżenie męskie";
  "Strzyżenie damskie - niezależnie od długości włosów | Strzyżenie damskie";
  "Strzyżenie dziewczynki - niezależnie od długości włosów | Strzyżenie dziewczynki";
  "Modelowanie włosów - niezależnie od długości włosów | Modelowanie włosów";
  "Upięcie włosów na każdą okazję | Upięcie włosów";
  "Koloryzacja  - niezależnie od typu | Koloryzacja";
  "Baleyage - niezależnie od typu | Baleyage";
  "Ombre - niezależnie od długości włosów | Ombre";
  "Sombre - niezależnie od długości włosów | Sombre";
  "Refleksy - całe włosy | Refleksy";
  "Trwała ondulacja -niezależnie od długości włosów | Trwała ondulacja";
  "Keratynowe prostowanie włosów - niezależnie od długości włosów | Keratynowe prostowanie włosów";
  "Makijaż klasyczny na każdą okazję | Makijaż  klasyczny";
  "Regulacja brwi - niezależnie od typu | Regulacja brwi";
  "Regulacja brwi niezależnie od typu  + henna | Regulacja brwi + henna";
  "Masaż klasyczny - każdy rodzaj | Masaż klasyczny";
  "Solarium - każdy typ | Solarium";
  "Opalanie natryskowe – każdy rodzaj | Opalanie natryskowe";
  "Mezoterapia igłowa - niezależnie od partii ciała | Mezoterapia igłowa";
  "Mezoterapia bezigłowa -niezależnie od partii ciała | Mezoterapia bezigłowa";
  "Oxybrazja - niezależnie od partii ciała | Oxybrazja";
  "Icon Time - niezależnie od typu zabiegu | Icon Time";
  "Peeling tox peel  - niezależnie od partii ciała | Peeling tox peel";
  "Biorewitalizacja skóry - niezależnie od typu zabiegu | Biorewitalizacja skóry";
  "Zabieg retinolowy RETIX C - niezależnie od typu zabiegu | Zabieg retinolowy RETIX C";
  "DermaQuest - niezależnie od typu zabiegu | DermaQuest";
  "Laser frakcyjny - niezależnie od partii ciała | Laser frakcyjny EMERGE";
  "Jonoforeza  - niezależnie od partii ciała | Jonoforeza";
  "Fotoodmładzanie  - niezależnie od partii ciała | Fotoodmładzanie";
  "Elektrokoagulacja -niezależnie od zmian skórnych | Elektrokoagulacja";
  "Powiększanie i modelowanie ust - niezależnie od metody | Powiększanie i modelowanie ust";
  "Drenaż limfatyczny - każda partia ciała | Drenaż limfatyczny";
  "Mezoterapia - niezależnie od partii ciała | Mezoterapia";
  "Sauna - niezależnie od rodzaju | Sauna";
  "Fala uderzeniowa - niezależnie od obszaru | Fala uderzeniowa";
  "Fale radiowe – niezależnie od obszaru | Fale radiowe";
  "Hifu - niezależnie od obszaru | HIFU";
  "Karboksyterapia CO2 -niezależnie od obszaru | Karboksyterapia CO2";
  "Endermologia  - niezależnie od obszaru | Endermologia LPG";
  "Termolifting - niezależnie od obszaru | Termolifting";
  "Liporadiologia – niezależnie od obszaru | Liporadiologia";
  "Osocze bogatopłytkowe - niezależnie od obszaru | Osocze bogatopłytkowe";
  "Depilacja woskiem  - niezależnie od części ciała | Depilacja woskiem";
  "Depilacja Lycon – niezależnie od części ciała | Depilacja Lycon";
  "Depilacja pastą cukrową – niezależnie od części ciała | Depilacja pastą cukrową";
  "Depilacja laserowa - niezależnie od części ciała | Depilacja laserowa";
  "Fotodepilacja – niezależnie od części ciała | Fotodepilacja";
  "Depilacja woskiem miękkim  - niezależnie od części ciała | Depilacja woskiem miękkim";
  "Depilacja woskiem twardym  - niezależnie od części ciała | Depilacja woskiem twardym";
  "Depilacja woskiem autorskim -  niezależnie od części ciała | Depilacja woskiem autorskim";
  "Strzyżenie męskie ogólne | Strzyżenie męskie";
  "Strzyżenie damskie ogólne | Strzyżenie damskie";
  "Strzyżenie dziewczynki ogólne | Strzyżenie dziewczynki";
  "Modelowanie włosów ogólne | Modelowanie włosów";
  "Koloryzacja  ogólna | Koloryzacja";
  "Baleyage ogólny | Baleyage";
  "Ombre ogólne | Ombre";
  "Sombre ogólne | Sombre";
  "Trwała ondulacja ogólna | Trwała ondulacja";
  "Keratynowe prostowanie włosów ogólne | Keratynowe prostowanie włosów";
  "Depilacja woskiem zwykłym ogólna | Depilacja woskiem";
  "Regulacja brwi ogólna | Regulacja brwi";
  "Regulacja brwi ogólna  + henna | Regulacja brwi + henna";
  "Masaż klasyczny ogólny | Masaż klasyczny";
  "Solarium ogólne | Solarium";
  "Opalanie natryskowe ogólne | Opalanie natryskowe";
  "Mezoterapia igłowa ogólna | Mezoterapia igłowa";
  "Mezoterapia bezigłowa ogólna | Mezoterapia bezigłowa";
  "Oxybrazja ogólna | Oxybrazja";
  "Icon Time ogólny | Icon Time";
  "Peeling tox peel  ogólny | Peeling tox peel";
  "Biorewitalizacja skóry ogólna | Biorewitalizacja skóry";
  "Zabieg retinolowy RETIX C ogólny | Zabieg retinolowy RETIX C";
  "DermaQuest ogólna | DermaQuest";
  "Laser frakcyjny ogólny | Laser frakcyjny EMERGE";
  "Jonoforeza  ogólna | Jonoforeza";
  "Fotoodmładzanie  ogólne | Fotoodmładzanie";
  "Elektrokoagulacja ogólna | Elektrokoagulacja";
  "Powiększanie i modelowanie ust ogólne | Powiększanie i modelowanie ust";
  "Drenaż limfatyczny ogólny | Drenaż limfatyczny";
  "Mezoterapia ogólna | Mezoterapia";
  "Sauna ogólna | Sauna";
  "Fala uderzeniowa ogólna | Fala uderzeniowa";
  "Fale radiowe ogólna | Fale radiowe";
  "Hifu ogólne | HIFU";
  "Karboksyterapia CO2 ogólna | Karboksyterapia CO2";
  "Endermologia  ogólna | Endermologia LPG";
  "Termolifting ogólny | Termolifting";
  "Liporadiologia ogólna | Liporadiologia";
  "Osocze bogatopłytkowe ogólne | Osocze bogatopłytkowe";
  "Masaż klasyczny pełen | Masaż klasyczny";
  ]

let analyze_records l =
  analyze_usluga "beauty_branza" (fun r -> r.branza) l;
  analyze_usluga "beauty_kategoria" (fun r -> r.kategoria) l;
  analyze_usluga "beauty_usluga1" (fun r -> r.usluga1) l;
  analyze_usluga "beauty_usluga2" (fun r -> r.usluga2) l;
  Xlist.iter l (fun r -> if r.typ_klienta <> ["osoba"] (*&& r.typ_klienta <> ""*) then (
    print_prefix r; 
    failwith ("analyze_records typ_klienta: " ^ String.concat ", " r.typ_klienta)));
  analyze_feature lexemes_base_path ["Person"] (fun r -> r.podtyp_klienta) l;
  analyze_feature usluga_path ["beauty_synonimy"] (fun r -> r.synonimy) l;
  analyze_feature lexemes_beauty_path ["Profession.beauty"] (fun r -> r.wykonawca) l;
  analyze_feature lexemes_base_path ["BodyPart"] (fun r -> r.czesc_klienta) l;
  analyze_feature2 [lexemes_base_path,"Length.adj";lexemes_fixed_path,"Length.fixed"] (fun r -> r.podrzednik_czesci_klienta) l;
  analyze_feature lexemes_base_path ["Flaw"] (fun r -> r.ulomnosc) l;
  analyze_feature lexemes_beauty_path ["Service.beauty";"Service.beauty.inf"] (fun r -> r.czesc_glowna) l;
  analyze_feature2 [
    lexemes_base_path,"Attr";lexemes_base_path,"ServiceParam";lexemes_base_path,"Length.adj";
    lexemes_fixed_path,"ServiceParam_eng";lexemes_fixed_path,"ServiceParam"] (fun r -> r.podrzednik_czesci_glownej) l;
  analyze_feature lexemes_beauty_path ["Domain.beauty"] (fun r -> r.dziedzina) l;
  analyze_feature lexemes_beauty_path ["Instrument.beauty"] (fun r -> r.instrument) l;
  analyze_feature lexemes_beauty_path ["Effect.beauty"] (fun r -> r.efekt) l;
  analyze_feature lexemes_beauty_path ["OrganizationType.beauty"] (fun r -> r.typ_organizacji) l;
  let map = Xlist.fold l IntMap.empty (fun map r ->
    let map = if r.usluga1 <> "" then IntMap.add_inc map (int_of_string r.id1) [r.usluga1] (fun l -> r.usluga1 :: l) else map in
    let map = if r.usluga2 <> "" then IntMap.add_inc map (int_of_string r.id2) [r.usluga2] (fun l -> r.usluga2 :: l) else map in
    map) in
  IntMap.iter map (fun id l ->
    if Xlist.size l > 1 then 
      if StringSet.mem known_multiple_identifiers (String.concat " | " l) then () else
      Printf.printf "MULTIPLE IDENTIFIER %d %s\n" id (String.concat " | " l));
(*   check_substrings l; *)
  let l,_,_,_ = Xlist.fold l ([],"","","") (fun (l,b,k,u) r ->
    let r,b = if r.branza = "" then {r with branza=b},b else r,r.branza in
    let r,k = if r.kategoria = "" then {r with kategoria=k},k else r,r.kategoria in
    let r,u = if r.usluga1 = "" then {r with usluga1=u},u else r,r.usluga1 in
    r::l,b,k,u) in
  let l = List.rev l in
(*   Xlist.iter l print_prefix; *)
(*  Xlist.iter l (fun r ->
  print_values "podtyp_klienta" l (fun r -> r.podtyp_klienta);
  print_values "klient" l (fun r -> r.klient);
  print_values "synonimy" l (fun r -> r.synonimy);
  print_values "wykonawca" l (fun r -> r.wykonawca);
  print_values "czesc_klienta" l (fun r -> r.czesc_klienta);
  print_values "czesc_glowna" l (fun r -> r.czesc_glowna);
  print_values "podrzednik" l (fun r -> r.podrzednik);
(*  let podtyp_klienta = Xlist.fold l StringSet.empty (fun set r -> 
    Xlist.fold (Xstring.split "," r.podtyp_klienta) set (fun set s -> StringSet.add set (Xstring.remove_white s)) in
  File.file_out "results/values_podtyp_klienta.tab" (fun file ->
    StringSet.iter podtyp_klienta (fun s -> Printf.fprintf file "%s\n" s));*)
(*   Xlist.iter l print_infix; *)
(*   Xlist.iter l print_sufix; *)*)
  l
    
let check_synonyms_presence l synonyms =
  let set = Xlist.fold synonyms StringSet.empty (fun set (s,sl) ->
    Xlist.fold sl set (fun set s -> StringSet.add set (Xunicode.lowercase_utf8_string s))) in
  let found = Xlist.fold l StringSet.empty (fun found r ->
    Xlist.fold [r.podtyp_klienta;r.wykonawca;r.czesc_klienta;r.podrzednik_czesci_klienta;r.ulomnosc;
      r.czesc_glowna;r.podrzednik_czesci_glownej;r.dziedzina;r.instrument;r.efekt;r.typ_organizacji] found (fun found v ->
        Xlist.fold ((*split_comma*) v) found (fun found s -> 
          if StringSet.mem set (Xunicode.lowercase_utf8_string s) then StringSet.add found s else found))) in
  if StringSet.size found > 0 then 
    Printf.printf "SYNONYMS: %s\n" (String.concat " | " (StringSet.to_list found))
    
let get_usluga_id r =
  match r.usluga1,r.id1,r.usluga2,r.id2 with
   "",_,"","" -> failwith "create_tables 1"
 | _,"","","" -> failwith ("create_tables 2: " ^ r.usluga1)
 | usluga,id,"","" -> usluga,id
 | _,_,"",_ -> failwith "create_tables 3"
 | usluga,id,_,"" -> print_endline ("create_tables 4: " ^ r.usluga2); usluga,id
 | _,_,usluga,id -> usluga,id 
   
let create_table name syn_map data selector_fun =
  File.file_out ("data/" ^ name ^ ".tab") (fun file ->
    Xlist.iter data (fun r ->
      let usluga,id = get_usluga_id r in
      let values = List.rev (StringSet.to_list (Xlist.fold (selector_fun r) StringSet.empty (fun set s -> 
        let set = StringSet.add set s in
        let sl = try StringMap.find syn_map (Xunicode.lowercase_utf8_string s) with Not_found -> [] in
        Xlist.fold sl set StringSet.add))) in
      Printf.fprintf file "%s\n" (String.concat "\t" (usluga :: id :: values))))
      
(*let create_service_table name data trie selector_fun =
  File.file_out ("data/" ^ name ^ ".tab") (fun file ->
    Xlist.iter data (fun r ->
      let usluga,id = get_usluga_id r in
      let values = recognize_usluga trie (selector_fun r) in
      let values = Xlist.map values Xstring.remove_white in
      Printf.fprintf file "%s\n" (String.concat "\t" (usluga :: id :: values))))*)
      
let create_usluga_table data =
  File.file_out ("data/usluga1_usluga2.tab") (fun file ->
    Xlist.iter data (fun r ->
      Printf.fprintf file "%s\t%s\t%s\t%s\n" r.usluga1 r.id1 r.usluga2 r.id2))

let create_tables synonyms l =
  let syn_map = Xlist.fold synonyms StringMap.empty (fun map (s,sl) ->
    StringMap.add map (Xunicode.lowercase_utf8_string s) sl) in
  create_table "podtyp_klienta" syn_map l (fun r -> r.podtyp_klienta);
(*   create_table "klient" l (fun r -> r.klient); *)
(*   create_table "synonimy" l (fun r -> r.synonimy); *)
  create_table "wykonawca" syn_map l (fun r -> r.wykonawca);
  create_table "czesc_klienta" syn_map l (fun r -> r.czesc_klienta);
  create_table "podrzednik_czesci_klienta" syn_map l (fun r -> r.podrzednik_czesci_klienta);
  create_table "ulomnosc" syn_map l (fun r -> r.ulomnosc);
  create_table "czesc_glowna" syn_map l (fun r -> r.czesc_glowna);
  create_table "podrzednik_czesci_glownej" syn_map l (fun r -> r.podrzednik_czesci_glownej);
  create_table "dziedzina" syn_map l (fun r -> r.dziedzina);
  create_table "instrument" syn_map l (fun r -> r.instrument);
  create_table "efekt" syn_map l (fun r -> r.efekt);
  create_table "typ_organizacji" syn_map l (fun r -> r.typ_organizacji);
(*  create_service_table "kategoria" l kategoria_trie (fun r -> r.kategoria);
  create_service_table "usluga1" l usluga1_trie (fun r -> r.usluga1);
  create_service_table "usluga2" l usluga2_trie (fun r -> r.usluga2);*)
  create_usluga_table l;
  ()
   
let create_synonym_map synonyms =
  Xlist.fold synonyms StringMap.empty (fun map (s,sl) ->
    let s = Xunicode.lowercase_utf8_string s in
    Xlist.fold sl map (fun map t ->
      let t = Xunicode.lowercase_utf8_string t in
      StringMap.add_inc map t [s] (fun l -> s :: l)))
  
let extract_attributes synonym_map t =
  let l = find_attributes [] [] t in
  let l = Xlist.fold l [] (fun l (path,s) -> 
    let syns = try StringMap.find synonym_map s with Not_found -> [s] in
    Xlist.fold syns l (fun l s -> (path, s) :: l)) in
  Xlist.fold l empty_record (fun r -> function
    | "alias", s -> r
    | "doer#profession", s -> {r with wykonawca = s :: r.wykonawca}
    | "organization#type", s -> {r with typ_organizacji = s :: r.typ_organizacji}
    | "patient#flaw", s -> {r with ulomnosc = s :: r.ulomnosc}
    | "patient#part", s -> {r with czesc_klienta = s :: r.czesc_klienta}
    | "patient#part-length", s -> {r with podrzednik_czesci_klienta = s :: r.podrzednik_czesci_klienta}
    | "patient#part-param", s -> {r with podrzednik_czesci_klienta = s :: r.podrzednik_czesci_klienta}
    | "patient#part-quantity", s -> {r with podrzednik_czesci_klienta = s :: r.podrzednik_czesci_klienta}
    | "patient#part-colour", s -> {r with podrzednik_czesci_klienta = s :: r.podrzednik_czesci_klienta}
    | "patient#person", s -> {r with podtyp_klienta = s :: r.podtyp_klienta}
    | "quantity", s -> r (* FIXME *)
    | "service#domain", s -> {r with dziedzina = s :: r.dziedzina}
    | "service#effect", s -> {r with efekt = s :: r.efekt}
    | "service#instrument", s -> {r with instrument = s :: r.instrument}
    | "service#name", s -> {r with czesc_glowna = s :: r.czesc_glowna}
    | "service#param", s -> {r with podrzednik_czesci_glownej = s :: r.podrzednik_czesci_glownej}
    | "service#quantity", s -> {r with podrzednik_czesci_glownej = s :: r.podrzednik_czesci_glownej}
    | path, s -> print_endline ("extract_attributes: " ^ path); r)
  
let string_of_stringset set =
  String.concat ", " (List.sort compare (StringSet.to_list set))
  
let print_extention parsed_map l name selector trie =
  File.file_out ("results/attr_" ^ name ^ ".tab") (fun file ->
    Xlist.iter l (fun r ->
      let usluga = if r.usluga2 = "" then r.usluga1 else r.usluga2 in
(*       print_endline "print_extention 1"; *)
      let descriptions = 
        List.flatten (Xlist.map ([r.branza; r.kategoria; r.usluga1; r.usluga2] @ r.synonimy) (fun s -> 
          try recognize_usluga trie s with Not_found -> failwith ("print_extention 1: " ^ s))) in
(*        print_endline "print_extention 2"; *)
      let provided = StringSet.of_list (selector r) in
      let provided,both,inferred = Xlist.fold descriptions (provided,StringSet.empty,StringSet.empty) (fun (provided,both,inferred) description ->
        let p = 
          try StringMap.find parsed_map description
          with Not_found -> failwith ("print_extention 2: " ^ description) in
        Xlist.fold (selector p) (provided,both,inferred) (fun (provided,both,inferred) s -> 
          if StringSet.mem provided s then StringSet.remove provided s, StringSet.add both s, inferred else
          if StringSet.mem both s then provided, both, inferred else
          provided, both, StringSet.add inferred s)) in          
(*       print_endline "print_extention 3"; *)
      Printf.fprintf file "%s\t%s | %s | %s\n" usluga 
          (string_of_stringset provided) (string_of_stringset both) (string_of_stringset inferred)))
   
let extend_table synonyms l =
  ignore (Sys.command "rm -f results/attr_*.tab");
  let synonym_map = create_synonym_map synonyms in
  let parsed_map = 
    Xlist.fold ["branza";"kategoria";"usluga1";"usluga2";"synonimy"] 
      StringMap.empty load_parsed in
  let parsed_map = StringMap.map parsed_map (extract_attributes synonym_map) in
  let trie = Patterns.TokenTrie.load usluga_path ["beauty_branza";"beauty_kategoria";"beauty_usluga1";"beauty_usluga2";"beauty_synonimy"] in
  Xlist.iter [
    "podtyp_klienta",(fun r -> r.podtyp_klienta);
    "wykonawca",(fun r -> r.wykonawca);
    "czesc_klienta",(fun r -> r.czesc_klienta);
    "podrzednik_czesci_klienta",(fun r -> r.podrzednik_czesci_klienta);
    "ulomnosc",(fun r -> r.ulomnosc);
    "czesc_glowna",(fun r -> r.czesc_glowna);
    "podrzednik_czesci_glownej",(fun r -> r.podrzednik_czesci_glownej);
    "dziedzina",(fun r -> r.dziedzina);
    "instrument",(fun r -> r.instrument);
    "efekt",(fun r -> r.efekt);
    "typ_organizacji",(fun r -> r.typ_organizacji)
    ] (fun (name,selector) -> 
    print_extention parsed_map l name selector trie)

let _ =
  let l = load_table beauty_filename in
  ignore (Sys.command "rm -f results/add_*.tab");
  let l = analyze_records l in
  let synonyms = load_synonyms beauty_filename2 in
  analyze_synonyms synonyms;
  check_synonyms_presence l synonyms;
  extend_table synonyms l;
  create_tables synonyms l;
  ()
