#  Dialog Manager
#  Copyright (C) 2022 SELIDOR - T. Puza, Ł. Wasilewski Sp.J.
#
#  This library is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

# coding: utf-8

if __name__ == "__main__":
    import os
    import sys
    dir_up = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    sys.path.append(dir_up)
    # sys.path.append(os.path.join(dir_up, "dj"))
    import utils.log_config

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

from socket import *
import json
from benedict import benedict
from typing import Union


from utils.config import load_json_cfg
from variables import ENIAM_HOSTNAME, ENIAM_PORT, GROUNDER_HOSTNAME, GROUNDER_PORT, CAT_GROUNDER_HOSTNAME, CAT_GROUNDER_PORT, PHONE_ENIAM_HOSTNAME, PHONE_ENIAM_PORT, NAME_ENIAM_HOSTNAME, NAME_ENIAM_PORT, ENIAM_CONNECT_TIMEOUT, ENIAM_RECEIVE_TIMEOUT
# from variables import ENIAM_GRID_HOSTNAME, ENIAM_GRID_PORT  ### for future use with grids
from utils.parameters import Time, Service
from communicators.base_communicator import MessageType


understood_keys = ['time', 'service']

# ENIAM_TRANSLATOR = load_json_cfg('eniam.json')

previous_eniam_parse = {} # KZ 2020.12.03
eniam_parse_str = ""

def eniam_parse_str_f():
    return eniam_parse_str

def get_eniam_parse(paragraph, msg_type, context):
    global previous_eniam_parse
    global eniam_parse_str
    
    logging.debug('paragraph= ' + str(paragraph))
    logging.debug('context= ' + str(context))
    logging.debug('previous_eniam_parse= ' + repr(previous_eniam_parse))
    key_for_previous_eniam_parse = paragraph + str(context)
    if key_for_previous_eniam_parse in previous_eniam_parse and previous_eniam_parse[key_for_previous_eniam_parse]: # KZ 2021.04.22
        return previous_eniam_parse[key_for_previous_eniam_parse]
        
    text = paragraph.strip()
    try:
        eniam_parse_str = ""
        eniam_host = ENIAM_HOSTNAME
        eniam_port = ENIAM_PORT
        # if msg_type == MessageType.GRID:   ### for future use with grids
            # eniam_host = ENIAM_GRID_HOSTNAME
            # eniam_port = ENIAM_GRID_PORT
        if "telephone" in context:
            eniam_host = PHONE_ENIAM_HOSTNAME
            eniam_port = PHONE_ENIAM_PORT
        elif "patient" in context:
            eniam_host = NAME_ENIAM_HOSTNAME
            eniam_port = NAME_ENIAM_PORT
        with socket(AF_INET, SOCK_STREAM) as s:  # utworzenie gniazda
            s.settimeout(ENIAM_CONNECT_TIMEOUT)
            s.connect((eniam_host, eniam_port))  # nawiązanie połączenia
            encoded_text = "{}\n\n".format(text).encode()
            logging.info("Sending to ENIAM port " + str(eniam_port) + ": " + encoded_text.decode('utf8').strip())
            s.send(encoded_text)
            s.settimeout(ENIAM_RECEIVE_TIMEOUT)
            try:
                while True:
                    tm = s.recv(4096)
                    if tm:
                        eniam_parse_str += tm.decode('utf8')
                        if eniam_parse_str[-2:] == "\n\n":  # na końcu odp. są 2 znaki newline
                            break
                    else:
                        break
            finally:
                s.close()
        eniam_parse_str.strip()
        logging.info("Received from ENIAM:\n" + eniam_parse_str)
        if len(eniam_parse_str) == 0:
            raise Exception("ENIAM zwrócił pustą odpowiedź")
        eniam_parse_raw = json.loads(eniam_parse_str) # KZ 19.11.2020 adding 'client_declaration' for compatibility with new ENIAM (2020)
        if "error" in eniam_parse_raw:
            logging.error(str(eniam_parse_raw))
            raise Exception(str(eniam_parse_raw["error"]))
        text = None
        if 'text' in eniam_parse_raw:
            text = eniam_parse_raw['text']
            del eniam_parse_raw['text']
        eniam_parse = dict()
        if text is not None:
            eniam_parse['text'] = text
        if eniam_parse_raw:
            eniam_parse['client_declaration'] = eniam_parse_raw
    except json.decoder.JSONDecodeError as e:
        logging.error(str(e))
        raise e # KZ 2021.03.18
    except Exception as e:
        logging.error(repr(e))
        raise Exception("ENIAM " + str(e)) # KZ 2021.03.18

    # if not has_client_declaration(eniam_parse, True):  # KZ: wyłączone 2021.01.07
        # return ENIAM_TRANSLATOR.get(text, {})
    logging.debug("Returning: " + repr(eniam_parse))
    previous_eniam_parse = {key_for_previous_eniam_parse: eniam_parse}
    return eniam_parse

