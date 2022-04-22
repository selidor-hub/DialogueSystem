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

(*let parse_lattice filename lines =
  Xlist.fold lines [] (fun paths line ->
    match Xstring.split " " line with
      [start;en;word;weight] -> 
        let beg = int_of_string start in
        let next = int_of_string en in
(*         if beg >= next then print_endline ("parse_lattice: " ^ filename ^ " " ^ start ^ " " ^ en ^ " " ^ word); *)
        {empty_token_env with orth=word; 
         beg;len=next-beg;next;
         token=(*Lemma(word,"unk",[],"X")*)AllSmall(word,word,word);
         weight=float_of_string weight} :: paths
    | [en;weight] -> 
        {empty_token_env with 
         beg=int_of_string en;
         len=1000000 - int_of_string en;
         next=1000000;
         token=Interp "<empty>";
         weight=float_of_string weight} :: paths
    | [en] -> 
        {empty_token_env with 
         beg=int_of_string en;
         len=1000000 - int_of_string en;
         next=1000000;
         token=Interp "<empty>";
         weight=0.0} :: paths
    | [] -> paths
    | line -> failwith ("load_lattices: " ^ filename ^ " " ^ (String.concat " " line)))*)
   
let parse_lattice = function
    Edge(start,en,word,weight) -> 
        {empty_token_env with orth=word; 
         beg=start;len=en-start;next=en;
         token=(*Lemma(word,"unk",[],"X")*)AllSmall(word,word,word);
         weight}
  | Leaf(en,weight) -> 
        {empty_token_env with 
         beg=en;
         len=1000000 - en;
         next=1000000;
         token=Interp "<empty>";
         weight}
  
   
(*let load_lattices data =
  Xlist.map data (fun r ->
    let filename = "../../ASR/lats/" ^ r.name ^ ".lat.1.words.fst.txt" in
    let lines = File.load_lines filename in
    {r with paths=[1,parse_lattice r.name lines, 1000000]})*)
   
(*let rec load_lattices2_rec r =
(*  let best_filename = "../../ASR/lats/clarin_mixed_grammar_2/L2a/marta/" ^ r.name ^ 
    "." ^ string_of_int n ^ ".best.txt" in*)
  let best_filename = "../../ASR/lats/tdnnf_mixed_grammar_2/lats_L2a_Marta/" ^ r.name ^ 
    "." ^ string_of_int n ^ ".best.txt" in
  let best_path = if Sys.file_exists best_filename then Xstring.remove_trailing_spaces (File.load_file best_filename) else "" in
(*   let filename = "../../ASR/lats/clarin_simple_large_grammar/" ^ r.name ^  
    "." ^ string_of_int n ^ ".lat.fst.txt" in*)
(*  let filename = "../../ASR/lats/clarin_mixed_grammar/" ^ r.name ^ 
    "." ^ string_of_int n ^ ".lat.fst.txt" in*)
(*  let filename = "../../ASR/lats/clarin_mixed_grammar_2/rafal/beam8/" ^ r.name ^ 
    "." ^ string_of_int n ^ ".lat.fst.txt" in*)
(*  let filename = "../../ASR/lats/clarin_mixed_grammar_2/rafal/beam14/" ^ r.name ^ 
    "." ^ string_of_int n ^ ".lat.fst.txt" in*)
(*  let filename = "../../ASR/lats/clarin_mixed_grammar_2/L2a/marta/" ^ r.name ^ 
    "." ^ string_of_int n ^ ".lat.fst.txt" in*)
  let filename = "../../ASR/lats/tdnnf_mixed_grammar_2/lats_L2a_Marta/" ^ r.name ^ 
    "." ^ string_of_int n ^ ".lat.fst.txt" in
  if Sys.file_exists filename then
    let lines = File.load_lines filename in
    let paths1 = parse_lattice r.name lines, 1000000 in
    let paths1 = if !has_question_marker then 
       match paths1 with
         {token=AllSmall("?","?","?"); weight=w} :: paths1, last -> paths1, last (* FIXME: dodać obsługę w *)
       | _ -> failwith "load_lattices2_rec: question marker" else paths1 in      
    (n,{empty_path with paths1; best_path}) :: (load_lattices2_rec (n+1) r)
  else (
    if n = 0 then print_endline ("load_lattices2_rec: '" ^ filename ^ "' not found");
    [])*)
   
