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

import os
import sys
dir_up = os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
if dir_up not in sys.path:
    sys.path = [dir_up] + sys.path
import utils.log_config

def add_client_IP_to_LogRecordFactory(client):
    from logging import getLogRecordFactory as getLogRecordFactory, setLogRecordFactory as setLogRecordFactory
    old_factory = getLogRecordFactory()
    def record_factory(*args, **kwargs):
        record = old_factory(*args, **kwargs)
        record.client_IP = client.get_IP()
        record.user_id = client.get_user_id()
        return record
    setLogRecordFactory(record_factory)

class Client:
    def __init__(self):
        self.IP = ""
        self.user_id = ""
    def set_IP(self, IP):
        self.IP = IP
    def get_IP(self):
        return self.IP + ' '
    def set_user_id(self, user_id):
        self.user_id = user_id
    def get_user_id(self):
        return str(self.user_id) + ' '

client = Client()
add_client_IP_to_LogRecordFactory(client)

import logging
logger = logging.getLogger(__name__)
logger.debug("Logging is configured.")
logger_DIALOG = logging.getLogger("DIALOG")
logger_DIALOG.debug("Logging is configured.")

import json
import requests, random, re
import time

from django.views.generic import View
from django.utils.decorators import method_decorator

from django.views.decorators.csrf import csrf_exempt

# Create your views here.

from django.http import HttpResponse, HttpResponseRedirect, JsonResponse
from django.shortcuts import get_object_or_404, render
from django.urls import reverse
from communicators.base_communicator import MessageType
from dispatcher import dispatch_request
from utils.utils import json_beautifier_compact
from communicators.messenger import Messenger
from communicators.textonly_messenger import TextOnlyMessenger
from communicators.mock_messenger import MockMessenger
from communicators.asr_messenger import ASRMessenger, TTSMessenger
from convos.convo_cache import ConvoCache

# from .models import UserInput
from .forms import UserInputForm, ResetForm

class Webhook(View):
    def __init__(self):
        super().__init__()
        self.page_id = None
        
    def dispatch(self, request, *args, **kwargs):
        start_time = time.time()
        # logger.debug(repr(request.META))
        global client
        client.set_IP(request.META.get("REMOTE_ADDR"))
        client.set_user_id(request.session.session_key)
        res = super().dispatch(request, *args, **kwargs)
        logger.debug('returning:\n' + repr(res))
        exec_time = time.time() - start_time
        log_str = "Bot response time: {:.2f} seconds".format(exec_time)
        # print(log_str)
        if exec_time >= 4.0: # seconds
            logger.error(log_str)
        else:
            logger.info(log_str)
        return res

    def get(self, request, *args, **kwargs):
        pass

    def post(self, request, *args, **kwargs):
        pass

class WebhookDjangoPage(Webhook):
    @method_decorator(csrf_exempt) # required
    def dispatch(self, request, *args, **kwargs):
        return super().dispatch(request, *args, **kwargs) #python3.6+ syntax

    def make_request_dict(self, user_input_dict):
        request_dict = {"page_id":  self.page_id,
                "user_id":  self.user_id}
        request_dict.update(user_input_dict)
        return request_dict

class WebIndex(WebhookDjangoPage):
    def get(self, request, *args, **kwargs):
        request.session['previous_dialog'] = []
        return HttpResponse("Hello you're at the dummy index. Dialog was reset.", status=200)
    
class WebResetPreviousDialog(WebhookDjangoPage):
    def post(self, request, *args, **kwargs):
        reset_form = ResetForm(request.POST)
        logger.debug("reset_form['path'].value()= " + reset_form['path'].value())
        request.session['previous_dialog'] = []
        logger.debug('request.path= ' + request.path)
        # return HttpResponseRedirect(reverse('question'))
        return HttpResponseRedirect(reset_form['path'].value())
    
