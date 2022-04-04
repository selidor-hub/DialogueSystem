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

import datetime
import simpleeval

from communicators.base_communicator import make_text_response, make_button_response
from convos.convo_aims import KnowChoice
from utils.hits import Hit

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

meta_data_to_text = {
    "RESET": "Od nowa",
    "HELP": "Pomoc",
    "START": "Start"
}


def translate_meta_data(meta_data):
    return meta_data_to_text.get(meta_data)


def eval_meta_data(convo_state, meta_data):
    if meta_data == 'REQUEST_BOT':
        convo_state.disabled = False
        return
    if meta_data == 'REQUEST_HUMAN':
        convo_state.disabled = True
        msg1 = make_text_response("Zawsze możesz wrócić do rozmowy z botem, klikając poniższy przycisk.")
        msg2 = make_button_response('Wróć do bota', [('Wybierz', 'REQUEST_BOT')])
        convo_state.send_messages([msg1, msg2])
        return
    available_functions = {
        'Hit': Hit,
        'datetime': datetime,
    }
    names = {}

    evaluator = simpleeval.EvalWithCompoundTypes(
        functions=available_functions,
        names=names
    )
    meta_data_obj = evaluator.eval(meta_data)
    if isinstance(meta_data_obj, Hit):
        logging.debug(repr(meta_data_obj))
        convo_state.knowledge['chosen_hit'] = meta_data_obj
        # KZ 2020.08.27 convo_state.aim.change_aim(KnowChoice)
    else:
        logging.error("Weird meta data object: {}".format(repr(meta_data_obj)))