keys_used_by_grounder = [
    "*doer.profession",
    "*organization.type",
    "*patient.flaw",
    "*patient.part",
    "*service.domain",
    "*service.effect",
    "*service.instrument",
    "*service.name",
    "*service.param",
    "*patient.part-length",
    "*patient.part-param",
    "*patient.part-quantity",
    "*patient.person",
    "*service.quantity"]

previous_ground_parse={}
def ground_it(dct, convo_state):
    global previous_ground_parse
    logging.debug('dct= ' + str(dct), stack_info=False)
    if "patient" in dct:
        for key in ["first-name", "second-name", "last-name"]: # GROUNDER nie chce danych os. pacjenta
            dct["patient"].pop(key, None)

    if str(dct) not in previous_ground_parse:
        b = benedict(dct)
        grounder_res = dict()
        # if b.match('*service') or b.match('*patient'):
        if any(b.match(key) for key in keys_used_by_grounder):
            text = json.dumps(dct, ensure_ascii=False)
            try:
                ground_parse_str = ""
                with socket(AF_INET, SOCK_STREAM) as s:  # utworzenie gniazda
                    s.settimeout(ENIAM_CONNECT_TIMEOUT)
                    s.connect((GROUNDER_HOSTNAME, GROUNDER_PORT))  # nawiązanie połączenia
                    encoded_text = "{}\n\n".format(text).encode('utf8')
                    logging.info("Sending to GROUNDER port " + str(GROUNDER_PORT) + ": " + encoded_text.decode('utf8').strip())
                    s.send(encoded_text)
                    s.settimeout(ENIAM_RECEIVE_TIMEOUT)
                    try:
                        while True:
                            tm = s.recv(4096)
                            if tm:
                                ground_parse_str += tm.decode('utf8')
                                if ground_parse_str[-2:] == "\n\n":  # na końcu odp. są 2 znaki newline
                                    break
                            else:
                                break
                    finally:
                        s.close()
                logging.info("Received from GROUNDER:\n" + ground_parse_str.strip())
                grounder_res = json.loads(ground_parse_str)
            except json.decoder.JSONDecodeError as e:
                logging.error(str(e))
                if len(ground_parse_str) == 0:
                    raise Exception("pusta odpowiedź od GROUNDER")
                else:
                    raise Exception("niekompletna odpowiedź od GROUNDER: " + str(len(tm)) + " bajtów") # KZ 2021.07.08
            except Exception as e:
                logging.warning(str(e))
                raise e # KZ 2021.03.18
                
            previous_ground_parse={}
            previous_ground_parse[str(dct)] = grounder_res
        else:
            logging.warning("W zapytaniu do GROUNDER nie ma 'service' ani 'patient'")
    else:
        logging.debug('grounder_res from cache')
        grounder_res = previous_ground_parse[str(dct)]

    try:
        b = benedict(grounder_res)
        # service_id_with = b.match("*service.id.") ### * = "with" jeżeli więcej niż 1 id
        service_id_with = b.match("*service.id.with")
        if not service_id_with:
            service_id_list = b.match("*service.id")
            ids_list_numbers = service_id_list
        elif len(service_id_with) < 1 or len(service_id_with[0]) < 1:
            ids_list_numbers = []
        else:
            ids_list_numbers = service_id_with[0]
        ids_list = [str(id) for id in ids_list_numbers if id != "no data"]
        if not ids_list:
            logging.warning("GROUNDER nie znalazł usług")
    except (KeyError, TypeError) as e:
        err_str = "Błąd od GROUNDERa: " + str(e)
        logging.error(err_str)
        raise Exception(err_str)
        # ids_list = []

    convo_state.params['organisation'].service_base.intersect_entries_by_ids(ids_list)
    return

