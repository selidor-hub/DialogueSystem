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

# coding: utf-8
import logging
logging_eniam = logging.getLogger("interfaces.eniam")
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")
logging_eniam.debug("Logging is configured.")

from datetime import datetime as dt, timedelta as dl
from enum import Enum

from dateutil.relativedelta import relativedelta as rd

import locale
import calendar
import json
from typing import Union
from socket import *

locale.setlocale(locale.LC_ALL, '')

from variables import TIME_GROUNDER_HOSTNAME, TIME_GROUNDER_PORT, ENIAM_CONNECT_TIMEOUT, ENIAM_RECEIVE_TIMEOUT

def ask_time_grounder(query_dct):
    text = json.dumps(query_dct, ensure_ascii=False)
    try:
        ground_parse_str = ""
        with socket(AF_INET, SOCK_STREAM) as s:  # utworzenie gniazda
            s.settimeout(ENIAM_CONNECT_TIMEOUT)
            logging.debug("connect timeout [s] =  " + str(ENIAM_CONNECT_TIMEOUT))
            s.connect((TIME_GROUNDER_HOSTNAME, TIME_GROUNDER_PORT))  # nawiązanie połączenia
            encoded_text = "{}\n\n".format(text).encode('utf8')
            logging_eniam.info("Sending to TIME_GROUNDER port " + str(TIME_GROUNDER_PORT) + ": " + encoded_text.decode('utf8').strip())
            s.send(encoded_text)
            s.settimeout(ENIAM_RECEIVE_TIMEOUT)
            logging.info("receive timeout [s] =  " + str(ENIAM_RECEIVE_TIMEOUT))
            try:
                while True:
                    tm = s.recv(4096)
                    if tm:
                        ground_parse_str += tm.decode('utf8')
                        if ground_parse_str[-2:] == "\n\n":  # na końcu odp. są 2 znaki newline
                            break
                    else:
                        break
            finally:
                s.close()
        logging_eniam.info("Received from TIME_GROUNDER:\n" + ground_parse_str.strip())
        grounder_res = json.loads(ground_parse_str)
    except json.decoder.JSONDecodeError as e:
        logging_eniam.error(str(e))
        if len(ground_parse_str) == 0:
            raise Exception("pusta odpowiedź od TIME_GROUNDER")
        else:
            raise Exception("niekompletna odpowiedź od TIME_GROUNDER: " + ground_parse_str) # KZ 2021.07.08
    except Exception as e:
        logging_eniam.error(str(e) + " " + ground_parse_str)
        raise Exception("TIME_GROUNDER: " + str(e) + " " + ground_parse_str)
    return grounder_res

