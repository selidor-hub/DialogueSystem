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

import re
from random import choice
from string import ascii_lowercase

from communicators.base_communicator import make_open_question, make_choice_response
from nlg.literals import TooManyEmails, NotEnoughEmails, MustBeBothNameAndSurname, Confirm, NoPhones


def field_factory(convo_state, field_rule):
    return {
        "full_name": FullName,
        "email": Email,
        "phone": Phone,
    }.get(field_rule['field_kind_system_name'], Field)(convo_state, field_rule)


class Field:
    default_rule = None
    question_suffix = ' klienta'
        
    asking_about = None  ### KZ 2021.03.16 added

    def __init__(self, convo_state, field_rule=None):
        if field_rule is None:
            field_rule = self.default_rule
        self.type = field_rule['name']['pl']
        self.required = field_rule.get('is_required', 0)
        self.client_kind_id = field_rule.get('client_kind_id')
        self.field_kind_id = field_rule.get('field_kind_id')
        self.field_subkind_id = field_rule.get('field_subkind_id')
        self.field_rule_id = field_rule.get('id')
        self.value = None
        self.default = None
        self.asked = False
        self.error_msg = None

    def generate_message(self, question=None):
        default_is_not_None = all(self.default) if isinstance(self.default, list) else self.default is not None
        # logging.debug(str(not self.asked) + ' and ' + str(default_is_not_None))
        if not self.asked and default_is_not_None:
            logging.debug('self.type = ' + repr(self.type) + ', self.default = ' + repr(self.default ))
            text = "{}: {}. Potwierdź lub podaj inną wartość.".format(self.type, self.value_str(self.default))
            response = make_choice_response(text=text, choices=[Confirm],
                                            func=self.parse_default,
                                            func_for_other_choice=self.parse)
        else:
            question = self.error_msg or question or "{}{}?".format(self.type, self.question_suffix)
            logging.debug('question= ' + repr(question) + ', asking_about= ' + repr(self.asking_about) + ', func= ' + repr(self.parse))
            response = make_open_question(question=question, asking_about=self.asking_about, func=self.parse)

        self.asked = True
        self.error_msg = None
        return response

    def parse(self, content):
        self.value = content

    def parse_default(self, _):
        self.value = self.default

    def params(self, i):
        return 1, {
            'ReservationUniField[new{}][create]'.format(i): 1,
            'ReservationUniField[new{}][field_kind_id]'.format(i): self.field_kind_id,
            'ReservationUniField[new{}][field_rule_id]'.format(i): self.field_rule_id,
            'ReservationUniField[new{}][field_subkind_id]'.format(i): self.field_subkind_id,
            'ReservationUniField[new{}][value]'.format(i):	self.value
        }

    @staticmethod
    def new_hash(length=6):
        return ''.join(choice(ascii_lowercase) for _ in range(length))

    @staticmethod
    def value_str(value):
        # return value
        return str(value) # KZ 2021.03.17

    def __bool__(self):
        return self.asked and (self.value is not None or not self.required)

    def __str__(self):
        return '{}: {}'.format(self.type, self.value_str(self.value))

### KZ 2021.03.17
    def __repr__(self):
        return self.__str__()
### end KZ

