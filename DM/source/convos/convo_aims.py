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
from collections import OrderedDict
from anytree import RenderTree
from datetime import datetime as dt, timedelta as dl

from communicators.base_communicator import make_open_question, make_text_response, make_file_response, MessageType, MessageDataType

from interfaces import reservis
from nlg.literals import HitChoiceRegistered, AskIfConfirmation, WantConfirmationOnMail, WantConfirmationAsFile, \
    Confirm, NotConfirm, ConfirmationOfCorrectness, ReservationFailure, No, Yes, AskIfSendToThisMail, \
    AskForAnotherMail, NoServices, Reset, ConfirmationDemo, Resign, ChangeData, ByeFailure, \
    DayOfWeek
from nlg.replies import what_service, what_service_business, what_service_category, which_service, \
    hit_choice_not_allowed_msg, offer_limiting, show_services
from convos.convo_decisions import enough_knowledge_to_generate_hits, respond_to_no_hits, respond_to_too_many_hits, \
    respond_to_not_enough_knowledge
from interfaces.reservis import reservis_hits, do_temporary_reservation, do_reservation, get_confirmation_file
from nlg.replies import end_conversation
from utils.fields import Email
from utils.service_base import ServiceEntry, ServiceBase

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

class BaseConvoAim(metaclass=ABCMeta):
    def __init__(self, convo_state):
        self.convo_state = convo_state
        self.make_choice_response = convo_state.communicator.make_choice_response
        self.make_hits_response = convo_state.communicator.make_hits_response

    def preprocess_message(self, msg_type, content):
        pass

    def process_message(self, msg_type, content):
        return False

    @abstractmethod
    def generate_message(self):
        pass

    @abstractmethod
    def next_aim(self):
        pass

    @abstractmethod
    def fulfilled(self):
        pass

    def next_if_fulfilled(self):
        if self.fulfilled():
            logging.debug('Aim ' + self.__str__() + ' FULFILLED, will change_aim')
            self.change_aim(self.next_aim())
            logging.debug('Current Aim: ' + self.convo_state.aim.__str__())
        else:
            # logging.debug('FALSE. no change_aim', stack_info=True)
            logging.debug('Aim ' + self.convo_state.aim.__str__() + ' NOT FULFILLED')


    def change_aim(self, aim_class):
        self.convo_state.aim = aim_class(self.convo_state)
        self.convo_state.aim.next_if_fulfilled()

    def __str__(self):
        return self.__class__.__name__


class CustomNameAim(BaseConvoAim):
    def __init__(self, convo_state, aim_string):
        super().__init__(convo_state)
        self.name = aim_string

    def generate_message(self):
        pass

    def next_aim(self):
        return None

    def fulfilled(self):
        return False

    def __str__(self):
        return self.name


class KnowAction(BaseConvoAim):
    def generate_message(self):
        #  TODO
        return make_text_response("KnowAction")

    def next_aim(self):
        return KnowService

    def fulfilled(self):
        return True  # TODO


