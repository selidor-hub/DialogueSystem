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
import urllib.request

import requests
import json

from utils.fields import field_factory
from utils.hits import Hits
from variables import RESERVIS_URL

import logging
logging = logging.getLogger(__name__)
logging.debug("Logging is configured.")

def reservis_hits(params):
    get_params = {
        'service_ids': 1,
        'value_kind': 'date'
    }
    for item in params.values():
        if item is not None:
            item_params = item.get_params()
            get_params.update(item_params)
    try:  # TODO: when too many params, reservis returns zero hits
        logging.info(RESERVIS_URL + 'brickSchedule/getavailablecells ' + str(get_params))
        response = requests.get(RESERVIS_URL + 'brickSchedule/getavailablecells', params=get_params)
        # logging.debug(response)
    ### KZ 2021.03.17
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        raise e

        # if response.status_code != 200:
            # logging.error('reservis.reservis_hits: Status code - {}'.format(response.status_code))
            # return Hits.empty(params)
    try:
        json_response = response.json()
        # logging.debug("json_response = " + str(json_response))
        schedule = json_response['schedule']
        ### KZ 2021.03.15
        if '' not in schedule: # new version of reservis nie ma klucza ''
            sched = {}
            for key in schedule:
                sched.update(schedule[key])
            schedule = {}
            schedule[''] = sched
        ### KZ end
        cells = schedule[''] if schedule else dict()
        logging.debug("NUMBER cells = " + str(len(cells)))
        return Hits.from_reservis(cells, params)
    except (KeyError, json.decoder.JSONDecodeError) as e:
        raise e
        # return Hits.empty(params)


def needed_client_data(convo_state, organisation_code, service_id, division_no=0):
    logging.info(RESERVIS_URL + 'main/getdata' + "params={'code': " + organisation_code + '}')
    try:
        req = requests.get(RESERVIS_URL + 'main/getdata', params={'code': organisation_code})
        logging.debug(req)
    ### KZ 2021.03.17
        req.raise_for_status()
    except requests.exceptions.RequestException as e:
        raise e
    try:
        response = req.json()
        division_field_rules = response['Divisions'][division_no]['FieldRules']
        service = next((s for s in response['Services'] if s['id'] == service_id), None)
        if service is None:
            # FIXME: log error
            return []
        service_field_rules = [s for s in service['ServiceDivisions'][division_no]['FieldRules']
                               if not any([f['field_kind_id'] == s['field_kind_id'] and
                                           f['client_kind_id'] == s['client_kind_id'] for f in division_field_rules])]
        division_fields = [field_factory(convo_state, f) for f in division_field_rules if f['client_kind_id'] == '1']
        service_fields = [field_factory(convo_state, f) for f in service_field_rules if f['client_kind_id'] == '1']
    except (KeyError, json.decoder.JSONDecodeError) as e:
        logging.exception(e)
        raise e
    additional_service_fields = []  # TODO
    return [*division_fields, *service_fields]


def get_confirmation_file(organisation_code, reservation_code):
    url = RESERVIS_URL + \
          'print/reservationcustomerpdf?code={}&reservation_code={}&color=1&orientation=P'.format(organisation_code,
                                                                                                  reservation_code)
    filename = '/tmp/{}.pdf'.format(reservation_code)
    urllib.request.urlretrieve(url, filename)
    return filename


def action_on_temporary_reservation(hit, extend=True):
    if extend and hit.booking_id is None:
        return False
    params = {
        'code': hit.organisation_id,
        'Booking[client_kind_id]': 1,
        'Booking[currency_id]': 1,
        'Booking[division_id]': hit.division_id,
        'Booking[id]': None if not extend else hit.booking_id,
        'Booking[is_auto_employee]': 1,
        'Booking[is_service_in_order]': 0,
        'Booking[override_free_time]': 0,
        'Booking[start_at]': str(hit.date),
        'BookingService[0][duration_in_minutes]': hit.duration,
        'BookingService[0][is_custom]': 0,
        'BookingService[0][position]': 1,
        'BookingService[0][service_id]': hit.service_id,
        'client_kind_id': 1,
        'ClientMessageApproval[approvals][business][email]': 0,
        'ClientMessageApproval[approvals][business][sms]': 0,
        'ClientMessageApproval[approvals][system][email]': 0,
        'ClientMessageApproval[approvals][system][sms]': 0,
    }
    if extend:
        params['BookingService[0][id]'] = hit.booking_id2
    else:
        params['BookingService[0][create]'] = 1
    logging.info(json.dumps(params, ensure_ascii=False, sort_keys=True, indent=2, separators=(',', ': ')))
    response = requests.post(RESERVIS_URL + 'booking/save', params=params).json()
    # logging.debug(response)
    logging.info("response['success'] = " + json.dumps(response['success']))
    if response['success'] != 1 or len(response['Booking']['BookingServices']) != 1:
        logging.info(json.dumps(response, ensure_ascii=False, sort_keys=True, indent=2, separators=(',', ': ')))
        return False
    else:
        hit.booking_id = response['Booking']['BookingServices'][0]['id']
        hit.booking_id2 = response['Booking']['BookingServices'][0]['booking_id']
    return True


def do_temporary_reservation(hit):
    return action_on_temporary_reservation(hit) or action_on_temporary_reservation(hit, extend=False)


def do_reservation(hit, fields):
    params = {
        'code': hit.organisation_id,
        'client_kind_id': 1,
        'ClientMessageApproval[approvals][business][email]': 0,
        'ClientMessageApproval[approvals][business][sms]': 0,
        'ClientMessageApproval[approvals][system][email]': 0,
        'ClientMessageApproval[approvals][system][sms]': 0,
        'Reservation[booking_id]': hit.booking_id,
        'Reservation[client_kind_id]': 1,
        'Reservation[currency_id]': 1,
        'Reservation[division_id]': hit.division_id,
        'Reservation[id]': None,
        'Reservation[is_auto_employee]': 1,
        'Reservation[is_service_in_order]': 0,
        'Reservation[override_free_time]': 0,
        'Reservation[start_at]': str(hit.date),
        'ReservationService[0][create]': 1,
        'ReservationService[0][duration_in_minutes]': hit.duration,
        'ReservationService[0][is_custom]': 0,
        'ReservationService[0][position]': 1,
        'ReservationService[0][service_id]': hit.service_id
    }
    index = 1
    for field in fields:
        index_incr, field_params = field.params(index)
        params.update(field_params)
        index += index_incr
    logging.info(json.dumps(params, ensure_ascii=False, sort_keys=True, indent=2, separators=(',', ': ')))
    response = requests.post(RESERVIS_URL + 'reservation/save', params=params).json()
    logging.info("response['success'] = " + json.dumps(response['success'], ensure_ascii=False, sort_keys=True, indent=2, separators=(',', ': ')))
    return response['internal_code'] if response['success'] == 1 else None