class FullName(Field):
    omitted_words = ['dr', 'doktor', 'mgr', 'magister', 'pani', 'pan']
    omitted_chars = ['.']
    asking_about = ["patient"] # KZ 

    def __init__(self, convo_state, field_rule=None):
        self.convo_state = convo_state
        super().__init__(convo_state, field_rule)
        # self.default = [name for name in [convo_state.first_name, convo_state.second_name, convo_state.last_name] if name]
        self.default = [convo_state.first_name, convo_state.second_name, convo_state.last_name]
        logging.debug("self.default = " + repr(self.default))
        
    def params(self, i):
        id_hash = self.new_hash()
        return 3, {
            'ReservationUniField[new{}][create]'.format(i): 1,
            'ReservationUniField[new{}][field_kind_id]'.format(i): self.field_kind_id,
            'ReservationUniField[new{}][field_rule_id]'.format(i): self.field_rule_id,
            'ReservationUniField[new{}][field_subkind_id]'.format(i): self.field_subkind_id,
            'ReservationUniField[new{}][id_hash]'.format(i): id_hash,
            'ReservationUniField[new{}][is_container]'.format(i): 1,
            'ReservationUniField[new{}][value]'.format(i): ' '.join(self.value),

            'ReservationUniField[new{}][create]'.format(i+1): 1,
            'ReservationUniField[new{}][field_kind_id]'.format(i+1): 3,
            'ReservationUniField[new{}][id_hashes][0][column]'.format(i+1): 'container_id',
            'ReservationUniField[new{}][id_hashes][0][id_hash]'.format(i+1): id_hash,
            'ReservationUniField[new{}][value]'.format(i+1): ' '.join(self.value[:-1]),

            'ReservationUniField[new{}][create]'.format(i+2): 1,
            'ReservationUniField[new{}][field_kind_id]'.format(i+2): 4,
            'ReservationUniField[new{}][id_hashes][0][column]'.format(i+2): 'container_id',
            'ReservationUniField[new{}][id_hashes][0][id_hash]'.format(i+2): id_hash,
            'ReservationUniField[new{}][value]'.format(i+2): self.value[-1]
        }

    @classmethod
    def omit(cls, string):
        return string in cls.omitted_words or bool([c for c in cls.omitted_chars if c in string])

    def parse(self, content):
        logging.debug(repr(content))
        names = []
        if isinstance(content, str):
            content = content.split()
            # names = [s for s in content if not self.omit(s)]
            names = [s for s in content.split() if not self.omit(s)]
        elif isinstance(self.default, list):
            names += [name for name in [self.convo_state.first_name, self.convo_state.second_name, self.convo_state.last_name] if name]
        logging.debug("names = " + repr(names))
        if len(names) < 2:
            self.error_msg = MustBeBothNameAndSurname
        else:
            self.value = names

    @staticmethod
    def value_str(value):
        # return ' '.join(value)
        return ' '.join(value) if value else 'None' # KZ 2021.03.17

    def __bool__(self):
        return bool(self.value)


class Email(Field):
    default_rule = {'name': {'pl': 'Email'}}
    email_regex = re.compile(r'[\w\.-]+@[\w\.-]+\.\w+')
    question_suffix = ' kontaktowy'
    asking_about = ["email"] # KZ 

    def __init__(self, convo_state, field_rule=None, use_default=True):
        super().__init__(convo_state, field_rule)
        if use_default:
            self.default = convo_state.email
        
    def parse(self, content):
        self.value = content ### KZ 2021.12.10 tymczasowo dopóki ENIAM nie rozpoznaje adresów email
        return
        
        matched = self.email_regex.findall(content)
        if len(matched) == 1:
            self.value = matched[0]
        elif matched:
            self.error_msg = TooManyEmails
        else:
            self.error_msg = NotEnoughEmails


class Phone(Field):
    question_suffix = ' kontaktowy'
    # phone_regex = re.compile(r"(1[ \-\+]{0,3}|\+1[ -\+]{0,3}|\+1|\+)?"
                             # r"((\(\+?1-[2-9][0-9]{1,2}\))|"
                             # r"(\(\+?[2-8][0-9][0-9]\))|"
                             # r"(\(\+?[1-9][0-9]\))|"
                             # r"(\(\+?[17]\))|"
                             # r"(\([2-9][2-9]\))|"
                             # r"([ \-\.]{0,3}[0-9]{2,4}))?"
                             # r"([ \-\.][0-9])?"
                             # r"([ \-\.]{0,3}[0-9]{2,4}){2,3}")
    # asking_about = ['quantity'] # KZ TODO powinno być phone_number, jak ENIAM obsłuży numery telefonów
    asking_about = ["telephone"] 

    def parse(self, content):
        logging.debug('content= ' + repr(content), stack_info=False)

        ### KZ 2021.04.15 added 
        # if isinstance(content, dict):
            # if 'and' in content:
                # content = ''.join(str(elem) for elem in list(content['and']))
                # if content:
                    # self.value = content
                # else:
                    # self.error_msg = NoPhones
                # return
        ### KZ 2021.04.15 end

        # matched = self.phone_regex.search(content)
        # if matched:
            # self.value = matched.group()
        if content:
            if content in ["forgotten", "none"]:
                self.value = "brak"
            elif content == "self-correction":
                pass
            else:
                self.value = content # KZ od PHONE_ENIAMa przychodzi prawidłowy nr telefonu
        else:
            self.error_msg = NoPhones

