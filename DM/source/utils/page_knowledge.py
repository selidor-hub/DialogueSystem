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
import requests
from urllib3.exceptions import HTTPError
import json

from utils.config import load_json_cfg, get_config_root
from utils.exceptions import FirmNotConfigured
from utils.parameters import Organisation
from variables import RESERVIS_FB_API, API_KEY

cfg_filename = os.path.join(get_config_root('organisations.json'), 'organisations.json')
org_dict = load_json_cfg(cfg_filename)

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

previous_page_knowledge = {}
def _parse_info_page(page_id, f):
    global previous_page_knowledge
    if page_id not in previous_page_knowledge: # KZ 2021.03.30
        logging.debug('page_id= ' + str(page_id))
        
        try:
            logging.debug(RESERVIS_FB_API + "headers={'api-key': " + API_KEY + "}, params={'fb_page_id': " + str(page_id) + "}, timeout=1")
            r = requests.get(RESERVIS_FB_API,
                                          headers={'api-key': API_KEY},
                                          params={'fb_page_id': str(page_id)},
                                          timeout=1)
        ### KZ 2021.03.17
            r.raise_for_status()
            page_knowledge = r.json()
            logging.debug('response:\n' + json.dumps(page_knowledge, indent=2, separators=(',', ': ')))
        except requests.exceptions.RequestException as e:
            logging.warning('From ' + RESERVIS_FB_API + ' received: ' + str(e))
            # raise e
            page_knowledge = {}
        except HTTPError as e:
            logging.warning('Could not connect to reservis fb api: ' + str(e))
            # logging.error('Could not connect to reservis fb api: ' + str(e))
            # raise e
            page_knowledge = {}
        except json.decoder.JSONDecodeError as e:
            logging.warning('NOT JSON: ' + str(repr(r.text) if r.text else '<empty string>') + ' received from ' + str(r.url))
            # raise FirmNotConfigured('Firma ' + page_id + ' nie jest skonfigurowana w systemie.') # KZ 2021.03.18 TODO docelowo
            page_knowledge = {}
        if not all(k in page_knowledge for k in ['reservis_company_code', 'reservis_division_id', 'fb_access_token']):
            page_knowledge = org_dict.get(str(page_id), {'reservis_company_code': page_id, 
                                                         'reservis_division_id': '1',
                                                         'fb_access_token': "undefined"
                                                        })
    else:
        page_knowledge = previous_page_knowledge[page_id]
    # previous_page_knowledge = {}
    previous_page_knowledge[page_id] = page_knowledge

    if all(k in page_knowledge for k in ['reservis_company_code', 'reservis_division_id', 'fb_access_token']):
        logging.debug('returning f(' + json.dumps(page_knowledge, indent=2, separators=(',', ': ')) + ')')
        try:
            res = f(page_knowledge)
        # except (requests.exceptions.ConnectionError, requests.exceptions.ConnectTimeout) as e:
        except Exception as e:
            raise e
        logging.info('return ' + str(res))
        return res
    else:
        raise FirmNotConfigured()


def get_knowledge_about_page(page_id):
    return _parse_info_page(page_id, lambda x: Organisation(x['reservis_company_code'],
                                                            x['reservis_division_id'],
                                                            x.get('mode')))


def get_communicator_token_for_page(page_id):
    return _parse_info_page(page_id, lambda x: x['fb_access_token'])
