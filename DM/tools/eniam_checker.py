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
import time
import traceback

from interfaces.eniam import get_eniam_parse, ground_eniam
from utils.desambiguation import desambiguate

FILES_MODE = 0

import logging
logging.basicConfig(format='%(levelname)s:%(module)s.%(funcName)s\n\t%(message)s', level=logging.DEBUG)


def eniam_parse_string(string_to_parse, print_all):
    parsed = get_eniam_parse(string_to_parse)
    if print_all:
        print('\n')
        print(string_to_parse)
        print(json.dumps(parsed, ensure_ascii=False, sort_keys=True, indent=2, separators=(',', ': ')))
        time.sleep(1)
    try:
        is_ok, desambiguated = desambiguate(parsed, [], {}, True)
        print(desambiguated)
        grounded = ground_eniam(desambiguated)
        for key, val in grounded.items():
            if val is not None:
                params = val.get_params()
                if print_all:
                    print(val.tss_dict)
                    print(params)
    except Exception as e:
        if not print_all:
            print('\n')
            print(string_to_parse)
            print(json.dumps(parsed, ensure_ascii=False, sort_keys=True, indent=2, separators=(',', ': ')))
            time.sleep(1)
        print(e)
        traceback.print_exc()


if __name__ == "__main__":
    if FILES_MODE:
        folder = "/home/daniel/Dropbox/rezerve/examples"
        files = [
            # 'Question.txt',
            # 'Declaration.txt',
            # 'Indexical.txt',
            # 'Time.txt',
            # 'Flexibility.txt',
            # 'Other.txt',
            # 'Service.txt',
            'Sort.txt',
            # 'Corpus.txt',
            # 'Location.txt'
        ] or os.listdir(folder)
        for file in files:
            if file.endswith(".txt"):
                print('\n\n', file)
                with open(os.path.join(folder, file)) as f:
                    for line in f:
                        if line.startswith("#"):
                            break
                        eniam_parse_string(line, False)
    else:
        string = 'tak'
        # string = '8 popołudnie'
        # string = 'poniedziałek 24.04 10:00'
        eniam_parse_string(string, True)
