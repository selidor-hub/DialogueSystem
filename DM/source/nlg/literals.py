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

HelpMsg = 'Proszę wpisać, "Od nowa", aby zrestartować rozmowę.'

HelloWorldDemo = "Witaj w demonstracyjnej wersji systemu dialogowego służącego do rezerwowania wizyty w salonie " \
             "fryzjerskim. System nie rezerwuje rzeczywistych terminów, a jedynie pozwala przetestować przebieg " \
             "rezerwacji."

ConfirmationDemo = "W tym miejscu w pełnej wersji systemu zostałaby wykonana rezerwacja."

ByeActive = "Rezerwacja wykonana pomyślnie. Zapraszamy ponownie."
ByeNeedsConfirmation = "Wstępna rezerwacja wykonana pomyślnie. Osoba z firmy skontaktuje się " \
                       "w celu potwierdzenia rezerwacji."
ByeFailure = "Zapraszamy ponownie."

TimeLate = "Nie jestem w stanie dokonać rezerwacji w tym terminie. Najpóźniejszy dostępny termin to {}."
TimeEarly = "Nie jestem w stanie dokonać rezerwacji w tym terminie. Najwcześniejszy dostępny termin to {}."

HitChoiceRegistered = "Wybrany termin wizyty: {hit}."  # (hit_represantation)

MustBeBothNameAndSurname = "Należy podać zarówno imię, jak i nazwisko. Spróbuj ponownie."

TooManyEmails = "Proszę o podanie tylko jednego adresu mailowego."
NotEnoughEmails = "Nie rozpoznałem poprawnego adresu mailowego. Spróbuj ponownie."

NoPhones = "Nie rozpoznałem poprawnego numeru telefonu. Spróbuj ponownie."

ConfirmationOfCorrectness = "Proszę o potwierdzenie poprawności danych:"
ReservationFailure = "Z powodu błędu nie udało się poprawnie przeprowadzić rezerwacji. Wybierz inny termin " \
                     "lub zmień parametry."

AskIfConfirmation = "Czy chcesz otrzymać potwierdzenie rezerwacji?"
WantConfirmationOnMail = "Tak, na maila"
WantConfirmationAsFile = "Tak, jako plik"
AskIfSendToThisMail = "Czy wysłać potwierdzenie na maila: {}?"
AskForAnotherMail = "Na jaki mail w takim razie wysłać potwierdzenie?"

Yes = "Tak"
No = "Nie"

Confirm = "Potwierdzam"
NotConfirm = "Nie potwierdzam"
Resign = "Rezygnuję"
ChangeData = "Chcę zmienić dane"

FirmNotExistsMsg = "Niestety, ta firma nie istnieje w danych Reservisu."

WhichDefault = 'Potrzebuję doprecyzowania:'
WhichParameter = 'Potrzebuję doprecyzowania. Jaki parametr masz na myśli pisząc {}?'
WhichTimePeriod = 'Potrzebuję doprecyzowania. Jaki okres masz na myśli pisząc {}?'
WhichLocationField = 'Potrzebuję doprecyzowania. Jaką część adresu masz na mysli pisząc {}?'
WhichHour = 'Potrzebuję doprecyzowania. Chodzi o godzinę {} rano czy po południu?'
AM = 'rano'
PM = 'po południu'

NoServices = 'Niestety żadna usługa nie pasuje do podanych kryteriów.'
Reset = 'Od nowa'
ResetReply = 'Ok, od nowa.'

MonthGenetivus = {
    1: 'stycznia',
    2: 'lutego',
    3: 'marca',
    4: 'kwietnia',
    5: 'maja',
    6: 'czerwca',
    7: 'lipca',
    8: 'sierpnia',
    9: 'września',
    10: 'października',
    11: 'listopada',
    12: 'grudnia'
}

# DayOfWeek = {
    # 0: 'pn.',
    # 1: 'wt.',
    # 2: 'śr.',
    # 3: 'czw.',
    # 4: 'pt.',
    # 5: 'sob.',
    # 6: 'niedz.'
# }

DayOfWeek = {
    0: 'poniedziałek',
    1: 'wtorek',
    2: 'środa',
    3: 'czwartek',
    4: 'piątek',
    5: 'sobota',
    6: 'niedziela'
}
