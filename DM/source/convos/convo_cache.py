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

from convos.convo_state import ConvoState

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")


class ConvoCache:
    def __init__(self, communicator_cls):
        self.cache = {}
        self.communicator_cls = communicator_cls

    def get(self, page_id, user_id):
        logging.info('user_id: ' + str(user_id));
        # page_convos = self.cache.setdefault(page_id, {})
        page_convos = self.cache
        if user_id not in page_convos:
            if not page_id:
                raise Exception("Brak page_id")
            page_convos[user_id] = ConvoState(page_id, user_id, self.communicator_cls)
        return page_convos[user_id]

    def delete_convo(self, user_id):
        self.cache.pop(user_id, None)