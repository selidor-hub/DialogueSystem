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

from communicators.base_communicator import make_open_question
from nlg.replies import what_time
from scope_changes.best_scope_change import best_scope_change_msg, ExtensionMode, DivisionMode
from utils.parameters import Parameter

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")


params_to_verify = ['organisation', 'time', 'service']


def enough_knowledge_to_generate_hits(convo_state):
    logging.debug('convo_state.params = ' + '\n'.join([repr(convo_state.params[p]) for p in params_to_verify]))
    return all(convo_state.params[p] is not None and
               convo_state.params[p].is_ready_to_generate_hits() for p in params_to_verify)


def respond_to_not_enough_knowledge(convo_state):
    if convo_state.params['time'] is None:
        return make_open_question(what_time(convo_state), ["time"])
    if not convo_state.params['time'].is_ready_to_generate_hits():
        return convo_state.params['time'].respond_to_not_ready_to_generate_hits()
    if convo_state.params['service'] is None or not convo_state.params['service'].is_ready_to_generate_hits():
        from convos.convo_aims import KnowService
        convo_state.aim.change_aim(KnowService)
        return convo_state.aim.generate_message()
    return Parameter.respond_to_not_ready_to_generate_hits()


def respond_to_no_hits(convo_state):
    return best_scope_change_msg(convo_state, ExtensionMode, True)


def respond_to_too_many_hits(hits, convo_state):
    return best_scope_change_msg(convo_state, DivisionMode, False, hits)
