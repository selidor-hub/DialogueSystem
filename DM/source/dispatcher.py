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
# KZ import NLP.source.dispatcher as betaNLP

if __name__ == "__main__":
    import utils.log_config
import logging
logger_DIALOG = logging.getLogger("DIALOG")
logger_DIALOG.debug("Logging is configured.")

logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

from datetime import datetime as dt
import requests
import io
from contextlib import redirect_stdout
import json

from communicators.base_communicator import make_text_response, MessageType
from convos.convo_cache import ConvoCache
from definitions import CONTEXT
from nlg.literals import FirmNotExistsMsg
from utils.exceptions import FirmNotExists
from variables import PAGE_VERIFY_TOKEN
from communicators.messenger import Messenger
from communicators.mock_messenger import MockMessenger
from communicators.textonly_messenger import TextOnlyMessenger
from communicators.asr_messenger import ASRMessenger


# communicator_cls = Messenger  # Facebook Messenger
# conversations = ConvoCache(communicator_cls)

def dispatch_request(request, conversations):
    page_id, user_id, messages, request_text = conversations.communicator_cls.parse_request(request)
    # logging.debug("page_id = " + str(page_id))
    # logging.debug("user_id = " + str(user_id))
    result_text = ''
    try:
        with io.StringIO() as output_file:
            logging.debug('io.StringIO() as output_file= ' + repr(output_file))
            try:
                convo = conversations.get(page_id, user_id)
                convo.output_file = output_file
                convo.request_text = request_text
                convo.communicator.service_base = convo.params['organisation'].service_base
                if messages:
                    convo.reply(messages)
                out = output_file.getvalue()
                result_text += out
                if convo.marked_for_deletion:
                    conversations.delete_convo(user_id)
            except FirmNotExists as e:
                logging.warning(FirmNotExistsMsg)
                # dt, d = make_text_response(FirmNotExistsMsg)
                # convo.communicator.send(user_id, dt, d)
                raise Exception(FirmNotExistsMsg)
            except requests.exceptions.RequestException as e: # KZ 2021.03.17
                logging.warning(str(e))
                raise e
            except Exception as e: # KZ 2021.03.18
                logging.exception(str(e))
                raise e

    except Exception as e:
        result_text += 'Wystąpił błąd. ' + str(e)
    logging.info(result_text)
    logger_DIALOG.info('SENDING TO CLIENT:\n{0}\n'.format(result_text))
    return result_text

if __name__ == "__main__":
    page_id = 1
    user_id = 1
    conversations = ConvoCache(MockMessenger)
    while (True):
        try:
            input_str = input("DM> ")
        # Wyjście z programu przez Ctrl-D lub Ctrl-C:
        except:
            print('\tBye...')
            break
        print(dispatch_with_captured_output(page_id, user_id, [input_str], conversations))
