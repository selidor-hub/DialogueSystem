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
Link do danych w mailu ???przestrze?? dyskowa do wymiany plik??w??? z 12.08.2021. Link ma posta??
```
https://selidor.sharepoint.com/sites/Listausug/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2FListausug%2FShared%20Documents%2FdialogueManager%5Ffiles&p=true
```
> Link nie dzia??a je??li nie ma odpowiednich ciasteczek w przegl??darce.

Trzeba pobra?? plik `beauty_attributes.xlsx` i zapisa?? w katalogu `DialogueSystem/corpus/sharepoint/beauty_attributes_<bie????ca data>.xlsx`

Skonwertowanie dwu pierwszych arkuszy do formatu `csv` i zapisanie ich do `DialogueSystem/corpus/sharepoint/beauty_attributes_....csv`. Separatorem pola jest tabulator.

## Wygenerowanie danych dla groundera

Uaktualnienie warto??ci `beauty_filename` i `beauty_filename2` w pliku `beautyLoader.ml`.

Skompilowanie i uruchomienie `beauty_loader`.
```
cd DialogueSystem/NLU/grounding
make
./beauty_loader
```

Wygenerowane zostan?? pliki `results/add_*.tab`, kt??re zawieraj?? informacj?? o tym jakie s?? nieznane nazwy us??ug oraz warto??ci atrybut??w. 

> Uwaga: b????d `print_extention 1: ` pojawia si??, gdy nie wszystkie nazwy us??ug s?? na listach sparsowanych nazw i konieczne jest ich dodanie.

Nieznane nazwy us??ug nale??y sparsowa?? i doda?? do list sparsowanych fraz odpowiednich typ??w (znajduj?? si?? w plikach `DialogueSystem/corpus/examples/*_parsed.json`). Nowe warto??ci atrybut??w trzeba doda?? do leksykon??w znajduj??cych si?? w `DialogueSystem/NLU/lexemes/data`.

Parser uruchamia si?? poleceniem:
```
cd DialogueSystem/NLU/lexemes
subsyntax -m -p 1234 -a --def-cat -u base -u beauty -u fixed
eniam --port 1234 --no-disamb --line-mode -u base -u beauty -u fixed --partial -j
eniam --port 1234 --no-disamb --line-mode -u base -u beauty -u fixed --no-sem
eniam --port 1234 --no-disamb -u base -u beauty -u fixed --partial -t
```
Podczas parsowania mo??e by?? konieczne rozszerzenie leksykon??w i gramatyki znajduj??cych si?? w `DialogueSystem/NLU/lexemes/data`.

Mo??e by?? r??wnie?? konieczne uzupe??nienie listy znanych podw??jnych identyfikator??w.

Je??li w `beauty_attributes.xlsx` znajduj?? si?? b????dy, np. liter??wki nale??y je poprawi?? i wgra?? poprawion?? list?? na sharepoint.

## Instalacja

Wgranie danych na gita:
```
git commit -a -m "uaktualnienie listy beauty w grounderze"
git push
```

W????czenie VPN.

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

Je??li mia??y miejsce zmiany w `DialogueSystem/NLU/lexemes/data` nale??y wykona?? r??wnie?? restart parsera (patrz `DialogueSystem/NLU/lexemes/README.md`).

Wylogowanie z maszyny wirtualnej.

Wy????czenie VPN.

Wys??anie maila o dokonaniu zmian.

# Procedura aktualizacji tabeli z drzewem kategorii

## Pobranie aktualnej wersji danych
Link do danych w mailu ???przestrze?? dyskowa do wymiany plik??w??? z 12.08.2021. Link ma posta??
```
https://selidor.sharepoint.com/sites/Listausug/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2FListausug%2FShared%20Documents%2FdialogueManager%5Ffiles&p=true
```
> Link nie dzia??a je??li nie ma odpowiednich ciasteczek w przegl??darce.

Trzeba pobra?? plik `tabela (1).xlsx` i zapisa?? w katalogu `DialogueSystem/corpus/sharepoint/tabela_<bie????ca data>.xlsx`

Nast??pnie trzeba skopiowa?? przez schowek wszystkie pola zawieraj??ce nazwy kategorii do pliku tekstowego i zrobi?? z nich list?? po jednej kategorii w wierszu usuwaj??c spacje znajduj??ce si?? na pocz??tkach i ko??cach wers??w.

List?? nale??y wklei?? na koniec pliku `DialogueSystem/corpus/examples/tabela.tab` (w sekcji `TODO`).

## Wygenerowanie danych dla groundera

Sprawdzenie, kt??re wpisy nie s?? sparsowane
```
cd DialogueSystem/NLU/walidator
./select -s ../../corpus/examples -t tabela -p ../../corpus/examples -f tabela >eff.txt
```

W pliku `DialogueSystem/corpus/examples/tabela.tab` w sekcji `TODO` trzeba pozostawi?? tylko te wpisy kt??re nie s?? sparsowane. A nast??pnie je sparsowa?? i umie??ci?? w pliku `DialogueSystem/corpus/examples/tabela_parsed.json`.

Parser uruchamia si?? poleceniem:
```
cd DialogueSystem/NLU/lexemes
subsyntax -m -p 1234 -a --def-cat -u base -u beauty -u fixed
eniam --port 1234 --no-disamb --line-mode -u base -u beauty -u fixed --partial -j
eniam --port 1234 --no-disamb --line-mode -u base -u beauty -u fixed --no-sem
eniam --port 1234 --no-disamb -u base -u beauty -u fixed --partial -t
```
Podczas parsowania mo??e by?? konieczne rozszerzenie leksykon??w i gramatyki znajduj??cych si?? w `DialogueSystem/NLU/lexemes/data`.

Sparsowane wpisy w pliku `DialogueSystem/corpus/examples/tabela.tab` nale??y przenie???? przed sekcj?? `TODO`.

Je??li w `tabela (1).xlsx` znajduj?? si?? b????dy, np. liter??wki nale??y je poprawi?? i wgra?? poprawiony plik na sharepoint.

## Instalacja

Wgranie danych na gita:
```
git commit -a -m "uaktualnienie znanych kategorii w grounderze"
git push
```

W????czenie VPN.

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

Je??li mia??y miejsce zmiany w `DialogueSystem/NLU/lexemes/data` nale??y wykona?? r??wnie?? restart parsera (patrz `DialogueSystem/NLU/lexemes/README.md`).

Wylogowanie z maszyny wirtualnej.

Wy????czenie VPN.

Wys??anie maila o dokonaniu zmian.
