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

import json
from html import unescape
from typing import List, Tuple, Union

import requests
from abc import ABCMeta, abstractmethod
from datetime import datetime as dt, timedelta as td

from communicators.base_communicator import make_text_response, make_open_question
from definitions import RESOURCES_ROOT

from grounders.TimeSegmentSequence import ground_time_declaration, ground_time_reset_generator_cache, TssError

from interfaces.reservis import reservis_hits

from nlg.literals import TimeEarly, TimeLate
from nlg.replies import wrong_time_msg
from scope_changes.extensions import HourExtension, WeekDayExtension, MonthDayExtension
from variables import RESERVIS_URL

from utils.utils import dict_contains_key, set_to_first_day
from utils.exceptions import FirmNotExists
from utils.config import load_json_cfg
from scope_changes.divisions import HourDivision, WeekDayDivision
from utils.service_base import ServiceBase, ServiceEntry

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

class Parameter(metaclass=ABCMeta):
    final = False
    divisions_cls = set()
    extensions_cls = set()

    def __init__(self):
        self.param_cache = None
        self._used = set()

    @abstractmethod
    def _merge(self, obj, proposed_hits=None):
        pass

    def merge(self, obj, proposed_hits=None):
        if isinstance(obj, self.__class__) and not self.final:
            self.param_cache = None
            self._merge(obj, proposed_hits)

    def mark_scope_change_used(self, scope_change_cls):
        if scope_change_cls in self.divisions_cls or scope_change_cls in self.extensions_cls:
            self._used.add(scope_change_cls)
        else:
            logging.error("Missing scope change class({}) in {}".format(scope_change_cls.__name__,
                                                                        self.__class__.__name__))

    def scope_change_used(self, scope_change_cls):
        return scope_change_cls in self._used

    def get_params(self):
        if not self.param_cache:
            self.param_cache = self._get_params()
        return self.param_cache

    @abstractmethod
    def _get_params(self):
        pass

    @abstractmethod
    def grade_of_definition(self):
        # FIXME: unused for now
        pass

    @staticmethod
    def is_ready_to_generate_hits():
        return True

    @staticmethod
    def respond_to_not_ready_to_generate_hits():
        logging.error("parameters.respond_to_not_ready_to_generate_hits: should not execute this part of function")
        return make_text_response("Nie rozpoznaję jaką firmę mam reprezentować :(, skontaktuj się z nią bezpośrednio.")

    @staticmethod
    def division_allowed(_):  # TODO
        return True

    def preference_grade(self, hit):
        return 1

