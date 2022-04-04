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

# coding: utf-8
from collections import OrderedDict
from random import sample

import requests
import json
from pymessenger2 import Bot
from pymessenger2.bot import NotificationType

from communicators.base_communicator import BaseCommunicator, MessageType, MessageDataType, make_text_response
from utils.hits import Hits
from variables import FB_API_VERSION    
from utils.utils import json_beautifier_compact
from definitions import MAX_VISUALIZABLE_HITS, QUICK_REPLIES_LIMIT, MAX_TEXT_MESSAGE_LENGTH


import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

GENERIC_TEMPLATE_ELEMENTS_LIMIT = 10



class Messenger(BaseCommunicator, Bot):
    """Messenger communicator"""
# KZ 2020.08.13
    def __init__(self, *args, **kwargs):
        self.convo_state = kwargs['convo_state'] 
        del kwargs['convo_state'] 

        kwargs['api_version'] = FB_API_VERSION
        super().__init__(*args, **kwargs)
        self.MAX_VISUALIZABLE_HITS = MAX_VISUALIZABLE_HITS
        self.QUICK_REPLIES_LIMIT = QUICK_REPLIES_LIMIT
        self.MAX_TEXT_MESSAGE_LENGTH = MAX_TEXT_MESSAGE_LENGTH
        self.show_services_text = "Pokaż usługi" 

    def send(self, id, data_type, data, debug=False):
        super().send(id, data_type, data)

    def make_list_string_and_choices(self, entries):
        msg = "\n".join(["{}. {}".format(i, e.name) for i, e in enumerate(entries, start=1)])
        choices = OrderedDict([(str(i), e.id) for i, e in enumerate(entries, start=1)])
        return msg, choices


    def send_raw(self, payload):
        logging.debug('POST: {0}/me/messages'.format(self.graph_url))
        logging.info('SENDING TO MESSENGER: {0}'.format(repr(payload)))
        # logging.info('SENDING TO MESSENGER: {0}'.format(json_beautifier_compact(payload)))
        return super().send_raw(payload)