cat_grounder_resp = ""
def get_cat_grounder_resp_str():
    return cat_grounder_resp
    
def ask_category_grounder(dct):
    global cat_grounder_resp
    cat_grounder_resp = ""
    logging.debug("dct = " + repr(dct))
    text = json.dumps(dct, ensure_ascii=False)
    try:
        ground_parse_str = ""
        with socket(AF_INET, SOCK_STREAM) as s:  # utworzenie gniazda
            s.settimeout(ENIAM_CONNECT_TIMEOUT)
            s.connect((CAT_GROUNDER_HOSTNAME, CAT_GROUNDER_PORT))  # nawiązanie połączenia
            encoded_text = "{}\n\n".format(text).encode('utf8')
            logging.info("Sending to CAT_GROUNDER port " + str(CAT_GROUNDER_PORT) + ": " + encoded_text.decode('utf8').strip())
            s.send(encoded_text)
            s.settimeout(ENIAM_RECEIVE_TIMEOUT)
            try:
                while True:
                    tm = s.recv(4096)
                    if tm:
                        ground_parse_str += tm.decode('utf8')
                        if ground_parse_str[-2:] == "\n\n":  # na końcu odp. są 2 znaki newline
                            break
                    else:
                        break
            finally:
                s.close()
            cat_grounder_resp = ground_parse_str
        logging.info("Received from CAT_GROUNDER:\n" + ground_parse_str.strip())
        grounder_res = json.loads(ground_parse_str)
    except json.decoder.JSONDecodeError as e:
        logging.error(str(e))
        if len(ground_parse_str) == 0:
            raise Exception("pusta odpowiedź od CAT_GROUNDER")
        else:
            raise Exception("niekompletna odpowiedź od CAT_GROUNDER: " + ground_parse_str) # KZ 2021.07.08
    except Exception as e:
        logging.error(str(e) + " " + ground_parse_str)
        raise Exception(str(e) + " " + ground_parse_str)
            
    try:
        category = grounder_res['category'] if type(grounder_res['category']) == str else None
        if category == "not found":
            category = None
    except (KeyError, TypeError) as e:
        logging.warning(repr(e))
        # raise e  ### KZ tymczasowo ?
        category = None
    return category


def has_client_declaration(eniam_parse, do_not_check_for_keys):
    return eniam_parse and eniam_parse.get('client_declaration') and \
           (do_not_check_for_keys or eniam_parse['client_declaration'].keys() & understood_keys)
    # return eniam_parse and eniam_parse.get('text') and \
           # (do_not_check_for_keys or eniam_parse['text'].keys() & understood_keys)


def ground_time(time_decl, convo_state):
    return Time(time_decl, convo_state) if time_decl else None


def ground_service(service_decl, patient_decl, doer_decl, text, service_base):
    if not any([service_decl, patient_decl, doer_decl]):
        return None
    return Service(service_decl, patient_decl, doer_decl, text, service_base)


def ground_eniam(eniam_parse, convo_state):
    if not eniam_parse:
        return None
    ### KZ 2021.03.09
    if "client_declaration" not in eniam_parse:
        eniam_parse = {"client_declaration": eniam_parse}
    ### KZ end
    if has_client_declaration(eniam_parse, True):
    
        client_decl = eniam_parse.get("client_declaration", dict())
        return {
            'time': ground_time(client_decl.get("time"), convo_state),
            'service': ground_service(client_decl.get("service"),
                                      client_decl.get("patient"),
                                      client_decl.get("doer"),
                                      # eniam_parse['text'],
                                      eniam_parse.get('text', ""), # KZ 2020.11.24
                                      convo_state.params['organisation'].service_base)
        }
    elif has_client_declaration(eniam_parse, False):  # i do not understand
        return {}
    else:  # eniam does not understand
        return None

# KZ 2020.08.24
if __name__ == "__main__":
    print('ENIAM_HOSTNAME = ' + ENIAM_HOSTNAME + ', ENIAM_PORT = ' + str(ENIAM_PORT))
    while (True):
        try:
            input_str = input("send to ENIAM> ")
        # Wyjście z programu przez Ctrl-D lub Ctrl-C:
        except:
            print('\tBye...')
            break
        res_E = get_eniam_parse(input_str)
        print(res_E)