previous_reservis_response = {}
class Organisation(Parameter):
    def __init__(self, reservis_id, division, mode=None, final=True):
        # logging.debug(str(reservis_id) + ', ' + str(division) + ', ' + str(mode) + ', ' + str(final))
        super().__init__()
        self.code = reservis_id
        self.division = division
        self.mode = mode
        self.final = final
        
        global previous_reservis_response
        if self.code not in previous_reservis_response:
            try:
                logging.debug('requests.get(' + RESERVIS_URL + 'main/getdata' + ", params={'code': " + str(self.code) + '})')
                r = requests.get(RESERVIS_URL + 'main/getdata', params={'code': self.code})
                r.raise_for_status()
                if not r:
                    raise Exception("Pusta odpowiedź od " + RESERVIS_URL + 'main/getdata')
                previous_reservis_response = {}
                previous_reservis_response[self.code] = r
            except requests.exceptions.RequestException as e:
                raise e
        else:
            r = previous_reservis_response[self.code]

        try:
            response = r.json()
            logging.debug('response success: ' + str(response['success']))
            if response['success'] == 1:
                # logging.debug('response Services:\n' + json.dumps(response['Services'], indent=2, separators=(',', ': '))[:1000] + '...')
                # logging.debug('response Services[0]:\n' + json.dumps(response['Services'][0], indent=2, separators=(',', ': ')))
                
                self.long_description = response.get("Company", {}).get("long_description", {}).get("pl")
                self.handicap = response.get("Company", {}).get("has_handicap_facilities")
                self.parking = response.get("Company", {}).get("has_parking")
                self.card = response.get("Company", {}).get("accept_payment_card")
                self.services = [s['id'] for s in response.get("Services", [])]
                division_info = next((d for d in response["Divisions"] if d['id'] == division))
                self.not_earlier_in_minutes = int(division_info.get("not_earlier_in_minutes", "0"))
                self.not_later_in_minutes = int(division_info.get("not_later_in_minutes", "129600"))  # 90 days
                self.requires_employee_confirmation = int(division_info.get("internet_reservation_status_id", 1)) == 2
                entries = [self._process_reservis_service_entry(s) for s in response['Services']]
                # logging.debug("NUMBER ENTRIES RECEIVED: " + str(len(entries)))
                # logging.debug('ServiceBase(' + str(entries) + ')')
                self.service_base = ServiceBase(entries=entries)
                # logging.debug("NUMBER ENTRIES IN ServiceBase: " + str(len(self.service_base.entries)))
            else:
                logging.debug ('raising exception FirmNotExists') 
                raise FirmNotExists()
        except (KeyError, json.decoder.JSONDecodeError) as e:
            previous_reservis_response = {}
            logging.error(repr(e))
            raise Exception("Zła odpowiedź od " + RESERVIS_URL + 'main/getdata')

    def _merge(self, obj, proposed_hits=None):
        pass  # FIXME for now Organization is always final

    def _get_params(self):
        return {
            'code': self.code,
            'division_ids[]': [self.division]
        }

    @staticmethod
    def _process_reservis_service_entry(entry):
        # KZ 2021.03.30 dodano pola z globalnej listy usług
        try:
            global_ids = [e['global_service_id'] for e in entry['ServiceGlobalService']]
        except Exception as e:
            logging.error(str(e))
            # raise e
            # global_ids = None
            # global_ids = [entry['id']] if entry['id'] in [e.id for e in self.service_base.entries] else []
            global_ids = [entry['id']]
        # KZ end
        # logging.debug("entry['id'] = " + entry['id'] + " : " + str(global_ids))
        if len(global_ids) == 0:
            raise Exception("No global_id found for service entry: " + repr(entry))
        return {
            'id': entry['id'],
            'name': unescape(entry['name']['pl']),
            'duration_in_minutes': entry['duration_in_minutes'],
            'global_ids': global_ids
        }

    def grade_of_definition(self):
        return 1