# end KZ

    def send_recipient(self,
                       recipient_id,
                       payload,
                       notification_type=NotificationType.regular):
        payload['recipient'] = {'id': recipient_id}
        payload['notification_type'] = notification_type.value
        return self.send_raw(payload)

    @staticmethod
    def verify_request(request):
        # KZ 2020.08.12
        # data = request.get_json()
        data = json.loads(request.body.decode('utf-8'))
        # end KZ
        return data and 'object' in data and data['object'] == 'page'

    @staticmethod
    def set_id(old, new):
        if old is not None:
            assert old == new, "One request, different ids"  # FIXME
        return new

    @staticmethod
    def parse_request(request):
        # KZ 2020.08.12
        # data = request.get_json() # flask
        data = json.loads(request.body.decode('utf-8')) # django
        # end KZ
        page, psid, messages = None, None, []
        for entry in data['entry']:
            for msg_event in entry['messaging']:
                page1 = msg_event['recipient']['id']
                psid1 = msg_event['sender']['id']
                if 'message' in msg_event and ('text' in msg_event['message'] or 'is_echo' in msg_event['message']):
                    if 'is_echo' not in msg_event['message']:
                        messages.append((MessageType.TEXT, msg_event['message']['text']))
                    else:
                        psid1 = msg_event['recipient']['id']
                        page1 = msg_event['sender']['id']
                elif 'postback' in msg_event:
                    messages.append((MessageType.META_DATA, (msg_event['postback']['payload'],
                                                             msg_event['postback']['title'])))
                else:
                    logging.error("Cannot understand messenger input {}".format(str(msg_event)))
                page = Messenger.set_id(page, page1)
                psid = Messenger.set_id(psid, psid1)
        return page, psid, messages, ""

    @staticmethod
    def is_visualizable(aim, data):
        if aim == MessageDataType.TEXT:
            return len(data) < 2000
        elif aim == MessageDataType.HITS:
            return not Messenger._hits_randomized(data)
        else:
            return False

    @staticmethod
    def _hits_randomized(hits):
        random_used = False
        good_panel_exists = False
        many_days = Hits.from_one_day(hits)

        if len(hits) != 1:
            groups = OrderedDict()
            for hit in hits:
                key = hit.day() if many_days else hit.hour_category()
                if key in groups:
                    groups[key].append(hit)
                else:
                    groups[key] = [hit]

            for key, group in groups.items():
                if len(group) > 1:
                    good_panel_exists = True
                    if len(group) > 3:
                        random_used = True
                        group = sorted(sample(group, 3))
                groups[key] = [(h.hour(), repr(h)) for h in group]

            if not good_panel_exists:
                random_used = False
                if len(hits) > 4:
                    random_used = True
            elif len(groups) == GENERIC_TEMPLATE_ELEMENTS_LIMIT:
                random_used = True

        return random_used

    def _send_hits(self, psid, hits):
        random_used = False
        good_panel_exists = False
        many_days = Hits.from_one_day(hits)

        if len(hits) == 1:
            hit = hits[0]
            text = "Znalazłem jeden pasujący termin:"
            elements_data = {
                "text": str(hit),
                "buttons_data": [("Wybierz", repr(hit))]
            }
            f = self._send_button
        else:
            groups = OrderedDict()
            for hit in hits:
                key = hit.day() if many_days else hit.hour_category()
                if key in groups:
                    groups[key].append(hit)
                else:
                    groups[key] = [hit]

            for key, group in groups.items():
                if len(group) > 1:
                    good_panel_exists = True
                    if len(group) > 3:
                        random_used = True
                        group = sorted(sample(group, 3))
                groups[key] = [(h.hour(), repr(h)) for h in group]

            if not good_panel_exists:
                random_used = False
                if len(hits) > 4:
                    random_used = True
                    hits = sorted(sample(hits, 4))
                    many_days = Hits.from_one_day(hits)
                elements_data = [(h.day(), h.hour(), repr(h)) if many_days else
                                 (h.hour(), '', repr(h)) for h in hits]
                f = self.send_list_template
            else:
                if len(groups) == GENERIC_TEMPLATE_ELEMENTS_LIMIT:
                    random_used = True
                elements_data = [
                    (key, groups[key])
                    for key in groups.keys()
                ][:GENERIC_TEMPLATE_ELEMENTS_LIMIT]
                f = self.send_generic_template

            text = 'Oto {} dostępne terminy{}:'.format('niektóre' if random_used else 'wszystkie',
                                                       '' if many_days else ' ({})'.format(hits[0].day()))

        return self.send_text_message(psid, text), f(psid, elements_data)

    def _send_text(self, psid, text):
        return self.send_text_message(psid, text)

    def _send_choice(self, psid, data):
        if len(data['text']) <= self.MAX_TEXT_MESSAGE_LENGTH:
            text = data['text']
        else:
            ### KZ 2021.05.06 z powodu limitu 2000 znaków, wysyłamy po 25 pozycji w jednej wiadomości
            chunks = data['text'].split('\n')
            n = len(data['choices']) // 25
            for i in range(n):
                text = '\n'.join(chunks[i*25:(i+1)*25])
                self._send_text(psid, text)
            text = '\n'.join(chunks[n*25:len(data['choices'])])
        return self.send_quick_replies(psid, text,
                                       [c for c in data['choices']][:self.QUICK_REPLIES_LIMIT])
        # you can send only up to 11 quick replies

    def _send_file(self, psid, filename):
        return self.send_file(psid, filename)

    def _send_button(self, psid, data):
        return self.send_button_message(psid, data['text'],
                                        [
                                            {
                                                "type": "postback",
                                                "title": text,
                                                "payload": postback
                                            } for text, postback in data['buttons_data']
                                        ])

    def get_user_info(self, psid, fields=None):
        request_endpoint = '{}/{}'.format(self.graph_url, psid)
        response = requests.get(
            request_endpoint,
            params={
                'fields': 'first_name,last_name,gender,email' if fields is None else ','.join(fields),
                'locale': 'en_US',
                **self.auth_args
            }
        )
        return response.json()

    def send_quick_replies(self, recipient_id, message, replies):
        """
        Send text messages to the specified recipient.
        https://developers.facebook.com/docs/messenger-platform/send-api-reference/text-message
        Input:
            recipient_id: recipient id to send to
            message: message to send
            replies: quick replies for users
        Output:
            Response from API as <dict>
        """

        def reply_template(text):
            return {
                "title": text,
                "content_type": "text",
                # TODO DO payload powinien być różny w zależności od znaczenia przycisku. Należy to mapowanie przechować np. w stanie rozmowy, żeby potem zrozumieć wybór użytkownika.
                "payload": "start_over"
            }

        quick_replies = [reply_template(text) for text in replies]
        payload = {
            'recipient': {
                'id': recipient_id
            },
            'message': {
                "quick_replies": quick_replies,
                "text": message
            }
        }
        return self.send_raw(payload)

    def send_generic_template(self, recipient_id, elements_data,
                              notification_type=NotificationType.regular):
        """Send generic template to the specified recipient.
        https://developers.facebook.com/docs/messenger-platform/reference/template/generic/
        Input:
            recipient_id: recipient id to send to
            elements_data: generic message elements to send
        Output:
            Response from API as <dict>
        """
        return self.send_message(recipient_id, {
            "attachment": {
                "type": "template",
                "payload": {
                    "template_type": "generic",
                    "elements": [
                        OrderedDict(
                            [("title", e_title),
                             ("buttons", [
                                {
                                    "type": "postback",
                                    "title": b_title,
                                    "payload": b_payload
                                }
                                for b_title, b_payload in e_buttons_data
                             ])]
                        )
                        for e_title, e_buttons_data in elements_data
                    ]
                }
            }
        }, notification_type)

    def send_list_template(self, recipient_id, elements_data,
                           notification_type=NotificationType.regular):
        """Send generic messages to the specified recipient.
        https://developers.facebook.com/docs/messenger-platform/reference/template/list/
        Input:
            recipient_id: recipient id to send to
            elements: generic message elements to send
            image_aspect_ratio: 'horizontal' (default) or 'square'
        Output:
            Response from API as <dict>
        """
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
