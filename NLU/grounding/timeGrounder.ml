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

let corpus_mode = ref false
let corpus_filename = ref ""
let validation_filename = ref ""
let comm_stdio = ref true
let port = ref 9761

let spec_list = [
  "-i", Arg.Unit (fun () -> comm_stdio:=true), "Communication using stdio (default)";
  "-p", Arg.Int (fun p -> comm_stdio:=false; port:=p), "<port> Communication using sockets on given port number";
  "-c", Arg.String (fun s -> corpus_mode:=true; corpus_filename:=s), "<filename> Process corpus given as an argument";
  "-v", Arg.String (fun s -> validation_filename:=s), "<filename> Validation set";
  "--debug", Arg.Unit (fun () -> debug:=true), "Debug mode";
  ]

let usage_msg =
  "Usage: category_grounder <options>\nOptions are:"
  
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

let load_corpus filename =
  let json = Xjson.json_of_string (File.load_file filename) in
  let l = match json with JArray l -> l | _ -> failwith "load_corpus" in
  List.rev (Xlist.rev_map l split_json_entry)
 
let process_query = function 
    JObject l -> 
      let query,now,horizon,limit,start_year,pp,cats = Xlist.fold l (JNull,"",365,30,0,"",[]) (fun (query,now,horizon,limit,start_year,pp,cats) -> function
          "query",t -> t,now,horizon,limit,start_year,pp,cats
        | "now", JString s -> query,s,horizon,limit,start_year,pp,cats
        | "horizon", JNumber n -> query,now,(try int_of_string n with _ -> failwith "Invalid query: horizon value"),limit,start_year,pp,cats
        | "limit", JNumber n -> query,now,horizon,(try int_of_string n with _ -> failwith "Invalid query: limit value"),start_year,pp,cats
        | "start-year", JNumber n -> query,now,horizon,limit,(try int_of_string n with _ -> failwith "Invalid query: limit value"),pp,cats
        | "previous-proposal", JString s -> query,now,horizon,limit,start_year,pp,cats
        | "categories",JArray l -> query,now,horizon,limit,start_year,pp,l
        | e,t -> failwith ("Invalid query: " ^ e)) in
      if query = JNull then failwith "Invalid query: no query provided" else
      if now = "" then failwith "Invalid query: now not provided" else
      let cats = List.rev (Xlist.rev_map cats (function JString s -> s | _ -> failwith "Invalid query: categories value")) in
      let start_year = if start_year = 0 then try int_of_string (String.sub now 0 4) with _ -> failwith "Invalid query" else start_year in
      query,now,horizon,limit,start_year,pp,cats
  | q -> failwith "Invalid query"
  
let input_text channel =
  let s = ref (try input_line channel with End_of_file -> "") in
  let lines = ref [] in
  while !s <> "" do
    lines := !s :: !lines;
    s := try input_line channel with End_of_file -> ""
  done;
  String.concat "\n" (List.rev !lines)
  
let rec select_time_key = function
    JObject[s,JArray l] when s="and" || s="or" || s="with" ->
      let l = Xlist.rev_map l select_time_key in
      JObject[s,JArray l]
  | JObject l ->
      let l = Xlist.fold l [] (fun l (e,t) ->
        if e = "time" then t :: l else l) in
      if l = [] then JEmpty else
      JObject["and",JArray l]
  | t -> if !debug then failwith ("select_time_key: " ^ json_to_string_fmt2 "" t) else JEmpty
  
    
(* FIXME: czas trzeba liczyć od początku roku. Trzeba ustalić od którego roku *)

let parse_time s =
  match Xstring.full_split " \\|:\\|-" s with
    [y;"-";m;"-";d;" ";h;":";mi;":";s] -> 
      (try {
        Unix.tm_sec=int_of_string s; Unix.tm_min=int_of_string mi; Unix.tm_hour=int_of_string h; 
        Unix.tm_mday=int_of_string d; Unix.tm_mon=int_of_string m - 1; Unix.tm_year=int_of_string y - 1900;
        Unix.tm_wday=0; Unix.tm_yday=0; Unix.tm_isdst=false}
      with _ -> failwith ("parse_time 1: " ^ s))
  | l -> failwith ("parse_time 2: " ^ s)

