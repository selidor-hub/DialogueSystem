(*
 *  dara preprocessing for name parser
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
 
type name = FirstName | LastName
type gender = Male | Female
 
let load_table3 filename sex_pat =
  let lines = File.load_lines filename in
  print_endline ("load_table3: " ^ List.hd lines);
  List.rev (Xlist.fold (List.tl lines) [] (fun l line -> 
    match Xstring.split "," line with 
      [v;sex;count] -> 
        if sex <> sex_pat then failwith ("load_table3: " ^ sex) else
        (v,count) :: l
    | _ -> failwith ("load_table3: " ^ line)))
    
let load_table2 filename =
  let lines = File.load_lines filename in
  print_endline ("load_table2: " ^ List.hd lines);
  List.rev (Xlist.fold (List.tl lines) [] (fun l line -> 
    match Xstring.split "," line with 
      [v;count] -> (v,count) :: l
    | _ -> failwith ("load_table2: " ^ line)))
  
let is_foreign s =
  Xlist.fold (Xunicode.classified_chars_of_utf8_string s) false (fun b -> function
      Xunicode.Other _ -> true
    | Xunicode.Sign "(" -> true
    | Xunicode.Sign "." -> true
    | Xunicode.Sign "/" -> true
    | Xunicode.Sign "'" -> true
    | Xunicode.Small(_,"r") -> true
    | _ -> b)
  
let remove_foreign data =
  Xlist.rev_map data (fun (n,g,l) ->
    n,g,Xlist.fold l [] (fun l (v,q) ->
      if is_foreign v then l else (v,q) :: l))
  
let add_char_quantities qmap s =
  Xlist.fold (Xunicode.utf8_chars_of_utf8_string s) qmap (fun qmap c -> 
    if c = "\n" then StringQMap.add qmap ("\\n " ^ s) else
    let b = match Xunicode.classified_chars_of_utf8_string c with [Xunicode.Other _] -> true | _ -> false in
    if b then StringQMap.add qmap (c ^ " " ^ s)
    else StringQMap.add qmap c)
  
let print_char_quantities filename data =
  let qmap = Xlist.fold data StringQMap.empty (fun qmap (_,_,l) ->
    Xlist.fold l qmap (fun qmap (v,_) -> add_char_quantities qmap v)) in
  File.file_out filename (fun file ->
    StringQMap.iter qmap (fun k v ->
     Printf.fprintf file "%6d %s\n" v k))
    
let split_names data =
  Xlist.rev_map data (fun (n,g,l) ->
    let set = Xlist.fold l StringSet.empty (fun set (v,q) ->
      Xlist.fold (Xstring.split " \\|-" v) set StringSet.add) in
    let l = StringSet.to_list (StringSet.remove set "NAZWISKA") in
    n,g,l)
  
let lowercase_names data =
  Xlist.rev_map data (fun (n,g,l) ->
    n,g,Xlist.fold l [] (fun l s ->
      match Xunicode.utf8_chars_of_utf8_string s with
        [] -> l
      | [_] -> l
      | c :: s -> (c ^ (Xunicode.lowercase_utf8_string (String.concat "" s))) :: l))
   
let save data =
  Xlist.iter data (fun (n,g,l) ->
    let filename = "results/" ^
      (match n with FirstName -> "FirstName" | LastName -> "LastName") ^
      (match g with Male -> ".m" | Female -> ".f") ^ ".tab" in
    File.file_out filename (fun file ->
      Xlist.iter l (Printf.fprintf file "%s\n")))
   
let _ =
  let data = [
    FirstName,Male,
      load_table3 "sources/imiona_męskie_imię_pierwsze.csv" "MĘŻCZYZNA" @
      load_table3 "sources/imiona_męskie_imię_drugie.csv" "MĘŻCZYZNA";
    FirstName,Female,
      load_table3 "sources/imiona_żeńskie_imię_pierwsze.csv" "KOBIETA" @
      load_table3 "sources/imiona_żeńskie_imię_drugie.csv" "KOBIETA";
    LastName,Male, load_table2 "sources/nazwiska_męskie.csv";
    LastName,Female, load_table2 "sources/nazwiska_żeńskie.csv"] in
  let data = remove_foreign data in
(*   print_char_quantities "results/char_quatities.txt" data; *)
  let data = split_names data in
  let data = lowercase_names data in
  save data;
  ()
