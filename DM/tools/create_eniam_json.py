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
import os

from tools.helper import overwrite_json
from utils.config import load_json_cfg


def parse_xls(eniam_dir, rootpath):
    eniam = load_json_cfg('eniam.json')
    for file in os.listdir(eniam_dir):
        if file.endswith(".json"):
            parsed = load_json_cfg(file, eniam_dir)
            for p in parsed:
                print(p)
                eniam[p['text']] = p
    overwrite_json(rootpath, 'eniam', eniam)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-e", "--eniam-json-dir", required=True, help="path to enism json directory")
    parser.add_argument("-c", "--config-path", required=True, help="path to folder in which json files will be written")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    parse_xls(args.eniam_json_dir, args.config_path)
