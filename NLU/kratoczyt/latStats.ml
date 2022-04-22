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
open SubsyntaxTypes

(*let rec extract_path visited rev i =
  if i = 0 then rev else
  let e = try IntMap.find visited i with Not_found -> failwith "extract_path" in
  extract_path visited (e :: rev) e.beg
  
let rec find_best_path_rec last paths visited q =
  let cost, e0, q = FuzzyDetector.PrioQueue.extract q in
  if IntMap.mem visited e0.next then find_best_path_rec last paths visited q else
  let visited = IntMap.add visited e0.next e0 in
  if e0.next = last then cost, visited else
  let q = Xlist.fold (IntMap.find paths e0.next) q (fun q e ->
    FuzzyDetector.PrioQueue.add q (cost +. e.weight) e) in
  find_best_path_rec last paths visited q
  
let find_best_path2 p =
  let paths,last = p.paths1 in
  let paths = Xlist.fold paths IntMap.empty (fun map e ->
    IntMap.add_inc map e.beg [e] (fun l -> e :: l)) in
  let q = Xlist.fold (IntMap.find paths 0) FuzzyDetector.PrioQueue.empty (fun q e ->
    FuzzyDetector.PrioQueue.add q e.weight e) in
  let best_cost, visited = find_best_path_rec last paths IntMap.empty q in
  let best_path = extract_path visited [] last in
  let best_path = String.concat " " (Xlist.map best_path (fun e -> e.orth)) in
  let best_path = if best_path <> p.best_path then best_path ^ " | " ^ p.best_path else best_path in
  {p with best_cost; best_path}
  
let find_best_path data =
  Xlist.map data (fun r ->
(*     print_endline ("find_best_path: " ^ r.sentence); *)
    let paths = Xlist.map r.paths (fun (n,p) -> n, find_best_path2 p) in
    {r with paths})  *)
  
(*let rec add_oracle_queue cost q e = function
    [] -> FuzzyDetector.PrioQueue.add q (cost +. e.weight +. 100000.) (e,[])
  | t :: oracle -> 
(*       let q = add_oracle_queue (cost +. 100000.) q e oracle in *)
      let q = FuzzyDetector.PrioQueue.add q (cost +. e.weight +. 100000.) (e, t :: oracle) in
      if e.orth = t then FuzzyDetector.PrioQueue.add q (cost +. e.weight) (e, oracle)
      else FuzzyDetector.PrioQueue.add q (cost +. e.weight +. 100000.) (e, oracle)
  
let rec find_oracle_path_rec last paths visited q =
  let cost, (e0,oracle), q = FuzzyDetector.PrioQueue.extract q in
  if IntMap.mem visited e0.next then find_oracle_path_rec last paths visited q else
  let visited = IntMap.add visited e0.next e0 in
  if e0.next = last then cost, visited else
  let q = Xlist.fold (IntMap.find paths e0.next) q (fun q e ->
    add_oracle_queue cost q e oracle) in
  find_oracle_path_rec last paths visited q
  
let rec split_oracle_cost x = 
  if x > 10000. then 
    let i, x = split_oracle_cost (x -. 100000.) in
    i+1, x
  else 0, x
  
let find_oracle_path2 oracle p =
  let paths,last = p.paths1 in
  let paths = Xlist.fold paths IntMap.empty (fun map e ->
    IntMap.add_inc map e.beg [e] (fun l -> e :: l)) in
  let q = Xlist.fold (IntMap.find paths 0) FuzzyDetector.PrioQueue.empty (fun q e ->
    add_oracle_queue 0. q e oracle) in
  let oracle_cost, visited = find_oracle_path_rec last paths IntMap.empty q in
  let oracle_path = extract_path visited [] last in
  let oracle_path = String.concat " " (Xlist.map oracle_path (fun e -> e.orth)) in
  let _,oracle_cost = split_oracle_cost oracle_cost in
  {p with oracle_cost; oracle_path}
  
let find_oracle_path data =
  Xlist.map data (fun r ->
    print_endline ("find_oracle_path: " ^ r.sentence);
    let oracle = Xstring.split " " r.sentence in
    let paths = Xlist.map r.paths (fun (n,p) -> n, find_oracle_path2 oracle p) in
    {r with paths})*)  
  
