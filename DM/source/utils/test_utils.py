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

from communicators.base_communicator import BaseCommunicator, MessageDataType
from definitions import MAX_VISUALIZABLE_HITS
from convos.convo_state import ConvoState
from interfaces.eniam import get_eniam_parse, ground_eniam
from utils.desambiguation import desambiguate
from utils.page_knowledge import org_dict


def add_to_org_dict(communicator_firm_id, division='1'):
    org_dict[communicator_firm_id] = {'reservis_company_code': 'GGAPD9',
                                      'reservis_division_id': division,
                                      'fb_access_token': 'token'}


def get_grounded(text, add_service=True):
    add_to_org_dict('100')
    convo_state = ConvoState(100, 1, MockCommunicator)
    if add_service:
        _, desamb = desambiguate(get_eniam_parse('olaplex'), [], {})
        convo_state.add_to_knowledge(ground_eniam(desamb, convo_state))
    if_ok, desamb = desambiguate(get_eniam_parse(text), [], {})
    return ground_eniam(desamb, convo_state)


class ConvoStateMock:
    def __init__(self, gender='female'):
        self.gender = gender


class MockCommunicator(BaseCommunicator):
    def __init__(self, _):
        self.last_aim = []
        self.last_id = []
        self.last_data = []
        self.last_text = []

    def verify_request(self, request):
        return True

    def parse_request(self, request):
        return request

    def is_visualizable(self, aim, data):
        return len(data) <= MAX_VISUALIZABLE_HITS

    def get_user_info(self, psid, fields=None):
        return {'first_name': 'Janina', 'last_name': 'Jankowska', 'gender': 'female', 'email': 'j.jankowska@test.com'}

    def _send_hits(self, user_id, hits):
        self.last_aim.append(MessageDataType.HITS)
        self.last_id.append(user_id)
        self.last_data.append(hits)
        self.last_text.append("Hits")

    def _send_text(self, user_id, text):
        self.last_aim.append(MessageDataType.TEXT)
        self.last_id.append(user_id)
        self.last_data.append(text)
        self.last_text.append(text)

    def _send_choice(self, user_id, data):
        self.last_aim.append(MessageDataType.CHOICE)
        self.last_id.append(user_id)
        self.last_data.append(data)
        self.last_text.append(data['text'])

    def _send_open_question(self, user_id, data):
        self.last_aim.append(MessageDataType.OPEN_QUESTION)
        self.last_id.append(user_id)
        self.last_data.append(data)
        self.last_text.append(data['question'])

    def _send_file(self, user_id, filename):
        self.last_aim.append(MessageDataType.FILE)
        self.last_id.append(user_id)
        self.last_data.append(filename)
        self.last_text.append("File")

    def _send_button(self, user_id, data):
        self.last_aim.append(MessageDataType.BUTTON)
        self.last_id.append(user_id)
        self.last_data.append(data)
        self.last_text.append(data['text'])
