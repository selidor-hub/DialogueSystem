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
from collections import OrderedDict
# import pandas as pd

from anytree.importer import DictImporter
from anytree import AnyNode, RenderTree, NodeMixin, find_by_attr, search

import math
from difflib import SequenceMatcher

import requests

from communicators.base_communicator import make_choice_response
from utils.config import load_json_cfg
from variables import ELASTIC_URL
from nlg.literals import HitChoiceRegistered, AskIfConfirmation, WantConfirmationOnMail, WantConfirmationAsFile, \
    Confirm, NotConfirm, ConfirmationOfCorrectness, ReservationFailure, No, Yes, AskIfSendToThisMail, \
    AskForAnotherMail, NoServices, Reset, ConfirmationDemo, Resign, ChangeData, ByeFailure

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

PARAM_WEIGHT = 0.7
NAME_WEIGHT = 0.2
REQ_WEIGHT = 0.1

class ServiceEntry:
    _params = ['keywords', 'params', 'patients', 'professions', 'parts']

    @property
    def group_representative(self):
        if not self.representative:
            self.representative = self.service_base.find_by_id(self.group_id)
        return self.representative

    def __init__(self, service_base, entry_dict, types):
    # def __init__(self, service_base, entry_dict, types, services_root): ### KZ 2021.06.18
        # logging.debug('entry_dict= ' + repr(entry_dict) + ', types= ' + repr(types))
        # logging.debug('entry_dict= ' + repr(entry_dict))
        # logging.debug('services_root =\n' + str(RenderTree(services_root)))
        self.service_base = service_base
        # self.services_root = services_root
        # self.id = entry_dict['id']
        self.id = str(entry_dict['id'])
        self.duration = entry_dict.get('duration_in_minutes', 30)
        self.group_id = entry_dict.get('group') or self.id
        self.representative = self if self.id == self.group_id else self.service_base.find_by_id(self.group_id)
        self.business = entry_dict.get('business')
        self.category = entry_dict.get('category')
        self.parent = entry_dict.get('parent')
        self.children = entry_dict.get('children')
        self.name = entry_dict['name']
        self.keywords = set(entry_dict.get('keywords', []))
        self.params = set(entry_dict.get('params', []))
        self.patients = set(entry_dict.get('patients', [])) # można pobrać synonimy do "patient_subtypes"
        self.patient_types = set(entry_dict.get('patient_types', []))
        self.patient_subtypes = set(entry_dict.get('patient_subtypes', []))
        self.professions = set(entry_dict.get('professions', []))
        self.parts = set(entry_dict.get('parts', []))
        self.types = types
        self.defined = len([t for t in [self.keywords, self.params, self.patients, self.professions, self.parts] if t])

# KZ 2021.02.17 dodano pola z globalnej listy usług
        self.domain = set(entry_dict.get('domain', []))
        self.tool = set(entry_dict.get('tool', []))
        self.effect = set(entry_dict.get('effect', []))
        self.organisation_type = set(entry_dict.get('organisation_type', []))
# KZ end

        self.recognised_vals = set()