class Time(Parameter):
    divisions_cls = {
        WeekDayDivision,
        HourDivision
    }
    extensions_cls = {
        MonthDayExtension,
        WeekDayExtension,
        HourExtension
    }
    flexibilities_description = load_json_cfg("flexibilities.json", RESOURCES_ROOT)

    def __init__(self, tss_dict, convo_state, final=False):
        super().__init__()

        self.extend = None
        self.limits_any = set()
        self.limits_no = set()

        # self.tss_dict, flexibilities = self._extract_flexibilities(tss_dict)

        logging.debug(tss_dict)
        try:
            # flexibility_info = self._get_flexibility_info(tss_dict.get('flexibility', {}).get('mod'))
                
            # if isinstance(flexibility_info, bool):
                # self.extend = flexibility_info
                # tss_dict = tss_dict['flexibility']['arg']
            # elif isinstance(flexibility_info, str):
                # if flexibility_info == 'any':
                    # self.limits_any.add(tss_dict['flexibility']['arg'])
                # if flexibility_info == 'no':
                    # self.limits_no.add(tss_dict['flexibility']['arg'])

            if 'and' in tss_dict:
                sort_dict = next((d for d in tss_dict['and'] if 'sort' in d), {})
                self.sort = sort_dict.pop('sort', None)
                hour = next((d['hour'] for d in tss_dict['and'] if 'hour' in d), {})
            else:
                self.sort = tss_dict.pop('sort', None)
                hour = tss_dict.get('hour', {})
            if isinstance(hour, dict):
                self.hour_sort = hour.pop('sort', None)
            else:
                self.hour_sort = None
            if hour == {}:
                if 'and' in tss_dict and 'hour' in tss_dict['and']:
                    tss_dict['and'] = [d for d in tss_dict['and'] if 'hour' not in d]
                elif 'hour' in tss_dict:
                    del tss_dict['hour']
        except:
            tss_dict = {}

        # self.tss_dict, preferences_dicts = self._extract_flexibility(tss_dict)
        self.tss_dict = tss_dict
        # self.preferences = set()
        today = dt.combine(dt.today(), dt.min.time())
        # self.preferences.add((2, ((today, today + td(days=14)),)))
        # logging.debug("self.preferences = " + repr(self.preferences))
        # self.preferences.update([
            # (self._get_flexibility_info(flex),
             # tuple(iter(ground_time_declaration(desc, do_cut_past=True)))[1:])
            # for (flex, desc) in preferences_dicts
        # ])
        # logging.debug("self.preferences after update = " + repr(self.preferences))
        self.final = final
        self.convo_state = convo_state

    def __repr__(self): ### KZ added 2021.11.26
        return ("\n".join( ["time attributes = {", 
                            "self.tss_dict = " + repr(self.tss_dict), 
                            # "self.preferences = " + repr(self.preferences),
                            "self.final = " + repr(self.final) + "}"]))

    def _get_flexibility_info(self, flex) -> Union[int, bool, str]:
        # -> int, value of preference modifier
        if flex in self.flexibilities_description['prefer']:
            return self.flexibilities_description['prefer'][flex]

        # -> 'and'/'or', flex defines whether to extend or not
        elif flex in self.flexibilities_description['and']:
            return False
        elif flex in self.flexibilities_description['or']:
            return True

        # -> , flex defines limits
        elif flex in self.flexibilities_description['any']:
            return 'any'
        elif flex in self.flexibilities_description['no']:
            return 'no'
        else:
            if flex is not None:
                logging.error("parameters: missing flex - {}".format(flex))
            return None

    def _merge(self, obj, proposed_hits=None):
        logging.debug("self.tss_dict = " + repr(self.tss_dict) + ", obj = " + repr(obj) + ", proposed_hits = " + str(proposed_hits))
        horizon = self.tss_dict.pop("horizon", None) ### KZ 2022.01.25 added key "horizon" for compatibility with TIME_GROUNDER
        logging.debug("horizon = " + str(horizon))
        if dict_contains_key(obj.tss_dict, 'previous'):
            logging.debug("dict_contains_key(" + repr(obj.tss_dict) + ", 'previous') = TRUE")
            if proposed_hits:
                # after -> max, 'after', before -> min, 'before'
                f, key = (max, 'after') if dict_contains_key(obj.tss_dict, 'after') else (min, 'before')
                date = f([set_to_first_day(h.date) for h in proposed_hits])
                date_dict = {'hour': date.hour}
                if date.minute != 0:
                    date_dict['minute'] = date.minute
                desc = {key: date_dict}
                # self.preferences.add((4, tuple(iter(ground_time_declaration(desc, do_cut_past=True)))[1:]))
                # self.preferences.add((2, tuple(iter(ground_time_declaration(self.tss_dict, do_cut_past=True)))[1:]))
                self.tss_dict = {'or': [self.tss_dict, desc]}
                if not dict_contains_key(obj.tss_dict, 'hour'):
                    date = f([h.date for h in proposed_hits])
                    desc = {key: {'year': date.year, 'month': date.month, 'monthday': date.day}}
                    # self.preferences.add((4, tuple(iter(ground_time_declaration(desc, do_cut_past=True)))[1:]))
                    self.tss_dict = {'or': [self.tss_dict, desc]}
        else:
            if obj.tss_dict:
                operator = obj.extend or ('or' if obj.convo_state.extend else 'and')
                # self.tss_dict = {operator: [self.tss_dict, obj.tss_dict]}  # FIXME
                if self.tss_dict != obj.tss_dict:
                    self.tss_dict = {operator: [self.tss_dict, obj.tss_dict]}  # KZ 2022.01.25
            # self.preferences.update(obj.preferences)

            if horizon: ### KZ 2022.01.25 added key "horizon" for compatibility with TIME_GROUNDER
                self.tss_dict["horizon"] = horizon
            logging.debug("tss_dict = " + repr(self.tss_dict))
            if not self.get_params() and obj.tss_dict:
                self.tss_dict = obj.tss_dict
                self._used = set()
            # KZ self.sort = obj.sort or self.sort
            try:
                self.sort = obj.sort or self.sort
            except:
                self.sort = False
                
            # KZ self.hour_sort = obj.hour_sort or self.hour_sort
            try:
                self.hour_sort = obj.hour_sort or self.hour_sort
            except:
                self.hour_sort = False # end KZ

            self.limits_any = self.limits_any.union(obj.limits_any).difference(obj.limits_no)
            self.limits_no = self.limits_no.union(obj.limits_no).difference(obj.limits_any)
            
    def _extract_flexibility(self, obj):
        if not isinstance(obj, (dict, list)):
            return obj, []
        elif isinstance(obj, list):
            flexs = [(d["flexibility"]["mod"], d["flexibility"]["arg"]) for d in obj if isinstance(d, dict)
                     and "flexibility" in d
                     and isinstance(self._get_flexibility_info(d['flexibility']['mod']), int)]
            rest = [d for d in obj if d not in flexs]
            return rest, flexs
        else:
            if "flexibility" in obj:
                if isinstance(self._get_flexibility_info(obj['flexibility']['mod']), int):
                    return {}, [(obj["flexibility"]["mod"], obj["flexibility"]["arg"])]
                else:
                    return obj, []
            else:
                flexs = []
                for key in obj:
                    new_obj, part_flexs = self._extract_flexibility(obj[key])
                    obj[key] = new_obj
                    flexs.extend(part_flexs)
                return obj, flexs

    def _extract_flexibilities(self, obj):
        if not isinstance(obj, (dict, list)):
            return obj, []
        elif isinstance(obj, list):
            flexs = [(d["flexibility"]["mod"], d["flexibility"]["arg"]) for d in obj if "flexibility" in d]
            rest = [d for d in obj if "flexibility" not in d]
            return rest, flexs
        else:
            if "flexibility" in obj:
                return {}, [(obj["flexibility"]["mod"], obj["flexibility"]["arg"])]
            else:
                flexs = []
                for key in obj:
                    new_obj, part_flexs = self._extract_flexibilities(obj[key])
                    obj[key] = new_obj
                    flexs.extend(part_flexs)
                return obj, flexs

    def intervals(self, cast_to=None, do_cut_past=True, description=False):
        start, stop = self.establish_borders()
        tss = ground_time_declaration(self.tss_dict, do_cut_past=do_cut_past, start=start, stop=stop)
        loi = list(iter(tss))
        ground_time_reset_generator_cache(self.tss_dict)
        logging.debug("loi = " + repr(loi))
        if description:
            return loi[0]
        else:
            if cast_to is None:
                return loi[1:]
            else:
                return [(cast_to(a), cast_to(b)) for a, b in loi[1:]]

    def _get_params(self):
        params = {}
        for ind, (start, end) in enumerate(self.intervals(cast_to=str)):
            if start > end:
                logging.error("start_key ({}) > end_key ({}): {}".format(start, end, self.tss_dict))
            if ind == 0:
                params["start_at"] = start
            start_key = "dateRanges[{}][start_at]".format(ind)
            end_key = "dateRanges[{}][end_at]".format(ind)
            params[start_key] = start
            params[end_key] = end
            params["end_at"] = end
            if len(params) > 100:
                break
        if params and params["start_at"] > params["end_at"]:
            logging.error("start_at > end_at: {}".format(self.tss_dict))
        return params

    def find_first_available(self, params, date, descending=False):
        params['time'] = Time({
            'year': date.year,
            'month': date.month,
            'monthday': date.day
        }, self.convo_state)
        return reservis_hits(params).first(descending)

    def establish_borders(self, must_be_available=False):
        start = dt.today() + td(minutes=self.convo_state.params['organisation'].not_earlier_in_minutes)
        stop = dt.today() + td(minutes=self.convo_state.params['organisation'].not_later_in_minutes)
        if not must_be_available:
            return start, stop

        params = {k: v for k, v in self.convo_state.params.items()}
        start_day = start.replace(hour=0, minute=0, second=0, microsecond=0)
        stop_day = stop.replace(hour=0, minute=0, second=0, microsecond=0)
        available_start, available_stop = None, None
        for single_date in (start_day + td(days=n) for n in range((stop-start_day).days+1)):
            temp = self.find_first_available(params, single_date)
            if temp is not None:
                available_start = temp
                break
        for single_date in (stop_day - td(days=n) for n in range((stop-start_day).days+1)):
            temp = self.find_first_available(params, single_date, descending=True)
            if temp is not None:
                available_stop = temp
                break
        return available_start, available_stop

    def is_ready_to_generate_hits(self):
        return bool(self.get_params())

    def respond_to_not_ready_to_generate_hits(self):
        desc = self.intervals(do_cut_past=True, description=True)
        err = desc[1].get('error', None)
        earliest, latest = self.establish_borders(True)
        response = "Niestety w chwili obecnej nie ma w ogóle wolnych terminów."
        if err == TssError.TOO_EARLY and earliest is not None:
            response = TimeEarly.format(str(earliest))
        elif err == TssError.TOO_LATE and latest is not None:
            response = TimeLate.format(str(latest))
        elif err == TssError.OTHER:
            response = wrong_time_msg(self.convo_state)
        return make_open_question(response, ["time"])

    def grade_of_definition(self):
        interval_sum = 0
        for start, end in self.intervals():
            delta = end.timestamp() - start.timestamp()
            interval_sum += delta
        day = 24 * 60 * 60
        return 1 if interval_sum > day else interval_sum / day

    # def preference_grade(self, hit):
        # grade = 1
        # for mod, periods in self.preferences:
            # if any([b <= hit.date <= e for (b, e) in periods]):
                # grade *= mod
        # return grade

    def first(self, date1, date2):
        """
        :param date1:
        :param date2:
        :return: is date1 before date2 (considering self.sort and self.hour_sort)
        """
        def cmp_dates(d1, d2, order):
            if d1 == d2:
                return None
            elif order is None or order == "ascending":
                return d1 < d2
            else:
                return d2 < d1
        if self.hour_sort:
            hour1 = set_to_first_day(date1)
            hour2 = set_to_first_day(date2)
            if hour1 != hour2:
                return cmp_dates(hour1, hour2, self.hour_sort)
        else:
            return cmp_dates(date1, date2, self.sort)


