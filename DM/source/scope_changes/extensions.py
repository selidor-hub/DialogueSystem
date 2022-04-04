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
from copy import deepcopy

from communicators.base_communicator import MessageDataType, make_text_response
from interfaces.reservis import reservis_hits

from nlg.replies import no_hits_msg
from scope_changes.base_scope_change import BaseScopeChange


class BaseExtension(BaseScopeChange, metaclass=ABCMeta):
    def __init__(self, convo_state, customer):
        super().__init__(convo_state, customer)
        self.given = self.set_given()
        self.extended = self.extend()

    @abstractmethod
    def set_given(self):
        pass

    @abstractmethod
    def extend(self):
        pass


class NoExtension(BaseExtension):
    def __init__(self, convo_state, customer=None):
        super().__init__(convo_state, customer)

    def mark_used(self):
        pass

    def set_given(self):
        pass

    def extend(self):
        pass

    def grade(self):
        return 0

    def message(self):
        return MessageDataType.TEXT, no_hits_msg(self.convo_state)


class TimeExtension(BaseExtension, metaclass=ABCMeta):
    @property
    @abstractmethod
    def attribute(self):
        pass

    @property
    @abstractmethod
    def range_len(self):
        pass

    @property
    @abstractmethod
    def offset(self):
        pass

    def set_given(self):
        given_set = self.get_base_for_atrribute_with_int(self.customer.tss_dict, self.range_len)
        if given_set:
            return min(given_set), max(given_set)
        else:
            return None, None

    def extend(self):
        extended_low, l_str, l_len = self.establish_available_neighbour(self.given[0], self.offset, False)
        extended_high, h_str, h_len = self.establish_available_neighbour(self.given[1], self.offset + self.range_len, True)
        if extended_low is not None and extended_high is not None:
            if l_len - (self.given[0] - extended_low) > h_len - (extended_high - self.given[1]):
                return extended_low, l_str, l_len
            else:
                return extended_high, h_str, h_len
        elif extended_low is not None:
            return extended_low, l_str, l_len
        else:
            return extended_high, h_str, h_len

    def grade(self):
        choice, _, hits_no = self.extended
        if choice is None:
            return 0
        if choice < self.given[0]:
            return 1 / (self.given[0] - choice)
        else:
            return 1 / (choice - self.given[1])

    @classmethod
    def get_base_for_atrribute_with_int(cls, tss, range_len, offset=0):
        if tss is None:
            return set()
        if cls.attribute in tss and isinstance(tss[cls.attribute], int):
            return {tss[cls.attribute]}
        if 'and' in tss:
            res = set()
            for a in tss['and']:
                set_a = cls.get_base_for_atrribute_with_int(a, range_len, offset)
                if set_a:
                    res = res.intersection(set_a) if res else set_a
            return res
        if 'after' in tss:
            return cls.get_tss_range(tss['after'], range_len, offset,
                                               lambda x: range(x+1, range_len+offset))
        if 'before' in tss:
            return cls.get_tss_range(tss['before'], range_len, offset,
                                               lambda x: range(0+offset, x))
        if 'begin' in tss:
            return cls.get_tss_range(tss['begin'], range_len, offset,
                                               lambda x: range(x, range_len+offset))
        if 'end' in tss:
            return cls.get_tss_range(tss['end'], range_len, offset,
                                               lambda x: range(0+offset, x+1))
        return set()  # FIXME: 'or'

    @classmethod
    def get_tss_range(cls, tss, range_len, start_from_zero, range_f):
        tss_set = cls.get_base_for_atrribute_with_int(tss, range_len, start_from_zero)
        if len(tss_set) == 1:
            elem = tss_set.pop()
            return {i for i in range_f(elem)}
        else:
            return tss_set

    @classmethod
    def change_attribute_in_tss(cls, tss, old_value, new_value):
        if isinstance(tss, dict):
            if cls.attribute in tss and tss[cls.attribute] == old_value:
                tss[cls.attribute] = new_value
            else:
                for value in tss.values():
                    cls.change_attribute_in_tss(value, old_value, new_value)
        elif isinstance(tss, list):
            for d in tss:
                cls.change_attribute_in_tss(d, old_value, new_value)
        return tss

    def check_if_available(self, old_value, new_value, threshold):
        go_up = old_value < new_value
        if new_value >= threshold if go_up else threshold > new_value:
            raise IndexError

        params = {k: v for k, v in self.customer.convo_state.params.items()}
        new_tss = self.change_attribute_in_tss(deepcopy(params['time'].tss_dict), old_value, new_value)

        # if tss denotes range <a, b>, it can be defined in tss explicitly as any of:
        # (a-1, b+1), <a, b+1), (a-1, b>, <a, b>
        # old value is equal a or b, so if changing it does not work it means it must be a-1 or b+1
        new_str = str(new_value)
        if new_tss == params['time'].tss_dict:
            step = 1 if go_up else -1
            old_value += step
            new_value += step
            if new_value >= threshold if go_up else threshold > new_value:
                new_value -= self.range_len * step
            new_str = ("przed {}" if go_up else "po {}").format(new_value)

        from utils.parameters import Time
        params['time'] = Time(self.change_attribute_in_tss(deepcopy(params['time'].tss_dict),
                                                           old_value, new_value), params['time'].convo_state)
        return len(reservis_hits(params).hits), new_str

    def establish_available_neighbour(self, start_value, threshold, go_up: bool):
        if start_value is None:
            return None, None, 0
        step = 1 if go_up else -1
        new_value = start_value + step
        hits_no = 0
        try:
            while True:
                hits_no, new_str = self.check_if_available(start_value, new_value, threshold)
                if hits_no != 0:
                    break
                new_value += step
        except IndexError:
            return None, None, hits_no
        return new_value, new_str, hits_no


class HourExtension(TimeExtension):
    attribute = 'hour'
    range_len = 24
    offset = 0

    def message(self):
        return make_text_response("Niestety nie ma wolnych terminów w podanym terminie. "
                                  "Może godzina {}?".format(self.extended[1]))


class MonthDayExtension(TimeExtension):
    attribute = 'monthday'
    range_len = 31
    offset = 1

    def message(self):
        return make_text_response("Niestety nie ma wolnych terminów w podanym terminie. "
                                  "Może dzień miesiąca {}?".format(self.extended[1]))


class WeekDayExtension(TimeExtension):
    attribute = 'weekday'
    range_len = 7
    offset = 1

    def message(self):
        return make_text_response("Niestety nie ma wolnych terminów w podanym terminie. "
                                  "Może dzień tygodnia {}?".format(self.extended[1]))