# KZ 2021.03.30 dodano IDs z globalnej listy usług
        self.global_ids = entry_dict.get('global_ids', [self.id])
        # self.global_ids = entry_dict['global_ids']
        # logging.debug("self.name = " + str(self.name))
        # logging.debug("self.global_ids = " + str(self.global_ids))
        # logging.debug("self.global_ids_and_parents = " + str(self.global_ids_and_parents))
        
        self.key_for_selection = self.id

        for p_type in self.patient_types:
            self.recognised_vals.update(self.types['recognised'][p_type])
        self.subtypes_vals = set()
        for subtype in self.patient_subtypes:
            self.subtypes_vals.update(self.types['subtypes'][subtype])

    def __repr__(self):
        # return 'Service({}, {}, {})'.format(self.id, self.category, self.name)
        return 'ServiceEntry(id = {}, global_ids = {}, category = {}, name = {})'.format(self.id, str(self.global_ids), self.category, self.name)

    def make_service_tree(self, services_root):
        # logging.debug("entry = " + repr(self))
        try:
            assert self.global_ids, "No global_ids for: " + repr(self)
            self.service_node = find_by_attr(services_root, name="id", value=self.global_ids[0]) # tylko 1. global_id
            assert self.service_node is not None, "self.name = " + str(self.name) + ", self.global_ids = " + str(self.global_ids) + " has no service_node"
            self.service_node.is_in_service_base = True
            # logging.debug("self.service_node.is_in_service_base = " + str(self.service_node.is_in_service_base))
            parent = self.service_node.parent
            while parent:
                parent.is_in_service_base = True
                parent = parent.parent
        except Exception as e:
            logging.error(str(e))
            # raise e  ### KZ można tymczasowo wykomentować aby szukać usług brakujących w tabeli

    def requirement_grade(self, desc):
        """
        0.0 if wrong type, business, category or group_id
        0.0 if subtypes defined, recognised words used but no for given subtypes
        0.5 if no subtypes defined for entry
        0.5 if subtypes defined but no recognised words used
        2.0 if subtypes defined and words for given subtypes used
        """
        if (self.patient_types and desc['patient_types'] and not desc['patient_types'] & self.patient_types)\
                or (desc["no_merging"]["business"] and desc["no_merging"]["business"] != self.business)\
                or (desc["no_merging"]["category"] and desc["no_merging"]["category"] != self.category)\
                or (desc["no_merging"]["group_id"] and desc["no_merging"]["group_id"] != self.group_id):
            return 0.0
        elif self.subtypes_vals:
            all_params = set()
            for key in self._params:
                all_params.update(desc[key])
            if self.recognised_vals & all_params:
                return 2.0 * int(bool(self.subtypes_vals & all_params))
            else:
                return 0.5
        else:
            return 0.5

    @staticmethod
    def set_intersection_grade(set1, set2, weight=1.0):
        i_len = len(set1 & set2)
        return weight * (2 - math.pow(0.5, i_len - 1)) if i_len else 0

    def grade(self, description):
        req_grade = self.requirement_grade(description)
        if req_grade == 0:
            return 0
        marks = sum([
            self.set_intersection_grade(description['keywords'], self.keywords, 1),
            self.set_intersection_grade(description['params'], self.params, 1),
            self.set_intersection_grade(description['patients'], self.patients, 0.5),
            self.set_intersection_grade(description['professions'], self.professions, 0.5),
            self.set_intersection_grade(description['parts'], self.parts, 0.5)
        ])
        param_grade = 0 if self.defined == 0 else math.pow(marks, 2)

        name_grade = 0
        for text in description['texts']:
            pre_new_grade = SequenceMatcher(None, text.lower(), self.name.lower()).ratio()
            new_grade = 0.1/((1 - pre_new_grade) + 0.1)
            name_grade = max(name_grade, new_grade)
        if name_grade == 1:
            return 1

        final_grade = req_grade * REQ_WEIGHT + param_grade * PARAM_WEIGHT + name_grade * NAME_WEIGHT
        return final_grade

