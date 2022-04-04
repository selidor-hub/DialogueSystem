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

from unittest import TestCase
from interfaces.eniam import get_eniam_parse, eniam_compare, has_client_declaration
from utils.test_utils import get_grounded


class ENIAMtests(TestCase):
    def test_time(self):
        grounded = get_grounded("za 8 dni")
        self.assertEqual(4, len(grounded['time'].get_params()))

    def test_config(self):
        parsed = get_eniam_parse("chętnie")
        self.assertTrue(has_client_declaration(parsed, True))

    def test_service(self):
        grounded = get_grounded("Strzyżenie damskie")
        self.assertEqual({'service_ids[]': ['11'], 'service_id': '11'}, grounded['service'].get_params())

    def test_service_lowercase(self):
        grounded = get_grounded("olaplex")
        self.assertEqual({'service_ids[]': ['1'], 'service_id': '1'}, grounded['service'].get_params())

    def test_service_many(self):
        grounded = get_grounded("strzyżenie")
        self.assertCountEqual(['6', '11', '12', '16', '17',
                               '18', '19', '20', '21', '24'], grounded['service'].get_params()['service_ids[]'])
        # 10 best out of 15

    def test_compare(self):
        parse = {'client_declaration': {'action': {
            'with': [
                {'attitude': {'and': ['jasne', 'tak']}},
                {'attitude2': 'test'}
            ]
        }}, 'text': 'tak, jasne'}
        pattern = {'client_declaration': {'action': {'attitude': 'tak'}}}
        self.assertTrue(eniam_compare(parse, pattern))
