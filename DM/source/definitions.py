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

SOURCE_ROOT = os.path.dirname(__file__)
CONFIGURATION_ROOT = os.path.join(os.path.dirname(SOURCE_ROOT), 'configs')
RESOURCES_ROOT = os.path.join(os.path.dirname(SOURCE_ROOT), 'resources')
LOG_ROOT = os.path.join(os.path.dirname(SOURCE_ROOT), 'logs')
LOG_CONFIG = os.path.join(CONFIGURATION_ROOT, "log_config.yaml")
GENERAL_LOG = os.path.join(LOG_ROOT, 'general.log')
ENIAM_LOG = os.path.join(LOG_ROOT, 'eniam.log')
ASR_TEXT_LOG = os.path.join(LOG_ROOT, 'ASRtext.log')

MAX_VISUALIZABLE_HITS = 9
TEXTONLY_MAX_VISUALIZABLE_HITS = 5
QUICK_REPLIES_LIMIT = 11
TEXTONLY_QUICK_REPLIES_LIMIT = 5
MAX_TEXT_MESSAGE_LENGTH = 2000

CONTEXT = (os.path.join(CONFIGURATION_ROOT, 'cert', 'wildcard.pem'),
           os.path.join(CONFIGURATION_ROOT, 'cert', 'key.key'))

PARAMETERS_TRANSLATOR = {
    'time': 'czas',
    'service': 'usługa',
    'location': 'miejsce',
    'rating': 'ocena',
    'doer': 'wykonawca',
    'price': 'cena'
}

TIME_PERIOD_TRANSLATOR = {
    ('hour',): 'godzina',
    ('hour', 'minute'): 'godzina',
    ('monthday',): 'dzień miesiąca',
    ('month', 'monthday'): 'dzień miesiąca',
    ('year',): None
}

LOCATION_FIELD_TRANSLATOR = {
    'quarter': 'dzielnica',
    'town': 'miasto'
}