class ServiceBase:
    def __init__(self, entries=None):
        class ServiceNode(AnyNode):
            def __init__(self, *args, **kwargs):
                super().__init__(*args, **kwargs)
                self.is_in_service_base = False
                self.key_for_selection = self.name
            # def __eq__(self, other):
                # return self.name == other.name
            # def __hash__(self):
                # return hash(('name', self.name))

        if entries:
            logging.debug("len(entries) = " + str(len(entries)))
        else:
            logging.debug("entries = " + str(entries))
        self.types = load_json_cfg('types.json')
        self.entries = []
        try:
            self.global_service_list = load_json_cfg('services.json')
            logging.debug("LENGTH global_service_list: " + str(len(self.global_service_list)))
            if entries is None:
                entries = self.global_service_list
                logging.debug("entries is None -> will self.parse_entries(self.global_service_list)")

            self.services_tree_dct = load_json_cfg('services_tree.json')
            self.importer = DictImporter(nodecls=ServiceNode)
            
            self.initial_entries = entries ### KZ 2021.04.01 added
            self.parse_entries(entries)

        except search.CountError as e: ### KZ tymczasowo do debuggingu tabeli,  potem wykasować
            logging.error(str(e))
        except Exception as e:
            logging.exception(str(e), stack_info=False)
            raise e
        logging.debug("LENGTH ENTRIES: " + str(len(self.entries)), stack_info=False)
            

    ### KZ 2021.04.01 added
    def intersect_entries_by_ids(self, global_ids):
        logging.debug("Intersecting " + str(len(self.entries)) + " service_base.entries with " + str(len(global_ids)) + " global_ids")
        # logging.debug("\n" + "\n".join("id={}, name={}, global_ids={}".format(e.id, e.name, e.global_ids) for e in self.entries))
        # logging.debug("global_ids = " + str(global_ids))
        self.entries = []
        self.parse_entries(self.initial_entries)
        found_entries = []
        for gid in global_ids:
            found = self.find_by_global_id(gid)
            if found:
                found_entries.append(found)
        self.entries = []
        self.parse_entries(found_entries)
        
        logging.debug("LENGTH ENTRIES: " + str(len(self.entries)))
        
        def find_global_service_by_gid(g_id, global_service_list):
            for g_e in global_service_list:
                if str(g_e["id"]) == g_id:
                    return g_e
            return None
            
        for e in self.entries:
            if not find_global_service_by_gid(e.global_ids[0], self.global_service_list):
                raise Exception("Nie odnaleziono usługi " + str(e.global_ids[0]) + " na globalnej liście usług.")
        # logging.debug("ENTRIES = \n" + "\n".join("local id='{}', name='{}', global id='{}', name='{}', tabela='{}'".format(e.id, e.name, e.global_ids[0], find_global_service_by_gid(e.global_ids[0], self.global_service_list)["name"], e.service_node.name) for e in self.entries))

        # logging.debug(str(RenderTree(self.services_root)))

    def find_by_global_id(self, gid):
        for entry in self.entries:
            # logging.debug("looking for " + gid + " in " + repr(entry.global_ids))
            for e_gid in entry.global_ids:
                if e_gid == gid:
                    return entry
        return None

    def find_by_name(self, name):
        for entry in self.entries:
            if entry.name == name:
                return entry
        return None

    def find_by_global_name(self, name):
        for entry in self.entries:
            if entry.service_node.name == name:
                return entry
        return None

    def find_by_id(self, eid):
        for entry in self.entries:
            if entry.id == eid:
                return entry
        return None

    def parse_entries(self, entries):
        # logging.debug(str(len(entries)) + " entries")
        for entry in entries:
            if not isinstance(entry, ServiceEntry):
                # logging.debug("entry = " + repr(entry))
                entry = ServiceEntry(self, entry, self.types)
            self.entries.append(entry)
        # KZ 2021.07.15
        self.services_root = self.importer.import_(self.services_tree_dct)
        assert self.services_root, "No services_tree imported"
        # logging.debug("services tree =\n" + str(RenderTree(self.services_root)))
        for entry in self.entries:
                entry.make_service_tree(self.services_root)
        # logging.debug(' '.join(str(e.id) + ' ' + e.name + ', ' for e in self.entries))
        # logging.debug("LENGTH ENTRIES: " + str(len(self.entries)))

    def choose_n_best(self, description, n=5):
        # logging.debug(repr(description), stack_info=False)
        # self.choose_elastic_best(description)
        # logging.debug("len(service_base.entries) = " + str(len(self.entries)), stack_info=False)
        grades = [(entry.grade(description), entry) for entry in self.entries]
        # logging.debug(repr(grades[:15]) + ' ...')
        return sorted(grades, key=(lambda t: (t[0], t[1].id)), reverse=True)[:n]


    def generate_list_msg(self, convo_state):
        if len(self.entries) == 0:
            return convo_state.communicator.make_choice_response(NoServices, [Reset], None)
        else:
            return convo_state.communicator.make_choice_response(msg="", choices=self.entries, func=convo_state.on_service_chosen, asking_about=['service'])

    @staticmethod
    def choose_elastic_best(description):
        headers = {'Content-Type': 'application/x-www-form-urlencoded'}
        elastic_params = {
            "eniam_declaration": {
                "full_text": ' '.join(description['texts'])
            }
        }
        request = requests.post(ELASTIC_URL, data='data={}'.format(json.dumps(elastic_params)), headers=headers)
        logging.info(json.loads(request.text))
        # TODO
        
