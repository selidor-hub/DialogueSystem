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

from abc import abstractmethod, ABCMeta

from communicators.base_communicator import MessageDataType, make_choice_response
from datetime import datetime as dt, timedelta as td

from nlg.replies import too_many_hits_msg, weekday_division_msg, hour_division_msg, monthday_division_msg
from scope_changes.base_scope_change import BaseScopeChange


class BaseDivision(BaseScopeChange, metaclass=ABCMeta):
    def __init__(self, convo_state, data, customer):
        super().__init__(convo_state, customer)
        self.point_of_division = None
        self.size = len(data)
        self.sets = self.divide(data)

    @abstractmethod
    def divide(self, data):
        pass

    @staticmethod
    def divide_given_pred(data, pred, amount, filter_empty=True):
        sets = [set() for _ in range(amount)]
        for item in data:
            sets[pred(item)].add(item)
        return [s for s in sets if s or not filter_empty]

    def distribution_grade(self):
        """
        # len(setA) = 5, len(setB) = 5 -> 0.5 * 0.5 * 4 = 1
        # len(setA) = 0, len(setB) = 5 -> 0.0 * 0.0 * 4 = 0
        # len(setA) = 2, len(setB) = 8 -> 0.2 * 0.2 * 4 = 0.16
        :return: grade of size similarity of sets (any value from 0 to 1)
        """
        sets_amount = len(self.sets)
        if sets_amount <= 1:
            return 0
        mapped = map(len, self.sets if isinstance(self.sets, list) else self.sets.values())
        min_rejected_prc = (self.size - max(mapped)) / self.size
        normalized = min_rejected_prc * (sets_amount/(sets_amount-1))
        return normalized * normalized

    def grade(self):
        fiftyfifty = self.distribution_grade()

        # do both sets' offer is diverse?
        diversity = 1  # TODO

        # will the division lower the level of ambiguity?
        ambiguity_level = 1  # TODO
        return fiftyfifty * diversity * ambiguity_level


class NoDivision(BaseDivision):
    def __init__(self, convo_state, data=None, customer=None):
        super().__init__(convo_state, [] if data is None else data, customer)

    def mark_used(self):
        pass

    def divide(self, hits):
        pass

    def grade(self):
        return 0

    def message(self):
        return MessageDataType.TEXT, too_many_hits_msg(self.convo_state)


class BinaryDivision(BaseDivision, metaclass=ABCMeta):
    def binary_divide(self, hits, begin, end):
        while self.while_pred(begin, end):
            middle = self.middle_mod(begin, end)
            sets = self.divide_given_pred(hits, lambda hit: int(self.binary_pred(hit, middle)), 2, False)
            if len(sets[0]) < len(sets[1]):
                begin = middle
            else:
                end = middle

        beg_sets = self.divide_given_pred(hits, lambda hit: int(self.binary_pred(hit, begin)), 2, False)
        end_sets = self.divide_given_pred(hits, lambda hit: int(self.binary_pred(hit, end)), 2, False)

        # distribution_grade(begA, begB) <= distribution_grade(endA, endB) <=> len(begA) <= len(endB)
        if len(beg_sets[0]) <= len(end_sets[1]):
            self.point_of_division = end
            return end_sets
        else:
            self.point_of_division = begin
            return beg_sets

    @staticmethod
    @abstractmethod
    def while_pred(begin, end):
        pass

    @staticmethod
    @abstractmethod
    def middle_mod(begin, end):
        pass

    @staticmethod
    @abstractmethod
    def binary_pred(hit, point_of_division):
        pass


class FixedDayDivision(BinaryDivision):
    def divide(self, hits):
        begin = dt.combine(min(hits, key=lambda x: x.date).date, dt.min.time())
        end = dt.combine(max(hits, key=lambda x: x.date).date, dt.min.time())
        return self.binary_divide(hits, begin, end)

    @staticmethod
    def while_pred(begin, end):
        return end - begin > td(days=1)

    @staticmethod
    def middle_mod(begin, end):
        return dt.combine(begin + (end - begin) / 2, dt.min.time())

    @staticmethod
    def binary_pred(hit, point_of_division):
        return hit.date >= point_of_division

    def message(self):
        self.point_of_division = self.point_of_division.strftime("%d.%m.%Y")
        choices = ["przed {}".format(self.point_of_division), "od {}".format(self.point_of_division)]
        return make_choice_response(monthday_division_msg(self.convo_state), choices, None, ["time", "monthday"])