def produce_time_intervals_generator(grounder_res):
    result_intervals_list = [("zgłoś_jak_to_zobaczysz_1",{"whatever": "zgłoś_jak_to_zobaczysz_2"})] ### KZ result_intervals_list jest używany w zakresie [1:] 
    try:
        dates = grounder_res["date"]
        if not isinstance(dates, list):
            dates = [dates]

        hours = grounder_res["hour"]
        if not isinstance(hours, list):
            hours = [hours]
        
        for date in dates:
            if date == "unspecified":
                date = {}
                date["at"] = dt.now().strftime("%Y-%m-%d")
            try:
                date_at = date["at"]
                for hour in hours:
                    if hour == "unspecified":
                            time_interval = (dt.strptime(date_at, "%Y-%m-%d"),
                                             dt.strptime(date_at, "%Y-%m-%d") + dl(days=1))
                    else:
                        try:
                            time_interval = (dt.strptime(date_at + " " + hour["strict"]["begin"], "%Y-%m-%d %H:%M:%S"),
                                             dt.strptime(date_at + " " + hour["strict"]["end"], "%Y-%m-%d %H:%M:%S") + dl(minutes=120))
                        except:
                            time_interval = (dt.strptime(date_at + " " + hour["strict"]["at"], "%Y-%m-%d %H:%M:%S"),
                                             dt.strptime(date_at + " " + hour["strict"]["at"], "%Y-%m-%d %H:%M:%S") + dl(minutes=120))
                    result_intervals_list.append(time_interval)
            except: # date has begin and end 
                for hour in hours:
                    if hour == "unspecified":
                        time_interval = (dt.strptime(date["begin"], "%Y-%m-%d"),
                                         dt.strptime(date["end"], "%Y-%m-%d") + dl(days=1))
                        result_intervals_list.append(time_interval)
                    else: 
                        sdate = dt.strptime(date["begin"], "%Y-%m-%d")
                        edate = dt.strptime(date["end"], "%Y-%m-%d")
                        for timestamp in pandas.date_range(sdate,edate,freq='d').tolist():
                            try: ### hour["strict"] has "begin" and "end"
                                hour_strict_begin = dt.strptime(timestamp.date().strftime("%Y-%m-%d") + " " + hour["strict"]["begin"], 
                                                               "%Y-%m-%d %H:%M:%S")
                                hour_strict_end = dt.strptime(timestamp.date().strftime("%Y-%m-%d") + " " + hour["strict"]["end"], 
                                                               "%Y-%m-%d %H:%M:%S")
                                if hour_strict_end - hour_strict_begin < dl(minutes=120):
                                    hour_strict_end = hour_strict_begin + dl(minutes=120)
                            except: ### hour["strict"] has "at"
                                hour_strict_begin = dt.strptime(timestamp.date().strftime("%Y-%m-%d") + " " + hour["strict"]["at"], 
                                                               "%Y-%m-%d %H:%M:%S")
                                hour_strict_end = hour_strict_begin + dl(minutes=120)
                            time_interval = (hour_strict_begin, hour_strict_end)
                            result_intervals_list.append(time_interval)
    except Exception as e:
        logging.exception(repr(e))
        raise e

    logging.info(repr(result_intervals_list))
    return (y for y in result_intervals_list) # generator

result_intervals_dict = {}
def ground_time_reset_generator_cache(declaration: Union[dict, str]):
    global result_intervals_dict
    result_intervals_dict.pop(str(declaration))

def ground_time_declaration(declaration: Union[dict, str], do_cut_past=False, start=None, stop=None):
    global result_intervals_dict

    result_intervals = result_intervals_dict.get(str(declaration))
    if not result_intervals:
        try:
            horizon = declaration.pop("horizon", 365)
        except:
            horizon = 365
        query_dct =   { "now": dt.now().strftime("%Y-%m-%d %H:%M:%S"),
                        "query": {"time": declaration},
                        "horizon": horizon}

        result_intervals = produce_time_intervals_generator(ask_time_grounder(query_dct))
        result_intervals_dict[str(declaration)] = result_intervals

    return result_intervals # generator

# def ask_time_category(categories):

"""
Implemented both a sequence and a mereological sum of its items.
Each sequence item is a TimeSegment, i.e. a typed pair of datetime objects
with additional info about their position in the sequence (index)
and about their relation to declaration, say approximation or flexibility.
TSSs are apt user declaration bearers.
The types of TSS are:
[minute,
hour,
time_of_day,
week_day,
month_day,
year_day,
week,
month,
year,
academic_year].
"""


class TssError(Enum):
    TOO_LATE = 0
    TOO_EARLY = 1
    OTHER = 2


def open_tss(tss):
    if tss is None:
        start = AtomicTSS.floor(dt.today(), "month")
        stop = dt.today() + dl(days=62)
        iter_tss = iter([[start, stop]])
        return None, "anytime", iter_tss
    else:
        iter_tss = iter(ground_time_declaration(tss))
        time_type, thought = next(iter_tss)
        return time_type, thought, iter_tss


def compute_ttype(*ttypes):
    """Temporary solution, add elegant type hierarchy"""
    temp_order = [
        None,
        "minute",
        "hour",
        # "time_of_day",
        "time-of-day", ### KZ 2021.10.18
        "day",
        "week_day",
        "month_day",
        "year_day",
        "week",
        "month",
        "year",
        "academic_year",
        "nonpast"
    ]
    return max(ttypes, key=lambda tp: temp_order.index(tp))