let create_time nowx horizonx start_yearx ppx =
    let now0 = parse_time nowx in
    let now = (int_of_float (fst (Unix.mktime now0))) / (60 * 60 * 24) in
    let pp_hour, pp_min, pp_date = 
      if ppx = "" then -1, -1, now else
      let pp = parse_time ppx in 
      pp.Unix.tm_hour, pp.Unix.tm_min,
      (int_of_float (fst (Unix.mktime pp))) / (60 * 60 * 24) in
    let pp_date = [Interval.interval_of_date_interval (Interval.create_date_interval pp_date 0)] in
    let start = parse_time (string_of_int start_year ^ "-01-01 01:00:00") in (* FIXME: ignoruję start_yearx *)
    let start = (int_of_float (fst (Unix.mktime start))) / (60 * 60 * 24) in
    let horizon = horizonx + now - start in
    let time = Interval.create_date_interval start horizon in
    let days = List.rev (Xlist.rev_map (Interval.make_days time) Interval.interval_of_date_interval) in
    let weeks = List.rev (Xlist.rev_map (Interval.make_weeks Interval.empty_date_interval [] time) Interval.interval_of_date_interval) in
    let months = List.rev (Xlist.rev_map (Interval.make_months Interval.empty_date_interval [] time) Interval.interval_of_date_interval) in
    let years = List.rev (Xlist.rev_map (Interval.make_years Interval.empty_date_interval [] time) Interval.interval_of_date_interval) in
    let time = Interval.interval_of_date_interval time in
    let future = Interval.get_greater_equal now time (*[Interval.get_greater_equal now time]*) in
    let past = (*[*)(*List.rev*) (Interval.get_lesser_equal now time)(*]*) in (* FIXME *)
    let time = [time] in
    now0, now, pp_hour, pp_min, pp_date, start, horizon, days, weeks, months, years, time, future, past

let select_dates cats = function
    JString "unspecified" -> cats
  | JArray dates ->
      List.rev (Xlist.fold cats [] (fun cats cat ->
        let s = try String.sub cat 0 10 with _ -> failwith "Invalid query: categories format 1" in
(*         print_endline ("select_dates 1: " ^ s); *)
        let b = Xlist.fold dates false (fun b -> function
            JObject["at",JString d] -> (*print_endline ("select_dates 2: " ^ d);*) if s = d then true else b
          | JObject["begin",JString d] -> if s >= d then true else b
          | JObject["end",JString d] -> if s <= d then true else b
          | JObject["begin",JString d1;"end",JString d2] | JObject["end",JString d2;"begin",JString d1] -> 
              if s >= d1 && s <= d2 then true else b
          | _ -> failwith "select_dates") in
        if b then cat :: cats else cats))
  | _ -> failwith "select_dates"
  
