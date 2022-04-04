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

# from communicators.base_communicator import make_choice_response
from definitions import PARAMETERS_TRANSLATOR, TIME_PERIOD_TRANSLATOR, LOCATION_FIELD_TRANSLATOR
from nlg.literals import AM, PM, WhichHour, WhichParameter, WhichTimePeriod, WhichDefault, WhichLocationField

# import os
# import logging
# import logging.config
# import yaml
# from definitions import CONFIGURATION_ROOT
# with open(os.path.join(CONFIGURATION_ROOT, "log_config.yaml"), 'r') as config:
    # logging.config.dictConfig(yaml.load(config))
# logging = logging.getLogger(__name__)
# logging.debug("Logging is configured.")

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")


def not_sure_what_parameter(options):
    return all([isinstance(o, dict) and len(o) == 1 and
                list(o.keys())[0] in PARAMETERS_TRANSLATOR for o in options])


def not_sure_which_time_period(options):
    return all([isinstance(o, dict) and
                tuple(sorted(o.keys())) in TIME_PERIOD_TRANSLATOR for o in options])


def not_sure_which_location_field(options):
    return all([isinstance(o, dict) and len(o) == 1 and
                list(o.keys())[0] in LOCATION_FIELD_TRANSLATOR for o in options])


def not_sure_which_hour(options):
    return len(options) == 2 \
           and isinstance(options[0], int) \
           and isinstance(options[1], int) \
           and abs(options[1]-options[0]) == 12


def get_options_representative(options, convo_state):
    for option in options:
        if isinstance(option, dict) and len(option) == 1:
            candidate = next(iter(option.values()))
            if isinstance(candidate, (int, str)):
                return candidate
    return '"{}"'.format(convo_state.withs[2])


def generate_question(convo_state):
    options_numbered = sorted([(o, i) for (i, o) in enumerate(convo_state.withs[0])],
                              key=lambda x: list(x[0]) if isinstance(x[0], dict) else x[0])
    options = [o for (o, i) in options_numbered]
    logging.debug("options = " + repr(options))
    asking_about=[]
    if not_sure_what_parameter(options):
        text = WhichParameter.format(get_options_representative(options, convo_state))
        args = [(PARAMETERS_TRANSLATOR[list(d.keys())[0]], i) for (d, i) in options_numbered]
    elif not_sure_which_time_period(options):
        text = WhichTimePeriod.format(get_options_representative(options, convo_state))
        args = [(TIME_PERIOD_TRANSLATOR[tuple(sorted(d.keys()))], i) for (d, i) in options_numbered]
    elif not_sure_which_location_field(options):
        text = WhichLocationField.format(get_options_representative(options, convo_state))
        args = [(LOCATION_FIELD_TRANSLATOR[list(d.keys())[0]], i) for (d, i) in options_numbered]
    elif not_sure_which_hour(options):
        text = WhichHour.format(options[0])
        args = [(AM, options_numbered[0][1]), (PM, options_numbered[1][1])]
    else:
        with_options = ['{}. {}'.format(i, json.dumps(w)) for i, w in enumerate(options, start=1)]
        text = '\n'.join([WhichDefault, *with_options])
        args = [(str(i), i - 1) for i, _ in enumerate(options, start=1)]
        logging.debug("args = " + repr(args))
        logging.warning('desambiguation.generate_question: do not know what to do with - {}'.format(options), stack_info=False)
        asking_about=["quantity"]
    choices = OrderedDict([(k, v) for (k, v) in args if k is not None])
    logging.debug("choices = " + repr(choices))
    logging.debug("text = " + repr(text))
    convo_state._withs = convo_state.withs
    return convo_state.communicator.make_choice_response(text, choices, convo_state.resolve_desambiguation, asking_about=asking_about)


def establish_if_am_or_pm(time_of_day):
    return {
        'morning': min,
        'afternoon': max,
        'evening': max
    }.get(time_of_day)


def matching_to_context(obj, context):
    found_matches = []
    if context:
        if isinstance(obj, list):
            if all(isinstance(x, dict) for x in obj):
                found_matches = [dic for dic in obj if context[0] in dic.keys()]
            elif not_sure_which_hour(obj):
                if isinstance(context[0], str):
                    f = establish_if_am_or_pm(context[0])
                    if f:
                        found_matches = [f(obj)]
                elif isinstance(context[0], list):
                    intersection = list(set(obj) & set(context[0]))
                    if len(intersection) == 1:
                        found_matches = intersection
        elif isinstance(obj, dict):
            found_matches = [obj] if not isinstance(context[0], list) and context[0] in obj else []
    return found_matches