let load_lattices2 data =
  Xlist.map data (fun r ->
    {r with paths=Xlist.map r.paths (fun (id,p) ->
      id, {p with lat={p.lat with paths1=Xlist.map p.lat.paths0 parse_lattice, 1000000}})})

        


let disambiguate_variant = function
    Token{orth=""} -> []
  | Token{token=Interp "."} -> []
  | Token{token=Ideogram(_,"dig")} as t -> [t]
  | Token{token=Ideogram(_,"natnum")} -> []
  | Token{token=Ideogram(_,"hour")} -> []
  | Token{token=Ideogram(_,"1dig")} -> []
  | Token{token=Ideogram(_,"2dig")} -> []
  | Token{token=Ideogram(_,"3dig")} -> []
  | Token{token=Ideogram(_,"4dig")} -> []
  | Token{token=Ideogram(_,"posnum")} -> []
  | Token{token=Ideogram(_,"month")} -> []
  | Token{token=Ideogram(_,"day")} -> []
  | Token{token=Ideogram(_,"minute")} -> []
  | Token{token=Ideogram(_,"pref3dig")} -> []
  | Token{token=Ideogram(_,"roman")} -> []
  | Token{token=Ideogram(_,"roman-month")} -> []
  | Token t -> [Token t]
  | Seq[Token _;Token{orth="m"}] -> []
  | Seq[Token _;Token{orth="M"}] -> []
  | Seq[Token _;Token{orth="em"}] -> []
  | Seq[Token _;Token{orth="ż"}] -> []
  | Seq[Token _;Token{orth="Ż"}] -> []
  | Seq[Token _;Token{orth="że"}] -> []
  | Seq[Token _;Token{orth="ń"}] -> []
  | Seq[Token _;Token{orth="by"}] -> []
  | Seq[Token _;Token{orth="ście"}] -> []
  | Seq[Token _;Token{orth="eście"}] -> []
  | Seq[Token _;Token{orth="śmy"}] -> []
  | Seq[Token _;Token{orth="ś"}] -> []
  | Seq[Token _;Token{orth="eś"}] -> []
  | Seq[Token _;Token{orth="by"};Token{orth="m"}] -> []
  | Seq[Token _;Token{orth="BY"};Token{orth="M"}] -> []
  | Seq[Token _;Token{orth="by"};Token{orth="ście"}] -> []
  | Seq[Token _;Token{orth="by"};Token{orth="śmy"}] -> []
  | Seq[Token _;Token{orth="by"};Token{orth="ś"}] -> []
  | Seq[Token{orth="x"};Token _] -> []
  | Seq[Token{orth=""};Token{orth="."}] -> []
  | Seq[Token{orth=""};Token{orth="..."}] -> []
  | t -> print_endline ("disambiguate_variant: " ^ SubsyntaxStringOf.string_of_tokens 0 t); []
  
let rec disambiguate_tokens = function
    [] -> []
(*  | Token({token=Interp("<query>")} as t) :: l -> Token{t with token=Interp("<empty>")} :: disambiguate_tokens l
  | [Token{token=Interp("</query>")}] -> []*)