class WebQuestion(WebhookDjangoPage):
    def __init__(self):
        super().__init__()
        self.form = None
        if 'conversationsMockMessenger' not in globals():
            global conversationsMockMessenger
            conversationsMockMessenger = ConvoCache(MockMessenger)

    def dispatch(self, request, *args, **kwargs):
        self.page_id = 1 # strona firmy ?
        request.session._get_or_create_session_key()
        self.user_id = request.session.session_key
        if 'previous_dialog' not in request.session:
            request.session['previous_dialog'] = []
        super().dispatch(request, *args, **kwargs) #python3.6+ syntax        
        self.form = UserInputForm(initial={'user_input_form_text': ''})
        context = {
            'previous_dialog': request.session['previous_dialog'],
            'form': self.form,
            'reset_form': ResetForm(initial={'path': request.path})
        }
        return render(request, 'czatbot/question.html', context)

    def post(self, request, *args, **kwargs):
        self.form = UserInputForm(request.POST)
        if self.form.is_valid():
            user_input = self.form.cleaned_data['user_input_form_text']
            bot_response = dispatch_request(self.make_request_dict({"text": user_input}), conversationsMockMessenger)
            # if 'previous_dialog' not in request.session:
                # request.session['previous_dialog'] = []
            request.session['previous_dialog'] += ['Ty: ' + user_input, '________Bot: ' + bot_response]

    # def get(self, request, *args, **kwargs):
        # self.form = UserInputForm(initial={'user_input_form_text': ''})

class ASRWebQuestion(WebQuestion):
    def __init__(self):
        super().__init__()
        if 'conversationsASRMessenger' not in globals():
            global conversationsASRMessenger
            conversationsASRMessenger = ConvoCache(ASRMessenger)
        self.conversations = conversationsASRMessenger
        
    def make_content_dict(self, user_input):
        return {"grid": user_input}

    def post(self, request, *args, **kwargs):
        self.form = UserInputForm(request.POST)
        if self.form.is_valid():
            user_input = self.form.cleaned_data['user_input_form_text']
            logger.info('RECEIVED FROM USER: ' + user_input)
            try:
                request_dict = self.make_request_dict(self.make_content_dict(user_input))
                logger.debug('request_dict= ' + repr(request_dict))
                bot_response = dispatch_request(request_dict, self.conversations)
                bot_response += "\n Wysłano odpowiedź głosową."
            except Exception as e:
                logger.error(str(e))
                bot_response = "Wystąpił błąd: " + str(e)
            request.session['previous_dialog'] += ['Ty: ' + user_input, '________Bot: ' + bot_response]


class TTSWebQuestion(ASRWebQuestion):
    def __init__(self):
        super().__init__()
        if 'conversationsTTSMessenger' not in globals():
            global conversationsTTSMessenger
            conversationsTTSMessenger = ConvoCache(TTSMessenger)
        self.conversations = conversationsTTSMessenger

    def make_content_dict(self, user_input):
        return {"text": user_input}

# from .models import WebhookTransaction

class WebhookTest(Webhook): # testowy webhook
    def get(self, request, *args, **kwargs):
        logger.debug('entering webhook_test')
        logger.debug('request: ' + repr(request))
        logger.debug('request.method: ' + repr(request.method))
        fulfillmentText = {'fulfillmentText': 'This is Django response from webhook_test.'}
        # return HttpResponse(status=200)
        return JsonResponse(fulfillmentText, safe=False)

from variables import FB_API_VERSION    
FB_ENDPOINT = 'https://graph.facebook.com/v{0}'.format(FB_API_VERSION)

PAGE_ACCESS_TOKEN = "EAAORQs6XT10BABIgXWSSEGuh3l3bXWxmwiZAWrjYGVkwYmFVEQlYGc5YtBiNbYn13dT7LyXy8JpV4BXO7OJIZBA7E38vyY75PKdno0JhI6syjQeDGsy8wGk8dFu9JHnaNN6qhj3LzyXEaHvTZCzZCOPHZAHokG98Sb14SR7QVUtbwtjTLVpNc"

