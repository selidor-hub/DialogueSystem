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

from scope_changes.divisions import NoDivision
from scope_changes.extensions import NoExtension


class BaseScopeChangeMode(metaclass=ABCMeta):
    @property
    @abstractmethod
    def default(self):
        pass

    @staticmethod
    @abstractmethod
    def get_set(item):
        pass


class DivisionMode(BaseScopeChangeMode):
    default = NoDivision

    @staticmethod
    def get_set(item):
        return item.divisions_cls


class ExtensionMode(BaseScopeChangeMode):
    default = NoExtension

    @staticmethod
    def get_set(item):
        return item.extensions_cls


def max_scope_change(scope_changes, min_grade=-1):
    if not scope_changes:
        return None
    else:
        best = max(scope_changes, key=lambda x: x.grade())
        if best.grade() > min_grade:
            return best
        else:
            return None


def best_scope_change_msg(convo_state, mode, use_default, *args, **kwargs):
    scope_change = mode.default(convo_state)
    for paramname, item in convo_state.params.items():
        if item is not None:
            scope_changes = [sc for sc in (cls(convo_state, *args, **kwargs, customer=item)
                             for cls in mode.get_set(item)) if sc.available()]
            item_scope_change = max_scope_change(scope_changes, min_grade=scope_change.grade())
            if item_scope_change is not None:
                scope_change = item_scope_change
    if isinstance(scope_change, mode.default) and not use_default:
        return None
    scope_change.mark_used()
    return scope_change.message()

