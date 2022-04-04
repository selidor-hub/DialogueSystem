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

#KZ 2020.10.28
dir_up = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
dir_source = dir_up + "/source"
if dir_source not in sys.path:
    sys.path = [dir_source] + sys.path

from utils.config import load_json_cfg
from anytree import Node, RenderTree
from anytree.exporter import JsonExporter

dct = load_json_cfg('tabela.json') # konwersja z Excela na JSON przez https://beautifytools.com/excel-to-json-converter.php

root = Node(None)
node = root

lvl = 0
for cell in dct["Arkusz1"]:
    # v_list = v for k,v in cell.items() if v != "x" and k != "liczba"
    v_list = [v for k,v in list(cell.items())[0:-1]]
    # v_list = [v.rstrip() for k,v in list(cell.items())[0:-1]]

    while lvl > 10-len(v_list):
    # while lvl > 11-len(v_list):
        node=node.parent
        lvl -= 1

    while len(v_list) > 1:
        lvl += 1
        child = Node(v_list[0], parent=node)
        node=child
        v_list = v_list[1:]
        
    if len(v_list) == 1:
        node.id = v_list[0]

print(RenderTree(root))

exporter = JsonExporter(indent=2, sort_keys=False, ensure_ascii=False)
with open('services_tree.json', 'w', encoding='utf-8') as f:
    print(exporter.export(root), file=f)