let rec find_best_path_rec pi rev i =
  if i = 0 then rev else
  if pi.(i).orth = "" then find_best_path_rec pi rev pi.(i).beg
  else find_best_path_rec pi (pi.(i) :: rev) pi.(i).beg
  
let find_best_path paths last best_path0 =
  let a = Array.make last [] in
  Xlist.iter paths (fun e ->
    a.(e.beg) <- e :: a.(e.beg));
  if a.(0) = [] then failwith "find_best_path" else
  let dist = Array.make (last+1) 1000000. in
  dist.(0) <- 0.;
  let pi = Array.make (last+1) SubsyntaxTypes.empty_token_env in
  Int.iter 0 (last-1) (fun i ->
    Xlist.iter a.(i) (fun e ->
      if dist.(i) +. e.weight < dist.(e.next) then (
        dist.(e.next) <- dist.(i) +. e.weight;
        pi.(e.next) <- e)));
  let best_path = find_best_path_rec pi [] last in
  let best_path = String.concat " " (Xlist.map best_path (fun e -> e.orth)) in
  let best_path = if best_path <> best_path0 then best_path ^ " | " ^ best_path0 else best_path in
  dist.(last), best_path
   
let rec get_min = function
    [cost,e,j] -> cost,e,j
  | (cost1,e1,j1) :: (cost2,e2,j2) :: l -> if cost1 < cost2 then get_min ((cost1,e1,j1) :: l) else  get_min ((cost2,e2,j2) :: l)
  | [] -> (*failwith "get_min"*)(100000,empty_token_env,-1)
   
let rec find_oracle_path_rec m cost rev i j =
  if i = 0 && j = 0 then cost,rev else 
  let _,e,j2 = m.(i).(j) in
  find_oracle_path_rec m (cost +. e.weight) (e :: rev) e.beg j2  
    
let find_oracle_path paths last oracle_path0 =
  if oracle_path0 = "" then 0.,"X" else
(*        print_endline "XXXXXXXXXXXXXXXXXXXXXXXXX "; 
        print_endline oracle_path0; 
        print_endline (SubsyntaxStringOf.token_list false paths);*)
  let oracle_path0 = Array.of_list (Xstring.split " " oracle_path0) in
  let a = Array.make (last+1) [] in
  Xlist.iter paths (fun e ->
    a.(e.next) <- e :: a.(e.next));
  let m = Array.make_matrix (last+1) (Array.length oracle_path0) (100000,empty_token_env,-1) in
  Int.iter 0 last (fun i ->
    Int.iter 0 (Array.length oracle_path0 - 1) (fun j ->
      if i = 0 && j = 0 then m.(i).(j) <- 0,empty_token_env,-1 else (
(*       Printf.printf "find_oracle_path 1: i=%d j=%d\n%!" i j; *)
      m.(i).(j) <- get_min (
        Xlist.map a.(i) (fun e ->
          let cost,_,_ = m.(e.beg).(j) in
          cost+1,e,j) @
        (if j = 0 then [] else Xlist.map a.(i) (fun e ->
          let cost,e0,_ = m.(e.beg).(j-1) in
          cost+(if e0.orth = oracle_path0.(j) then 0 else 1),e,j-1)) @
        (if j = 0 then [] else [let cost,e,j2 = m.(i).(j-1) in cost+1,e,j2])))));
  let cost,oracle_path = find_oracle_path_rec m 0. [] last (Array.length oracle_path0 - 1) in
  let oracle_path = String.concat " " (Xlist.map oracle_path (fun e -> e.orth)) in
  cost, oracle_path
        
