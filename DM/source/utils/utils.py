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
import re

def dict_contains_key(obj, key):
    if isinstance(obj, dict):
        if key in obj:
            return True
        else:
            for val in obj.values():
                if dict_contains_key(val, key):
                    return True
    else:
        return obj == key

def set_to_first_day(datetime):
    return datetime.replace(day=1).replace(month=1).replace(year=1970)

def json_beautifier_compact(json_str):
	return re.sub(r'\n\s*{', r'{', re.sub(r'\n\s*([\]}])', r'\1', json.dumps(json_str, indent=2), flags=re.MULTILINE), flags=re.MULTILINE)
