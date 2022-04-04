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

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

import locale
from datetime import datetime as dt

from definitions import MAX_VISUALIZABLE_HITS
from nlg.literals import MonthGenetivus, DayOfWeek

locale.setlocale(locale.LC_ALL, '')


class Hit:
    def __init__(self, hit_id, date, service_id, organisation_id, division_id, duration, params=None):
        self.hit_id = hit_id
        self.date = dt.strptime(date, "%Y-%m-%d %H:%M:%S") if isinstance(date, str) else date
        self.service_id = service_id
        self.organisation_id = organisation_id
        self.division_id = division_id
        self.duration = duration
        self.params = params if params is not None else {}
        self.booking_id = None
        self.booking_id2 = None
        
        ### KZ 2021.03.22 for compatibility with make_list_string_and_choices()
        self.name = self.__str__()
        self.key_for_selection = hit_id

    def day(self):
        return "{weekday}, {day} {month} {year}".format(weekday=DayOfWeek[self.date.weekday()],
                                                        day=self.date.day,
                                                        month=MonthGenetivus[self.date.month],
                                                        year=self.date.year)

    def weekday_name(self):
        return DayOfWeek[self.date.weekday()]

    def hour(self):
        return dt.strftime(self.date, "%H:%M")

    def hour_category(self):
        return "godzina {}".format(self.date.hour)

    def __str__(self):
        return '{}, {}'.format(self.day(), self.hour())

    def __repr__(self):
        return "Hit({}, {}, {}, {}, {}, {})".format(repr(self.hit_id), repr(self.date), repr(self.service_id),
                                                    repr(self.organisation_id), repr(self.division_id),
                                                    repr(self.duration))

    def __lt__(self, other):
        """
        :param other:
        :return: self is more desirable than other
        """
        first = None
        time = self.params.get('time')
        if time:
            first = time.first(self.date, other.date)
        if first is None:
            return self.__key__() < other.__key__()
        else:
            return first

    def __key__(self):
        return self.hit_id, self.date, self.service_id, self.organisation_id, self.division_id


class Hits:
    def __init__(self, hits, params):
        logging.debug("hits params = " + repr(params))
        logging.debug("NUMBER hits = " + str(len(hits)))
        logging.debug("hits = " + repr(hits))
        self.hits = hits
        self.params = params

    @classmethod
    def from_reservis(cls, cells, params):
        logging.debug("cells = " + repr(cells))
        org = params['organisation']
        srv = params['service'].get_outstanding()
        return cls([Hit(k, v, srv.id, org.code, org.division, srv.duration, params=params)
                    # for k, v in sorted(cells.items())], params)
                    for k, v in sorted(cells.items()) if v != 'service too long' and v != 'occupied'], params) ### KZ 2021.03.15

    @staticmethod
    def from_one_day(hits):
        return len({h.day() for h in hits}) != 1

    @classmethod
    def empty(cls, params):
        return cls([], params)

    def cut_hits(self):
        return self.params['time'] and (self.params['time'].sort or self.params['time'].hour_sort)

    def best_hits(self):
        logging.debug("NUMBER hits to sort = " + str(len(self.hits)))
        return sorted(self.hits, key=lambda h: h.date) ### KZ 2021.11.29
        # hits_with_grades = []
        # for hit in self.hits:
            # grade = 1
            # for item in self.params.values():
                # if item is not None:
                    # grade *= item.preference_grade(hit)
            # hits_with_grades.append((grade, hit))
        # sorted_hits = sorted(hits_with_grades, key=lambda a: (-a[0], a[1]))
        # result = []
        # last_grade = None
        # all_similar = True
        # for grade, hit in sorted_hits:
            # if result and last_grade >= 2*grade:
                # all_similar = False
            # result.append(hit)
            # last_grade = grade
            # if len(result) >= 15 and not all_similar:
                # break
        ### return result[:MAX_VISUALIZABLE_HITS] if self.cut_hits() else result
        # return result

    def first(self, descending=False):
        if not self.hits:
            return None
        elif descending:
            return self.hits[-1]
        else:
            return self.hits[0]
