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

import json
import os
from configparser import ConfigParser

from definitions import CONFIGURATION_ROOT


def get_config_root(name, root=CONFIGURATION_ROOT):
    if os.path.exists(os.path.join(root, 'local', name)):
        return os.path.join(root, 'local')
    else:
        return root


def read_section_from_ini(filename, section):
    cfg = ConfigParser()
    cfg.read(filename)
    return cfg[section] if section in cfg else {}


def load_json_cfg(name, root=CONFIGURATION_ROOT):
    root = get_config_root(name, root)
    configname = os.path.join(root, name)
    with open(configname) as f:
        jsondict = json.load(f)
    return jsondict
