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
 
open SubsyntaxTypes
open Xstd

type g = 
    Edge of int * int * string * float
  | Leaf of int * float
  

(*type t = {
  filename: string; sentence: string; 
  lattice: (int * int * string * string) list;
  graph: (int * int * string) list}

let empty_record = {filename=""; sentence=""; lattice=[]; graph=[]}*)

(*type t = {
  filename: string; sentence: string; 
  paths: (int * token_env list * int) list;
  paths2: (int * text * token_env ExtArray.t) list;
  best_path: string; oracle_path: string; best_cost: float; oracle_cost: float}

let empty_record = {filename=""; sentence=""; paths=[]; paths2=[]; best_path=""; oracle_path=""; best_cost=nan; oracle_cost=nan}*)

(*type path = {
  paths0: g list;
  paths1: (token_env list * int);
  best_paths1: (token_env list * int);
  oracle_paths1: (token_env list * int);
  paths2: (text * token_env ExtArray.t);
  best_paths2: (text * token_env ExtArray.t);
  oracle_paths2: (text * token_env ExtArray.t);
  best_path: string; oracle_path: string; best_cost: float; oracle_cost: float;
  question_marker: float;
  precision: float; recall: float; accuracy: float; 
  sem: Xjson.json;
  best_precision: float; best_recall: float; best_accuracy: float; 
  best_sem: Xjson.json;
  best_precision2: float; best_recall2: float; best_accuracy2: float; 
  best_sem2: Xjson.json;
  oracle_precision: float; oracle_recall: float; oracle_accuracy: float; 
  oracle_sem: Xjson.json;
  oracle_precision2: float; oracle_recall2: float; oracle_accuracy2: float; 
  oracle_sem2: Xjson.json;
  gold: string}*)

type p = {  
  text: string;
  paths0: g list;
  paths1: (token_env list * int);
  paths2: (text * token_env ExtArray.t);
  question_marker: float;
  cost: float; 
  precision: float; recall: float; accuracy: float; 
  sem: Xjson.json}
  
type paths = {
  lat: p;
  best: p;
  best2: p;
  oracle: p;
  oracle2: p;
(*   gold: p; *)
  start_time: float;
  end_time: float}
  
type t = {
  dir: string; name: string; turn: string; speaker: string;
  paths: (int * paths) list;
  turn_sem: Xjson.json;
  turn_type: string;
  }

(*let empty_path = {
  paths0=[];
  paths1=[],0; 
  best_paths1=[],0; 
  oracle_paths1=[],0; 
  paths2=AltText[],ExtArray.make 0 empty_token_env; 
  best_paths2=AltText[],ExtArray.make 0 empty_token_env; 
  oracle_paths2=AltText[],ExtArray.make 0 empty_token_env; 
  best_path=""; oracle_path=""; best_cost=nan; oracle_cost=nan;
  question_marker=nan;
  precision= -1.; recall= -1.; accuracy= -1.;
  sem=Xjson.JNull;
  best_precision= -1.; best_recall= -1.; best_accuracy= -1.;
  best_sem=Xjson.JNull;
  best_precision2= -1.; best_recall2= -1.; best_accuracy2= -1.;
  best_sem2=Xjson.JNull;
  oracle_precision= -1.; oracle_recall= -1.; oracle_accuracy= -1.;
  oracle_sem=Xjson.JNull;
  oracle_precision2= -1.; oracle_recall2= -1.; oracle_accuracy2= -1.;
  oracle_sem2=Xjson.JNull;
  gold=""}*)

let empty_p = {
  text="";
  paths0=[];
  paths1=[],0; 
  paths2=AltText[],ExtArray.make 0 empty_token_env; 
  cost=nan;
  question_marker=nan;
  precision= -1.; recall= -1.; accuracy= -1.;
  sem=Xjson.JNull}

let empty_paths = {
  lat=empty_p;
  best=empty_p;
  best2=empty_p;
  oracle=empty_p;
  oracle2=empty_p;
(*   gold=empty_p; *)
  start_time=nan;
  end_time=nan}

let empty_record = {dir=""; name=""; turn=""; speaker=""; paths=[]; turn_sem=Xjson.JNull; turn_type=""}

(* let words_filename = "../../ASR/lats/words.txt" *)

(*let sentence_L2a_filename = "../../ASR/lats/clarin_mixed_grammar_2/L2a/text"

let sentence_tdnnf_L2a_filename = "../../ASR/lats/tdnnf_mixed_grammar_2/lats_L2a_Marta.txt"
let sentence_tdnnf_L2_time_filename = "../../ASR/lats/tdnnf_mixed_grammar_2/lats_L2_corpus_time.txt"
let sentence_tdnnf_L1a_filename = "../../ASR/lats/tdnnf_mixed_grammar_2/lats_L1a_Lukasz.txt"*)

let has_question_marker = ref true

let corpus_mode = ref false
let corpus_path = ref ""
let comm_stdio = ref true
let port = ref 9761

let lemma_case_mapping = ref (StringMap.empty : StringSet.t StringMap.t)
