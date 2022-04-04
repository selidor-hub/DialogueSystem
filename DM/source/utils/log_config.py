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
dir_up = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
sys.path.append(os.path.join(dir_up, "dj"))

import logging
import logging.config
import yaml
from definitions import CONFIGURATION_ROOT, LOG_CONFIG, GENERAL_LOG, ENIAM_LOG, ASR_TEXT_LOG

with open(LOG_CONFIG, 'r') as config:
    dct = yaml.load(config)
    dct.update({'GENERAL_LOG': GENERAL_LOG,
                'ENIAM_LOG': ENIAM_LOG,
                'ASR_TEXT_LOG': ASR_TEXT_LOG})
    logging.config.dictConfig(dct)