(*  | Token{token=(AllCap _ as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(FirstCap _ as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(SomeCap _ as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(AllSmall _ as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(SmallLetter _ as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(CapLetter _ as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Interp "-" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Interp "," as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Interp "/" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Interp "’" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Interp "&" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Interp ";" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Interp "(" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Interp ")" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Interp "[" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Interp "]" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Interp "…" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Interp "……" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Interp "_" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Symbol "." as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Other "α" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Other "β" as t)} :: l -> t :: disambiguate_tokens l
  | Token{token=(Ideogram(_,"dig") as t)} :: l -> t :: disambiguate_tokens l*)
  | Token t :: l -> (Token t) :: disambiguate_tokens l
  | Variant vl :: l -> 
      let t = match List.flatten (Xlist.rev_map vl disambiguate_variant) with
          [t] -> t
        | _ -> failwith ("disambiguate_tokens: " ^ SubsyntaxStringOf.string_of_tokens 0 (Variant vl)) in
      disambiguate_tokens (t :: l)
  | t :: l -> failwith ("disambiguate_tokens: " ^ SubsyntaxStringOf.string_of_tokens 0 t)
(*   | t :: l -> print_endline ("disambiguate_tokens: " ^ SubsyntaxStringOf.string_of_tokens 0 t); [] *)

let wrap_tokens t l =
  Xlist.map l (fun s -> Token{t with token=AllSmall(s,s,s)})

let rec remove_punctuation_rec = function
    Token({token=Interp "<empty>"} as e) :: Token t :: l -> remove_punctuation_rec (Token{t with beg=e.beg; len=e.len+t.len} :: l)
  | [Token{token=Interp "<empty>"}] -> []
  | [] -> []
  | Token t :: l -> Token t :: (remove_punctuation_rec l)
  | _ -> failwith "remove_punctuation_rec"
  
let remove_punctuation tokens =
  let tokens = List.rev (Xlist.rev_map tokens (function
      Token t ->
        (match t.token with 
            Interp "<empty>" -> Token t
          | Interp "<query>" -> Token {t with token=Interp "<empty>"}
          | Interp "</query>" -> Token {t with token=Interp "<empty>"}
          | Interp "," -> Token {t with token=Interp "<empty>"}
          | Interp "?" -> Token {t with token=Interp "<empty>"}
          | Interp ":" -> Token {t with token=Interp "<empty>"}
          | Interp "$" -> Token {t with token=Interp "<empty>"}
(*           | Interp s -> print_endline s; [] *)
          | Symbol "." -> Token {t with token=Interp "<empty>"}
          | _ -> Token t)
    | t -> failwith ("remove_punctuation: " ^ SubsyntaxStringOf.string_of_tokens 0 t))) in
  remove_punctuation_rec tokens
  
let translate_tokens tokens =
  List.rev (List.flatten (Xlist.rev_map tokens (function
      Token t ->
        let l = match t.token with 
            SmallLetter(uc,lc) -> wrap_tokens t [lc]
          | CapLetter(uc,lc) -> wrap_tokens t [uc;lc]
          | AllSmall(uc,fc,lc) -> wrap_tokens t [lc]
          | AllCap(uc,fc,lc) -> wrap_tokens t [uc;fc;lc]
          | FirstCap(uc,fc,lc) -> wrap_tokens t [fc;lc]
          | SomeCap(uc,orth,lc) -> wrap_tokens t [orth;lc]
          | Ideogram(s,_) -> wrap_tokens t [s](*[Token t]*)
          | t -> failwith ("translate_tokens 2: " ^ SubsyntaxStringOf.string_of_token t) in
        (match l with
          [] -> failwith "translate_tokens 3"
        | [t] -> [t]
        | _ -> [Variant l])
    | t -> failwith ("translate_tokens 1: " ^ SubsyntaxStringOf.string_of_tokens 0 t))))
   
let make_lattice s =
    let tokens = Patterns.parse s in
    let tokens = disambiguate_tokens tokens in
    let tokens = remove_punctuation tokens in
    let paths,last = Patterns.translate_into_paths (translate_tokens tokens) in
    let paths =
        {empty_token_env with 
         beg=last;
         len=1000000 - last;
         next=1000000;
         token=Interp "<empty>";
         weight=0.0} :: paths in
    paths,1000000
   
let make_lattices data =
  Xlist.map data (fun r ->
    let paths = make_lattice r.turn in
    {r with paths=[1,{empty_paths with lat={empty_p with paths1=paths}}]})
   
let rec topol_dfs graph result visited n =
  let visited = IntSet.add visited n in
  let result,visited = IntSet.fold (try IntMap.find graph n with Not_found -> failwith "topol_dfs") (result,visited) (fun (result,visited) m ->
    if IntSet.mem visited m then result,visited else
    topol_dfs graph result visited m) in
  n :: result,visited
   
let topol paths =
  let paths = 
    {empty_token_env with beg=(-1);len=1;next=0;token=Interp "<query>"} :: 
    {empty_token_env with beg=1000000;len=factor;next=1000001;token=Interp "</query>"} :: paths in
  let graph = Xlist.fold paths IntMap.empty (fun graph t ->
    let graph = IntMap.add_inc graph t.next IntSet.empty (fun set -> set) in
    IntMap.add_inc graph t.beg (IntSet.singleton t.next) (fun set -> IntSet.add set t.next)) in
  let l,_ = topol_dfs graph [] IntSet.empty (-1) in
  let map,_ = Xlist.fold l (IntMap.empty, 0) (fun (map,n) k ->
    IntMap.add map k n, n+factor) in
  Xlist.map paths (fun t -> 
    let beg = try IntMap.find map t.beg with Not_found -> failwith "topol 1" in
    let next = try IntMap.find map t.next with Not_found -> failwith "topol 2" in
    {t with beg;len=next-beg;next}), try IntMap.find map 1000001 with Not_found -> failwith "topol 3"
   
(*let make_paths words data =
  Xlist.map data (fun r ->
    let graph = Xlist.rev_map r.lattice (fun (b,e,_,w,_) ->
      b,e,IntMap.find words w) in
    {r with graph})*)
    
open Inflexion

   
(* FIXME: docelowo trzeba będzie wstawić pełne parsowanie (segmentację) poszczególnych tokenów *)
(*let lemmatize paths = 
  List.flatten (Xlist.rev_map paths (fun t ->
    if t.token= Interp"<empty>" then [t] else 
    let prior,l = Lemmatization.lemmatize_token [] false false t.token in
    if l = [] then print_endline ("lemmatize: " ^ SubsyntaxStringOf.string_of_token t.token);
    Xlist.map l (fun (lemma,pos,tags,cat) -> {t with token=Lemma(lemma,pos^":"^cat,[tags],cat)})))*)
let lemmatize paths = 
(*   print_endline ("lemmatize 1");          *)
  List.flatten (Xlist.rev_map paths (fun t ->
    match t.token with
      Interp "<empty>" -> [t] 
    | Interp "<query>" -> [t] 
    | Interp "</query>" -> [t] 
    | AllSmall(word,_,_) -> 
(*         print_endline ("lemmatize 2: " ^ word);          *)
        let interpretations = get_interpretations word in
        let interpretations = Xlist.fold interpretations [] (fun interpretations i ->
          let set = try StringMap.find !lemma_case_mapping i.lemma with Not_found -> StringSet.empty in
          StringSet.fold set (i :: interpretations) (fun interpretations lemma ->
            {i with lemma} :: interpretations)) in
(*         print_endline ("lemmatize 3: " ^ word);          *)
        let found = Xlist.fold interpretations [] (fun found i ->
          if i.star = MorphologyTypes.Productive && i.tags = ["cat","ndm"] then found else
          Xlist.fold (Tagset.parse i.interp) found (fun found (pos,tags) ->
            if pos = "brev" then found else
            let set = 
              try StringMap.find (StringMap.find !known_lemmata i.lemma) (Tagset.simplify_pos pos)
              with Not_found -> OntSet.empty in
            OntSet.fold set found (fun found a -> 
              {t with token=Lemma(i.lemma,pos,[tags],a.ont_cat)} :: found))) in
(*         print_endline ("lemmatize 4: " ^ word);  *)
        let map = try StringMap.find !known_lemmata word with Not_found -> StringMap.empty in
        let set = try StringMap.find map "fixed" with Not_found -> OntSet.empty in
        let found = OntSet.fold set found (fun found a -> 
          {t with token=Lemma(word,"fixed",[],a.ont_cat)} :: found) in  
        let found = if found = [] then [{t with token=Lemma(word,"unk",[],"X")}] else found in
        if Lemmatization.is_known_orth t.token then ((*print_endline ("lemmatize 5: " ^ word);*) t :: found) else ((*print_endline ("lemmatize 6: " ^ word);*) found)     
(*     | Ideogram _ -> [t] *)
    | _ -> failwith ("lemmatize: " ^ SubsyntaxStringOf.string_of_token t.token)))
  
let remove_unk paths = 
  List.flatten (Xlist.rev_map paths (fun t ->
    match t.token with
      Interp "<empty>" -> [t] 
    | Interp "<query>" -> [t] 
    | Interp "</query>" -> [t] 
    | Lemma(_,"unk",_,_) -> []
    | Lemma(_,"fixed",_,_) -> [t]
    | AllSmall _ -> []
    | _ -> failwith ("remove_unk: " ^ SubsyntaxStringOf.string_of_token t.token)))
  
let main_cats = StringSet.of_list [
  "⟨Profession.beauty⟩"; "⟨Service.beauty⟩"; "⟨OrganizationType.beauty⟩"; 
  "⟨BodyPart⟩"; "⟨Action⟩"; "⟨Attitude⟩"; "⟨Confirmation⟩"; "⟨Farewell⟩"; "⟨Greetings⟩"; 
  "⟨Person⟩"; "⟨Time⟩"; "⟨Location⟩"; "⟨ServiceParam⟩"; 
  "Qub"; "⟨Prep⟩"; "⟨Conj⟩"; "⟨Comp⟩"; "⟨Attr⟩"; "⟨Spelling⟩"; "⟨Attitude.interj⟩"; "⟨Num⟩"; 
  "⟨OrdNum⟩"; "⟨TimeAttr⟩"; "⟨Domain⟩"; "⟨Make⟩"; "Time"; "Location"; "TimeOfDay"; "⟨Instrument.beauty⟩"; "MWEcomponent"; "Day"; "Duration"; "⟨State⟩"; "⟨AttrGen⟩"; "⟨Question⟩"; "Street"; "⟨Colour⟩"; "⟨Effect.beauty⟩"; "TownName"; "YearAttr"; "HourAttr"; "QuarterName"; "WeekDay"; "Month"; "⟨Length⟩"; "DayNumber"; "HourNumber"; "StreetName"; "⟨Flaw⟩"; "⟨Instance⟩"; "⟨Command⟩"; "NumberFuture"; "NumberPast"; "Hour"; "Minute"; "LexMinute"; "TimeDescription"; "TimeOrder"; "TimeApr"; "Week"; "Year"; "Town"; "Attitude"; "LocationApr"; "⟨FirstName⟩"; ""; ""; ""; ""; ""; ""; ""; ""] (* FIXME czy MWEcomponent powinno tu być? *)
let other_cats = StringSet.of_list ["⟨Profession⟩"; "⟨Service⟩"; "⟨OrganizationType⟩"; "⟨Animal⟩"; "⟨Artefact⟩"; "NumberMod"; "Iterator"; "NumberModMeta"; "SpatialRelation"; "NumberX"; "NumberExact"; "DayNumberUnit"; "OrdNumberX"; "NumberApprox"; "QuarterNameAttr"; "TownNameAttr"; "X"; "Number1"; "HourNumberUnit"; "TimePoint"; "OrdNumber1X"; "Number1X"; "OrdNumber1X"; "NumberE"; "NumberModBin"; "NumberX00"; "NumberX0"; "OrdNumberX0"; "Frequency"; ""; ""; ""; ""; ""; ""; ""; ""]
        
(*  ⟨Email⟩ ⟨Price⟩ ⟨Telephone⟩  ⟨Rating⟩   ⟨Organization⟩ ⟨Name⟩   
  ⟨Appointment⟩ ⟨Question⟩      
   ⟨Issue⟩      
     *)

let add_unk_weight paths = 
  Xlist.rev_map paths (fun t ->
    match t.token with
      Interp "<empty>" -> t
    | Interp "<query>" -> t
    | Interp "</query>" -> t
    | Lemma(_,"unk",_,_) -> {t with weight = t.weight+.10000.}
    | Lemma(_,_(*"fixed"*),_,cat) -> 
        if StringSet.mem main_cats cat then t else
        if StringSet.mem other_cats cat then {t with weight = t.weight+.1000.} else (
        print_endline ("add_unk_weight: unknown cat " ^ cat);
        {t with weight = t.weight+.1000.})
    | AllSmall(s,_,_) -> {t with weight = t.weight+.100000.; token=Lemma(s,"unk",[],"X")}
    | _ -> failwith ("add_unk_weight: " ^ SubsyntaxStringOf.string_of_token t.token))
 
let rec merge rev = function
    (cost1,path1) :: l1, (cost2,path2) :: l2 -> 
      if cost1 < cost2 then merge ((cost1,path1) :: rev) (l1, (cost2,path2) :: l2) 
      else merge ((cost2,path2) :: rev) ((cost1,path1) :: l1, l2) 
  | [], l2 -> List.rev rev @ l2
  | l1, [] -> List.rev rev @ l1
 
(*let rec expand rev = function
    (cost,paths) :: l -> 
      let rev = Xlist.fold paths rev (fun rev path -> (cost,path) :: rev) in
      expand rev l
  | [] -> rev
 
let rec select_first beam rev = function
    (cost,paths) :: l -> 
(*        Printf.printf "select_first 1: beam=%d cost=%0.2f |paths|=%d |rev|=%d\n" beam cost (Xlist.size paths) (Xlist.size rev); *)
       if beam > 0 then select_first (beam - Xlist.size paths) ((cost,paths) :: rev) l
       else expand [] rev
  | [] -> 
(*       Printf.printf "select_first 2: beam=%d |rev|=%d\n" beam (Xlist.size rev);  *)
      expand [] rev*)
 
let rec select_first beam rev = function
    (cost,path) :: l -> 
(*        Printf.printf "select_first 1: beam=%d cost=%0.2f |paths|=%d |rev|=%d\n" beam cost (Xlist.size paths) (Xlist.size rev); *)
       if beam > 0 then select_first (beam - 1) ((cost,path) :: rev) l
       else List.rev rev
  | [] -> 
(*       Printf.printf "select_first 2: beam=%d |rev|=%d\n" beam (Xlist.size rev);  *)
      List.rev rev
      
let print_cost_paths l =
  Xlist.iter l (fun (cost,path) ->
    Printf.printf "%0.2f %s\n" cost (String.concat " " (TokenEnvSet.fold path [] (fun l t -> t.orth :: l))))
 
let print_cost_paths2 l =
  Xlist.iter l (fun (cost,paths) ->
    Printf.printf "%0.2f %d\n" cost (Xlist.size paths))
 
let merge_select beam l1 l2 =
(*  print_endline ("merge_select l1: " ^ string_of_int (Xlist.size l1));
  print_cost_paths l1;
  print_endline ("merge_select l2: " ^ string_of_int (Xlist.size l2));
  print_cost_paths l2;*)
  let l = merge [] (l1,l2) in
(*   print_endline "merge_select merged:"; *)
(*  print_cost_paths l;*)
  let cost,path = List.hd l in
  let cost,path,l = Xlist.fold (List.tl l) (cost,path,[]) (fun (cost,path,l) (cost2,path2) ->
    if cost > cost2 then failwith "merge_select" else
    if cost < cost2 then cost2,path2, (cost,path) :: l
    else cost,TokenEnvSet.union path path2,l) in
(*  let cost,paths,l = Xlist.fold (List.tl l) (cost,[path],[]) (fun (cost,paths,l) (cost2,path) ->
    if cost > cost2 then failwith "merge_select" else
    if cost < cost2 then cost2,[path], (cost,paths) :: l
    else cost,path :: paths,l) in*)
  let l = List.rev ((cost,path) :: l) in
(*   print_endline "merge_select grouped:"; *)
(*  print_cost_paths2 l;  *)
  let l = select_first beam [] l in
(*   print_endline "merge_select l:"; *)
(*  print_cost_paths l;*)
  l
  
  
 
let select_best_paths beam paths last = 
(*  let prev_map = Xlist.fold paths IntMap.empty (fun prev_map t ->
    IntMap.add_inc prev_map t.next (IntSet.singleton t.beg) (fun set -> IntSet.add set t.beg)) in*)
  let paths = Xlist.sort paths Patterns.compare_token_record in
  let map = Xlist.fold paths (IntMap.add IntMap.empty 0 [0.,TokenEnvSet.empty]) (fun map t ->
    let l = IntMap.find map t.beg in
    let l = List.rev (Xlist.rev_map l (fun (cost,path) -> cost+.t.weight,TokenEnvSet.add path t)) in
    IntMap.add_inc map t.next l (fun l2 -> merge_select beam l l2)) in
(*  TokenEnvSet.to_list (Xlist.fold (IntMap.find map last) TokenEnvSet.empty (fun set (_,l) ->
    Xlist.fold l set TokenEnvSet.add))*)
  TokenEnvSet.to_list (Xlist.fold (IntMap.find map last) TokenEnvSet.empty (fun set (_,l) ->
    TokenEnvSet.union set l))
   
let check_best_path found loaded = (* FIXME: kwestia wyboru, gdy są równoważne ścieżki *)
  if found = loaded then loaded else
(*   if loaded = "" then () else *)
  match Xstring.split_delim " | " found with
    [a;b] -> if a = loaded || b = loaded then loaded else (print_endline ("check_best_path 1: „" ^ found ^ "” „" ^ loaded ^ "”"); b)
  | [] -> (print_endline ("check_best_path 2: „" ^ found ^ "” „" ^ loaded ^ "”"); found)
  | l -> (print_endline ("check_best_path 3: „" ^ found ^ "” „" ^ loaded ^ "”"); List.hd l)

let process_latticesx beam paths last =
(*        print_endline "XXXXXXXXXXXXXXXXXXXXXXXXX a1"; 
        print_endline (SubsyntaxStringOf.token_list false paths);*)
      let paths = lemmatize paths in
      let paths = Xlist.sort paths Patterns.compare_token_record in
(*        print_endline "XXXXXXXXXXXXXXXXXXXXXXXXX a2"; 
        print_endline (SubsyntaxStringOf.token_list false paths);*)
      let paths,last = MWE.process (paths,last) in
(*        print_endline "XXXXXXXXXXXXXXXXXXXXXXXXX a3"; 
        print_endline (SubsyntaxStringOf.token_list false paths);*)
      let paths = add_unk_weight paths in (* FIXME: docelowo to trzeba usunąć albo przenieść na koniec potoku przetwarzania *)
      let paths = select_best_paths beam paths last in (* FIXME: docelowo to trzeba usunąć albo przenieść na koniec potoku przetwarzania *)
      let paths = Xlist.sort paths Patterns.compare_token_record in
(*        print_endline "XXXXXXXXXXXXXXXXXXXXXXXXX a4"; 
        print_endline (SubsyntaxStringOf.token_list false paths);*)
(*    let paths2 = remove_unk paths in
    let paths2 = Xlist.sort paths2 Patterns.compare_token_record in
    let paths = 
      try 
        let paths3 = Patterns.remove_inaccessible_tokens paths2 0 last in
(*        let paths3 = Xlist.sort paths3 Patterns.compare_token_record in
        let paths3 = Patterns.remove_inaccessible_tokens paths3 0 1000000 in*)
        paths3
      with BrokenPaths _ -> print_endline ("process_lattices unk: " ^ r.name); paths in*)
    paths,last
    
let process_lattices beam data =
  Xlist.map data (fun r ->
(*     print_endline ("process_lattices: " ^ r.dir ^ " " ^ r.name); *)
    {r with paths = Xlist.map r.paths (fun (n,p) ->
      let paths,_ = p.lat.paths1 in
(*        print_endline "XXXXXXXXXXXXXXXXXXXXXXXXX a0"; 
        print_endline (SubsyntaxStringOf.token_list false paths);*)
      let paths,last = topol paths in
(*         print_endline "XXXXXXXXXXXXXXXXXXXXXXXXX a0.1";  *)
      let best_cost, best_path = LatStats.find_best_path paths last p.best.text in
      let best_path = check_best_path best_path p.best.text in
(*         print_endline "XXXXXXXXXXXXXXXXXXXXXXXXX a0.2";  *)
      let oracle_cost, oracle_path = LatStats.find_oracle_path paths last r.turn in
      let paths,last = process_latticesx beam paths last in
      let best_paths,best_last = make_lattice best_path in
      let best_paths,best_last = process_latticesx beam best_paths best_last in
      let oracle_paths,oracle_last = make_lattice oracle_path in
      let oracle_paths,oracle_last = process_latticesx beam oracle_paths oracle_last in
    n,{p with 
      lat={p.lat with paths1=paths,last}; 
      best={p.best with text=best_path; paths1=best_paths,best_last; cost=best_cost}; 
      best2={p.best2 with text=best_path; cost=best_cost}; 
      oracle={p.oracle with text=oracle_path; paths1=oracle_paths,oracle_last; cost=oracle_cost};
      oracle2={p.oracle2 with text=oracle_path; cost=oracle_cost}})})

let token_list sentence tokens =
  "digraph G {\n" ^
  "label=\"" ^ sentence ^ "\";\nlabelloc=top;\n" ^
  String.concat "\n" (List.rev (List.flatten (Xlist.rev_map tokens (fun t ->
      let lemma = Tokenizer.get_lemma t.token in
      if lemma = "" then [Printf.sprintf "  %d -> %d [label=\"%s\\n%s\\n%0.2f\"]" t.beg t.next t.orth (SubsyntaxStringOf.string_of_token t.token) t.weight] 
      else
        [Printf.sprintf "  %d -> %d [label=\"%s\\n%s\\n%s\\n%s:%s\\n%0.2f\"]" t.beg t.next t.orth lemma (Tokenizer.get_cat t.token) (Tokenizer.get_pos t.token) (Tokenizer.get_interp t.token) t.weight]))))
  ^ "}"

let basic = [
 "strzyżenie1"; "salon_fruzjerski"; "stż_damskie_z_farb"; "fryzjer1"; "fryzjer2"; 
 "stż_męskie_krótkie"; "fryzjer3"; "salon_kosmetyczny"; "nie"; "tak"]
  
let print_graphs data =
  Xlist.iter data (fun r ->
    if Xlist.mem basic r.name then (
    print_endline ("print_graphs: " ^ r.name);
    Xlist.iter r.paths (fun (n,p) ->
      let paths,last = p.lat.paths1 in
      let filename = "results/" ^ r.name ^ "." ^ string_of_int n in
      File.file_out (filename ^ ".gv") (fun file -> 
        output_string file (token_list r.turn paths ^ "\n\n"));
      ignore (Sys.command ("dot -Tpng " ^ filename ^ ".gv -o " ^ filename ^ ".png")))))
   
   
let parse_text_tokens tokens sentence paths =
(*   print_endline ("parse_text_tokens 1: " ^ query); *)
  let paragraphs = ["", "", sentence, paths] in
(*   print_endline ("parse_text_tokens 3: " ^ query); *)
  let n = if Xlist.size paragraphs = 1 then 0 else 1 in
  let paragraphs,_ = Xlist.fold paragraphs ([],n) (fun (paragraphs,n) (name,id,paragraph,paths) ->
    try
      (* print_endline paragraph; *)
      let stats = 0,0,0,0 in
      (* print_endline "parse_text 1"; *)
      let pid = 
        if !inner_pid_counter then (
          incr pid_counter;
          string_of_int !pid_counter ^ "_" )
        else if n = 0 then "" else string_of_int n ^ "_" in
(*        print_endline "XXXXXXXXXXXXXXXXXXXXXXXXX b1"; 
        print_endline (SubsyntaxStringOf.token_list false paths);*)
      let sentences = Sentences.no_split_into_sentences pid paragraph tokens paths in
(*         print_endline "XXXXXXXXXXXXXXXXXXXXXXXXX b2";  *)
      (AltParagraph ((if id = "" then [] else [Identifier,RawParagraph id]) @
        [Raw,RawParagraph paragraph] @ (if sentences = [] then [] else [Struct,StructParagraph(stats,sentences)]))) :: paragraphs, n+1
    with e ->
      (AltParagraph ((if id = "" then [] else [Identifier,RawParagraph id]) @
        [Raw,RawParagraph paragraph; Error,ErrorParagraph (Printexc.to_string e)])) :: paragraphs, n+1) in
  AltText[Raw,RawText sentence; Struct,StructText(List.rev paragraphs)], tokens

let parse_text sentence paths =
  (* print_endline ("parse_text: " ^ query); *)
  let tokens = ExtArray.make 100 empty_token_env in
  let _ = ExtArray.add tokens empty_token_env in (* id=0 jest zarezerwowane dla pro; FIXME: czy to jest jeszcze aktualne? *)
  let text,tokens = parse_text_tokens tokens sentence paths in
  text,tokens

let process_lattices2 data =
  Xlist.map data (fun r ->
    (*if r.name <> "fryzjer1" then r else*) (
(*     print_endline ("process_lattices2: " ^ r.dir ^ " " ^ r.name); *)
    {r with paths = Xlist.map r.paths (fun (n,p) ->
      let paths,_ = p.lat.paths1 in
      let text, tokens = parse_text r.turn paths in
      let best_paths,_ = p.best.paths1 in
      let best_text, best_tokens = parse_text r.turn best_paths in
      let oracle_paths,_ = p.oracle.paths1 in
      let oracle_text, oracle_tokens = parse_text r.turn oracle_paths in
      (n, {p with lat={p.lat with paths2=text,tokens}; best={p.best with paths2=best_text,best_tokens}; oracle={p.oracle with paths2=oracle_text,oracle_tokens}}))}))