class KnowService(BaseConvoAim):
    asked_for_keyword = False
    asked_for_patient = False
    asked_for_business = False
    asked_for_category = False

    # def __init__(self, *args, **kwargs):
        # super().__init__(*args, **kwargs)
        # self.convo_state.last_tree_choices = None
        # self.convo_state.key_for_last_tree_choices = None

    def _get_service(self):
        return self.convo_state.params.get('service')

    def select_first_proposed(self):
        if self.convo_state.sent_messages:
            try:
                logging.debug(repr(self.convo_state.sent_messages[-1]))
                data_type, data = self.convo_state.sent_messages[-1]
                logging.debug(repr(data))
                if data_type == MessageDataType.CHOICE:
                    if isinstance(data['choices'], dict):
                        logging.debug(list(data['choices'].items()))
                        logging.debug(list(data['choices'].items())[0])
                        label, service_id = list(data['choices'].items())[0]
                        logging.debug(service_id)
                        service_entry = None
                        if service_id == Reset and data["func"]:
                            data["func"]()
                            return
                        elif type(service_id) == ServiceEntry:
                            service_entry = service_id
                        elif type(service_id) == str:
                            service_entry = self.convo_state.params['organisation'].service_base.find_by_global_id(service_id)
                        else:
                            service_entry = self.convo_state.params['organisation'].service_base.find_by_global_name(service_id)
                        assert type(service_entry) == ServiceEntry, "Service entry not found for: " + str(service_id)
                        logging.debug("self.convo_state.params['organisation'].service_base.find_by_global_name(" + str(service_id) + ") = " + str(service_entry))
                        data["func"](service_entry)
                    elif isinstance(data['choices'], list) and data['choices']:
                        logging.debug("data['choices']= " + str(data['choices']))
                        data["func"]()
                    self.convo_state.withs = None
                    self.convo_state.last_tree_choices = None
                    self.convo_state.key_for_last_tree_choices = None
                    self.convo_state.counter_for_choice_not_understood = 0
            except Exception as e:
                # logging.error('cannot select')
                logging.error(e)
                raise e
        
    def generate_list_of_services(self):
        ret = show_services(what_service(self.convo_state), self.convo_state)
        service_base = self.convo_state.params['organisation'].service_base
        initial_entries = service_base.initial_entries
        logging.debug("len(service_base.entries) = " + str(len(service_base.entries)))
        if len(service_base.entries) == 0:
            service_base = ServiceBase(initial_entries)
        logging.info(repr(ret))
        return ret

    def generate_message(self):
        service = self._get_service()
        logging.debug("self.convo_state.last_tree_choices = " + repr(self.convo_state.last_tree_choices))
        logging.debug("self.convo_state.key_for_last_tree_choices = " + repr(self.convo_state.key_for_last_tree_choices))
        # logging.debug("self.convo_state.last_tree_choices[self.convo_state.key_for_last_tree_choices] = " + repr(self.convo_state.last_tree_choices[self.convo_state.key_for_last_tree_choices]))
        if self.convo_state.last_tree_choices and self.convo_state.key_for_last_tree_choices in self.convo_state.last_tree_choices:
            tree = self.convo_state.last_tree_choices[self.convo_state.key_for_last_tree_choices]
            # logging.debug('tree =\n' + str(RenderTree(tree)))
            # logging.debug('tree.leaves = ' + repr(tree.leaves))
            best = [self.convo_state.params['organisation'].service_base.find_by_global_id(leaf.id) for leaf in tree.leaves if leaf.is_in_service_base]
            best = [entry for entry in best if entry is not None]
            # logging.debug("best = " + repr(best))
            logging.debug("len(best) = " + repr(len(best)))
            
            self.convo_state.last_tree_choices = None
            self.convo_state.key_for_last_tree_choices = None
            self.convo_state.counter_for_choice_not_understood = 0
        else:
            # service = self._get_service() ### KZ przeniesione na początek metody
            logging.debug("service = " + repr(service))
            logging.debug("self.asked_for_keyword = " + repr(self.asked_for_keyword))
            # if service is None or (not service.description['keywords'] and not self.asked_for_keyword):
            if service is None:
                logging.debug(str(service is None or (not service.description['keywords'] and not self.asked_for_keyword)))
                self.asked_for_keyword = True
                # return show_services(what_service(self.convo_state), self.convo_state)
                return self.generate_list_of_services()
            # elif (service is None or not service.description['patient_types']) and not self.asked_for_patient:
            #     self.asked_for_patient = True
            #     return make_text_response(ServiceForWhom)
            else:
                # best = best_division(self.divisions_dict)
                best = service.choose_outstanding()
        businesses = {s.business for s in best}
        logging.debug("businesses = " + repr(businesses))
        if len(businesses) > 1 and not self.asked_for_business:
            self.asked_for_business = True
            return self.make_choice_response(what_service_business(self.convo_state), businesses, func=service.set_business if service else None)
        else:
            categories = {s.category for s in best}
            logging.debug("categories = " + repr(categories))
            if len(categories) > 1 and not self.asked_for_category:
                self.asked_for_category = True
                return self.make_choice_response(what_service_category(self.convo_state), categories,
                                            service.set_category)
            else:
                # services = {s.group_representative.name: s.group_id for s in best}
                services = {s.group_representative.name: s for s in best}
                # logging.debug("services = " + repr(services))
                logging.debug("len(services) = " + str(len(services)))
                if services:
                    return self.make_choice_response(which_service(self.convo_state), services, func=service.set_group_id if service else None)
                else:
                    logging.debug("return self.make_choice_response(NoServices, [Reset], None)")
                    # return self.make_choice_response(NoServices, [Reset], None)
                    return self.make_choice_response(NoServices, [Reset], self.convo_state.reset)



    def next_aim(self):
        return HaveVisualizableHits

    def fulfilled(self):
        service = self._get_service()
        return bool(service and service.is_ready_to_generate_hits())


