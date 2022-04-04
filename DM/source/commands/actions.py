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

from communicators.base_communicator import make_text_response, make_choice_response, MessageDataType
from convos.convo_aims import aim_factory
from nlg.literals import ResetReply, HelpMsg, No, Yes
from nlg.replies import hello, hello_world

import utils.log_config
import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

def send_messages(convo_state, messages):
    logging.info(repr(messages))
    convo_state.send_messages(messages)
    convo_state.wait_for_response = True


def send_text(convo_state, text):
    logging.info(text)
    send_messages(convo_state, make_text_response(text))

def send_hello(convo_state):
    if not convo_state.hello_sent:
        send_text(convo_state, hello(convo_state))
        convo_state.hello_sent = True

def send_choice(convo_state, text, choices):
    send_messages(convo_state,  make_choice_response(text, choices, None))


def send_mail(convo_state):
    # TODO
    send_text(convo_state, "Sending mail")


def send_file(convo_state):
    # TODO
    send_text(convo_state, "Sending file")


def change_aim(convo_state, aim_string):
    logging.debug('Creating new Aim: ' + aim_string)
    aim = aim_factory(convo_state, aim_string)
    convo_state.aim = aim
    convo_state.aim.next_if_fulfilled()

def change_aim_to_next(convo_state):
    convo_state.aim.next_if_fulfilled()
    logging.debug('CURRENT Aim: ' + convo_state.aim.__str__())

def do_not_wait_for_response(convo_state):
    convo_state.wait_for_response = False

def wait_for_response(convo_state):
    convo_state.wait_for_response = True


def hello_world_reply(convo_state):
    logging.info('hello_world_reply()')
    send_messages(convo_state, hello_world(convo_state))


def help_reply(convo_state):
    logging.info('help_reply()')
    send_text(convo_state, HelpMsg)


def reset(convo_state):
    logging.info('reset()')
    convo_state.reset()


def reset_msg(convo_state):
    logging.info('reset_msg()')
    send_text(convo_state, ResetReply)


def set_variable(convo_state, variable, value):
    convo_state.knowledge['variables'][variable] = value


def get_representative_service_name(convo_state):
    return convo_state.params['service'].get_outstanding().representative.name


def aim_select_first_proposed(convo_state):
    convo_state.aim.select_first_proposed()

def aim_parse_confirmation(convo_state, value): # Aim = ConfirmReservation
    convo_state.aim.parse_confirmation(value)

def aim_parse_if_confirmation(convo_state, value): # Aim = ProcessConfirmation
    convo_state.aim.parse_if_confirmation(value)

def generate_and_send_messages(convo_state):
    messages = convo_state.generate_messages()
    logging.info('will send: ' + repr(messages))
    convo_state.send_messages(messages)

def convo_state_list_services(convo_state):
    logging.debug('will call convo_state.list_services()')
    convo_state.list_services()

def aim_generate_message(aim):
    logging.debug('will call aim_generate_message() aim= ' + str(aim))
    return aim.generate_message()

def convo_state_ground_message(convo_state):
    convo_state.ground_message()
    return

def convo_state_step_back(convo_state):
    convo_state.step_back()
    return

def execute_action(action, convo_state):
    evaluator = simpleeval.EvalWithCompoundTypes(
        functions={
            'send_text': partial(send_text, convo_state),
            'send_hello': partial(send_hello, convo_state),
            'send_choice': partial(send_choice, convo_state),
            'send_mail': partial(send_mail, convo_state),
            'send_file': partial(send_file, convo_state),
            'send_messages': partial(send_messages, convo_state),
            'change_aim': partial(change_aim, convo_state),
            'change_aim_to_next': partial(change_aim_to_next, convo_state),
            'do_not_wait_for_response': partial(do_not_wait_for_response, convo_state),
            'wait_for_response': partial(wait_for_response, convo_state),
            'hello_world': partial(hello_world_reply, convo_state),
            'help': partial(help_reply, convo_state),
            'reset': partial(reset, convo_state),
            'reset_msg': partial(reset_msg, convo_state),
            'set_variable': partial(set_variable, convo_state),
            'get_representative_service_name': partial(get_representative_service_name, convo_state),
            'convo_state_list_services': partial(convo_state_list_services, convo_state),
            'aim_select_first_proposed': partial(aim_select_first_proposed, convo_state),
            'aim_parse_confirmation': partial(aim_parse_confirmation, convo_state), # KZ 2021.03.18
            'aim_parse_if_confirmation': partial(aim_parse_if_confirmation, convo_state), # KZ 2021.03.18 parse_if_confirmation returns True (can be ignored?)
            'aim_generate_message': partial(aim_generate_message, convo_state.aim),
            'convo_state_ground_message': partial(convo_state_ground_message, convo_state),
            'convo_state_step_back': partial(convo_state_step_back, convo_state),
            'Yes': Yes,
        }
    )
    evaluator.eval(action)
