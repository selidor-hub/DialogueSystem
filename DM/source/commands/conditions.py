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

import simpleeval
from functools import partial

from communicators.base_communicator import MessageType
# from interfaces.eniam import get_eniam_parse, eniam_compare
import json
from nested_lookup import nested_lookup
from benedict import benedict

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")


def aim(convo_state, aim_string):
    logging.info('convo_aim= ' + str(convo_state.aim) + ' <-> ' + aim_string)
    return str(convo_state.aim) == aim_string


# def client_said(message, pattern):
    # logging.warning('Nie używać tej funkcji...')
    # return message[0] == MessageType.TEXT and message[1] == pattern


# def client_said_contains(message, pattern):
    # return message[0] == MessageType.TEXT and pattern in message[1] 


def is_variable(convo_state, variable, value=None):
    if variable not in convo_state.knowledge['variables']:
        return False
    else:
        return value is None or convo_state.knowledge['variables'][variable] == value

def eniam_parsed_as(convo_state, message, eniam_pattern):
    if message != (None, None) and message[0] == MessageType.TEXT:
        if 'client_declaration' in message[1]:
            message1 = message[1]['client_declaration']
        else:
            message1 = message[1]
        # eniam_parse = get_eniam_parse(message[1])
        # return dict_compare(eniam_parse['client_declaration'], json.loads(eniam_pattern))
        res = dict_compare(message1, json.loads(eniam_pattern))
    else:
        res =  False
    equal_str = " == " if res else " <> "
    logging.info(repr(message) + equal_str + repr(eniam_pattern))
    return res

def eniam_parsed_contains_key(convo_state, message, keypath):
    logging.debug(repr(message))
    logging.debug(repr(keypath))
    if message != (None, None) and message[0] == MessageType.TEXT:
        last_key_in_path = keypath.split('.')[-1]
        if not last_key_in_path:
            last_key_in_path = keypath
        b =  benedict(message[1])
        if b.match('*' + keypath):
            convo_state.message_to_ground = {
                                             last_key_in_path: b.match('*' + keypath)[0]
                                            }
            return True
    return False

# KZ 2021.03.18 replaced
def dict_compare(parse, pattern): 
    # return any(value in nested_lookup(key, parse) for key, value in pattern.items())
    logging.debug(str(parse) + '<--->' + str(pattern))
    if parse == pattern:
        return True
    try:
        res = any(value in [{k:v} for k,v in nested_lookup(key, parse)[0].items()] for key, value in pattern.items())
        logging.debug('any = ' + str(res))
    except:
        try:
            res = any(value in nested_lookup(key, parse) for key, value in pattern.items())
            logging.debug('except/try = ' + str(res))
        except:
            res = False
            logging.debug('except/except = ' + str(res))
    return res

# KZ 2021.03.25 added
def dict_contains_key(parse, keypath): 
    # return len(benedict(parse).match(keypath)) > 0
    return len(benedict(parse).match('*' + keypath)) > 0 # KZ bezpieczniej z * przed keypath

# def eniam_raw_text_contains(message, pattern):
    # logging.debug(repr(message))
    # if message != (None, None) and message[0] == MessageType.TEXT and 'text' in message[1]:
        ## eniam_parse = get_eniam_parse(message[1])
        ## return eniam_compare(eniam_parse['client_declaration'], json.loads(eniam_pattern))
        # return pattern.lower() in message[1]['text'].lower()
    # else:
        # return False


def aim_fulfilled(convo_state):
    return convo_state.aim.fulfilled()


def check_condition(condition, convo_state, message):
    available_functions = {
        'aim': partial(aim, convo_state),
        'is_variable': partial(is_variable, convo_state),
        # 'client_said': partial(client_said, message), # KZ: OBSOLETE
        # 'client_said_contains': partial(client_said_contains, message), # KZ: OBSOLETE
        'eniam_parsed_as': partial(eniam_parsed_as, convo_state, message),
        'eniam_parsed_contains_key': partial(eniam_parsed_contains_key, convo_state, message),
        # 'eniam_raw_text_contains': partial(eniam_raw_text_contains, message),
        'aim_fulfilled': partial(aim_fulfilled, convo_state),
    }
    names = {}

    if isinstance(condition, dict):
        if 'or' in condition:
            return any(check_condition(c, convo_state, message) for c in condition['or'])
        if 'statement' in condition:
            names.update(condition['variables'])
            condition = condition['statement']
            
    evaluator = simpleeval.EvalWithCompoundTypes(
        functions=available_functions,
        names=names
    )
    result = evaluator.eval(condition)
    if not isinstance(result, bool):
        raise TypeError("condition '{}' does not return boolean value".format(condition))
    return result
