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

type tree = 
    L of string * int * int
  | N of tree StringMap.t
  | E
  
type result =
    Contradiction
  | Unspecified
  | JSON of json
  | IntSet of IntSet.t
  | StringList of string list
  | Error of string
  | Idle

type env = {
  eniam_in: in_channel;
  eniam_out: out_channel;
  now: string;
  horizon: string;
  id_service: string IntMap.t;
  service_tree: tree;
  }
  
type slots = {
  date: result;
  category: result;
  service_ids: result;
  current_service_tree: tree;
  }
  
type next_state =
    Next of string
  | Split of ((env -> slots -> bool) * string) list
  | Finish
  
let verbosity = ref 1

let empty_env = {
  eniam_in=stdin;
  eniam_out=stdout;
  now="";
  horizon="";
  id_service=IntMap.empty;
  service_tree=E;
  }

let empty_slots = {
  date=Idle;
  category=Idle;
  service_ids=Idle;
  current_service_tree=E;
  }
  
let is_error = function
    Error _ -> true
  | _ -> false
  
let get_error = function
    Error s -> s
  | _ -> failwith "get_error"
  
let get_json = function
    JSON t -> t
  | _ -> failwith "get_json"
  
let get_intset = function
    IntSet t -> t
  | _ -> failwith "get_intset"
  
let get_stringlist = function
    StringList t -> t
  | _ -> failwith "get_stringlist"
  
