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
import re
from collections import OrderedDict

import xlrd

# from tools.helper import overwrite_json, xls_index
from helper import overwrite_json, xls_index

if __name__ == "__main__":
    import os
    import sys
    dir_up = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    # sys.path.append(dir_up)
    sys.path.append(os.path.join(dir_up, "source"))
    import utils.log_config
import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")


XLS_COLUMNS = {
    # "patient_types": "Typy klientów (osoba, zwierzak lub przedmiot)",
    # "patient_subtypes": "Podtypy",
    # "patients": "Klient",
    # "professions": "Wykonawca",
    # "parts": "Część Ciała/Część Artefaktu",
    # "keywords": "Część główna nazwy",
    # "params": "Podrzędnik nazwy"

    "patient_types": "Typy klientów (osoba, zwierzak lub przedmiot)",
    "patient_subtypes": "Podtypy klientów",
    # "patients": "Klient", # można pobrać synonimy do "patient_subtypes"
    "professions": "Wykonawca",
    "parts": "Część Ciała/Część Artefaktu",
    "parts_params": "Podrzędnik części ciała/artefaktu",
    "keywords": "Część główna nazwy usługi",
    "params": "Podrzędnik nazwy usługi",
    
    "domain": "Dziedzina",
    "tool": "Instrument",
    "effect": "Efekt",
    "organisation_type": "Typ organizacji "
}
SERVICE_COLUMN = "Usługa"
ID_COLUMN = "Id"
BUSINESS = "Branża"
CATEGORY = "Kategoria"

pattern = re.compile("[\S]+ \([-.0-9]+\)")


def extract_weight(text):
    match_object = re.search("([\S]+)\s*\(?([-.0-9]+)?\)?", text)
    return match_object.groups("1")


def split_and_parse(row, index, with_weights=True):
# def split_and_parse(row, index, with_weights=False):
    # lowered = [v.lower() for v in row[index].value.split(',')]
    # lowered = [v.lower() for v in str(row[index].value).split(',')] # KZ 2021.08.19
    # lowered = [v.lower().strip() for v in str(row[index].value).split(',')]
    # try: # KZ 2020.02.16
        # if lowered[-1] == '':
            # lowered = lowered[:-1]
    # except IndexError:
        # pass
    val = row[index].value
    if type(val) == str:
        val = val.lower().strip()
        lowered = [v.strip() for v in val.split(',')]
    else:
        lowered = [val]
    if not val or lowered == ['']:
        return {} if with_weights else []
    else:
        # return {val: float(weight) for (val, weight) in map(extract_weight, lowered)} if with_weights else lowered # KZ 2020.02.16
        return {v: 1.0 for v in lowered} if with_weights and not type(val) == float else lowered # KZ 2020.08.19
        # return {val: 1.0} if with_weights else lowered # KZ 2020.08.19


def service_index(xls_header, service_lvl):
    return xls_index(xls_header, "{}{}".format(SERVICE_COLUMN, service_lvl))


def id_index(xls_header, id_lvl):
    return xls_index(xls_header, "{}{}".format(ID_COLUMN, id_lvl))


def establish_end(lvl, current_end, max_end, sheet):
    header = sheet.row(1)
    while current_end < max_end and not sheet.row(current_end + 1)[service_index(header, lvl)].value:
        current_end += 1
    return current_end


