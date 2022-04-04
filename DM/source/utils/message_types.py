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

from commands.commands_manager import apply_command
from communicators.base_communicator import MessageType, make_text_response
from interfaces.eniam import get_eniam_parse, ground_eniam, ground_it, eniam_parse_str_f
from utils.desambiguation import desambiguate
from utils.meta_data import translate_meta_data, eval_meta_data

from benedict import benedict

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

def process_text_message_by_eniam(convo_state, text, context, choices, simple, msg_type=None):
    if not simple: ### KZ 2021.10.14 1. call
        convo_state.any_with = None
        convo_state.withs = None
        convo_state.desambiguated = None
        convo_state.grounded = None

    try:
        if not isinstance(text, (dict,list)): # KZ text jest str
            convo_state.parsed = get_eniam_parse(text, msg_type, context)
            if "telephone" in context and ("error" in convo_state.parsed \
                                           or not benedict(convo_state.parsed).match("*patient.telephone") \
                                           or not benedict(convo_state.parsed).match("*patient.telephone")[0]): # KZ jeżeli pytanie o nr telefonu nie zwróciło nru telefonu
                context = []
                convo_state.parsed = get_eniam_parse(text, msg_type, context) # KZ pytaj ogólnego ENIAMa (bez kontekstu)
        else:
            convo_state.parsed = text
        parsed = convo_state.parsed
        logging.debug('parsed= ' + repr(parsed))
        logging.debug('context= ' + repr(context) + ', choices= ' + repr(choices) +  ', simple= ' + repr(simple))
    except Exception as e:
        logging.exception(e)
        convo_state.error_msg = "Wystąpił błąd: " + str(e)
        # return
        raise(e)

    ### KZ 2021.03.29 dla WJ
    if not simple and convo_state.ENIAM_DEBUG:  # 1.wywołanie
        r = make_text_response(eniam_parse_str_f())
        convo_state._send_to_communicator(r[0], r[1], debug=True)
        
        # print(eniam_parse_str_f(), file=convo_state.output_file)
    ### KZ 2021.03.29 end

    ### KZ 2021.03.10 jeżeli jest tylko 'text', to ENIAM nie sparsował
    if 'text' in parsed and len(parsed) == 1: 
        convo_state.error_msg = "Nie rozumiem: '{}'.".format(repr(text))
        logging.debug(convo_state.error_msg)
        return
    ### KZ end

    ### KZ 2021.03.16 ENIAM zwrócił błąd
    if 'client_declaration' in parsed and 'error' in parsed['client_declaration']: 
        if msg_type == MessageType.GRID:
            text = convo_state.request_text
        convo_state.error_msg = "Nie rozumiem: '{}'.".format(repr(text))
        logging.debug(convo_state.error_msg)
        return
    ### KZ end

    convo_state.any_with, convo_state.desambiguated = desambiguate(parsed, context, choices)
    desambiguated = convo_state.desambiguated
    logging.debug('convo_state.any_with: ' + repr(convo_state.any_with))
    logging.debug('desambiguated: ' + repr(desambiguated))

    ### KZ 2021.12.17 do not disambiguate time
    # logging.debug("benedict(desambiguated).match('*time.*.with') = " + str(benedict(desambiguated).match('*time.*.with')))
    # if benedict(desambiguated).match('*time.*.with'):
        # convo_state.any_with = None
    
    if not ("telephone" in context and benedict(desambiguated).match("patient.telephone")):
        convo_state.grounded = ground_eniam(desambiguated, convo_state)
        grounded = convo_state.grounded
        logging.debug('grounded: ' + repr(grounded))
        if grounded is None:
            text1 = text if isinstance(text, str) else ''
            logging.debug("type(text)=" + str(type(text)))
            logging.debug("text = " + repr(text))
            if isinstance(text, dict):
                if parsed['text']:
                    text1 = parsed['text']
                else:
                    text1 = repr(parsed)
            if msg_type == MessageType.GRID:
                text1 = convo_state.request_text
            convo_state.error_msg = "Nie rozumiem: '{}'.".format(text1)
            logging.debug('convo_state.error_msg = ' + repr(convo_state.error_msg))
            return

        if 'client-data' in desambiguated:              # KZ 2020.12.11
            if 'gender' in desambiguated['client-data']:
                if desambiguated['client-data']['gender'] == 'm':
                    convo_state.gender = "male"
                elif desambiguated['client-data']['gender'] == 'f':
                    convo_state.gender = "female"
                else:
                    convo_state.gender = "unknown"              # end KZ 2020.12.11

        ### KZ 2021.03.09
        logging.debug('convo_state.any_with= ' + repr(convo_state.any_with))
        if convo_state.any_with:
            convo_state.withs = convo_state.any_with, MessageType.TEXT, text, context, choices
        else:
            convo_state.withs = None
        logging.debug('convo_state.withs= ' + repr(convo_state.withs))
        
        if not convo_state.any_with:
            convo_state.add_to_knowledge(grounded)
            if not convo_state.last_tree_choices and grounded["service"]:
                dct = convo_state.knowledge_to_eniam()
                if "patient" in dct:
                    dct["patient"].pop("state", None)
                    if not dct["patient"]:
                        dct.pop("patient", None)
                if dct:
                    ground_it(dct, convo_state)

    if simple:
        return

    logging.debug('convo_state.withs= ' + repr(convo_state.withs))

    text = convo_state.desambiguated if convo_state.desambiguated else convo_state.parsed
    process_text_message(convo_state, text, context, choices)

def process_text_message(convo_state, text, context, choices):
    logging.info('will apply_command() ' + repr(text))
    if not apply_command(convo_state, (MessageType.TEXT, text)):
        logging.debug('will convo_state.parse_first_message() ' + repr(text))
        if convo_state.parse_first_message((MessageType.TEXT, text)):
            text = convo_state.desambiguated if convo_state.desambiguated else convo_state.parsed
            logging.info('will apply_command() ' + repr(text))
            if not apply_command(convo_state, (MessageType.TEXT, text)):
                logging.debug('will convo_state.aim.process_message() ' + repr(text))
                return convo_state.aim.process_message(MessageType.TEXT, text)
        else:
            logging.debug('will convo_state.aim.process_message() ' + repr(text))
            return convo_state.aim.process_message(MessageType.TEXT, text)
    convo_state.withs = None

def process_meta_data_message(convo_state, content, context, choices, simple, msg_type):
    logging.debug('content= ' + repr(content))
    meta_data, _text = content
    # text = translate_meta_data(meta_data)
    text_from_meta_data = translate_meta_data(meta_data)
    if text_from_meta_data: ### KZ added 2021.05.11
        text = get_eniam_parse(text_from_meta_data, msg_type)
        if text is not None:
            process_text_message(convo_state, text, context, choices)
            # if process_text_message(convo_state, text, context, choices):
                # pass
            return
    try:
        eval_meta_data(convo_state, content[0])
    except Exception as e:
        logging.error("Error in meta data: {}\n{}".format(str(e), content))
