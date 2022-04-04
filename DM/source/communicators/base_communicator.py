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

from abc import ABCMeta, abstractmethod
from enum import Enum
from typing import Union, Tuple, List

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")


class BaseCommunicator(metaclass=ABCMeta):


    @abstractmethod
    def make_list_string_and_choices(self, entries):
        pass

    @staticmethod
    @abstractmethod
    def verify_request(request):
        pass

    @staticmethod
    @abstractmethod
    def parse_request(request):
        pass

    @staticmethod
    @abstractmethod
    def is_visualizable(data_type, data):
        pass

    @abstractmethod
    def get_user_info(self, user_id, fields=None):
        pass

    @abstractmethod
    def _send_hits(self, user_id, hits):
        pass

    @abstractmethod
    def _send_text(self, user_id, text):
        pass

    @abstractmethod
    def _send_choice(self, user_id, data):
        pass

    def _send_open_question(self, user_id, data):
        return self._send_text(user_id, data["question"])

    @abstractmethod
    def _send_file(self, user_id, filename):
        pass

    @abstractmethod
    def _send_button(self, user_id, data):
        pass

    def send(self, user_id, data_type, data):
        logging.info('user_id= ' + str(user_id) + ', data_type= ' + str(data_type) + ', data= ' + repr(data))
        
        response = {
            MessageDataType.UNKNOWN: lambda _x, _y: None,
            MessageDataType.HITS: self._send_hits,
            MessageDataType.TEXT: self._send_text,
            MessageDataType.CHOICE: self._send_choice,
            MessageDataType.OPEN_QUESTION: self._send_open_question,
            MessageDataType.FILE: self._send_file,
            MessageDataType.BUTTON: self._send_button
        }[data_type](user_id, data)
        if response is not None and 'error' in response:
            logging.error(str(response['error']))

    ### KZ 2021.03.22 added
    def make_hits_response(self, hits):
        return make_hits_response(hits) 
    ### KZ end

    ### KZ 2021.04.22 added
    def make_choice_response(self, *args, **kwargs):
        return make_choice_response(*args, **kwargs)
    ### KZ end

class MessageType(Enum):
    UNKNOWN = 0
    TEXT = 1
    META_DATA = 2
    GRID = 3


class MessageDataType(Enum):
    UNKNOWN = 0
    HITS = 1
    TEXT = 2
    CHOICE = 3
    OPEN_QUESTION = 4
    FILE = 5
    BUTTON = 6


def make_hits_response(hits):
    return MessageDataType.HITS, hits


def make_text_response(text):
    return MessageDataType.TEXT, text


def make_choice_response(text: str, choices: Union[set, dict, list], func,
                         asking_about: List[Union[str, Tuple[str, str]]] = None,
                         func_for_other_choice=None) -> Tuple:
    """
    Generates a choice response
    :param text: text to be shown to users
    :param choices: choices available to user
    :param func: function to process choice (if one of choices), it takes one parameter (user's choice if choices is set or
                val ue of user's choice in choices if choices is dict)
    :param func_for_other_choice: function to process choice (if other than choices)
    :param asking_about:
    :return:
    """
    return MessageDataType.CHOICE, {"text": text, "choices": choices,
                                    "func": func,
                                    "func_for_other_choice": func_for_other_choice,
                                    "asking_about": asking_about}


def make_open_question(question: str, asking_about: List[Union[str, Tuple[str, str]]] = None, func=None):
    return MessageDataType.OPEN_QUESTION, {"question": question, "asking_about": asking_about, "func": func}


def make_file_response(filename):
    return MessageDataType.FILE, filename


def make_button_response(text, buttons_data):
    return MessageDataType.BUTTON, {'text': text, 'buttons_data': buttons_data}
