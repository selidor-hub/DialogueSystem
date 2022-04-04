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
 import os
import shutil
import datetime
import json


def overwrite_json(rootpath, name, data):
    new = os.path.join(rootpath, name + '.json')
    old = os.path.join(rootpath, 'bak', "{}_{}.json".format(name, datetime.datetime.today().strftime("%Y-%m-%d")))
    os.makedirs(os.path.join(rootpath, 'bak'), exist_ok=True)
    if os.path.exists(new):
        shutil.copy(new, old)
    with open(new, 'w') as outfile:
        json.dump(data, outfile, ensure_ascii=False, indent=2, separators=(',', ': '))


def xls_index(xls_header, col_name):
    # print("xls_header = " + repr(xls_header))
    # print("col_name = " + repr(col_name))
    for idx, cell in enumerate(xls_header):
        if cell.value == col_name:
            return idx
    print("ERROR", col_name)
    raise LookupError