def compute_distance(expression, time_type: str):
    """convert 'little bit' before hour to 30 min timedelta -- and alike"""
    if expression is None:
        return dl(0)
    with open("source/distance modifiers.json", 'r', encoding='utf-8') as f:
        distance_modifiers = json.load(f)
    distance = distance_modifiers.get(expression, {}).get(time_type, {})
    return dl(**distance)


def aprox(tss):
    # currently empty operator, returns what it receives
    # TODO
    time_type, thought, iter_tss = open_tss(tss)
    yield time_type, ({"formal": "aprox( {decl} )".format_map({"decl": thought})})
    try:
        while True:
            yield next(iter_tss)
    except StopIteration:
        return


def identity_with_arg_mod(tss):
    # empty operator, returns 'arg' value from dict it receives
    time_type, thought, iter_tss = open_tss(tss['arg'])
    yield time_type, ({"formal": "id( {}, mod={} )".format(thought, tss['mod'])})
    try:
        while True:
            yield next(iter_tss)
    except StopIteration:
        return


def at(tss):
    return overlap([tss, {"minute": 0}])  # TODO: does it really work?


def indexed_by_groups(indexee_tss, grouper):
    def belong_to_group(i, g):
        # for interval i (shorter) and group g (longer) return True if they overlap
        belongs = g[0] <= i[0] < g[1] or g[0] < i[1] <= g[1]
        return belongs
    try:
        group = next(grouper)
        interv = next(indexee_tss)
        while interv[1] <= group[0]:
            interv = next(indexee_tss)
        ind = 0
        while True:
            while belong_to_group(interv, group):
                yield (ind, interv)
                ind += 1
                interv = next(indexee_tss)
            ind = 0
            group = next(grouper)
    except StopIteration:
        return


def indexee(tss, **kwargs):
    time_type, thought, iter_tss = open_tss(tss)
    groupby = kwargs.get("set", "future")
    grouper_name, grouper = open_tss(groupby)[1:]
    index = kwargs.get("index")
    thought = "indexee( {}, index={}, group_by={} )".format(thought, index, grouper_name)
    yield time_type, {"formal": thought}
    for pair in indexed_by_groups(iter_tss, grouper):
        if index is None or pair[0] == index:
            yield pair[1]


def cut_past(tss, **kwargs):
    time_type, thought, iter_tss = open_tss(tss)
    _1, _2, nonpast = open_tss("future")
    try:
        _start, _stop = next(nonpast)
        start = kwargs.get("start", _start)
        stop = kwargs.get("stop", _stop)
        interval = next(iter_tss)
    except StopIteration:
        yield time_type, {"error": TssError.OTHER}
        return
    if interval[0] > stop:
        # say that we only book until (n=3) months forward
        yield time_type, {
            "formal": " ..Sorry, we only book until 3 months forward ",
            "error": TssError.TOO_LATE
        }
    else:
        still_past = True
        try:
            while True:
                if start < interval[0] < stop or start < interval[1] < stop:
                    if still_past:
                        yield time_type, {"formal": thought}
                        still_past = False
                    yield interval
                interval = next(iter_tss)
        except StopIteration:
            if still_past:
                # say that the declaration seems to be in the past
                yield time_type, {
                    "formal": " ..Sorry, we don't book in the past ",
                    "error": TssError.TOO_EARLY
                }


def before(tss, **kwargs):
    time_type, thought, iter_tss = open_tss(tss)
    thought = "before( {} )".format(thought)
    cycle = AtomicTSS.get_cycle(time_type, "portato")
    yield cycle, {"formal": thought}
    try:
        while True:
            segm = next(iter_tss)
            new_beg = AtomicTSS.floor(segm[0], cycle)
            yield new_beg, segm[0]
    except StopIteration:
        return


def after(tss, **kwargs):
    time_type, thought, iter_tss = open_tss(tss)
    thought = "after( {} )".format(thought)
    cycle = AtomicTSS.get_cycle(time_type, "portato")
    yield cycle, {"formal": thought}
    try:
        while True:
            segm = next(iter_tss)
            new_end = AtomicTSS.ceiling(segm[1], cycle)
            if time_type not in ("hour", "minute"):
                new_beg = segm[1]
            else:
                new_beg = segm[0] + dl(minutes=1)
            if new_beg < new_end:
                yield new_beg, new_end
    except StopIteration:
        return