let test_corpus corpus validation =
  let now0, now, pp_hour, pp_min, pp_date, start, horizon, days, weeks, months, years, time, future, past = create_time "2021-10-28 13:30:00" 1239 start_year "2021-10-29 14:45:00" in
  let limit = 1000000 in
  Xlist.iter corpus (fun (text,query0) ->
    let query1 = select_time_key query0 in
    let query = TimePreprocessing.split_jobjects query1 in
    let query = TimePreprocessing.translate query in
    let date_query = TimePreprocessing.select_date query in
    let hour_query = TimePreprocessing.select_hour query in
    let preference_query = TimePreprocessing.select_preference query in
(*     if hour_query = Unspecified then ( *)
(*    print_endline (
      "\n=================================================================\n\n" ^ 
      text ^ "\n\n" ^ json_to_string_fmt2 "" query0);      
    print_endline (json_to_string_fmt2 "" query1);
    print_endline ("date_query: " ^ string_of_t date_query);
    print_endline ("hour_query: " ^ string_of_t hour_query);*)
    try 
      let date = DateGrounder.ground days weeks months years future past time pp_date limit date_query in
      let hour = HourGrounder.merge (HourGrounder.ground now0.Unix.tm_hour now0.Unix.tm_min pp_hour pp_min hour_query) in (* FIXME: uwaga gdy liczymy względem now godzina ustala datę i nie musi to być „dziś” *) 
      let preferences = PreferenceGrounder.ground_preference preference_query in 
      let hour = HourGrounder.json_of_hour_intervals hour in
      let preference = PreferenceGrounder.json_of_preferences preferences in
      let valid = try StringMap.find validation text with Not_found -> JNull in      
      if valid = JObject(preference @ ["date",date;"hour",hour]) then () else (
        if valid <> JNull then Printf.printf "Valid:\n%s\nObtained:\n" (json_to_string_fmt2 "" valid);
        let json = JObject(["text",JString text] @ preference @ ["date",date;"hour",hour]) in
        print_endline (json_to_string_fmt2 "" json ^ ",\n"))
    with Failure e -> (
      print_endline (
        "\n=================================================================\n\n" ^ 
        text ^ "\n\n" ^ json_to_string_fmt2 "" query0);      
      print_endline (json_to_string_fmt2 "" query1);
      print_endline ("preference_query: " ^ string_of_t preference_query);
      print_endline ("date_query: " ^ string_of_t date_query);
      print_endline ("hour_query: " ^ string_of_t hour_query);
      print_endline e);
(*    let date_query,time_query = split_query query in
    print_endline ("date_query: " ^ (json_to_string_fmt2 "" date_query));
    print_endline ("time_query: " ^ (json_to_string_fmt2 "" time_query));*)
    ())     

let rec main_loop in_chan out_chan =
  let text = input_text in_chan in
  try
    let queryx,nowx,horizonx,limitx,start_yearx,ppx,cats = process_query (json_of_string text) in
    let now0, now, pp_hour, pp_min, pp_date, start, horizon, days, weeks, months, years, time, future, past = create_time nowx horizonx start_yearx ppx in
    let limit = limitx in
    let query1 = select_time_key queryx in
    let query = TimePreprocessing.split_jobjects query1 in
    let query = TimePreprocessing.translate query in
    let date_query = TimePreprocessing.select_date query in
    let hour_query = TimePreprocessing.select_hour query in
    let preference_query = TimePreprocessing.select_preference query in
    let date = DateGrounder.ground days weeks months years future past time pp_date limit date_query in
    let hour = HourGrounder.merge (HourGrounder.ground now0.Unix.tm_hour now0.Unix.tm_min pp_hour pp_min hour_query) in
    let preferences = PreferenceGrounder.ground_preference preference_query in
    if cats = [] then
      let hour = HourGrounder.json_of_hour_intervals hour in
      let preference = PreferenceGrounder.json_of_preferences preferences in
      let json = JObject(preference @ ["date",date;"hour",hour]) in
      Printf.fprintf out_chan "%s\n\n%!" (json_to_string_fmt2 "" json)
    else (
(*       print_endline ("main_loop 1: " ^ String.concat " " cats); *)
      let cats = select_dates cats date in
(*       print_endline ("main_loop 2: " ^ String.concat " " cats); *)
      let cats = HourGrounder.select_hour cats hour in
(*       print_endline ("main_loop 3: " ^ String.concat " " cats); *)
      let cats = PreferenceGrounder.select_preference cats preferences in
(*       print_endline ("main_loop 4: " ^ String.concat " " cats); *)
      let json = JObject["categories", JArray(Xlist.map cats (fun s -> JString s))] in
      Printf.fprintf out_chan "%s\n\n%!" (json_to_string_fmt2 "" json))
  with e -> 
    let t = JObject["error", JString (Printexc.to_string e)] in
    Printf.fprintf out_chan "%s\n\n%!" (json_to_string_fmt2 "" t)
    
let _ =
(*   prerr_endline message; *)
  Arg.parse spec_list anon_fun usage_msg;
  if !corpus_mode then 
    let corpus = load_corpus !corpus_filename in
    let validation = 
      if !validation_filename = "" then StringMap.empty 
      else Xlist.fold (load_corpus !validation_filename) StringMap.empty (fun map (text,t) -> StringMap.add map text t) in
    test_corpus corpus validation else
  if !comm_stdio then main_loop stdin stdout
  else
    let sockaddr = Unix.ADDR_INET(Unix.inet_addr_any,!port) in
    Unix.establish_server (main_loop ) sockaddr

(* FIXME:
- doparsowanie przykładów dialogi3
- przesuwający się do przodu koniec czasu

*)

    
(* 

1. Jaką kwantyzację czasu przyjmujemy? Proponuję, żeby wszelkie terminy były oznaczane z dokładnością do 5 minut. Czyli np. 12:03 będzie interpretowana jako 12:00.

Z dokładnością do minuty.
Zwracam przedziały.

2. Kto ustala, kiedy jest teraz? Czy będziesz przekazywać mi bieżący czas, czy też mam go sam pobierać z zegara systemowego?

Menedżer dialogu. Format taki jak w pkt. 5.

3. W jakim horyzoncie czasowym mam zwracać wyniki. Np. interpretacją frazy „dowolny czwartek” jest nieskończona lista dat. Jaką część tej listy potrzebujesz?

Szukam terminów 1 rok do przodu. I zwracam wszystkie znalezione.
Informacja jest dostarczana razem z zapytaniem.

4. Daty i godziny rozpatruję niezależnie od siebie. Osobno będę przekazywać listę dni, a osobno listę godzin-minut, które pasują do wypowiedzi klienta. W szczególności „w czwartek lub w piątek po południu” oznacza to samo co „w czwartek po południu lub w piątek po południu”. To ostatnie wynika też z ograniczeń parsera.

Daty i godziny są łączone po stronie groundera.

5. W jakim formacie chciałbyś otrzymywać listę dat i listę godzin-minut?

json z listą słowników z kluczami:
'start_at': '2021-10-19 00:00:00'
'end_at': '2021-10-20 00:00:00',

6. Klient może powiedzieć „to za późno”, co jest odniesieniem do wcześniej wskazanego terminu - grounder potrzebuje znać dotychczas zaproponowany przez agenta termin

W reakcji na propozycję manegera -
w zapytaniu grounder dostaje jeden lub więcej terminów lub zakresów, które menedżer zaproponował klientowi i reprezentację wypowiedzi klienta.
Format taki jak w pkt. 5.
Rozszerzenie formatu o przekazywanie informacji że termin ma być wszcześniejszy lub późniejszy niż zaproponowane.

7. Klient może powiedzieć „jak najpóźniej” i „jak najwcześniej” - co nie jest przetłumaczalne na konkretne godziny bez znajomości dostępnych terminów.

W wersji kategorii - grounder wybiera
W wersji ogólnej - Rozszerzenie formatu o przekazywanie tych preferencji.

8. klucz with traktujemy jak klucz or

9. wprowadzam znacznik past dla określenia że data dotyczy przeszłości.

10. początek czasu to 2017-01-01, koniec czasu to now + 2 lata lub now + 3 lata

11. jakie zakresy wskazywać dla następujących terminów wskazanych przez użytkownika? 
(zwracanie punktu w czasie grozi nie znalezieniem terminu, ale z drugiej strony taka jest preferencja użytkownika)

13
13:00
o 13
o 13:00
około 13
około 13:00
przed 13
przed 13:00
po 13
po 13:00
do 13
do 13:00
od 13
od 13:00

teraz
za pięć minut
za piętnaście minut
za godzinę
za dwie godziny
*)
(* 
Grounder czasu znajduje się na maszynie 192.168.6.8 na porcie 9763
Grounderowi przekazuje się jsona zawierającego klucze:
query - zdezambiguowana semantyka wypowiedzi klienta wygenerowana przez ENIAM'a
now - aktualna data i czas
horizon - liczba dni w przyszłości, które będą brane pod uwagę podczas szukania uziemienia (domyślnie 365)
limit - maksymalna liczba alternatywnych przedziałów dat zwracana przez grounder (domyślnie 30)
start-year - rok od początku którego uziemiane są daty przeszłe (domyślnie początek roku wskazanego przez now)
previous-proposal - data i czas ostatniego terminu zaproponowanego użytkownikowi przez agenta (jeśli nie jest podana, wypowiedzi klienta odnoszące się do niej interpretowane są jako sprzeczne)

Grounder zwraca jsona zawierającego:
date - lista dat pasujących do zapytania
hour - lista godzin pasujących do zapytania
hour-preference - preferencje dotyczące wyboru godziny 
date-preference - preferencje dotyczące wyboru daty
time-preference - preferencje dotyczące czasu bez wskazania, czy chodzi o datę, czy godzinę

Jest to wstępna wersja groundera, którą będę jeszcze rozwijać. 
Powinna ona wystarczyć na potrzeby testów.

Przykładowe wywołania (po zalogowaniu na 192.168.6.8:
cd /home/wojtek.jaworski/DialogueSystem/NLU/grounding
cat tx1.json | netcat localhost 9763
cat tx2.json | netcat localhost 9763


*)

(* 
Cześć,

kolejna  porcja przykładów wyrażeń temporalnych, dla których trzeba określić uziemienie:

dowolny miesiąc
dowolny tydzień
dowolny dzień
dowolny weekend
dowolny termin
dowolna godzina

każdy piątek
jakiś piątek
któryś piątek
jakikolwiek piątek

tylko po godzinie 18
tylko godzina 18
tylko piątek

nieco/trochę po osiemnastej
nieco/trochę przed osiemnastą

jeszcze dziś
Jeszcze przed piątkiem

dowolny, tylko, jeszcze - jako nowe informacje w grounderze
nieco/trochę - jako zmiana zakresów

*)
