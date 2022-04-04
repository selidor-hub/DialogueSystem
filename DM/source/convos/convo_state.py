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

import requests
from urllib3.exceptions import HTTPError
from nested_lookup import nested_lookup
from benedict import benedict
import time
import copy
import threading

from variables import ENIAM_DEBUG
from commands.commands_manager import apply_command
from communicators.base_communicator import MessageType, make_text_response, MessageDataType
from convos.convo_aims import KnowAction, KnowClientData
from utils.desambiguation import generate_question
# from utils.message_types import process_text_message, process_meta_data_message, process_simply_text_message
from utils.message_types import process_text_message_by_eniam, process_meta_data_message
from utils.page_knowledge import get_knowledge_about_page, get_communicator_token_for_page
from utils.parameters import Service
# from interfaces.eniam import ground_eniam, ground_it, ask_category_grounder
from interfaces.eniam import ground_eniam, ask_category_grounder, get_cat_grounder_resp_str
from grounders.TimeSegmentSequence import ask_time_grounder
from datetime import datetime as dt

import logging
from logging import DEBUG as logging_DEBUG
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")


class ConvoState:
    _parameters = ['time', 'action', 'organisation', 'doer', 'patient', 'service', 'location', 'price', 'rating']

    def __init__(self, page_id, user_id, communicator_cls, aim=None):
        self.lock = threading.Lock()
        self.page_id = page_id
        self.id = user_id
        
        self.communicator = communicator_cls(get_communicator_token_for_page(page_id), convo_state=self) ### KZ 2021.03.22 added
        logging.debug("self.communicator = " + repr(self.communicator))
        self.knowledge = {
            'parameters': {
                **{par: None for par in self._parameters},
                'organisation': get_knowledge_about_page(page_id)
            },
            'variables': {}
        }
        self.params = self.knowledge['parameters']  # alias
        # assert self.params['organisation'].service_base, 'No service_base'
        # logging.debug("type(self.params['organisation']) = " + repr(type(self.params['organisation'])))
        # logging.debug("type(self.params['organisation'].service_base) = " + repr(type(self.params['organisation'].service_base)))
        self.demo = self.params['organisation'].mode == 'demo'
        user_info = self.communicator.get_user_info(self.id)
        logging.debug("user_info = " + repr(user_info))
        self.first_name = user_info.get("first_name", "")
        self.second_name = ""
        self.last_name = user_info.get("last_name", "")
        self.gender = user_info.get("gender", "unknown")
        if self.gender == "mężczyzna":
            self.gender = "male"
        if self.gender == "kobieta":
            self.gender = "female"
        if self.gender not in ["male", "female"]:
            self.gender = "unknown"
        self.email = user_info.get("email")
        self.sent_messages = []
        if aim is None:
            self.aim = KnowAction(self)
        self.extend = False
        self.wait_for_response = True
        self.withs = None
        self.error_msg = None
        self.disabled = False
        self.message_to_ground = None
        self.hello_sent = False

        self.last_tree_choices = None
        self.key_for_last_tree_choices = None
        self.counter_for_choice_not_understood = 0
        
        self.ENIAM_DEBUG = ENIAM_DEBUG
        # self.ENIAM_DEBUG = False
        logging.debug("self.ENIAM_DEBUG = " + str(bool(self.ENIAM_DEBUG)))
        self.marked_for_deletion = False


    def add_to_knowledge(self, data):
        try:
            horizon = self.params['time'].tss_dict.get("horizon", None) ### added key "horizon" for compatibility with TIME_GROUNDER
        except:
            horizon = None
        
        if data:
            logging.debug('Adding to knowledge: ' + repr(data))
            for par in self._parameters:
                if self.params.get(par):
                    # logging.debug("MERGING data.get(par) = " + str(data.get(par)) + " AND self.knowledge.get('previous_proposed_hits') = " + str(self.knowledge.get('previous_proposed_hits')))
                    self.params[par].merge(data.get(par), self.knowledge.get('previous_proposed_hits'))
                else:
                    self.params[par] = data.get(par)
            logging.debug("data.get('service') = " + str(data.get('service')))
            logging.debug("self.params['service'] = " + str(self.params['service']))
            if data.get('service'): 
                logging.debug("data.get('service').eniam_specs = " + repr(data.get('service').eniam_specs))
                if data['service'].eniam_specs.get("service"):
                    if self.params['service'].eniam_specs.get("service"):
                        try:
                            self.params['service'].eniam_specs["service"].update(data['service'].eniam_specs.get("service", {}))
                        except:
                            pass
                    else:
                        self.params['service'].eniam_specs["service"] = data['service'].eniam_specs.get("service", {})

                if data['service'].eniam_specs.get("patient"):
                    unrecognized = ["", "not-recognized"]
                    
                    logging.debug('data["service"].eniam_specs["patient"] = ' + repr(data["service"].eniam_specs["patient"]))
                    first_name =  data['service'].eniam_specs["patient"].pop("first-name", "")
                    logging.debug('data["service"].eniam_specs["patient"] = ' + repr(data["service"].eniam_specs["patient"]))
                    if first_name not in unrecognized:
                        if first_name and "with" in first_name:
                            self.first_name = " ".join(name for name in first_name["with"])
                        else:
                            self.first_name = first_name

                    second_name = data['service'].eniam_specs["patient"].pop("second-name", "")
                    if second_name not in unrecognized:
                        if second_name and "with" in second_name and first_name not in unrecognized:
                            self.second_name = " ".join(name for name in second_name["with"])
                        else:
                            self.second_name = second_name

                    last_name =   data['service'].eniam_specs["patient"].pop("last-name", "")
                    if last_name not in unrecognized:
                        if last_name and "with" in last_name:
                            self.last_name = " ".join(name for name in last_name["with"])
                        else:
                            self.last_name = last_name
                    if "patient" not in self.params['service'].eniam_specs:
                        self.params['service'].eniam_specs["patient"] = {}
                    self.params['service'].eniam_specs["patient"].update(data['service'].eniam_specs.get("patient"))

        if horizon: ### added key "horizon" for compatibility with TIME_GROUNDER
            self.params['time'].tss_dict["horizon"] = horizon
        logging.info("self.knowledge['parameters'] = " + repr(self.knowledge['parameters']))
        
    def knowledge_to_eniam(self):
        dct={}
        if 'service' in self.params and self.params['service']:
            dct = self.params['service'].eniam_specs
        return dct                

    def reset(self, _=None):
        self.__init__(self.page_id, self.id, type(self.communicator))

    def list_services(self, _=None):
        msg = self.params['organisation'].service_base.generate_list_msg(self)
        # msg = self.aim.generate_message()
        logging.debug('generated: ' + repr(msg), stack_info=False)
        self.send_messages(msg)
        self.wait_for_response = True

    def on_service_chosen(self, service_id):
        logging.debug('service_id= ' + service_id)
        # logging.debug('service_base.entries= ' + repr(self.params['organisation'].service_base.entries))
        service_entry = self.params['organisation'].service_base.find_by_id(service_id)
        if service_entry:
            self.params['service'] = Service.from_entry(service_entry)

    def on_tree_chosen(self, key):
        logging.debug("self.aim = " + str(self.aim) + ", key = " + str(key))
        self.key_for_last_tree_choices = key

    ### KZ 2021.03.22 added 
    def on_hit_chosen(self, hit_id):
        logging.debug('hit_id= ' + str(hit_id))
        self.knowledge['chosen_hit'] = [h for h in self.knowledge['proposed_hits'] if str(h.hit_id) == str(hit_id)][0] # powinien być dokładnie 1, czyli ...[0]
        logging.debug('self.knowledge["chosen_hit"]= ' + str(self.knowledge['chosen_hit']))
    ### KZ end

    def parse_choice(self, data, msg_type, content):
        logging.debug('data= ' + repr(data) + ', msg_type= ' + repr(msg_type) + ', content= ' + repr(content))
        logging.debug('self.withs= ' + repr(self.withs))
        # if self.withs and data["asking_about"]:
        if data["asking_about"]:
            return self.parse_open_question(data, msg_type, content)

        lookup_res = nested_lookup("text", self.parsed)
        if len(lookup_res) == 1 and type(lookup_res[0]) == str:
            content = lookup_res[0]
        else:
            content = ""
        logging.debug('content= ' + repr(content))

        if "func" in data and "choices" in data and content:
            if msg_type == MessageType.TEXT and data["func"] is not None:
                content_in_choices = False
                for key in data["choices"]:
                    if content.lower() == key.lower()[0:len(content)]:
                    ## if content.lower() in key.lower():
                        content = key
                        content_in_choices = True
                        break;
                logging.debug('content= ' + repr(content))
                if content_in_choices:
                    if isinstance(data["choices"], (set, list)):
                        data["func"](content)
                    elif isinstance(data["choices"], dict):
                        data["func"](data["choices"][content])
                    return True
        if data["func_for_other_choice"] is not None:
            logging.debug('data["func_for_other_choice"] is not None')
            data["func_for_other_choice"](content)
            return True
        else:
            logging.debug('data["func_for_other_choice"] is None')
        return False

    def parse_open_question(self, data, msg_type, content):
        logging.debug('data= ' + repr(data) + ', msg_type= ' + repr(msg_type) + ', content= ' + repr(content))
        logging.debug('self.key_for_last_tree_choices = ' + repr(self.key_for_last_tree_choices))
        logging.debug('self.last_tree_choices = ' + repr(self.last_tree_choices))


        content_orig = copy.deepcopy(content)
        
        if isinstance(content, dict) and "time" in content:
            self.withs = None
        if self.withs:
            content = self.withs[0] # content is a list of dictionaries now
            class GetOutOfLoop( Exception ):
                pass
            try:
                for asking_about in data["asking_about"]:
                    for d in content:
                        try:
                            for key in d.keys():
                                if asking_about == key:
                                    content = d
                                    raise GetOutOfLoop
                        except GetOutOfLoop:
                            raise GetOutOfLoop
                        except:
                            if asking_about == d: # d jest str (kluczem w słowniku content)
                                content = d
                                raise GetOutOfLoop
                            
            except GetOutOfLoop:
                pass
        logging.debug('content= ' + repr(content))

        key_for_data_choices = self.key_for_last_tree_choices
        func_arg=None
        data_asking_about_dict = {}
        if not key_for_data_choices and isinstance(content, (dict, list)):
            lookup_res = None
            i = 0
            while not lookup_res and i < len(data["asking_about"]):
                lookup_res = nested_lookup(data["asking_about"][i], content)
                if lookup_res:
                    data_asking_about_dict = {data["asking_about"][i]: lookup_res[0]}
                    break
                i += 1
            logging.debug("lookup_res = " + repr(lookup_res))
            
            # if not lookup_res and "quantity" not in data["asking_about"]:
                # lookup_res = nested_lookup("quantity", content) # defaultowo poszukujemy wyboru liczbowego
                # logging.debug("lookup_res = " + repr(lookup_res))
                
            if lookup_res and not isinstance(lookup_res[0], (dict, list)):
                    key_for_data_choices = lookup_res[0]
                    logging.debug('key_for_data_choices= ' + str(key_for_data_choices) + ', type= ' + str(type(key_for_data_choices)))

            if "choices" in data and not key_for_data_choices and not func_arg:
                if isinstance(content, dict):
                    knowledge_dct = content 
                    if self.last_tree_choices:
                        query_dct = {"categories": list(self.last_tree_choices.keys()),
                                     "query": knowledge_dct}
                        logging.debug("query_dct = " + repr(query_dct))
                        res = ask_category_grounder(query_dct)

                        if self.ENIAM_DEBUG:
                            r = make_text_response(get_cat_grounder_resp_str())
                            self._send_to_communicator(r[0], r[1], debug=True)

                        if self.last_tree_choices and res in self.last_tree_choices:
                            key_for_data_choices = res  ### key_for_data_choices to nazwa kategorii
                            self.counter_for_choice_not_understood = 0
                        elif res:
                            choice_nb_dct = {v.name: k for k,v in data["choices"].items()}
                            key_for_data_choices = choice_nb_dct[res]  ### key_for_data_choices is int
                        else:
                            self.counter_for_choice_not_understood += 1
                    else:
                        if self.knowledge.get("proposed_hits"):
                            query_dct = {"categories": [hit.date.strftime("%Y-%m-%d %H:%M:%S") for hit in self.knowledge['proposed_hits']],
                                         "now": dt.now().strftime("%Y-%m-%d %H:%M:%S"),
                                         "query": knowledge_dct}
                            logging.debug("query_dct = " + repr(query_dct))
                            res = ask_time_grounder(query_dct)
                            if "categories" in res:
                                if res["categories"]:
                                    datetime_chosen = dt.strptime(res["categories"][0], "%Y-%m-%d %H:%M:%S")
                                    for hit in self.knowledge['proposed_hits']:
                                        if hit.date == datetime_chosen:
                                            func_arg = hit.hit_id
                                            break
        logging.debug('key_for_data_choices= ' + str(key_for_data_choices) + ', type= ' + str(type(key_for_data_choices)))
        logging.debug('func_arg = ' + str(func_arg) + ', type= ' + str(type(func_arg)))
        if data["func"] and func_arg is None:
            if not isinstance(key_for_data_choices, dict):
                if key_for_data_choices:
                    key_for_data_choices = str(key_for_data_choices)
                    logging.debug('key_for_data_choices= ' + repr(key_for_data_choices) + ', type= ' + repr(type(key_for_data_choices)))
                    if "choices" in data:
                        if key_for_data_choices in data["choices"]: ### KZ wybór liczbowy
                            func_arg = data["choices"][key_for_data_choices]
                        else:
                            key_for_data_choices1 = key_for_data_choices + ", "
                            if key_for_data_choices1 in data["choices"]: ### KZ wybór liczbowy
                                func_arg = data["choices"][key_for_data_choices1]
                            else:
                                key_for_data_choices2 = key_for_data_choices + "."
                                if key_for_data_choices2 in data["choices"]: ### KZ wybór liczbowy
                                    func_arg = data["choices"][key_for_data_choices2]
                                elif key_for_data_choices in data["choices"].values(): ### KZ wybór słowny
                                    func_arg = key_for_data_choices
                                else:
                                    self.errfunc_argor_msg = 'Nie mogę wybrać ' + key_for_data_choices
                    else: #KZ 2021.03.25  było OPEN_QUESTION bez żadnych propozycji "choices"
                        func_arg = key_for_data_choices
                elif not isinstance(content, (dict, list)):
                    func_arg = content
                    logging.debug("func_arg = " + repr(func_arg) + ", type(func_arg) = " + str(type(func_arg)))
            elif key_for_data_choices: # key_for_data_choices is dict
                logging.warning(repr(key_for_data_choices) + ' is dict')
                func_arg = key_for_data_choices
            else:
                data["func"]()
        logging.debug("func_arg = " + repr(func_arg) + ", type(func_arg) = " + str(type(func_arg)))
        if data["func"] and func_arg is not None:
            logging.debug('data["func"] = ' + repr(data["func"]))
            data["func"](func_arg)
            self.withs = None
        elif lookup_res and not lookup_res[0]:
            data["func"](lookup_res[0])
            self.withs = None
        else:
            if lookup_res and lookup_res[0] and isinstance(lookup_res[0], (dict, list)):
                content = data_asking_about_dict
            else:
                content = content_orig
            logging.debug('self.any_with = ' + repr(self.any_with))
            logging.debug('will parse_message(msg_type= ' + repr(msg_type) + ', content= ' + repr(content) + ', data["asking_about"]= ' + repr(data["asking_about"]) + ', simple=True)')
            self.parse_message(msg_type, content, data["asking_about"], simple=True)
        return True

    def parse_first_message(self, message):
        # TODO: sent_messages powinny być zdefiniowane na podstawie zwrotek "is_echo"
        # (komunikacja siecowa może rozwalić kolejność)
        if not self.sent_messages:
            logging.info('return False')
            return False
        data_type, data = self.sent_messages[-1]
        f = {
            MessageDataType.CHOICE: self.parse_choice,
            MessageDataType.OPEN_QUESTION: self.parse_open_question
        }.get(data_type, None)
        if f is None:
            logging.info('return False')
            return False
        else:
            msg_type, content = message
            logging.info(repr(data_type) + ', ' + repr(data) + '; ' + repr(message))
            res = f(data, msg_type, content)
            logging.debug(repr(res))
            return res

    def parse_message(self, msg_type, content, context=None, choices=None, simple=False):
        self.aim.preprocess_message(msg_type, content)
        logging.debug('msg_type= ' + repr(msg_type) + ', content= ' + repr(content) + ', context= ' + repr(context) + \
                      ', choices= ' + repr(choices) + ' , simple= ' + repr(simple))
        context = context if context is not None else []
        choices = choices if choices is not None else []

        ### KZ 2021.12.10 skrót tymczasowy, dopóki ENIAM nie rozpoznaje imion i nazwisk "patient"
        def process_text_message_by_eniam_1(self, content, context, choices, simple, msg_type):
            data_type, data = self.sent_messages[-1]
            if  type(self.aim) == KnowClientData \
                and "asking_about" in data \
                and "email" in data["asking_about"] \
                and not "choices" in data \
                and "func" in data \
                and data["func"] \
                and type(self.request_text) == str:
                    logging.debug('data["func"] = ' + repr(data["func"]))
                    logging.debug('self.request_text = ' + repr(self.request_text))
                    data["func"](self.request_text)
                    return True
            else:
                if not context and data_type in [MessageDataType.CHOICE, MessageDataType.OPEN_QUESTION] \
                               and "asking_about" in data and data["asking_about"]:
                    context = data["asking_about"]
                return process_text_message_by_eniam(self, content, context, choices, simple, msg_type)
        ### KZ end

        {
            MessageType.UNKNOWN: lambda _1, _2, _3, _4: None,
            # MessageType.TEXT: process_simply_text_message if simple else process_text_message,
            MessageType.TEXT: process_text_message_by_eniam_1, ### KZ przywrócić process_text_message_by_eniam po usunięciu skrótu process_text_message_by_eniam_1
            MessageType.GRID: process_text_message_by_eniam_1, ### KZ przywrócić process_text_message_by_eniam po usunięciu skrótu process_text_message_by_eniam_1
            MessageType.META_DATA: process_meta_data_message
        # }[msg_type](self, content, context, choices)
        }[msg_type](self, content, context, choices, simple, msg_type)

    def process_messages(self, messages):
        self.error_msg = None
        for msg_type, content in messages:
            self.parse_message(msg_type, content)

    def resolve_desambiguation(self, content):
        logging.debug('content = ' + repr(content))
        logging.debug('self._withs = ' + repr(self._withs))
        # self.parse_message(self.withs[1], self.withs[2], self.withs[3],
                           # [(self.withs[0], content), *self.withs[4]], simple=True)
        self.parse_message(self._withs[1], self._withs[2], self._withs[3],
                           [(self._withs[0], content), *self._withs[4]], simple=True)
        self._withs = None
        return True

    def generate_messages(self):
        logging.debug('self.withs= ' + repr(self.withs))
        if self.error_msg is not None:
            logging.debug('self.error_msg= ' + repr(self.error_msg))
            return make_text_response(self.error_msg)
        elif self.withs is not None:
            return generate_question(self)
        else:
            logging.debug('else')
            return self.aim.generate_message()

    def _send_to_communicator(self, data_type, data, debug=False):
        # logging.debug('sending to CLIENT: ' + repr(data_type) + ', ' + repr(data), stack_info=False)
        i=0
        while True:
            i += 1
            try:
                self.communicator.send(self.id, data_type, data, debug=debug)
            except requests.exceptions.ConnectionError as e:
                if i <= 3:
                    # logging.debug(str(e) + ', retrying...' + str(i))
                    time.sleep(0.05)
                    continue
                else:
                    logging.error(e)
                    raise(e)
            except HTTPError as e:
                logging.error(e)
                raise(e)
            except Exception as e:
                # logging.exception(e)
                logging.error(e)
                raise(e)
            break

    def send_message(self, data_type, data):
        if data_type is None:
            logging.warning('NOT send_message: data_type is None, data= ', repr(data))
            return
        else:
            self.aim.next_if_fulfilled()
            ### KZ 2021.02.23
            # logging.debug('will sent_messages.append: ' + repr((data_type, data)))
            # self.sent_messages.append((data_type, data))
            if not self.error_msg and (data_type, data) != make_text_response(self.error_msg):
                logging.debug('will sent_messages.append: ' + repr((data_type, data)))
                self.sent_messages.append((data_type, data))
            else:
                self.error_msg = None
            ### KZ end
            # logging.debug('\n'.join(repr(msg) for msg in self.sent_messages))
            self._send_to_communicator(data_type, data)

    def step_back(self):
        self.last_tree_choices = None
        return
        # if self.sent_messages[-2]:
            # msg_type, msg_content = self.sent_messages[-2]
            # self.send_message(msg_type, msg_content)
        # else:
            # self.reset()

    def send_messages(self, messages):
        # logging.debug(repr(messages) + ', type: ' + str(type(messages)))
        if not isinstance(messages, list):
            if isinstance(messages, str):
                msg = make_text_response(messages)
            else: # messages already is 2-tuple
                msg = messages
            messages = [msg]

        for data_type, data in messages:
            self.send_message(data_type, data)
        return
            
    def apply_commands(self):
        while apply_command(self):
            pass

    def reply(self, messages):
        with self.lock:
            logging.info('Received from CLIENT: ' + repr(messages))
            self.hello_sent = False
            if self.disabled:
                if any(content[0] == 'REQUEST_BOT' for msg_type, content in messages if msg_type == MessageType.META_DATA):
                    self.send_message(self.sent_messages[-3][0], self.sent_messages[-3][1])
                    # third message from the end is the one sent before requesting human
                    self.disabled = False
                    return
                else:
                    return
            self.wait_for_response = False
            logging.debug("will apply_commands()   execute commands not based on messages")
            self.apply_commands()  # execute commands not based on messages
            logging.debug("will process_messages(messages)  change of knowledge and aims, execute commands if found")
            self.process_messages(messages)   # change of knowledge and aims, execute commands if found
            if self.disabled:
                return
            logging.debug("will apply_commands()   execute commands not based on messages")
            self.apply_commands()  # execute commands not based on messages
            self.aim.next_if_fulfilled()
            while not self.wait_for_response:
                logging.debug("will apply_command")
                if not apply_command(self):
                    self.wait_for_response = True
                    messages = self.generate_messages() 
                    logging.debug(repr(messages))
                    self.send_messages(messages)

                    # if logging.isEnabledFor(logging_DEBUG):
                        # services_str = ""
                        # if 'service' in self.knowledge['parameters'] and self.knowledge['parameters']['service']:
                            # chosen = self.knowledge['parameters']['service'].choose_n_best()
                            # services_str = '\n'.join(["{} ({})".format(s.name, g) for (g, s) in chosen])
                        # if services_str:
                            # logging.debug("self.knowledge['parameters']['service'].choose_n_best()= " + services_str)
                # logging.debug("Aim: " + self.aim.__str__())