def begin(tss):
    time_type, thought, iter_tss = open_tss(tss)
    cycle = AtomicTSS.get_cycle(time_type, "portato")
    yield cycle, {"formal": "begin( {thought} )".format_map({"thought": thought})}
    try:
        while True:
            segm = next(iter_tss)
            new_end = AtomicTSS.ceiling(segm[1], cycle)
            yield (segm[0], new_end) if segm[1] < new_end else segm
    except StopIteration:
        return


def end(tss):
    time_type, thought, iter_tss = open_tss(tss)
    cycle = AtomicTSS.get_cycle(time_type, "portato")
    yield cycle, {"formal": "end( {thought} )".format_map({"thought": thought})}
    try:
        while True:
            segm = next(iter_tss)
            new_beg = AtomicTSS.floor(segm[0], cycle)
            if time_type not in ("hour", "minute"):
                yield new_beg, segm[1]
            else:  # time_type is "hour":
                yield new_beg, segm[0]
    except StopIteration:
        return


def complement(tss):
    time_type, thought, iter_tss = open_tss(tss)
    yield time_type, {"formal": "complement( {thought} )".format_map({"thought": thought})}
    cur_hind = AtomicTSS.floor(dt.today(), "day")
    stop = dt.today() + dl(days=366)
    try:
        while cur_hind < stop:
            new = next(iter_tss)
            if cur_hind < new[0]:
                yield cur_hind, new[0]
            cur_hind = new[1]
    except StopIteration:
        if cur_hind < stop:
            yield cur_hind, stop
        return


def tss_sum(args):
    """Accept TimeSegmentSequences and return their sum as a single TimeSegmentSequence.
    """
    opened_tss = map(open_tss, args)
    # collect types
    # collect thoughts
    # collect timelines
    time_types, thoughts, timelines = zip(*opened_tss)
    time_type = compute_ttype(*time_types)
    formal_thoughts = (thought["formal"] for thought in thoughts)
    yield time_type, {"formal": "{thoughts}".format_map({"thoughts": " ⊕ ".join(sorted(list(formal_thoughts)))})}
    # Expand each timeline once to get segments to compare
    segments = []
    for sequence in timelines:
        try:
            segments.append(next(sequence))
        except StopIteration:
            segments.append(None)
    while any(segments):
        # the least hindleg is the hindleg of the segment to be yielded
        # its foreleg is the current candidate for foreleg
        cur_hind, cur_fore = min([sgm for sgm in segments if sgm])
        while any(segments):
            # renew segments until all of them stick out of cur_fore
            for index in range(len(segments)):
                while segments[index] and segments[index][1] <= cur_fore:
                    try:
                        segments[index] = next(timelines[index])
                    except StopIteration:
                        segments[index] = None
            # check those that still ;ap cur_fore
            # the one that reaches the farthest will provide better cur_fore
            shaders = [sgm for sgm in segments if sgm and sgm[0] <= cur_fore]
            if shaders:
                cur_fore = max([sgm[1] for sgm in shaders if sgm])
            # if they don't, we have the winner foreleg
            else:
                yield cur_hind, cur_fore
                break


def overlap(args):
    """Accept pre-TimeSegmentSequences and return their overlap as a single TimeSegmentSequence.
    """
    opened_tss = map(open_tss, args)
    # collect types, thoughts, timelines
    time_types, thoughts, timelines = zip(*opened_tss)
    time_type = compute_ttype(*time_types)
    formal_thoughts = (thought["formal"] for thought in thoughts)
    yield time_type, {"formal": "{thoughts}".format_map({"thoughts": " ⊗ ".join(sorted(list(formal_thoughts)))})}
    # sorting of thoughts is a hack to get hours before minutes in both English and Polish for free

    # Expand each timeline once to get segments to comparet
    try:
        segments = [next(sequence) for sequence in timelines]
        while True:
            # Delimit the only possible candidate segment that can overlap all segments.
            hindleg, foreleg = \
                max(map(lambda segment: segment[0], segments)), min(map(lambda segment: segment[1], segments))
            # Check if candidate segment overlaps all segments
            if all([segment[0] <= hindleg < foreleg <= segment[1] for segment in segments]):
                yield hindleg, foreleg
            # Find out which timeline to expand next
            shortest_timeline_number = segments.index(min(segments, key=lambda segment: segment[1]))
            # Expand the shortest timeline by substituting in `segments` list
            # the segment from the shortest timeline with its successor.
            segments[shortest_timeline_number] = next(timelines[shortest_timeline_number])
    except StopIteration:
        return