def parse_and_send_fb_message(fbid, received_message):
    # Remove all punctuations, lower case the text and split it based on space
    tokens = re.sub(r"[^a-zA-Z0-9\s]",' ',received_message).lower().split()
    msg = None

    msg = "Otrzymałem: {0}".format(received_message)
    # for token in tokens:
        # if token in LOGIC_RESPONSES:
            # msg = random.choice(LOGIC_RESPONSES[token])
            # break
        
    if msg is not None:                 
        endpoint = "{0}/me/messages?access_token={1}".format(FB_ENDPOINT, PAGE_ACCESS_TOKEN)
        http_headers = {"Content-Type": "application/json"}
        response_msg = json.dumps({"recipient":{"id":fbid}, "message":{"text":msg}})
        logger.debug('POST REQUEST:\nendpoint={0}\nheaders={1}\ndata={2}'.format(endpoint, http_headers, response_msg))
        status = requests.post(
            endpoint, 
            headers=http_headers,
            data=response_msg)
        logger.info(status.json())
        return status.json()
    return None
        

class MessengerWebhook(WebhookDjangoPage):
    VERIFY_TOKEN = "3cb2c619b5a8d9675abe8ef5aac301e2f1483d8ca6cc26256e" 

    def __init__(self):
        super().__init__()
        if 'conversationsMessenger' not in globals():
            global conversationsMessenger
            conversationsMessenger = ConvoCache(Messenger)
    
    '''
    hub.mode
    hub.verify_token
    hub.challenge
    Are all from facebook. 
    '''
    def get(self, request, *args, **kwargs):
        logger.debug(repr(request))
        hub_mode = request.GET.get('hub.mode')
        hub_token = request.GET.get('hub.verify_token')
        hub_challenge = request.GET.get('hub.challenge')
        if str(hub_token) != self.VERIFY_TOKEN:
            logger.info('verification request received from FB: Error, invalid token')
            return HttpResponse('Error, invalid token', status=403)
        logger.info('Verification request received from FB: status OK')
        return HttpResponse(hub_challenge)

    def post(self, request, *args, **kwargs):
        try:
            incoming_message = json.loads(request.body.decode('utf-8'))
            _page_id, user_id, _messages, _request_text = conversationsMessenger.communicator_cls.parse_request(request)
            global client
            client.set_user_id(str(user_id)[-12:])
            logger.info('RECEIVED FROM MESSENGER: {0}'.format(json_beautifier_compact(incoming_message)))
        except:
            logger.error('RECEIVED FROM MESSENGER: {0}'.format(json_beautifier_compact(incoming_message)))
            return HttpResponse("Success", status=200)

        try:
            bot_response = dispatch_request(request, conversationsMessenger)
        except Exception as e:
            logger.error(repr(e))
        return HttpResponse("Success", status=200) # nie wysyłamy bot_response w odpowiedzi do FB
        


class DialogFlowWebhook(WebhookDjangoPage):
    def __init__(self):
        super().__init__()
        if 'conversationsTextOnlyMessenger' not in globals():
            global conversationsTextOnlyMessenger
            conversationsTextOnlyMessenger = ConvoCache(TextOnlyMessenger)

    def post(self, request, *args, **kwargs):
        incoming_message = json.loads(request.body.decode('utf-8'))
        try:
            self.page_id = incoming_message["queryResult"]["intent"]["name"].split('/')[1] # nazwa projektu: drugi element w "projects/......../agent/intents/0a302b67-e1a7-4ca5-a20c-c36051469b90"
            self.user_id = incoming_message["session"].split('/').pop() # id po ostatnim / w nazwie sesji
            global client
            client.set_user_id(str(self.user_id)[-12:])
        except:
            pass
        logger.debug('RECEIVED FROM DIALOGFLOW: {0}'.format(json_beautifier_compact(incoming_message)))
        logger.info('RECEIVED TEXT FROM DIALOGFLOW: {0}'.format(incoming_message["queryResult"]["queryText"]))
        logger_DIALOG.info('RECEIVED TEXT FROM DIALOGFLOW: {0}'.format(incoming_message["queryResult"]["queryText"]))

        # welcome = incoming_message["queryResult"]["action"] == "welcome"  # action = "welcome" jest ustawione w Default Welcome Intent
        # restart = incoming_message["queryResult"]["action"] == "restart"  # action = "restart" jest ustawione w Restart intent
        # if restart:
            # user_input = "Od nowa"  # "Od nowa" restartuje czatbota
        # else:
            # user_input = incoming_message["queryResult"]["queryText"]
        user_input = incoming_message["queryResult"]["queryText"]

        bot_response = dispatch_request(self.make_request_dict({"text": user_input}), conversationsTextOnlyMessenger)
        fulfillmentText = {'fulfillmentText': bot_response}
        return JsonResponse(fulfillmentText, safe=False)