class HaveVisualizableHits(BaseConvoAim):
    def __init__(self, convo_state):
        super().__init__(convo_state)
        if 'chosen_hit' in self.convo_state.knowledge:
            del self.convo_state.knowledge['chosen_hit']
        if 'proposed_hits' in self.convo_state.knowledge:
            self.convo_state.knowledge['previous_proposed_hits'] = self.convo_state.knowledge['proposed_hits']
            del self.convo_state.knowledge['proposed_hits']
        self.daytime_asked = False

    def generate_message(self):
        if enough_knowledge_to_generate_hits(self.convo_state):
            logging.debug('enough_knowledge_to_generate_hits')
            hits = reservis_hits(self.convo_state.params).best_hits()
            # logging.debug('hits= ' + repr(hits))
            logging.debug('NUMBER best_hits= ' + str(len(hits)))

            if len(hits) > self.convo_state.communicator.MAX_VISUALIZABLE_HITS:
                today = dt.now().date()
                weekday_list = []
                days = []
                dates = []
                tss_horizon = self.convo_state.knowledge["parameters"]["time"].tss_dict.get("horizon", None)
                for hit in hits:
                    date = hit.date.date()
                    if tss_horizon and (date - today).days > tss_horizon:
                        break
                    day = hit.day()
                    if day not in days:
                        days.append(day)
                        dates.append(date)
                    weekday_name = hit.weekday_name()
                    if weekday_name not in weekday_list:
                        if len(weekday_list) < len(DayOfWeek):
                            weekday_list.append(weekday_name)
                        if len(weekday_list) == len(DayOfWeek):
                            weekday_list = [" "] ### nie proponuj listy dni tygodnia, jeśli są dostępne wszystkie
                        
                if len(weekday_list) == 1 and weekday_list[0] in DayOfWeek.values():
                    if len(days) == 1:
                        if not self.daytime_asked:
                            self.daytime_asked = True
                            return [make_open_question(question="Jaka godzina lub pora dnia najbardziej Ci odpowiada?", asking_about=["time"])]
                    else:
                        days = days[:self.convo_state.communicator.QUICK_REPLIES_LIMIT]
                        dates = dates[:self.convo_state.communicator.QUICK_REPLIES_LIMIT]
                        # logging.debug("dates = " + repr(dates))
                        # logging.debug("days = " + repr(days))
                        horizon = (dates[-1] - today).days
                        logging.debug("horizon = " + str(horizon))
                        self.convo_state.knowledge["parameters"]["time"].tss_dict["horizon"] = \
                            min(horizon, self.convo_state.knowledge["parameters"]["time"].tss_dict.get("horizon", 365))
                        logging.debug('convo_state...tss_dict["horizon"] = ' + str(self.convo_state.knowledge["parameters"]["time"].tss_dict["horizon"]))
                        return [self.make_choice_response(msg="Która data najbardziej Ci odpowiada?", choices=days, \
                                func=None, asking_about=["time"])]
                else:
                    return [self.make_choice_response(msg="Jaki dzień tygodnia najbardziej Ci odpowiada?", choices=weekday_list, \
                            func=None, asking_about=["time"])]

            ### KZ 2021.03.22
            if not hits:
                self.convo_state.extend = True
                return respond_to_no_hits(self.convo_state)
            else:
                msg_type, msg_data = self.make_hits_response(hits)
                messages = [(msg_type, msg_data)]

                # if not self.convo_state.communicator.is_visualizable(msg_type, msg_data):
                    # self.convo_state.extend = False
                    # limit_msg = respond_to_too_many_hits(hits, self.convo_state)
                    # logging.debug('limit_msg= ' + str(limit_msg))
                    # if limit_msg is not None:
                        # messages = [(msg_type, msg_data),
                                    # make_text_response(offer_limiting(self.convo_state)), limit_msg]
            ### KZ end
            
                self.convo_state.knowledge['proposed_hits'] = hits
                logging.debug("NUMBER self.convo_state.knowledge['proposed_hits']= " + str(len(self.convo_state.knowledge['proposed_hits'])))
                return messages
        else:
            logging.debug('NOT enough_knowledge_to_generate_hits')
            return respond_to_not_enough_knowledge(self.convo_state)

    def next_aim(self):
        return KnowChoice

    def fulfilled(self):
        return self.convo_state.knowledge.get('proposed_hits')


