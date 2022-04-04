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

from commands.actions import execute_action
from commands.conditions import check_condition
from utils.config import load_json_cfg
from utils.exceptions import FirmNotExists

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

import yaml
import os
from definitions import CONFIGURATION_ROOT
with open(os.path.join(CONFIGURATION_ROOT, "commands.yaml"), 'r') as config:
    COMMANDS = yaml.load(config)


def find_command(convo_state, message):
    logging.debug(repr(message))
    for command in COMMANDS['commands']:
        logging.debug('command= ' + repr(command))
        good = True
        if not command or not 'conditions' in command:
            logging.error("Invalid command: {}".format(command))
            good = False
        for condition in command['conditions']:
            if not check_condition(condition, convo_state, message):
                logging.debug('message: ' + repr(message[1]) + ', command[id]= ' + str(command['id']) + ', condition: ' + repr(condition) + ': FALSE')
                good = False
                break
            logging.debug('message: ' + repr(message) + ', command[id]= ' + str(command['id']) + ', condition: ' + repr(condition) + ': TRUE')
        if good:
            # logging.info('return command with id= ' + repr(command['id']))
            return command
    logging.debug('returning None')
    return None


def execute_command(command, convo_state):
    if command is None:
        logging.debug('no command')
        return False
    if not command or 'actions' not in command:
        logging.error("Invalid command: {}".format(command))
        return False
    logging.info('will execute command with id= ' + str(command['id']))
    for action in command['actions']:
        logging.info('will execute_action(' + repr(action) + ')')
        execute_action(action, convo_state)
    logging.info('exiting True: ' + repr(command))
    return True


def apply_command(convo_state, message=(None, None)):
    # logging.info("Aim: " + convo_state.aim.__str__())
    logging.info("Aim: " + str(convo_state.aim))
    aim_old = convo_state.aim
    # logging.info('enter: ' + repr(message[1])) 
    command = 'undefined'
    try:
        command = find_command(convo_state, message)
        if command is None:
            if message != (None, None):
                log_message = ' for message= ' + repr(message)
            else:
                log_message = ''
            logging.debug("No command found" + log_message)
            res = False
        else:
            res = execute_command(command, convo_state)
    except FirmNotExists as e:
        raise e
    except Exception as e:
        logging.error("Exception: {}\n in command {}".format(repr(e), command), stack_info=False)
        raise e
        # res = False
    # logging.info("Aim: " + convo_state.aim.__str__())
    if aim_old != convo_state.aim:
        logging.info("Aim: " + str(convo_state.aim))
    return res
