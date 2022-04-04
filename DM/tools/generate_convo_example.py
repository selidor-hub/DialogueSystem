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
import logging
import traceback
import uuid
import os
import errno
import random

from communicators.base_communicator import MessageType, MessageDataType
from convos.convo_cache import ConvoCache
from utils.test_utils import MockCommunicator

logging.basicConfig(format='%(levelname)s:%(module)s.%(funcName)s\n\t%(message)s', level=logging.DEBUG)


def ensure_dir(path):
    dirname = os.path.dirname(path)
    try:
        os.makedirs(dirname)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise


def get_convo():
    return ConvoCache(MockCommunicator).get(1, 1)


def send_messages(convo, texts):
    messages = [(MessageType.TEXT, t) for t in texts]
    convo.reply(messages)


def generate_convos(amount, size, inputfile, output_dir):
    with open(inputfile) as f:
        replies = f.readlines()

    logging.debug("Size: {}".format(str(size)))

    for i in range(amount):
        unique_filename = 'convo_{}'.format(str(uuid.uuid4()))
        logging.error('{}. {}'.format(str(i+1), unique_filename))
        path = os.path.join(output_dir, str(size), unique_filename)
        ensure_dir(path)
        convo = get_convo()
        with open(path, 'w') as f:
            try:
                for j in range(size):
                    reply = random.choice(replies)
                    f.write(reply)
                    send_messages(convo, [reply])
                    f.write(convo.communicator.last_text[-1] + '\n\n')
            except Exception:
                f.write(traceback.format_exc())


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-n", type=int, required=True, help="amount of generated convos")
    parser.add_argument("-l", type=int, required=True, help="max len of generated convos")
    parser.add_argument("-i", "--input", required=True, help="path to customer replies file")
    parser.add_argument("-o", "--output", required=True, help="path to directory for output convos")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    logger = logging.getLogger()
    # logger.setLevel(logging.ERROR)
    logger.setLevel(logging.DEBUG)
    ch = logging.FileHandler(os.path.join(args.output, 'log'))
    logger.addHandler(ch)
    logger.addHandler(logging.StreamHandler())
    generate_convos(args.n, args.l, args.input, args.output)
