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

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

import requests
import json
from pymessenger2.utils import AttrsEncoder
from variables import TTS_URL, TTS_CONNECT_TIMEOUT
from convos.convo_aims import ConfirmReservation, ProcessConfirmation, EndConversation, EndConversationOnFailure
from communicators.base_communicator import MessageType
from communicators.textonly_messenger import TextOnlyMessenger

class ASRMessenger(TextOnlyMessenger):
    def send_raw(self, payload):
        logging.debug('payload= ' + repr(payload))
        try:
            data_json = { "text":     self.extract_text(json.dumps(payload, cls=AttrsEncoder)),
                          "session":  self.convo_state.id }
            logging.debug("self.convo_state.aim = " + str(self.convo_state.aim))
            logging.debug('self.convo_state.knowledge["reservation_code"] = ' + str(self.convo_state.knowledge.get("reservation_code")))
            if isinstance(self.convo_state.aim, (EndConversation, EndConversationOnFailure)) \
               and self.convo_state.knowledge.get("reservation_code"):
                    data_json["reservation_code"] = self.convo_state.knowledge.get("reservation_code")
                    self.convo_state.marked_for_deletion = True

            try:
                super().send_raw(payload)
            except Exception as e:
                logging.warning(repr(e))
            logging.debug("Sending to TTS: " + repr(data_json))
            response = requests.post(
                                    TTS_URL,
                                    # params=self.auth_args,
                                    headers={'Content-Type': 'application/json'},
                                    data = json.dumps(data_json).encode('utf-8'), 
                                    timeout=TTS_CONNECT_TIMEOUT) ### KZ timeout musi być dłuższy niż connection time
            logging.debug('response= ' + repr(response))
            response.raise_for_status()
        # except requests.exceptions.RequestException as e:
        except requests.exceptions.ReadTimeout: ### KZ don't wait for completion of TTS
            logging.warning(TTS_URL + " nie działa asynchronicznie.")
            return
        return response


class TTSMessenger(ASRMessenger):
    @staticmethod
    def parse_request(request):
        # KZ 2021.04.07
        return request["page_id"], request["user_id"], [(MessageType.TEXT, request["text"])]