def change_context(context, objects):
    # change context based on existence of time_of_day
    if context == [] or context == ['hour']:
        # time_of_days = [o['time_of_day'] for o in objects if isinstance(o, dict) and 'time_of_day' in o]
        time_of_days = [o['time-of-day'] for o in objects if isinstance(o, dict) and 'time-of-day' in o] ### KZ 2021.10.18
        if time_of_days:
            return ['hour', time_of_days[0]]
    if context == [] or context == ['hour'] or context == ['time', 'hour']:
        times = [o['time'] for o in objects if isinstance(o, dict) and 'time' in o]
        # time_of_days = [o['time_of_day'] for o in times if isinstance(o, dict) and 'time_of_day' in o]
        time_of_days = [o['time-of-day'] for o in times if isinstance(o, dict) and 'time-of-day' in o] ### KZ 2021.10.18
        if time_of_days:
            return ['time', 'hour', time_of_days[0]]
    return context


def merge_list(objects):
    """
    [{"time": a}, {"price": 100}, {"time": b}] ->  [{"time": {"and": [a, b]}}, {"price": 100}]
    """
    merged = []
    keys_indexes = {}  # key: i => merged[i] = {key: ...}
    for d in objects:
        if isinstance(d, dict) and len(d) == 1:
            key = list(d.keys())[0]
            if key in keys_indexes:
                merging_with = merged[keys_indexes[key]][key]
                if isinstance(merging_with, dict) and 'and' in merging_with:
                    ands = [*merging_with['and'], d[key]]
                else:
                    ands = [merging_with, d[key]]
                merged[keys_indexes[key]] = {key: {"and": ands}}
                continue
            else:
                keys_indexes[key] = len(merged)
        merged.append(d)
    return merged


def desambiguate(obj, context, choices, choose_first=False, neighbours=None):
    logging.debug('obj= ' + repr(obj) + ', context= ' + repr(context) + ', choices= ' + repr(choices) + \
                  ', choose_first= ' + repr(choose_first) + ', neighbours= ' + repr(neighbours))
    if isinstance(obj, dict):
        ### KZ 2021.03.05
        if 'client_declaration' in obj:
            obj = obj['client_declaration']
        ### KZ end
            
        if 'with' not in obj:
            if matching_to_context(obj, context):
                context = context[1:]
            for key in obj:
                replacement_with, replacement = desambiguate(obj[key], context, choices, choose_first)
                if isinstance(replacement, list) and len(replacement) == 1 \
                        and isinstance(replacement[0], dict) and len(replacement[0]) == 1 \
                        and list(replacement[0].keys())[0] not in obj:
                    new_key = list(replacement[0].keys())[0]
                    del obj[key]
                    obj[new_key] = replacement[0][new_key]
                else:
                    obj[key] = replacement
                if replacement_with is not None:
                    return replacement_with, obj
            if len(obj) == 1 and ('and' in obj or 'or' in obj) and len(obj.get('and') or obj.get('or')) == 1:
                return None, (obj.get('and') or obj.get('or'))[0]
            else:
                return None, obj
        else:
            matches = matching_to_context(obj["with"], context)
            if matches:
                return desambiguate(matches[0], context, choices, choose_first)
            elif obj['with'] in [options for (options, chosen) in choices]:
                chosen = next((chosen for (options, chosen) in choices if options == obj['with']))
                choice = obj['with'][chosen]
                return desambiguate(choice, context, choices, choose_first)
            elif choose_first:
                return desambiguate(obj['with'][0], context, choices, choose_first)
            elif neighbours is not None and [o for o in obj['with'] if o in neighbours]:
                return None, None
            # elif do_no
            else:
                return obj['with'], obj
    elif isinstance(obj, list):
        desambiguated = []
        context = change_context(context, obj)
        for d in obj:
            d_with, new_d = desambiguate(d, context, choices, choose_first, obj)
            if d_with is not None:
                return d_with, obj
            elif new_d is not None:
                desambiguated.append(new_d)

        return None, merge_list(desambiguated)
    else:
        return None, obj
