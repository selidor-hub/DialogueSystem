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

from utils.config import read_section_from_ini, get_config_root

variables_cfg = os.path.join(get_config_root('variables.ini'), 'variables.ini')
variables = read_section_from_ini(variables_cfg, 'VARIABLES')
ENIAM_HOSTNAME = variables['ENIAM_HOSTNAME']
ENIAM_PORT = int(variables['ENIAM_PORT'])
ENIAM_GRID_HOSTNAME = variables['ENIAM_GRID_HOSTNAME']
ENIAM_GRID_PORT = int(variables['ENIAM_GRID_PORT'])
GROUNDER_HOSTNAME = variables['GROUNDER_HOSTNAME']
GROUNDER_PORT = int(variables['GROUNDER_PORT'])
CAT_GROUNDER_HOSTNAME = variables['CAT_GROUNDER_HOSTNAME']
CAT_GROUNDER_PORT = int(variables['CAT_GROUNDER_PORT'])
TIME_GROUNDER_HOSTNAME = variables['TIME_GROUNDER_HOSTNAME']
TIME_GROUNDER_PORT = int(variables['TIME_GROUNDER_PORT'])
PHONE_ENIAM_HOSTNAME = variables['PHONE_ENIAM_HOSTNAME']
PHONE_ENIAM_PORT = int(variables['PHONE_ENIAM_PORT'])
NAME_ENIAM_HOSTNAME = variables['NAME_ENIAM_HOSTNAME']
NAME_ENIAM_PORT = int(variables['NAME_ENIAM_PORT'])

ENIAM_CONNECT_TIMEOUT = float(variables['ENIAM_CONNECT_TIMEOUT'])
ENIAM_RECEIVE_TIMEOUT = float(variables['ENIAM_RECEIVE_TIMEOUT'])

TTS_URL = variables['TTS_URL']
TTS_CONNECT_TIMEOUT = float(variables['TTS_CONNECT_TIMEOUT'])

ENIAM_DEBUG = True if variables['ENIAM_DEBUG'] == "True" else False

RESERVIS_URL = variables['RESERVIS_URL']
RESERVIS_FB_API = variables['RESERVIS_FB_API']
API_KEY = variables['API_KEY']

ELASTIC_URL = variables['ELASTIC_URL']

PAGE_VERIFY_TOKEN = variables['PAGE_VERIFY_TOKEN']

FB_API_VERSION = variables['FB_API_VERSION']