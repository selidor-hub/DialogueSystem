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

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

from random import choice
# from communicators.base_communicator import make_choice_response, make_text_response
from communicators.base_communicator import make_text_response
from nlg.literals import Reset, ByeActive, ByeNeedsConfirmation, HelloWorldDemo

misses = {
    "nom": "Pani",
    "gen": "Pani",
    "dat": "Pani",
    "acc": "Panią",
    "ins": "Panią",
    "loc": "Pani",
    "voc": "Pani",
    "couldyou": "mogłaby"
}
misters = {
    "nom": "Pan",
    "gen": "Pana",
    "dat": "Panu",
    "acc": "Pana",
    "ins": "Panem",
    "loc": "Panu",
    "voc": "Panie",
    "couldyou": "mógłby"
}
unknown = {
    key: '{}/{}'.format(female, misters[key])
    for key, female in misses.items()
}

_HelloMsg = ["Dzień dobry!"]

# _HelloWorld = ["Dzień Dobry! Tu automatyczny asystent rezerwacyjny Reservis. Na jaką usługę chce się {nom} zapisać?"]
_HelloWorld = ["Tu asystent rezerwacji Reservis. W czym mogę pomóc?"]

# _ServiceWhats = ["O jaką usługę chodzi?",
                 # "Jaką usługę chce {nom} zarezerwować?",
                 # "Jaka usługa {acc} interesuje?"]
_ServiceWhats = ["Jaką usługę chcesz zarezerwować?"]
_ServiceForWhoms = ["Dla kogo ma być usługa?",
                    "Kto będzie korzystać z usługi?"]
_ServiceBusinessWhats = ["O jaką branżę chodzi?",
                         "Jaką branżę reprezentuje usługa?",
                         "Z jakiej branży jets usługa?"]
_ServiceCategoryWhats = ["O jaką kategorię chodzi?",
                         "Do jakiej kategorii należy usługa?"]
# _ServiceWhichs = ["O jaką usługę chodzi?",
                  # "O którą usługę chodzi?"]
_ServiceWhichs = ["Dostępne usługi to:"]

_TimeWhats = ["Jaki termin mam dla Ciebie zarezerwować?"] ### KZ 2021.11.30 botflow_1.02
# _TimeWhats = ["Które dni i godziny będą odpowiednie?",
              # "Jaki termin będzie odpowiedni?",
              # "Czy {couldyou} {nom} podać pasujące terminy?",
              # "W jakich dniach szuka {nom} usługi?"]
_TimeWrongMsgs = ["Podany przedział czasowy jest niepoprawny. Podaj nowy.",
                  "Wpisano niepoprawny przedział czasowy, proszę podać nowy."]

_LocationWhats = ["Proszę o podanie miasta.",
                  "Czy {couldyou} {nom} doprecyzować/sprecyzować miasto?",
                  "Proszę o określenie miejsca.",
                  "Proszę o określenie miasta.",
                  "Jakie miejsce {acc} interesuje?"]

_PriceWhats = ["Jaki przedział cenowy jest odpowiedni?",
               "Jaki przedział cenowy {acc} interesuje?",
               "Od ilu do ilu powinna kosztować usługa?"]

# (choice_injection)eg: " (spośród ...)", " (oprócz ...)"
_HourDivisionMsgs = ["Która godzina{choice} jest najbardziej odpowiednia?",
                     "Która godzina {acc} interesuje{choice}?",
                     "Proszę wskazać preferowaną godzinę{choice}."]
_WeekDayDivisionMsgs = ["Jaki dzień tygodnia{choice} jest najbardziej odpowiedni?",
                        "Który dzień tygodnia {acc} interesuje{choice}?",
                        "Proszę wskazać preferowany dzień tygodnia{choice}."]
_MonthDayDivisionMsgs = ["Które dni są najlepsze?",
                         "Które dni {acc} interesują?",
                         "Jakie dni będą odpowiednie?"]