class ASRWebhook(WebhookDjangoPage):
    def __init__(self):
        super().__init__()
        if 'conversationsASRMessenger' not in globals():
            global conversationsASRMessenger
            conversationsASRMessenger = ConvoCache(ASRMessenger)
        self.conversations = conversationsASRMessenger

    def post(self, request, *args, **kwargs):
        global client
        incoming_message = request.body.decode('utf-8').strip()
        client.set_user_id('unknown')
        try:
            if len(incoming_message) > 0:
                # incoming_message_json = json.loads(incoming_message)
                logger.info('RECEIVED FROM ASR: "{0}"'.format(repr(incoming_message)))
                incoming_message_json = json.loads(incoming_message, strict=False) # KZ 2021.05.21 change for ASR grids with \n inside
                self.user_id = incoming_message_json.pop("session")
                user_input_dict = incoming_message_json
                # self.page_id = incoming_message_json.pop("page_id", "1") # KZ 1 ... ASR demo, TODO usunąć "1" jak ASR zacznie przysyłać "page_id"
                self.page_id = incoming_message_json.pop("page_id", None)
                client.set_user_id(str(self.user_id)[-12:]) # [-12:] na potrzeby logging

                bot_response = dispatch_request(self.make_request_dict(user_input_dict), self.conversations)
            else:
                logger.debug('RECEIVED FROM ASR: "{0}"'.format(incoming_message))
                bot_response = ""
            logger_DIALOG.info('RECEIVED FROM ASR: "{0}"'.format(repr(incoming_message)))
        except Exception as e:
            logger.exception(e)
            bot_response = "Wystąpił błąd: " + str(e)
        return HttpResponse(bot_response, status=200)
        # return HttpResponse("Success", status=200)

class ASRWebhookTextLogOnly(WebhookDjangoPage):
    def __init__(self):
        self.text_logger = logging.getLogger("ASRTextLog")
    
    def post(self, request, *args, **kwargs):
        global client
        incoming_message = request.body.decode('utf-8').strip()
        client.set_user_id('unknown')
        try:
            if len(incoming_message) > 0:
                # incoming_message_json = json.loads(incoming_message)
                incoming_message_json = json.loads(incoming_message, strict=False) # KZ 2021.05.21 change for ASR grids with \n inside
                self.user_id = incoming_message_json.pop('session')
                user_input_dict = incoming_message_json
                client.set_user_id(str(self.user_id)[-12:]) # [-12:] na potrzeby logging
                logger.info('RECEIVED FROM ASR: "{0}"'.format(repr(incoming_message)))
                bot_response = incoming_message_json["text"]
                logger.debug('bot_response = ' + repr(bot_response))
            else:
                logger.debug('RECEIVED FROM ASR: "{0}"'.format(incoming_message))
                bot_response = ""
        except Exception as e:
            logger.exception(e)
            bot_response = "Wystąpił błąd: " + str(e)
        if bot_response:
            self.text_logger.info(bot_response)
        return HttpResponse(bot_response, status=200)
    