operators_translator = {
    'at': at,
    'aprox': aprox,
    'distance': identity_with_arg_mod,
    'flexibility': identity_with_arg_mod,
    'element': indexee,
    'cut_past': cut_past,
    'before': before,
    'after': after,
    'begin': begin,
    'end': end,
    'not': complement,
    'complement': complement,
    'or': tss_sum,
    'sum': tss_sum,
    'and': overlap,
    'overlap': overlap,
}
# types = ['minute', 'hour', 'weekday', 'monthday', 'week', 'month', 'year', 'time_of_day']
types = ['minute', 'hour', 'weekday', 'monthday', 'week', 'month', 'year', 'time-of-day'] ### KZ 2021.10.18
available_operators = set(operators_translator.keys()).union(types)


def ground_time_declaration_OLD(declaration: Union[dict, str], do_cut_past=False, start=None, stop=None):
    logging.debug('declaration= ' + str(declaration))
    if declaration == {}:
        return NonPast()
    if isinstance(declaration, str):
        if declaration == "future":
            return NonPast()
        else:
            return AtomicTSS(declaration, do_cut_past=do_cut_past)
    cp_decl = declaration.copy()
    if do_cut_past:
        # cut past is the very last operator used always
        cp_decl = {
            "cut_past": cp_decl,
        }
        if start is not None:
            cp_decl["start"] = start
        if stop is not None:
            cp_decl["stop"] = stop
    mentioned_operators = available_operators & cp_decl.keys()
    if not mentioned_operators:
        if not isinstance(cp_decl, dict):
            raise Exception("Time declaration is not even a dict.")
        else:
            # logging.debug("available_operators = " + str(available_operators))
            # logging.debug("cp_decl.keys() = " + str(cp_decl.keys()))
            # logging.debug("mentioned_operators = " + str(mentioned_operators))
            # logging.debug("type(cp_decl) = " + str(type(cp_decl)))
            raise Exception("I cannot recognize the operator in {}".format(str(cp_decl.keys())))
    elif len(mentioned_operators) > 1:
        if not set(cp_decl.keys()).issubset(available_operators):
            raise Exception("Loose operators:{}".format(str(cp_decl.keys())))
        else:
            return overlap([{k: v} for k, v in cp_decl.items()])

    operator_name = mentioned_operators.pop()

    # compute the mentioned operator on its args
    # first arg is given as operator's val in declaration
    # and operator's siblings provide remaining **kwargs
    if operator_name in types:
        val = cp_decl.pop(operator_name)
        restr = val if val != {} else None
        if isinstance(restr, dict) and 'and' in restr:
            outcome = tss_sum([{operator_name: r, **cp_decl} for r in restr['and']])
        else:
            outcome = AtomicTSS(operator_name, restr=restr, do_cut_past=do_cut_past, **cp_decl)
    else:
        f = operators_translator[operator_name]
        first_arg = cp_decl.pop(operator_name)
        if isinstance(first_arg, dict) and len(first_arg) > 1 and set(first_arg.keys()).issubset(types):
            first_arg = {'and': [{k: v} for k, v in first_arg.items()]}
        outcome = f(first_arg, **cp_decl)
    return outcome


class NonPast:
    def __init__(self):
        self.time_type = None
        self.start = dt.today()
        self.stop = self.start + dl(weeks=52)

    def __iter__(self):
        yield "nonpast", {"formal": "nonpast"}
        yield self.start, self.stop


