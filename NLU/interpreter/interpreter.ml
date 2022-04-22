(*
 *  simple NLU module
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
open Xjson

let make_interpretation text =
  let json = Xlist.map text (fun (cat,orth) -> 
    if cat = "X" || cat = "MWEcomponent" then JEmpty else
    let cat = if Xstring.check_prefix "⟨" cat then Xstring.cut_prefix "⟨" cat else failwith ("make_interpretation 1: " ^ cat) in
    let cat = if Xstring.check_sufix "⟩" cat then Xstring.cut_sufix "⟨" cat else failwith ("make_interpretation 1: " ^ cat) in
    let cat,flex = match Xstring.split "\\." cat with
        cat :: l -> cat, String.concat "." l
      | [] -> failwith "make_interpretation 3" in
(*     Printf.printf "cat=%s flex=%s orth=%s\n%!" cat flex orth; *)
    match cat with
      "Action" -> JObject["action",JObject["name",JString orth]]
    | "Animal" -> JObject["patient",JObject["animal",JString orth]]
    | "Appointment" -> JObject["todo",JObject["Appointment",JString orth]]
    | "Artefact" -> JObject["patient",JObject["artefact",JString orth]]
    | "Attitude" -> JObject["action",JObject["attitude",JString orth]]
    | "Attr" -> JObject["todo",JObject["Attr",JString orth]]
    | "BodyPart" -> JObject["patient",JObject["part",JString orth]]
    | "Comp" -> JEmpty
    | "Confirmation" -> JObject["todo",JObject["Confirmation",JString orth]]
    | "Conj" -> JEmpty
    | "Domain" -> JObject["service",JObject["param",JString orth]]
    | "Email" -> JObject["todo",JObject["Email",JString orth]]
    | "Farewell" -> JObject["todo",JObject["Farewell",JString orth]]
    | "Greetings" -> JObject["todo",JObject["Greetings",JString orth]]
    | "Issue" -> JObject["todo",JObject["Issue",JString orth]]
    | "Location" -> JObject["todo",JObject["Location",JString orth]]
    | "Make" -> JObject["action",JObject["name",JString orth]]
    | "Name" -> JObject["todo",JObject["Name",JString orth]]
    | "Organization" -> JObject["organization",JObject["name",JString orth]]
    | "OrganizationType" -> JObject["organization",JObject["type",JString orth]]
    | "Person" -> JObject["patient",JObject["profession",JString orth]]
    | "Prep" -> JEmpty
    | "Price" -> JObject["todo",JObject["Price",JString orth]]
    | "Profession" -> JObject["doer",JObject["profession",JString orth]]
    | "Question" -> JObject["todo",JObject["Question",JString orth]]
    | "Rating" -> JObject["todo",JObject["Rating",JString orth]]
    | "Reservation" -> JObject["todo",JObject["Reservation",JString orth]] (* trzeba połączyć z Make *)
    | "Service" -> JObject["service",JObject["name",JString orth]]
    | "ServiceParam" -> JObject["service",JObject["param",JString orth]]
    | "Telephone" -> JObject["todo",JObject["Telephone",JString orth]]
    | "Time" -> JObject["todo",JObject["Time",JString orth]]
    | _ -> failwith ("make_interpretation 4: " ^ cat)) in
  let json = JObject["and",JArray json] in
(*   print_endline ("make_interpretation 5: " ^ json_to_string_fmt "" json); *)
  Json.normalize json
      

let subsyntax_host = ref "localhost"
let subsyntax_port = ref 4000

let get_sock_addr host_name port =
  let he = Unix.gethostbyname host_name in
  let addr = he.Unix.h_addr_list in
  Unix.ADDR_INET(addr.(0),port)

let sub_in = ref stdin
let sub_out = ref stdout
  
let initialize () =
  MarkedHTMLof.initialize ();
  InferenceRulesParser.initialize ();
  let su_in,su_out =
    Unix.open_connection (get_sock_addr !subsyntax_host !subsyntax_port) in
  sub_in := su_in;
  sub_out := su_out
  
let parse s =
  let text,tokens =
          try
(*             Printf.fprintf stderr "%s\n%!" s; *)
            Printf.fprintf !sub_out "%s\n\n%!" s;
            (Marshal.from_channel !sub_in : SubsyntaxTypes.text * SubsyntaxTypes.token_env ExtArray.t)
          with e -> (
(*            prerr_endline ("|'" ^ s ^ "'|=" ^ string_of_int (Xstring.size s));
            prerr_endline ("subsyntax_error: " ^ Printexc.to_string e);
            exit 1;*)
            AltText[Raw,RawText s;Error,ErrorText ("subsyntax_error: " ^ Printexc.to_string e)], ExtArray.make 0 SubsyntaxTypes.empty_token_env) in
  let text = match MarkedHTMLof.cat_tokens_sequence_text 1 tokens text with
            [name,text] -> text
          | _ -> failwith ("verse_worker: " ^ s) in
(*  Xlist.iter text (fun (cat,orth) -> 
           Printf.printf "cat=%s orth=%s\n%!" cat orth);*)
  make_interpretation text

  
  
(* uruchamianie subsyntax:
   cd NLU/lexemes
   subsyntax -m -p 4000 -a --def-cat -u inflected -u fixed *)

(* TODO:
- leksemy niejednoznaczne należące do wielu kategorii (np. miejsce)
- sprowadzanie do formy podstawowej
- leksemy niejednoznaczne mające ustaloną kategorię i wiele możliwych slotów (np. Attr)
- „Chcę odwołać swoją rezerwację” nie działa scalanie atrybutów
- „Chciałbym zarezerwować wizytę” - zarezerwować błędnie w Service
- zadbać - brakuje w leksykonie
- się błędnie w Profession
*)