_NoHitsMsgs = ["Nie ma wyników, zmień kryteria.",
               "Brak wyników, proszę zmienić kryteria"]
_TooManyHitsMsgs = ["Za dużo wyników, zawęź kryteria.",
                    "Zbyt duża ilość wyników, proszę zawęzić kryteria."]

_HitWhats = ["Który termin {dat} odpowiada?",
             "Który z podanych terminów będzie odpowiedni?"]
_HitChoiceNotAllowedMsgs = ["Wybrany termin niestety przestał być dostępny.",
                            "Wskazany termin niestety jest już niedostępny."]

_LimitMessages = ["Może też {nom} zawęzić parametry wyszukiwania."]


def _choose_one_from(convo_state, replies, **kwargs):
    reply = choice(replies)
    formatters = {
        **kwargs,
        **{
            "female": misses,
            "male": misters,
            "unknown": unknown
        }[convo_state.gender]
    }
    return reply.format(**formatters)


def what_service(convo_state):
    return _choose_one_from(convo_state, _ServiceWhats)


def for_whom_service(convo_state):
    return _choose_one_from(convo_state, _ServiceForWhoms)


def what_service_business(convo_state):
    return _choose_one_from(convo_state, _ServiceBusinessWhats)


def what_service_category(convo_state):
    return _choose_one_from(convo_state, _ServiceCategoryWhats)


def which_service(convo_state):
    return _choose_one_from(convo_state, _ServiceWhichs)


def what_time(convo_state):
    return _choose_one_from(convo_state, _TimeWhats)


def wrong_time_msg(convo_state):
    return _choose_one_from(convo_state, _TimeWrongMsgs)


def what_location(convo_state):
    return _choose_one_from(convo_state, _LocationWhats)


def what_price(convo_state):
    return _choose_one_from(convo_state, _PriceWhats)


def hour_division_msg(convo_state, choice_injection):
    return _choose_one_from(convo_state, _HourDivisionMsgs, choice=choice_injection)


def weekday_division_msg(convo_state, choice_injection):
    return _choose_one_from(convo_state, _WeekDayDivisionMsgs, choice=choice_injection)


def monthday_division_msg(convo_state):
    return _choose_one_from(convo_state, _MonthDayDivisionMsgs)


def no_hits_msg(convo_state):
    return _choose_one_from(convo_state, _NoHitsMsgs)


def too_many_hits_msg(convo_state):
    return _choose_one_from(convo_state, _TooManyHitsMsgs)


def what_hit(convo_state):
    return _choose_one_from(convo_state, _HitWhats)


def hit_choice_not_allowed_msg(convo_state):
    return _choose_one_from(convo_state, _HitChoiceNotAllowedMsgs)


def show_services(text, convo_state):
    logging.debug(text)
    # ret = make_choice_response(text, [convo_state.communicator.show_services_text], convo_state.list_services)
    ret = convo_state.communicator.make_choice_response(msg=text, choices=[convo_state.communicator.show_services_text], func=convo_state.list_services, asking_about=["service"])
    logging.info(repr(ret))
    return ret # KZ 2020.09.08


def hello(convo_state):
    hello_msg = _choose_one_from(convo_state, _HelloMsg)
    return hello_msg


def hello_world(convo_state):
    hw_msg = show_services(_choose_one_from(convo_state, _HelloWorld), convo_state)
    if convo_state.demo:
        return [make_text_response(HelloWorldDemo), hw_msg]
    else:
        return hw_msg


def end_conversation(convo_state):
    msg = ByeNeedsConfirmation if convo_state.params['organisation'].requires_employee_confirmation else ByeActive
    # return make_choice_response(msg, [Reset], None)
    return convo_state.communicator.make_choice_response(msg, [Reset], None)


def offer_limiting(convo_state):
    return _choose_one_from(convo_state, _LimitMessages)