def add_service(parent, group_id, business, category, lvl, beg, end, sheet):
    header = sheet.row(1)
    indexes = {field: xls_index(header, col_name) for field, col_name in XLS_COLUMNS.items()}
    logging.debug("indexes = " + repr(indexes)) ###

    row = sheet.row(beg)

    logging.debug("starting service[id=" + str(int(row[id_index(header, lvl)].value)) + "], lvl = " + str(lvl))
    service = OrderedDict(id=int(row[id_index(header, lvl)].value))
    service["name"] = row[service_index(header, lvl)].value.lower()
    service["parent"] = parent
    service["group"] = group_id or service['id']
    service["business"] = business
    service["category"] = category
    if beg == end:
        service["children"] = []
        for field in indexes.keys():
            if field in ["patient_types", "patient_subtypes"]:
                service[field] = split_and_parse(row, indexes[field], with_weights=False)
            else:
                service[field] = split_and_parse(row, indexes[field])
        return service, [service]
    else:
        direct_ancestors, ancestors = [], []
        service["children"] = [a.id for a in direct_ancestors]
        iterate_subservices(lvl+1, beg, end, sheet,
                            lambda x: direct_ancestors.append(x),
                            lambda x: ancestors.extend(x),
                            service["id"], service["group"], business, category)
        
        logging.debug("service = " + repr(service)) ###
        
        for field in indexes.keys():

            if field == 'professions':
                logging.debug("field = " + repr(field)) ###
            
            for ancestor in direct_ancestors:

                if field == 'professions':
                    logging.debug("ancestor = " + repr(ancestor)) ###
                if field == 'professions':
                    logging.debug("field 'professions' not in service = " + repr(field not in service)) ###

                if field not in service:
                    if field == 'professions':
                        logging.debug("service['" +field+ "'] = " + repr(ancestor[field])) ###
                    service[field] = ancestor[field]
                else:
                    if field in ["patient_types", "patient_subtypes"]:
                        service[field] = [el for el in service[field] if el in ancestor[field]]
                    else:
                        if field == 'professions':
                            logging.debug('field in ["patient_types", "patient_subtypes"] = ' + repr(field in ["patient_types", "patient_subtypes"])) ###
                        service[field] = {el: max(service[field][el], ancestor[field][el])
                                          for el in service[field] if el in ancestor[field]}
                        # service[field] = {el: 1.0
                                          # for el in service[field] if el in ancestor[field]}
                        if field == 'professions':
                            logging.debug('service["' +field+ '"] = ' + repr(service[field])) ###
        return service, [service, *ancestors]


def iterate_subservices(lvl, beg, end, sheet, direct_ancestors_f, all_ancestors_f,
                        s_id=None, g_id=None, bus=None, cat=None):
    logging.debug("lvl = " + str(lvl) + ", beg = " + str(beg) + ", end = " + str(end) + ", s_id = " + str(s_id) + ", g_id = " + str(g_id) + ", bus = " + str(bus) + ", cat = " + str(cat))
    b, e = beg, beg
    while e <= end:
        e = establish_end(lvl, e, end, sheet)
        logging.debug("b = " + str(b) + ", e = " + str(e))
        header = sheet.row(1)
        row = sheet.row(b)
        logging.debug("row(" + str(b) + ") = " + repr(row))
        bus = row[xls_index(header, BUSINESS)].value.lower() or bus
        cat = row[xls_index(header, CATEGORY)].value.lower() or cat
        logging.debug("bus = " + repr(bus) + ", cat = " + repr(cat))
        subservice, subservices = add_service(s_id, g_id, bus, cat, lvl, b, e, sheet)
        direct_ancestors_f(subservice)
        all_ancestors_f(subservices)
        logging.debug("subservice = " + repr(subservice))
        logging.debug("subservices = " + repr(subservices))
        b, e = e + 1, e + 1


def parse_xls(xls, rootpath):
    book = xlrd.open_workbook(xls)
    sheet = book.sheet_by_index(0)
    services = []

    iterate_subservices(lvl=1, beg=2, end=sheet.nrows-1, sheet=sheet,
                        direct_ancestors_f=lambda x: x,
                        all_ancestors_f=lambda x: services.extend(x))

    # KZ usuń duplikaty, zostaw ostatni, tzn. Id2 zastępuje Id1
    prev = OrderedDict(id=0)
    for svc in services:
        if svc['id'] == prev['id']:
            services.remove(prev)
        prev = svc
                        
    overwrite_json(rootpath, 'services', services)

    # type_sheets = ['osoba', 'zwierzak', 'przedmiot']
    # types = {
        # 'subtypes': {},
        # 'recognised': {
            # key: set() for key in type_sheets
        # }
    # }
    # for sheetname in type_sheets:
        # sheet = book.sheet_by_name(sheetname)
        # for row in sheet.get_rows():
            # types['subtypes'][row[0].value.lower()] = split_and_parse(row, 1, with_weights=False)
            # types['recognised'][sheetname].update(split_and_parse(row, 1))
        # types['recognised'][sheetname] = list(sorted(types['recognised'][sheetname]))
    # overwrite_json(rootpath, 'types', types)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-x", "--xls-path", required=True, help="path to xls file")
    parser.add_argument("-c", "--config-path", required=True, help="path to folder in which json files will be written")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    parse_xls(args.xls_path, args.config_path)