class AtomicTSS:
    """
    A simple TimeSegmentSequence obtained from 'type' attribute
    with 'restr' (PortatoTSS) or without (LegatoTSS).
    If restr not defined:
        yield legato TSS where period = time_type
    If restr:
        yield portato TSS where period > time_type
        eg. for {type: month, restr: 11} period = year
    """

    def __init__(self, time_type, **kwargs):
        if time_type in ["day", "monthday"]:
            self.time_type = "month_day"
        elif time_type == "weekday":
            self.time_type = "week_day"
        else:
            self.time_type = time_type
        self.start = self.floor(kwargs.get("start", self.floor(dt.today(), "month")), self.time_type)
        self.stop = kwargs.get("stop")
        if not self.stop:
            self.stop = dt.today() + dl(weeks=52)

        self.restr = kwargs.get("restr")
        # if time_type == "time_of_day" and self.restr and "time_of_day_mod" in kwargs:
            # self.restr = "{}_{}".format(kwargs["time_of_day_mod"], self.restr)
        if time_type == "time-of-day" and self.restr and "time-of-day-mod" in kwargs: ### KZ 2021.10.18
            self.restr = "{}_{}".format(kwargs["time-of-day-mod"], self.restr)
        if self.restr is None:
            self.restr = ""
            self.articulation = "legato"
            self.period = self.get_cycle(self.time_type, "legato")
        else:
            self.articulation = "portato"
            self.period = self.get_cycle(self.time_type, "portato")

    def __iter__(self):
        if self.articulation == "legato":
            hindleg = self.floor(self.start, self.time_type)
            foreleg = self.period_up(hindleg, self.period)

        elif self.articulation == "portato":
            # Case minute or hour
            if self.time_type in ("minute", "hour"):
                time_attr_name = self.get_cycle(self.time_type, "legato")
                logging.debug("time_attr_name = " + str(time_attr_name))
                logging.debug("self.restr = " + str(self.restr))
                hindleg = self.start.replace(**{time_attr_name: self.restr})
                foreleg = self.period_up(hindleg, time_attr_name)

            # Case month_day
            elif self.time_type == "month_day":
                # make sure the month is long enough
                while calendar.monthrange(self.start.year, self.start.month)[1] < self.restr:
                    self.start = self.period_up(self.start, "month")

                time_attr_name = self.get_cycle(self.time_type, "legato")
                hindleg = self.start.replace(**{time_attr_name: self.restr})
                foreleg = self.period_up(hindleg, time_attr_name)

            # Case week_day
            elif self.time_type == "week_day":
                cur_wd = self.start.isoweekday()
                day_delta = (self.restr - cur_wd + 7) % 7
                time_attr_name = self.get_cycle(self.time_type, "legato")
                hindleg = self.start + dl(day_delta)
                foreleg = self.period_up(hindleg, time_attr_name)

            # Case month
            elif self.time_type == "month":
                year_delta = 1 if self.start.month > self.restr else 0
                time_attr_name = self.get_cycle(self.time_type, "legato")
                replacement = {
                    "year": self.start.year + year_delta,
                    "month": self.restr
                }
                hindleg = self.start.replace(**replacement)
                foreleg = self.period_up(hindleg, time_attr_name)

            # Case year
            elif self.time_type == "year":
                time_attr_name = self.get_cycle(self.time_type, "legato")
                hindleg = dt(self.restr, 1, 1)
                foreleg = self.period_up(hindleg, time_attr_name)
                if foreleg <= self.stop:
                    self.stop = foreleg

            # Case time_of_day
            # elif self.time_type == "time_of_day":
            elif self.time_type == "time-of-day": ### KZ 2021.10.18
                hindleg, foreleg = self.find_time_of_day(self.start, self.restr)
            else:
                raise Exception("Unrecognised time type ({}) in iter".format(self.time_type))

        yield self.time_type, {"formal": "{}({})".format(self.time_type, self.restr)}
        while True:
            if self.start <= hindleg < self.stop:
                yield hindleg, foreleg
            if self.stop < foreleg:
                break
            hindleg = self.period_up(hindleg, self.period)
            while foreleg <= hindleg:
                foreleg = self.period_up(foreleg, self.period)

    @staticmethod
    def find_time_of_day(start: dt, time_type: str):
        times_of_day = {
            "early_morning": (6, 8),
            "late_morning": (9, 12),
            "pre_morning": (3, 9),
            "morning": (6, 10),
            "early_afternoon": (12, 15),
            "late_afternoon": (15, 19),
            "before_noon": (8, 12),
            "afternoon": (6, 18),
            "early_evening": (18, 20),
            "late_evening": (20, 23),
            "evening": (18, 22),
            "night": (22, 6)
        }
        begin, end = times_of_day[time_type]
        if begin < end:
            hindleg = start.replace(hour=begin)
            foreleg = start.replace(hour=end)
        else:
            hindleg = start.replace(hour=begin)
            foreleg = start.replace(day=start.day + 1, hour=end)
        return hindleg, foreleg

    @staticmethod
    def cross(first_date: str, second_date: str, index: int):
        return first_date[:index] + second_date[index:]

    @staticmethod  # objectify
    def get_cycle(time_type: str, articulation: str):
        return {
            "minute":
                {"legato": "minute", "portato": "hour"},
            "hour":
                {"legato": "hour", "portato": "day"},
            # "time_of_day":
            "time-of-day": ### KZ 2021.10.18
                {"portato": "day"},
            "week_day":
                {"legato": "day", "portato": "week"},
            "month_day":
                {"legato": "day", "portato": "month"},
            "year_day":
                {"legato": "day"},
            "day":
                {"legato": "day", "portato": "day"},
            "week":
                {"legato": "week"},
            "month":
                {"legato": "month", "portato": "year"},
            "year":
                {"legato": "year", "portato": "year"},
            None:
                {"legato": None, "portato": None},
            "academic_year":
                {"legato": "year", "portato": "year"}
        }[time_type][articulation]

    @classmethod
    def ceiling(cls, dtime: dt, cycle):
        out = cls.period_up(dtime, cycle) + dl(0, 0, -1)
        return cls.floor(out, cycle)

    @classmethod
    def floor(cls, dtime: dt, time_type: str):
        """round down dtime to full time_type"""
        level = {
            "minute": 16,
            "hour": 14,
            "day": 11,
            "week_day": 11,
            "month_day": 11,
            "year_day": 11,
            "month": 8,
            "year": 5,
            # "time_of_day": 14
            "time-of-day": 14 ### KZ 2021.10.18
        }

        if time_type in level:
            iso_str = cls.cross(dtime.isoformat(), "DUMM-01-01T00:00", level[time_type])
        elif time_type == "academic_year":
            if dtime.month < 10:
                dtime = dtime.replace(year=dtime.year - 1)
            iso_str = cls.cross(dtime.isoformat(), "DUMM-10-01T00:00", level["year"])
        elif time_type == "week":
            last_monday = dtime - dl(dtime.weekday())
            iso_str = cls.cross(last_monday.isoformat(), "DUMM-10-01T00:00", level["day"])
        else:
            return NotImplementedError

        return dt.strptime(iso_str, '%Y-%m-%dT%H:%M')

    @classmethod
    def period_up(cls, dtime, period, how_many_up=1):
        STEP_LENGTH = {
            "minute": {"minutes": how_many_up},
            "hour": {"hours": how_many_up},
            "time_of_day": {"days": how_many_up},
            "time-of-day": {"days": how_many_up}, ### KZ 2021.10.18
            "day": {"days": how_many_up},
            "week_day": {"days": how_many_up},
            "month_day": {"days": how_many_up},
            "year_day": {"days": how_many_up},
            "week": {"days": 7 * how_many_up},
        }

        if period in ["year", "academic_year"]:
            return dtime.replace(year=dtime.year + how_many_up)
        elif period in STEP_LENGTH:
            return dtime + dl(**STEP_LENGTH.get(period))
        elif period in ["month"]:
            while (dtime + rd(months=how_many_up)).day != dtime.day:
                how_many_up += 1
            return dtime + rd(months=how_many_up)
        else:
            raise NotImplementedError(period)
