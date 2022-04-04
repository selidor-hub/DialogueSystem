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

from definitions import TEXTONLY_MAX_VISUALIZABLE_HITS, TEXTONLY_QUICK_REPLIES_LIMIT

from pymessenger2.bot import NotificationType
# from communicators.base_communicator import make_choice_response
from communicators.base_communicator import make_open_question
from communicators.mock_messenger import MockMessenger
from utils.service_base import ServiceEntry
from utils.hits import Hit, Hits
from nlg.literals import Reset
from collections import OrderedDict
from anytree import AnyNode, RenderTree

class TextOnlyMessenger(MockMessenger):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.MAX_VISUALIZABLE_HITS = TEXTONLY_MAX_VISUALIZABLE_HITS
        self.QUICK_REPLIES_LIMIT = TEXTONLY_QUICK_REPLIES_LIMIT

    def make_list_string_and_choices(self, entries, func=None): # KZ 2021.10.26 entry: ServiceEntry, Hit
        logging.debug("len(entries) = " + str(len(entries)), stack_info=False)
        logging.debug("type(entries) = " + str(type(entries)))
        logging.debug("self.convo_state.last_tree_choices = " + repr(self.convo_state.last_tree_choices))
        msg = self.show_choice_text
        if not self.convo_state.last_tree_choices:
            in_service_tree = False

            class Entry():
                def __init__(self, name, value):
                    self.name = name
                    self.value = value
                    self.key_for_selection = value
                def __repr__(self):
                    return "Entry{name:" + self.name + ", value:" + str(self.value) + ", key_for_selection:" + str(self.key_for_selection) + "}"
            if isinstance(entries, dict):
                entries = [Entry(name=k, value=v) for (k, v) in entries.items()]
            elif entries and isinstance(entries, list):
                if all(isinstance(e, ServiceEntry) for e in entries): 
                    entries = [Entry(name=v.name, value=v) for v in entries]
                elif all(type(e) == str for e in entries): ### list of strings
                    entries = [Entry(name=v, value=v) for v in entries]
                # else:
                    # entries = [Entry(name=entry.name, value=entry.key_for_selection) for entry in entries]

            try: ### KZ próbujemy w hierarchii usług
                entries = [e.value.service_node.parent for e in entries]
                logging.debug("len(entries) = " + str(len(entries)))
                in_service_tree = True

                if len(entries) > 1:
                    try:
                        # logging.debug("entries = \n" + "\n".join(repr(e) for e in entries))
                        logging.debug("len(entries) = " + str(len(entries)))
                        entries_prev = entries
                        entries_up = [entry.parent for entry in entries]
                        entries_up = list(set(entries_up)) # deduplicate
                        # logging.debug("entries_up = \n" + "\n".join(repr(e) for e in entries_up))
                        logging.debug("len(entries_up) = " + str(len(entries_up)))
                        while len(entries_up) > 1:
                            entries = entries_up
                            entries_up = [entry.parent for entry in entries]
                            # entries_up = list(dict.fromkeys(entries_up)) # deduplicate
                            entries_up = list(set(entries_up)) # deduplicate
                            # logging.debug("entries_up = \n" + "\n".join(repr(e) for e in entries_up))
                            logging.debug("len(entries_up) = " + str(len(entries_up)))
                        logging.debug("len(entries) = " + str(len(entries)))

                        if len(entries) <= 1:
                            entries = entries_prev[:self.QUICK_REPLIES_LIMIT]  ### TODO można dodać sortowanie wg popularności i przewijanie listy
                            logging.debug("entries = " + repr(entries))
                        elif len(entries) > self.QUICK_REPLIES_LIMIT:
                            entries = entries[:self.QUICK_REPLIES_LIMIT]  ### TODO można sortowanie wg popularności i przewijanie listy
                            logging.debug("entries = \n" + "\n".join(repr(e) for e in entries))

                    except Exception as e:
                        logging.error(str(e))
                        raise e
            except Exception as e:
                entries = entries[:self.QUICK_REPLIES_LIMIT]  ### KZ proste przycięcie, TODO lepszy sposób wyboru
        else: # KZ powtórka poprzedniego menu
            entries = list(self.convo_state.last_tree_choices.values())
            in_service_tree = True

        logging.debug("entries = " + repr(entries))
        if len(entries) == 0:
            logging.warning("LENGTH of entries = " + str(len(entries)))
        elif len(entries) == 1:
            if isinstance(entries, dict):
                entries = [list(entries.keys())[0]]
            if in_service_tree:
                logging.debug(str(entries))
                while len(entries[0].children)==1:
                    entries[0] = entries[0].children[0]
                logging.debug(str(entries))
                self.convo_state.last_tree_choices = {e.key_for_selection: e for e in entries}
                logging.debug("self.convo_state.last_tree_choices = " + repr(self.convo_state.last_tree_choices))
                logging.debug("self.convo_state.aim = " + str(self.convo_state.aim))
            try:
                name_str = entries[0].key_for_selection
            except:
                name_str = str(entries[0])
            if name_str == Reset:
                msg = name_str + '?'
            else:
                msg = name_str + ". Czy potwierdzasz?"
            logging.debug("msg = " + msg)

            try:
                val = entries[0].id
            except:
                val = name_str
            logging.debug("msg = " + msg)
            choices = OrderedDict([(msg, val)])
            logging.debug("choices = " + repr(choices))

        else:
            try: # KZ if entries have name and key_for_selection
                # msg = self.show_choice_text
                choices_list = [(e.name + ", ", e.key_for_selection) for e in entries]
                last_in_list = choices_list[-1]
                new_last_item = (last_in_list[0][0:-2] + ".", last_in_list[1])   # KZ kropka na końcu zamiast przecinka
                choices_list = choices_list[0:-1]
                choices_list.append(new_last_item)
                choices = OrderedDict(choices_list)
                logging.debug("choices = " + repr(choices))
                if in_service_tree:
                    self.convo_state.last_tree_choices = {e.key_for_selection: e for e in entries}
                    logging.debug("self.convo_state.last_tree_choices = " + repr(self.convo_state.last_tree_choices))
                    logging.debug("self.convo_state.aim = " + str(self.convo_state.aim))
            except Exception as e:
                raise e
                # try: # KZ if entries are OrderedDict
                    # entries = entries.items()
                    # msg = ", ".join(["{}. {}".format(i, e[0]) for i, e in enumerate(entries, start=1)])
                    # choices = OrderedDict([(str(i), e[1]) for i, e in enumerate(entries, start=1)])
                # except: # KZ if entries are strings
                    # msg = ", ".join(["{}. {}".format(i, e) for i, e in enumerate(entries, start=1)])
                    ## choices = [str(i) for i, e in enumerate(entries, start=1)]
                    # choices = OrderedDict([(str(i), e) for i, e in enumerate(entries, start=1)])
            func = self.convo_state.on_tree_chosen if self.convo_state.last_tree_choices else func
        return msg, choices, func

    def make_choice_response(self, msg, choices, func, asking_about=[]):
        logging.debug("len(choices) = " + repr(len(choices)))
        if not choices or choices == [""]:
            return make_open_question(msg, asking_about, func)
        msg2 = ''
        if self.convo_state.counter_for_choice_not_understood > 0:
            if self.convo_state.counter_for_choice_not_understood <= 2:
                # if self.convo_state.last_tree_choices:
                    # choices = list(self.convo_state.last_tree_choices.values())
                msg2 = 'Nie rozumiem. '
            else:
                # msg2 = 'Niestety nie rozumiem. Czy chcesz rozpocząć wybieranie usługi od początku? '
                sth = 'usług ' if self.convo_state.last_tree_choices else ''
                msg2 = 'Niestety nie rozumiem. Czy chcesz rozpocząć wybieranie ' + sth + 'od początku? '
                self.convo_state.key_for_last_tree_choices = None
                self.convo_state.last_tree_choices = None
                self.convo_state.counter_for_choice_not_understood = 0
        msg1, choices1, func = self.make_list_string_and_choices(entries=choices, func=func)
        if len(choices1) > 1:
            msg1 = msg + ' ' + msg1
        else:
            msg1 = msg
            asking_about.append("confirmation")
        if self.convo_state.last_tree_choices:
            asking_about.append("service") # ENIAM rozpoznaje kategorie jako 'service'
        asking_about = list(dict.fromkeys(asking_about)) # deduplicate
        return super().make_choice_response(msg2 + msg1, choices1, func, asking_about=asking_about)

    def make_hits_response(self, hits):
        msg, choices, func = self.make_list_string_and_choices(entries=hits, func=self.convo_state.on_hit_chosen) 
        # return make_choice_response(msg, choices, self.convo_state.on_hit_chosen, asking_about=['quantity'])
        # return super().make_choice_response(msg, choices, func, asking_about=['quantity'])
        return super().make_choice_response(msg, choices, func, asking_about=['time'])

    def send_quick_replies(self, recipient_id, message, replies):
        payload = {
            'recipient': {
                'id': recipient_id
            },
            'message': {
                # "quick_replies": quick_replies,
                "text": message
            }
        }
        return self.send_raw(payload)

    def _send_button(self, psid, data):
        return self.send_text_message(psid, '\n'.join([data['text']] + [text for text, postback in data['buttons_data']]))

    def _send_hits(self, psid, hits):
        random_used = False
        good_panel_exists = False

        if len(hits) == 1:
            text = "Znalazłem jeden pasujący termin:"
        else:
            hits = hits[:self.MAX_VISUALIZABLE_HITS]
            text = "Znalazłem dostępne terminy. "
            if len(hits) == 1:
                text += "Pierwszy wolny termin to: "
            else:
                text += "Pierwsze wolne terminy to: "

        random_used = True
        hits = sorted(hits)
        many_days = Hits.from_one_day(hits)
        if len(hits) == 1:
            elements_data = [(h.day(), h.hour(), str(h)) if many_days else
                             (h.hour(), '', str(h)) for h in hits]
        else:
            elements_data = [(h.day(), h.hour(), str(i) + '. ' + str(h)) if many_days else
                            (h.hour(), '', str(i) + '. ' + str(h)) for i, h in enumerate(hits, start=1)] ### KZ 2021.03.18 numeracja hitów
        f = self.send_list_template
        return self.send_text_message(psid, text), f(psid, elements_data)
 
    def send_quick_replies(self, recipient_id, message, replies):
        return [self.send_text_message(recipient_id, txt) for txt in [message]+replies]


    def send_list_template(self, recipient_id, elements_data,
                           notification_type=NotificationType.regular):

        return self.send_message(recipient_id, {
            "attachment": {
                "type": "template",
                "payload": {
                    "template_type": "list",
                    "top_element_style": "compact",
                    "elements": [
                        {
                            "title": title,
                            "subtitle": subtitle,
                            "buttons": [
                                {
                                    "type": "postback",
                                    "title": "Wybierz",
                                    "payload": payload
                                }
                            ]
                        } if subtitle else
                        {
                            "title": title,
                            "buttons": [
                                {
                                    "type": "postback",
                                    "title": "Wybierz",
                                    "payload": payload
                                }
                            ]
                        }
                        for title, subtitle, payload in elements_data
                    ]
                }
            }
        }, notification_type)
