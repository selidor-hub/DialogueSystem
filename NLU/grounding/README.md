# Uruchamianie

## Uruchamianie na 192.168.6.8
```
/home/wojtek.jaworski/DialogueSystem/NLU/grounding/service_grounder -p 9761
/home/wojtek.jaworski/DialogueSystem/NLU/grounding/category_grounder -p 9762 -c ../../corpus/examples/tabela_parsed.json
/home/wojtek.jaworski/DialogueSystem/NLU/grounding/time_grounder -p 9763
```

## Urucjamianie lokalnie jako serwisy sieciowe
```
./service_grounder -p 9761
./category_grounder -p 9762 -c ../../corpus/examples/tabela_parsed.json
./time_grounder -p 9763
```

## grounder
```
cat ex1.json | netcat localhost 9761
cat ex2.json | netcat localhost 9761
cat ex3.json | netcat localhost 9761
cat ex3.json | ./service_grounder
```

## categry_grounder
```
./category_grounder -p 9762 -c ../../corpus/examples/tabela_parsed.json -c ../../corpus/examples/beauty_usluga1_parsed.json -c ../../corpus/examples/beauty_usluga2_parsed.json &
cat cx1.json | netcat localhost 9762
cat cx2.json | netcat localhost 9762
cat cx3.json | netcat localhost 9762

cat cx1.json | ./category_grounder -c ../../corpus/examples/tabela_parsed.json -c ../../corpus/examples/beauty_usluga1_parsed.json -c ../../corpus/examples/beauty_usluga2_parsed.json
cat cx2.json | ./category_grounder -c ../../corpus/examples/tabela_parsed.json -c ../../corpus/examples/beauty_usluga1_parsed.json -c ../../corpus/examples/beauty_usluga2_parsed.json
cat cx3.json | ./category_grounder -c ../../corpus/examples/tabela_parsed.json -c ../../corpus/examples/beauty_usluga1_parsed.json -c ../../corpus/examples/beauty_usluga2_parsed.json
cat cx4.json | ./category_grounder -c ../../corpus/examples/tabela_parsed.json -c ../../corpus/examples/beauty_usluga1_parsed.json -c ../../corpus/examples/beauty_usluga2_parsed.json

cat cx1.json | ./category_grounder -c ../../corpus/examples/tabela_parsed.json
cat cx3.json | ./category_grounder -c ../../corpus/examples/tabela_parsed.json
```

## time_grounder
```
cat tx1.json | ./time_grounder
cat tx2.json | ./time_grounder
cat tx3.json | ./time_grounder
cat tx4.json | ./time_grounder
cat tx1.json | netcat localhost 9763
cat tx2.json | netcat localhost 9763

./time_grounder --debug -c ../../corpus/examples/time_parsed.json
./time_grounder --debug -c ../../corpus/examples/sort_parsed.json
./time_grounder --debug -c ../../corpus/examples/flexibility_parsed.json
./time_grounder --debug -c ../../corpus/examples/indexical_parsed.json
./time_grounder --debug -c ../../corpus/examples/dialogi3_klient_parsed.json
./time_grounder --debug -c ../../corpus/examples/time_parsed.json -v ../../corpus/examples/time_grounded.json
./time_grounder --debug -c ../../corpus/examples/sort_parsed.json -v ../../corpus/examples/sort_grounded.json
./time_grounder --debug -c ../../corpus/examples/flexibility_parsed.json -v ../../corpus/examples/flexibility_grounded.json
./time_grounder --debug -c ../../corpus/examples/indexical_parsed.json -v ../../corpus/examples/indexical_grounded.json
./time_grounder --debug -c ../../corpus/examples/dialogi3_klient_parsed.json -v ../../corpus/examples/dialogi3_klient_grounded.json
```

# Procedura aktualizacji listy beauty

## Pobranie aktualnej wersji danych
Link do danych w mailu „przestrzeń dyskowa do wymiany plików” z 12.08.2021. Link ma postać
```
https://selidor.sharepoint.com/sites/Listausug/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2FListausug%2FShared%20Documents%2FdialogueManager%5Ffiles&p=true
```
> Link nie działa jeśli nie ma odpowiednich ciasteczek w przeglądarce.

Trzeba pobrać plik `beauty_attributes.xlsx` i zapisać w katalogu `DialogueSystem/corpus/sharepoint/beauty_attributes_<bieżąca data>.xlsx`

Skonwertowanie dwu pierwszych arkuszy do formatu `csv` i zapisanie ich do `DialogueSystem/corpus/sharepoint/beauty_attributes_....csv`. Separatorem pola jest tabulator.

## Wygenerowanie danych dla groundera

Uaktualnienie wartości `beauty_filename` i `beauty_filename2` w pliku `beautyLoader.ml`.

Skompilowanie i uruchomienie `beauty_loader`.
```
cd DialogueSystem/NLU/grounding
make
./beauty_loader
```

Wygenerowane zostaną pliki `results/add_*.tab`, które zawierają informację o tym jakie są nieznane nazwy usług oraz wartości atrybutów. 

> Uwaga: błąd `print_extention 1: ` pojawia się, gdy nie wszystkie nazwy usług są na listach sparsowanych nazw i konieczne jest ich dodanie.