class KnowChoice(BaseConvoAim):
    allowed = None
    responded = False

    # def preprocess_message(self, msg_type, content):
        # KZ 2020.08.24
        # if msg_type == MessageType.TEXT:
            # if content.lower() in 'tak ok okej zgoda zgadzam się biore biorę wybierz wybieram rezerwuj rezerwuje rezerwuję':
                # self.convo_state.knowledge['chosen_hit'] = self.convo_state.knowledge['proposed_hits'][0]
                # return
        # end KZ
        
        # if not (msg_type == MessageType.META_DATA and content[0].startswith("Hit")):
            # self.change_aim(HaveVisualizableHits)

    def select_first_proposed(self):
        if self.convo_state.knowledge['proposed_hits']:
            logging.debug("self.convo_state.knowledge['proposed_hits'] = " + str(self.convo_state.knowledge['proposed_hits']))
            self.convo_state.knowledge['chosen_hit'] = self.convo_state.knowledge['proposed_hits'][0]
            logging.info("self.convo_state.knowledge['chosen_hit'] = " + str(self.convo_state.knowledge['chosen_hit']))
            self.convo_state.withs = None
        
    def generate_message(self):
        ### KZ 2021.03.23
        if 'chosen_hit' not in self.convo_state.knowledge:
            self.change_aim(self.next_aim())
            return self.convo_state.aim.generate_message()
        ### KZ end
        self.allowed = do_temporary_reservation(self.convo_state.knowledge['chosen_hit'])
        self.responded = True
        self.convo_state.wait_for_response = False
        if self.allowed:
            chosen_hit = self.convo_state.knowledge['chosen_hit']
            ret = HitChoiceRegistered.format(hit=chosen_hit)
        else:
            ret = make_text_response(hit_choice_not_allowed_msg(self.convo_state))
        logging.debug(repr(ret))
        return ret

    def next_aim(self):
        return KnowClientData if self.allowed else HaveVisualizableHits

    def fulfilled(self):
        return self.responded


class KnowClientData(BaseConvoAim):
    def __init__(self, convo_state):
        super().__init__(convo_state)
        chosen_hit = self.convo_state.knowledge['chosen_hit']
        self.convo_state.knowledge['fields'] = reservis.needed_client_data(self.convo_state,
                                                                           chosen_hit.organisation_id,
                                                                           chosen_hit.service_id)
        logging.info('reservis.needed_client_data: ' + str(self.convo_state.knowledge['fields']))

    def generate_message(self):
        logging.debug('self.convo_state.knowledge["fields"]= ' + str(self.convo_state.knowledge['fields']))
        for field in self.convo_state.knowledge['fields']:
            if not field:
                logging.debug('will call ' + repr(field) + '.generate_message()')
                return field.generate_message()
        logging.error("convo_aims.KnowClientData.generate_message: should not execute this function when fulfilled")
        return make_text_response("Dziękuję, to wszystkie potrzebne dane.")

    def next_aim(self):
        return ConfirmReservation

    def fulfilled(self):
        return all(self.convo_state.knowledge['fields'])


