Przygotowanie środowiska:

1. sudo apt install python3-pip
2. pip3 -m install -r requirements.txt
3. mkdir logs

Uruchomienie agenta:
1. loadballancer - 
a) port wewnętrzny 8000 wraz z tcp stickness ma być dostępny pod adresem https://chatbot-dev.reservis.xyz 
(certyfikat jest już zaaploadowany na serwery autentykacyjne facebook'a)
b) port wewnętrzny 8001 wraz z tcp stickness ma być dostępny pod adresem https://chatbot.reservis.xyz

Agent Django
1. cd DialogueSystem/DM/agent/dev/source/dj; python3 manage.py runserver 0:8000 # instancja deweloperska
2. cd DialogueSystem/DM/agent/proto/source/dj; python3 manage.py runserver 0:8001 # instancja prototypowa

Agent konsolowy (tekstowy):
1. cd source; python3 dispatcher.py

Konfiguracja agenta:
1. W pliku configs/variables.ini

Import tabela.xls:
1. konwersja z Excela na JSON przez https://beautifytools.com/excel-to-json-converter.php
2. Wynikowy json zapisać do configs/tabela.json
3. cd configs; python3 tabela2tree.py
