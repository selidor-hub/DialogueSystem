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

#!/usr/bin/env python3
"""Django's command-line utility for administrative tasks."""
import os
import sys

#KZ 2020.10.28
# dir_up = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
# if dir_up not in sys.path:
    # sys.path = [dir_up] + sys.path
# import utils.log_config
import logging

import re

class HttpMsgFilter(logging.Filter):
    def __init__(self, allow=True, pattern_list=None):
        self.allow=allow # True for allow any matching rcrds or False for block all matching rcrds
        self.pattern_list = pattern_list  # list of strings

    def filter(self, record):
        if self.pattern_list is None:
            return True
        else:
            log_msg = record.getMessage()
            bool_list = [re.match(pattern, log_msg) for pattern in self.pattern_list]
            if self.allow:
                return any(bool_list)
            else:
                return not any(bool_list)

DJANGO_SERVER_LOGGER_NAME = 'django.server'
logging = logging.getLogger(DJANGO_SERVER_LOGGER_NAME)
logging.debug("Logging is configured.")
# end KZ


def main():
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'dm.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)

if __name__ == '__main__':
    main()
