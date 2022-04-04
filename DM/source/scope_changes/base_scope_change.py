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

from abc import ABCMeta, abstractmethod


class BaseScopeChange(metaclass=ABCMeta):
    def __init__(self, convo_state, customer):
        self.convo_state = convo_state
        self.customer = customer

    def mark_used(self):
        self.customer.mark_scope_change_used(self.__class__)

    @abstractmethod
    def grade(self):
        pass

    @abstractmethod
    def message(self):
        pass

    def available(self):
        return not self.customer.scope_change_used(self.__class__)