class FixedHourDivision(BinaryDivision):
    def divide(self, hits):
        return self.binary_divide(hits, 0, 24)

    @staticmethod
    def while_pred(begin, end):
        return end - begin > 1

    @staticmethod
    def middle_mod(begin, end):
        return begin + (end - begin) // 2

    @staticmethod
    def binary_pred(hit, point_of_division):
        return hit.date.hour >= point_of_division

    def message(self):
        hour = "{}:00".format(self.point_of_division)
        choices = ["przed {}".format(hour), "od {}".format(hour)]
        return make_choice_response(hour_division_msg(self.convo_state, ""), choices, None, ["time", "hour"])


class PartitionDivision(BaseDivision, metaclass=ABCMeta):
    max_partition = None
    asking_about = None

    def divide(self, data):
        sets = {}
        for item in data:
            set_id = self.get_equivalence_class(item)
            if set_id not in sets:
                sets[set_id] = set()
            sets[set_id].add(item)
        return sets

    @staticmethod
    @abstractmethod
    def message_literal_func(hit):
        pass

    @staticmethod
    @abstractmethod
    def get_equivalence_class(hit):
        pass

    @abstractmethod
    def get_choices_data(self):
        pass

    @staticmethod
    def conj(words):
        if len(words) >= 2:
            return "{} i {}".format(", ".join(words[:-1]), words[-1])
        elif len(words) == 1:
            return words[0]
        else:
            raise IndexError

    def message(self):
        choices_data = self.get_choices_data()
        injection = ''
        if len(choices_data["allowed"]) < self.max_partition:
            if len(choices_data["allowed"]) <= len(choices_data["forbidden"]):
                injection = " (spośród {})".format(self.conj(choices_data["allowed"]))
            else:
                injection = " (poza {})".format(self.conj(choices_data["forbidden"]))
        text = self.message_literal_func(self.convo_state, injection)
        asking_about = [*self.asking_about, choices_data['choices']]
        return make_choice_response(text, choices_data['choices'], None, asking_about)


class WeekDayDivision(PartitionDivision):
    max_partition = 7
    asking_about = ['time', 'weekday']

    weekdays = {
        0: ('poniedziałek', 'poniedziałku', 'poniedziałkiem'),
        1: ('wtorek', 'wtorku', 'wtorkiem'),
        2: ('środa', 'środy', 'środą'),
        3: ('czwartek', 'czwartku', 'czwartkiem'),
        4: ('piątek', 'piątku', 'piątkiem'),
        5: ('sobota', 'soboty', 'sobotą'),
        6: ('niedziela', 'niedzieli', 'niedzielą')
    }

    @staticmethod
    def message_literal_func(convo_state, injection):
        return weekday_division_msg(convo_state, injection)

    @staticmethod
    def get_equivalence_class(hit):
        return hit.date.weekday()

    def get_choices_data(self):
        keys = sorted(self.sets.keys())
        return {
            'choices': [self.weekdays[k][0] for k in keys],
            'allowed': [self.weekdays[k][1] for k in keys],
            'forbidden': [self.weekdays[k][2] for k in range(0, 7) if k not in keys]
        }

    def available(self):
        if 'day' in self.customer.limits_any:
            return False
        else:
            return super().available()


class HourDivision(PartitionDivision):
    max_partition = 24
    asking_about = ['time', 'hour']

    @staticmethod
    def message_literal_func(convo_state, injection):
        return hour_division_msg(convo_state, injection)

    @staticmethod
    def get_equivalence_class(hit):
        return hit.date.hour

    def get_choices_data(self):
        def add_interval(b, e, ls):
            if b <= e:
                if b == e:
                    ls.append(str(b))
                elif b == 0:
                    ls.append("przed {}".format(e+1))
                elif e == 23:
                    ls.append("od {}".format(b))
                else:
                    ls.append("{}-{}".format(b, e))

        keys = sorted(self.sets.keys())
        allowed = {
            True: [],
            False: []
        }
        beg, end = 0, -1
        state = False
        for i in range(0, 24):
            if state == (i in keys):
                end = i
            else:
                add_interval(beg, end, allowed[state])
                state = i in keys
                beg, end = i, i
        add_interval(beg, end, allowed[state])
        return {
            'choices': keys,
            'allowed': allowed[True],
            'forbidden': allowed[False]
        }

    def available(self):
        if 'hour' in self.customer.limits_any:
            return False
        else:
            return super().available()


class WeekendDivision(BaseDivision):
    def divide(self, hits):
        return [set(hits)]

    def message(self):
        pass


class BestServiceDivision(BaseDivision):
    def divide(self, hits):
        return [set(hits)]

    def message(self):
        pass


class BestCategoryDivision(BaseDivision):
    def divide(self, hits):
        return [set(hits)]

    def message(self):
        pass