class Service(Parameter):
    divisions_cls = {
        # BestServiceDivision,
        # BestCategoryDivision
    }

    # service_base = ServiceBase()  ### KZ 2021.06.18 przenieść do __init__()
    translator = [
        (("service", "name"), "keywords", None),
        (("service", "effect"), "keywords", None),
        (("service", "param"), "params", None),

        (("patient", "person"), "patients", None),
        (("patient", "person"), "patient_types", lambda s, _: s.add("osoba")),
        (("patient", "animal"), "patients", None),
        (("patient", "animal"), "patient_types", lambda s, _: s.add("zwierzak")),
        (("patient", "artefact"), "patients", None),
        (("patient", "artefact"), "patient_types", lambda s, _: s.add("przedmiot")),
        (("patient", "part"), "parts", None),

        (("doer", "profession"), "professions", None)
    ]

    def __init__(self, service, patient, doer, text, service_base=None, final=False):
        logging.debug("service = " + repr(service) + ", patient = " + repr(patient) + ", doer = " 
                    + repr(doer) + ", text = " + repr(text) + ", service_base = " + repr(service_base) 
                    + ", final = " + repr(final), stack_info=False)
        super().__init__()
        self.eniam_specs = dict()
        if service:
            self.eniam_specs["service"] = service
        if patient:
            self.eniam_specs["patient"] = patient
        if doer:
            self.eniam_specs["doer"] = doer
        if service_base:
            if not service_base.entries: ### KZ 2021.04.02 entries może być puste po groundingu
                self.service_base = ServiceBase(service_base.initial_entries)
            else:
                self.service_base = service_base
        else:
            self.service_base = ServiceBase()  ### KZ 2021.06.18 przeniesione z class

        self.description = {
            "keywords": set(),
            "params": set(),
            "patient_types": set(),
            "patients": set(),
            "professions": set(),
            "parts": set(),
            "texts": {text},
            "no_merging": {
                "business": None,
                "category": None,
                "group_id": None
            }
        }
        self.doers_names = set()
        self.client_names = set()
        self.add_to_description(service, "service")
        self.add_to_description(patient, "patient")
        self.add_name(patient, self.client_names)
        self.add_to_description(doer, "doer")
        self.add_name(doer, self.doers_names)
        self.final = final
        
    def __repr__(self):
        return ("service description = " + repr(self.description) + ", eniam_specs = " + repr(self.eniam_specs))
        # return ("Service.eniam_specs = " + repr(self.eniam_specs))

    @staticmethod
    def add_to_set(s, data):
        if isinstance(data, str):
            s.add(data)
        elif isinstance(data, dict):
            for value in data.values():
                Service.add_to_set(s, value)
        else:
            s.update(data)

    @staticmethod
    def from_entry(service_entry):
        return Service({}, {}, {}, "", ServiceBase([service_entry]))

    def add_to_description(self, info, info_type):
        if info:
            for (key, param), place, f in self.translator:
                if key == info_type and param in info:
                    if f is None:
                        f = Service.add_to_set
                    f(self.description[place], info[param])

    def set_business(self, bus):
        self.description["no_merging"]["business"] = bus

    def set_category(self, cat):
        self.description["no_merging"]["category"] = cat

    # def set_group_id(self, gid):
        # self.description["no_merging"]["group_id"] = gid

    def set_group_id(self, service_entry):
        if service_entry:
            logging.debug("service: " + repr(self) + " set_group_id = " + str(service_entry.group_id))
            self.description["no_merging"]["group_id"] = service_entry.group_id

    @staticmethod
    def add_name(info, names):
        if info:
            if "first_name" in info or "last_name" in info:
                names.add((info.get("first_name"), info.get("last_name")))

    def _merge(self, obj, proposed_hits=None):
        for key in self.description:
            if key != "no_merging":
                self.description[key].update(obj.description[key])
        self.doers_names.update(obj.doers_names)
        self.client_names.update(obj.client_names)

    def choose_n_best(self, n=5) -> List[Tuple[float, ServiceEntry]]:
        return self.service_base.choose_n_best(self.description, n)

    def choose_outstanding(self) -> List[ServiceEntry]:
        # best10 = self.choose_n_best(10)
        best10 = self.choose_n_best(1000000) ### KZ 2021.08.30 zmieniono z powodu implementacji wybierania z hierarchii

        ### KZ 2021.04.09 added
        if not best10:
            return []
        ### KZ 2021.04.09 end
        
        # logging.debug(repr(best10))
        best_grade = best10[0][0]
        threshold = best_grade * 0.5 * min(max(best_grade, 1.0), 1.6)
        return [s for (g, s) in best10 if g > threshold]

    def _get_params(self):
        res = {
            'service_ids[]': [s.id for s in self.choose_outstanding()]
        }
        if len(res['service_ids[]']) == 1:
            res['service_id'] = res['service_ids[]'][0]
        return res

    def grade_of_definition(self):
        grade = self.choose_n_best(1)[0][0]
        return 1 if grade >= 10 else grade / 10

    def is_ready_to_generate_hits(self):
        outstanding = self.choose_outstanding()
        # logging.debug("outstanding = " + repr(outstanding))
        groups = {s.group_id for s in outstanding}
        logging.debug("len(groups) = " + str(len(groups)))
        return len(groups) == 1

    def get_outstanding(self) -> ServiceEntry:
        best = self.choose_n_best(1)
        return best[0][1] if best else None
