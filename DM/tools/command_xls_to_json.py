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
 import argparse
from collections import OrderedDict

import xlrd

from tools.helper import overwrite_json, xls_index

CONDITIONS = 'conditions'
ACTIONS = 'actions'


def process(s: str):
    return s.replace('’', "'").replace('‘', "'")


def parse_xls(xls, rootpath):
    book = xlrd.open_workbook(xls)
    sheet = book.sheet_by_index(0)
    header = sheet.row(0)
    con_idx = xls_index(header, CONDITIONS)
    act_idx = xls_index(header, ACTIONS)
    commands = []

    for idx in range(1, sheet.nrows):
        row = sheet.row(idx)
        command = OrderedDict(id=idx)
        command[CONDITIONS] = [process(c) for c in row[con_idx].value.split('\n')]
        command[ACTIONS] = [process(a) for a in row[act_idx].value.split('\n')]
        commands.append(command)

    overwrite_json(rootpath, 'commands', {'commands': commands})


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-x", "--xls-path", required=True, help="path to xls file")
    parser.add_argument("-c", "--config-path", required=True, help="path to folder in which json files will be written")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    parse_xls(args.xls_path, args.config_path)