class ConfirmReservation(BaseConvoAim):
    success = True

    def __init__(self, convo_state):
        super().__init__(convo_state)
        self.fulfilled_bool = False

    def generate_message(self):
        if self.success:
            lines = [ConfirmationOfCorrectness, str(self.convo_state.knowledge['chosen_hit'])]
            for field in self.convo_state.knowledge['fields']:
                lines.append(str(field))
            return self.make_choice_response('\n'.join(lines), OrderedDict([(Confirm, 0),
                                                                       (ChangeData, 1),
                                                                       (Resign, 2)]),
                                             self.parse_confirmation,
                                             asking_about=["confirmation"])
        else:
            self.change_aim(HaveVisualizableHits)
            self.convo_state.wait_for_response = False
            return make_text_response(ReservationFailure)

    def parse_confirmation(self, confirmed):
        confirmed = int(confirmed)
        ### KZ 2021.04.15 added
        self.convo_state.withs = None
        ### KZ 2021.04.15 end

        logging.info('Confirmed = ' + str(confirmed))
        if confirmed == 0:
            logging.debug('Demo = ' + str(self.convo_state.demo))
            if self.convo_state.demo:
                self.change_aim(ProcessConfirmation)
            else:
                reservation_code = do_reservation(self.convo_state.knowledge['chosen_hit'],
                                                  self.convo_state.knowledge['fields'])
                if reservation_code is not None:
                    self.convo_state.knowledge['reservation_code'] = reservation_code
                    self.fulfilled_bool = True # KZ added 2021.03.18
                    # self.change_aim(ProcessConfirmation)
                else:
                    self.success = False
        elif confirmed == 1:
            self.change_aim(KnowClientData)
        else:
            self.change_aim(EndConversationOnFailure)

    def process_message(self, msg_type, content):
        self.change_aim(HaveVisualizableHits)
        return True

    def next_aim(self):
        return ProcessConfirmation 

    def fulfilled(self):
        # return False
        return self.fulfilled_bool # KZ 2021.03.18


class ProcessConfirmation(BaseConvoAim):
    answer = None
    processed = False
    mail = None
    correct_mail = False
    question = None

    def generate_message(self):
        if self.convo_state.demo:
            self.processed = True
            self.convo_state.wait_for_response = False
            return make_text_response(ConfirmationDemo)
        elif self.answer is None:
            # return self.make_choice_response(AskIfConfirmation, [No,
                                                            ### WantConfirmationOnMail,
                                                            # WantConfirmationAsFile],
            return self.make_choice_response(AskIfConfirmation, [WantConfirmationAsFile,
                                                            #### WantConfirmationOnMail,
                                                            No],
                                        self.parse_if_confirmation)
        else:
            if self.answer == WantConfirmationOnMail:
                if self.mail is not None and self.mail.value is not None:
                    self.processed = True
                    self.convo_state.wait_for_response = False
                    return make_text_response("Mail wysłany")  # TODO
                else:
                    if self.mail is None:
                        mail_fields = [f for f in self.convo_state.knowledge['fields'] if isinstance(f, Email)]
                        self.mail = mail_fields[0] if mail_fields else Email(self.convo_state)
                        if self.mail.value is not None:
                            self.question = AskForAnotherMail
                            return self.make_choice_response(AskIfSendToThisMail.format(self.mail.value), [Yes, No],
                                                        self.parse_if_send_to_this_mail)
                    return self.mail.generate_message(question=self.question)
            else:
                self.processed = True
                filename = get_confirmation_file(self.convo_state.knowledge['chosen_hit'].organisation_id,
                                                 self.convo_state.knowledge['reservation_code'])
                self.convo_state.wait_for_response = False
                return make_file_response(filename)

    def parse_if_confirmation(self, content):
        if content == No:
            self.change_aim(EndConversation)
        else:
            self.answer = content
        return True

    def parse_if_send_to_this_mail(self, content):
        if content == No:
            self.mail = Email(self.convo_state, use_default=False)
        return True

    def next_aim(self):
        return EndConversation

    def fulfilled(self):
        return self.processed


class EndConversation(BaseConvoAim):
    def generate_message(self):
        return end_conversation(self.convo_state)

    def next_aim(self):
        pass

    def fulfilled(self):
        return False


class EndConversationOnFailure(BaseConvoAim):
    def generate_message(self):
        return self.make_choice_response(ByeFailure, [Reset], None)

    def next_aim(self):
        pass

    def fulfilled(self):
        return False


def aim_factory(convo_state, aim_string):
    aim_cls = {
        'KnowAction': KnowAction,
        'KnowService': KnowService,
        'HaveVisualizableHits': HaveVisualizableHits,
        'KnowChoice': KnowChoice,
        'KnowClientData': KnowClientData,
        'ConfirmReservation': ConfirmReservation,
        'ProcessConfirmation': ProcessConfirmation,
        'EndConversation': EndConversation,
    }.get(aim_string)
    if aim_cls is None:
        return CustomNameAim(convo_state, aim_string)
    else:
        return aim_cls(convo_state)
