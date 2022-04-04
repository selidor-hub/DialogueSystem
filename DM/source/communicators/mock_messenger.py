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

import json
from pymessenger2.utils import AttrsEncoder
from communicators.messenger import Messenger
from communicators.base_communicator import MessageType, MessageDataType
from typing import Union, Tuple, List


class MockMessenger(Messenger):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # self.show_services_text = "Mogę szukać konkretnej usługi lub przekazać listę możliwych usług." 
        self.show_services_text = "" 
        # self.show_choice_text = "Możesz wybrać według nazwy lub według numeru:" 
        # self.show_choice_text = "Wybierz według nazwy: " 
        self.show_choice_text = ""

    @staticmethod
    def parse_request(request):
        ### KZ 2021.09.08 dopóki nie działa ENIAM kratowy, wysyłamy request["text"]
        # try:
            # return request["page_id"], request["user_id"], [(MessageType.GRID, request["grid"])], request.get("text", "")
        # except:
            # return request["page_id"], request["user_id"], [(MessageType.TEXT, request.get("text", ""))], request.get("text", "")
        text = request.get("text", "")
        messages = [(MessageType.TEXT, text)] if text else None
        return request["page_id"], request["user_id"], messages, text

    def get_user_info(self, user_id, fields=None):
        return {"user_id": user_id}  ### TODO to można zatąpić odpytanie o dane użytkownika z zewnętrznego źródła, np. od aplikacji frot-end

    def send(self, id, data_type, data, debug):
        if debug:
            print(str(data), file=self.convo_state.output_file)
        else:
            super().send(id, data_type, data)



    def extract_text(self, out):
        result_lines = []
        for line in out.splitlines():
            logging.debug(line)
            response_obj = json.loads(line)
            try:
                response_message = response_obj['message']
                try:
                    result_lines += [response_message['text']]
                except KeyError:
                    try:
                        for el in response_message["attachment"]["payload"]["elements"]:
                            for hit in el["buttons"]:
                                result_lines.append(str(hit["payload"]))
                    except KeyError:
                        logging.exception(response_message)
                        result_lines += [bytes(json.dumps(response_obj, indent=2, separators=(',', ': ')).encode()).decode('unicode-escape')]
            except KeyError:
                    logging.exception(bytes(json.dumps(response_obj, indent=2, separators=(',', ': ')).encode()).decode('unicode-escape'))
        return '\n'.join(result_lines)

    def send_raw(self, payload):
        logging.info('sending payload: ' + repr(payload))
        print(
            self.extract_text(json.dumps(payload, cls=AttrsEncoder)), file=self.convo_state.output_file)
        response = {"text": "OK"}  #fake JSON
        return response
        
    def make_text_response(text):
        return MessageDataType.TEXT, text


    def make_choice_response(self, text: str, choices: Union[set, dict, list], func,
                             asking_about: List[Union[str, Tuple[str, str]]] = None,
                             func_for_other_choice=None) -> Tuple:
        # """
        # Generates a choice response
        # :param text: text to be shown to users
        # :param choices: choices available to user
        # :param func: function to process choice (if one of choices), it takes one parameter (user's choice if choices is set or
                # val ue of user's choice in choices if choices is dict)
        # :param func_for_other_choice: function to process choice (if other than choices)
        # :param asking_about:
        # :return:
        # """
        return MessageDataType.CHOICE, {"text": text, "choices": choices,
                                        "func": func,
                                        "func_for_other_choice": func_for_other_choice,
                                        "asking_about": asking_about}


    def make_open_question(question: str, asking_about: List[Union[str, Tuple[str, str]]] = None, func=None):
        # return MessageDataType.OPEN_QUESTION, {"question": question, "asking_about": asking_about, "func": func}
        return MessageDataType.TEXT, question


    def make_file_response(filename):
        # return MessageDataType.FILE, filename
        return MessageDataType.TEXT, 'File ' + filename


    def make_button_response(text, buttons_data):
        # return MessageDataType.BUTTON, {'text': text, 'buttons_data': buttons_data}
        return MessageDataType.TEXT, text