Nieznane nazwy usług należy sparsować i dodać do list sparsowanych fraz odpowiednich typów (znajdują się w plikach `DialogueSystem/corpus/examples/*_parsed.json`). Nowe wartości atrybutów trzeba dodać do leksykonów znajdujących się w `DialogueSystem/NLU/lexemes/data`.

Parser uruchamia się poleceniem:
```
cd DialogueSystem/NLU/lexemes
subsyntax -m -p 1234 -a --def-cat -u base -u beauty -u fixed
eniam --port 1234 --no-disamb --line-mode -u base -u beauty -u fixed --partial -j
eniam --port 1234 --no-disamb --line-mode -u base -u beauty -u fixed --no-sem
eniam --port 1234 --no-disamb -u base -u beauty -u fixed --partial -t
```
Podczas parsowania może być konieczne rozszerzenie leksykonów i gramatyki znajdujących się w `DialogueSystem/NLU/lexemes/data`.

Może być również konieczne uzupełnienie listy znanych podwójnych identyfikatorów.

Jeśli w `beauty_attributes.xlsx` znajdują się błędy, np. literówki należy je poprawić i wgrać poprawioną listę na sharepoint.

## Instalacja

Wgranie danych na gita:
```
git commit -a -m "uaktualnienie listy beauty w grounderze"
git push
```

Włączenie VPN.

Zalogowanie na maszynie wirtualnej.
```
ssh wojtek.jaworski@192.168.6.8
bash
```

Uaktualnienie gita na maszynie wirtualnej.
```
cd DialogueSystem/
git pull
```

Restart serwisu
```
sudo systemctl stop grounder
sudo systemctl start grounder
```

Jeśli miały miejsce zmiany w `DialogueSystem/NLU/lexemes/data` należy wykonać również restart parsera (patrz `DialogueSystem/NLU/lexemes/README.md`).

Wylogowanie z maszyny wirtualnej.

Wyłączenie VPN.

Wysłanie maila o dokonaniu zmian.

# Procedura aktualizacji tabeli z drzewem kategorii

## Pobranie aktualnej wersji danych
Link do danych w mailu „przestrzeń dyskowa do wymiany plików” z 12.08.2021. Link ma postać
```
https://selidor.sharepoint.com/sites/Listausug/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2FListausug%2FShared%20Documents%2FdialogueManager%5Ffiles&p=true
```
> Link nie działa jeśli nie ma odpowiednich ciasteczek w przeglądarce.

Trzeba pobrać plik `tabela (1).xlsx` i zapisać w katalogu `DialogueSystem/corpus/sharepoint/tabela_<bieżąca data>.xlsx`

Następnie trzeba skopiować przez schowek wszystkie pola zawierające nazwy kategorii do pliku tekstowego i zrobić z nich listę po jednej kategorii w wierszu usuwając spacje znajdujące się na początkach i końcach wersów.

Listę należy wkleić na koniec pliku `DialogueSystem/corpus/examples/tabela.tab` (w sekcji `TODO`).

## Wygenerowanie danych dla groundera

Sprawdzenie, które wpisy nie są sparsowane
```
cd DialogueSystem/NLU/walidator
./select -s ../../corpus/examples -t tabela -p ../../corpus/examples -f tabela >eff.txt
```

W pliku `DialogueSystem/corpus/examples/tabela.tab` w sekcji `TODO` trzeba pozostawić tylko te wpisy które nie są sparsowane. A następnie je sparsować i umieścić w pliku `DialogueSystem/corpus/examples/tabela_parsed.json`.

Parser uruchamia się poleceniem:
```
cd DialogueSystem/NLU/lexemes
subsyntax -m -p 1234 -a --def-cat -u base -u beauty -u fixed
eniam --port 1234 --no-disamb --line-mode -u base -u beauty -u fixed --partial -j
eniam --port 1234 --no-disamb --line-mode -u base -u beauty -u fixed --no-sem
eniam --port 1234 --no-disamb -u base -u beauty -u fixed --partial -t
```
Podczas parsowania może być konieczne rozszerzenie leksykonów i gramatyki znajdujących się w `DialogueSystem/NLU/lexemes/data`.

Sparsowane wpisy w pliku `DialogueSystem/corpus/examples/tabela.tab` należy przenieść przed sekcję `TODO`.

Jeśli w `tabela (1).xlsx` znajdują się błędy, np. literówki należy je poprawić i wgrać poprawiony plik na sharepoint.

## Instalacja

Wgranie danych na gita:
```
git commit -a -m "uaktualnienie znanych kategorii w grounderze"
git push
```

Włączenie VPN.

Zalogowanie na maszynie wirtualnej.
```
ssh wojtek.jaworski@192.168.6.8
bash
```

Uaktualnienie gita na maszynie wirtualnej.
```
cd DialogueSystem/
git pull
```

Restart serwisu
```
sudo systemctl stop cat-grounder
sudo systemctl start cat-grounder
```

Jeśli miały miejsce zmiany w `DialogueSystem/NLU/lexemes/data` należy wykonać również restart parsera (patrz `DialogueSystem/NLU/lexemes/README.md`).

Wylogowanie z maszyny wirtualnej.

Wyłączenie VPN.

Wysłanie maila o dokonaniu zmian.
