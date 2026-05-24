# Voltera — manualul aplicatiei

Voltera e o aplicatie de diagnoza auto care ruleaza pe tableta si vorbeste cu masina ta printr-un adaptor OBD-II. Pe scurt: bagi un dongle in mufa de sub volan, conectezi tableta la el si vezi pe ecran tot ce simte calculatorul masinii — viteza, RPM, temperatura, codurile de eroare, consumul, totul in timp real.

E gandita ca sa stea fixata pe un suport in masina (sau pe banc, daca esti la atelier) si sa lucreze offline. Nu are nevoie de internet, nu trimite date in cloud, nu cere conturi. Pornesti masina, pornesti aplicatia, gata.

Documentul asta iti explica de la zero ce face fiecare ecran, ce inseamna fiecare numar si cum sa scoti maxim din el.

---

## Ce iti trebuie ca s-o pornesti

**Hardware:**
- O tableta Android (proiectul a fost testat pe Lenovo Tab M11, dar merge pe orice).
- Un adaptor OBD-II ELM327 cu **WiFi**. Recomandat: ESP32 cu firmware ELM327 — se gaseste cu 50-100 lei. Adaptoarele Bluetooth nu sunt suportate momentan (Bluetooth Classic e o batjocura pe Android, BLE nu e standard pe ELM327-uri ieftine).
- Cablu de alimentare pentru tableta — daca o folosesti zilnic, OBD-ul nu o incarca, ai nevoie de USB-C de la priza brichetei.

**In masina:**
- Mufa OBD-II, in general sub volan in stanga, langa pedala. Adaptorul ELM327 intra acolo.
- Contactul pus (motor pornit ideal — unele functii cer motor turat).

**Conexiunea:**
- Adaptorul ELM327 face propriul WiFi (ex. `WiFi_OBDII`, fara parola sau parola standard).
- Tableta se conecteaza la WiFi-ul adaptorului. Internet nu mai exista pentru tableta cat timp e conectata acolo, asta e normal.
- IP-ul si portul standard sunt `192.168.0.10:35000`. Daca adaptorul tau foloseste alt IP (`192.168.4.1:35000` e celalalt clasic), il schimbi din **Settings → WiFi adaptor**.

---

## Prima pornire

Cand deschizi aplicatia prima data, te intampina ecranul de **Adaptor OBD**. Ai doua optiuni:

1. **ELM327 WiFi (ESP32)** — alegerea normala, daca esti conectat la WiFi-ul adaptorului. Apasa pe el si Voltera incearca sa deschida o conexiune TCP la IP-ul si portul configurate. Dureaza 2-5 secunde, vezi un cerculet care se invarte si in spate ruleaza secventa standard ELM327: `ATZ` (reset), `ATE0` (echo off), `ATL0`, `ATS0`, `ATH0`, `ATAT1`, `ATSP0` (auto-protocol), apoi `0100` ca sa-si dea seama ce protocol vorbeste masina (CAN, J1850, KWP, ISO9141 — Voltera afla singura).

2. **Demo Vehicle (fara adaptor fizic)** — daca vrei sa testezi aplicatia in pat sau pe canapea fara sa stai in masina. Voltera simuleaza un motor: RPM-ul oscileaza, viteza creste si scade, raporteaza cateva coduri de eroare reale (P0301 misfire, P0420 catalizator, P0171 amestec sarac, P0455 scurgere EVAP) ca sa ai pe ce te uita. Toate ecranele functioneaza la fel ca pe masina reala.

Dupa ce te-ai conectat, sus stanga vezi un punct verde si scrie **LIVE** — esti in priza. Daca scrie **OFFLINE**, ESP32-ul nu raspunde sau IP-ul e gresit.

> **Tip:** apasa pe bara aia de status oricand vrei sa schimbi adaptorul sau sa te deconectezi. Iconita de roata din colt deschide setarile.

---

## Ecranul **DASH** — tabloul de bord

Asta e prima pagina pe care o vezi cand intri in aplicatie. E facuta sa fie utila in mers — numerele mari, citibile dintr-o privire.

**Sus** ai doua cadrane mari:
- **SPEED** — vitezometru, citeste din PID `0x0D`, valoarea e in km/h direct (sau mph daca ai bifat unitati imperiale in setari).
- **TACHOMETER** — turometru, citeste din PID `0x0C`. Valoarea raw vine in increment-uri de 0.25 RPM, Voltera o imparte la 4 sa scoata RPM real.

**La mijloc** ai trei panouri pe orizontala:
- Stanga: **ENGINE TEMP** (PID `0x05`, coolant). Sub 60°C e cyan (motor rece), 60-95 verde (zona normala), 95-105 portocaliu (atentie), peste 105 rosu (panica, opreste-te).
- Centru: silueta masinii cu **HEATMAP** termic. Asta e o premiera — nu e doar un desen static. Voltera ia toti senzorii termici din ECU si ii proiecteaza pe zone:
  - Capota fata = ECT + sarcina motor
  - Grila fata = IAT + clapeta (cat aer trage motorul acum)
  - Centrul motorului = temperatura uleiului (PID `0x5C`, daca masina o raporteaza, altfel e estimat din ECT+10)
  - Spate = evacuarea (estimat din ECT plus sarcina motorului)
  - Cele 4 jante = caldura franelor (estimat din viteza)
  Cand un punct devine portocaliu sau rosu in heatmap, ai unde sa te uiti. Sub silueta e o bara de **THROTTLE** (clapeta apasata 0-100%, PID `0x11`).
- Dreapta: **BATTERY** (PID `0x42`, tensiune control module). Sub 11.5V rosu (alternator mort sau baterie data), 11.5-12.4 portocaliu (slaba), peste 12.4 verde.

**Sub heatmap** sunt doua carduri: **COOLANT** (din nou, dar cu bara de progres pana la 130°C) si **MAF SENSOR** (debit aer in g/s, PID `0x10`). MAF-ul e indicatorul cel mai sensibil pentru consum si pentru sanatatea senzorilor de admisie.

**Sub** vine o bara segmentata pentru **ENGINE LOAD** (cat de tare lucreaza motorul, in procente, PID `0x04`). 0-30% e normal in mers linistit, 70-100% inseamna ca apesi serios.

**Jos** ai un grafic live pe ultimele 60 de secunde — RPM cu cyan continuu, TEMP cu portocaliu intrerupt. Util cat timp esti la o intersectie sau la semafor sa vezi cum se misca lucrurile.

Sus dreapta, langa bara de status, e un buton de roata care duce direct in **Settings**.

---

## Ecranul **CODES** — coduri de eroare

Asta e meniul pe care-l deschizi cand iti aprinde becul de check engine in bord.

Cand te conectezi la masina, Voltera scaneaza singura ECU-urile (Mode 03 pentru coduri stocate, Mode 07 pentru pending, Mode 0A pentru permanente). Daca masina e curata, vezi un cerc verde cu mesajul **NICIUN COD ACTIV — toate sistemele functioneaza normal**. Daca are coduri, le primesti in lista.

**Header-ul** sus iti arata:
- Numarul total de coduri
- Trei pastile colorate: **STORED** (rosu — coduri confirmate, becul aprins), **PENDING** (portocaliu — codul a aparut o data dar masina mai vrea sa-l confirme la urmatorul drum), **PERMANENT** (cyan — coduri care nu se sterg cu un simplu Mode 04, raman in ECU pana cand masina trece testele I/M)
- Cand a fost ultimul scan

**Filtru si cautare:**
- Pastilele **TOATE / STORED / PENDING / PERMANENT** filtreaza lista
- Bara de cautare iti gaseste un cod dupa litere/cifre (ex. tastezi "P03" si vezi toate misfire-urile) sau dupa cuvant cheie ("catalyst", "lambda")

**Cardul fiecarui cod** are:
- Codul (ex. P0301)
- Sistemul (Ignition, Fuel & Air, Catalyst etc.)
- Severitatea (chip colorat: critical / warning / info)
- O linie de descriere

Cand apesi pe card, se desfasoara si vezi:
- **CONSECINTE** — ce se intampla daca-l ignori (ex. "Pierdere de putere, vibratii, posibile daune la catalizator")
- **SOLUTIE** — pasii practici de remediere ("Verifica bujiile, bobinele de inductie, injectoarele, compresia cilindrilor si scurgerile de admisie")
- Severitatea si categoria detaliate (Powertrain / Body / Chassis / Network)

Voltera are in baza locala peste 200 de coduri uzuale (toate misfire-urile P0301-P030C, fuel trim P0170-P0175, sondele lambda P0130-P0161, catalizator P0420/P0430, EVAP, turbo, EGR, transmisie, ABS, CAN bus, etc.). Daca un cod nu e in baza, primesti un fallback util care iti spune categoria si daca e generic OBD-II sau cod specific producatorului — ca sa stii in ce manual sa te uiti.

**Doua butoane jos:**
- **SCAN ECU** — refa scanarea oricand
- **STERGE** — Mode 04, sterge codurile stocate, reseteaza monitorii readiness, stinge becul. Iti cere confirmare pentru ca operatiunea e ireversibila si daca masina chiar are o problema, codul revine la primul drum. Fluxul tipic: rezolvi problema fizica → stergi codul → faci 1-2 drumuri ca sa se verifice ca s-a fixat.

---

## Ecranul **TRACK** — track mode

E modul "circuit". Cand vrei sa cronometrezi accelerari sau sa retii ce ai facut intr-o sesiune.

Cand apesi **START SESSION**, Voltera incepe sa polleze RPM-ul si viteza la fiecare 50 ms si retine:

- **0 → 100 km/h** — cronometrul se opreste fix in clipa in care viteza atinge sau depaseste 100. Numarul mare central, in secunde cu doua zecimale.
- **G-FORCE** — calculat din variatia de viteza in timp (delta v / delta t / 9.81). Nu e un G real (pentru asta ai nevoie de accelerometru), e G-ul longitudinal estimat din OBD. Util ca trend, nu absolut.
- **MAX SPEED** si **MAX RPM** — peak-urile din sesiune.
- **CURRENT** — viteza live cu o bara orizontala pana la 260 km/h.
- **LAP** — apesi butonul si Voltera iti retine timpul curent ca un tur. Lista de tururi se acumuleaza dedesubt, cele noi sus.
- **STOP** — opreste sesiunea, dar valorile raman pe ecran pana cand pornesti alta.

Track mode-ul nu salveaza istoric pe disc — daca vrei sa-ti retii sesiunea cu mai multe date, foloseste **Trip Analysis** din meniul MORE.

---

## Ecranul **ECO** — sofat economic

Aici Voltera te invata sa conduci ca economie. Sufla in tine numere, dar in spate face calcule serioase.

**Sus** ai cardul mare cu scorul:
- Inelul cu numarul mare e **scor eco 0-100**. Calculul combina patru lucruri:
  - Cat de "neted" misti pedala (cat oscileaza throttle-ul de la o secunda la alta)
  - Cat de neted accelerezi/franezi (cat de mari sunt valorile delta-v)
  - Cat timp stai in zona ECO de turatie (1300-2500 RPM, unde motorul e cel mai eficient)
  - Penalizare pentru consum mare si pentru evenimente brute
- Sub eticheta scorului ai un **CONSUM live**:
  - Daca te misti (peste 5 km/h), arata **L/100 km** instantaneu, calculat din MAF si viteza
  - Daca stai pe loc, comuta automat pe **L/h** ca sa vezi cat fura motorul la idle

**Cardul de tip** — un Voltera-bot care iti da feedback real-time. Ce poate sa-ti spuna:
- "Anticipeaza traficul pentru a reduce franarile bruste" (daca ai prea multe harsh brake)
- "Apasa pedala progresiv — economisesti 10-15% combustibil" (daca apesi prea repede)
- "Schimba intr-o treapta superioara" (daca esti la 3500+ RPM la viteza mica)
- "Idling de mult. Opreste motorul daca stai > 1 minut" (daca tii motorul pornit la rosu lung)
- "Peste 130 km/h consumul creste exponential"
- Plus altele pentru consumul mare, oscilatii pe pedala etc.

**Trei inele de smoothness**, fiecare 0-100%:
- **THROTTLE** — cat de constanta e apasarea pe accel
- **ACCEL** — cat de uniforma e variatia vitezei
- **RPM ZONE** — cat % din timp ai stat in zona ECO 1300-2500

Verde > 70%, portocaliu 45-70%, rosu sub 45%.

**Statistici sesiune** — sase cifre care se acumuleaza din momentul pornirii ecranului (sau de cand ai apasat butonul reset sus dreapta):
- AVG L/100 (consum mediu)
- COMBUSTIBIL (litri arsi total)
- CO₂ (kilograme; folosim 2.31 kg CO₂ per litru benzina)
- DIST (km parcursi)
- HARSH+ (numar de accelerari brute, peste 3.5 m/s²)
- HARSH- (numar de franari brute, sub -4 m/s²)

**RPM ZONE bar** — un termometru orizontal cu gradient cyan-verde-portocaliu-rosu si un cursor alb care iti arata RPM-ul actual. Eticheta dedesubt iti aminteste zona eco si redline-ul.

**Jos de tot** ai blocul de **emissions readiness**: PASS sau FAIL pe inspectia tehnica, plus 6 monitori (Misfire, Fuel System, Components, Catalyst, O2 Sensor, O2 Heater) cu becul lor verde sau rosu. Asta inlocuieste vechiul ecran "Emissions" — e direct integrat in eco fiindca informatiile merg mana in mana.

---

## Ecranul **MORE** — restul aplicatiei

In MORE-ul ai un hub cu tot ce nu incape in bara de jos. Sus e un card cu vehiculul curent, sub el o grila cu 8 butoane:

### Trip Analysis

Cea mai mare functionalitate noua. Inregistreaza un drum complet, deseneaza traseul pe o harta si iti da statistici detaliate.

**Cum functioneaza harta fara GPS?** Voltera nu cere permisiuni de locatie. In schimb, sintetizeaza un traseu plauzibil din OBD: ia viteza in m/s, integreaza pe timp, simuleaza o directie de mers care se "plimba" usor (un mic Random walk pe heading). Rezultatul nu e o harta reala (n-o sa vezi strazile orasului), e o **harta cinematica**: un fel de schita a drumului cu lungimea reala parcursa, segmentele rapide colorate diferit fata de cele cu trafic, plus markere unde ai accelerat sau franat brusc. Daca ai mers mult intr-o directie si apoi te-ai intors, vei vedea un fel de bucla. E o reprezentare vizuala a "comportamentului" drumului, nu un GPS log.

**Pe harta vezi:**
- Linia traseului colorata in functie de viteza (cyan = mic, verde = mediu, galben = rapid, rosu = foarte rapid)
- Cerc verde = startul drumului
- Cerc cyan/rosu cu sageata = pozitia curenta + directia
- Puncte galbene = accelerari brute
- Puncte rosii = franari brute
- Bussola "N" sus dreapta
- Grid de fundal ca sa ai sens al scarii

**Cardul cu eco score** are inelul scorului si un mesaj contextual ("Stilul tau de condus este eficient. Continua tot asa!" sau "Anticipeaza traficul...").

**Statisticile** afisate:
- DISTANTA (integrata din vectorul cinematic, in km)
- DURATA
- VITEZA medie
- MAX (viteza maxima atinsa)
- CONSUM L/100 mediu
- CO₂ kg

**Speed profile** — un grafic timeseries cu viteza pe toata durata drumului, cu axa timp formatata mm:ss.

**Evenimente** — trei contoare: cate accelerari brute, cate franari brute, RPM-ul maxim atins.

**Butonul START TRIP / STOP TRIP** porneste sau opreste inregistrarea. Cand opresti, drumul e salvat automat in lista de trasee (ultimele 30 raman, ce e mai vechi se sterge ca sa nu se umple memoria).

**Iconita de lista** sus dreapta deschide sertarul cu istoricul: vezi toate drumurile salvate, plus drumul live daca e unul activ. Apesi pe oricare ca sa-l revezi. Poti sterge drumuri individual sau toate.

### Live Sensors

Grila cu toate PID-urile pe care Voltera le polleaza. Fiecare cartonas arata:
- Numele scurt al senzorului (RPM, ECT, MAF, BAT...)
- Numele complet
- Adresa hex (`0x0C`, `0x05`, etc.)
- Valoarea curenta cu unitatea
- O sparkline (mini-grafic) cu istoricul ultimelor 240 de mostre

E util cand vrei sa vezi un senzor in detaliu sau sa cauti dupa ceva anume — bara de cautare sus filtreaza dupa nume.

In partea de sus ai si un indicator de status: cate Hz pollezi, cate citiri totale au fost facute, cati senzori sunt afisati din total.

### Vehicle Info

Detaliile tehnice ale masinii.

**Sus** — un card hero cu numele masinii, motorul si VIN-ul. Daca nu e citit niciun VIN, vezi `Unknown vehicle` si te indeamna sa-l decodezi.

**VIN DECODE** — un input pentru cele 17 caractere ale VIN-ului. Doua butoane:
- **CITESTE DIN ECU** — trimite Mode 09 PID 02 la masina. Multe masini moderne il dau, unele vechi nu.
- **DECODE** — daca-l ai pe hartie/in talon, il introduci si Voltera intreaba serviciul NHTSA (gratuit, nu cere cont) ca sa-ti dea anul, marca, modelul, tipul de motor, cutia de viteze, tipul de caroserie, uzina unde a fost facuta. Necesita conexiune la internet o singura data, datele se cache-uiesc local dupa.

**SPECIFICATII** — grila cu campurile decoded.

**ADAPTOR** — info despre dongle-ul OBD: numele, tipul de transport (WiFi), adresa, firmware-ul ELM raportat (ex. `ELM327 v1.5`), protocolul negociat cu masina (ex. `ISO 15765-4 CAN 11/500`).

**MODULE ECU** — daca masina raporteaza adrese de ECU separate, le vezi aici. Standard pe CAN 11-bit ai pcm la `7E0`, transmissia la `7E1`, etc.

### Performance

Test de performanta in timp real. E ca Track Mode, dar cu metrice speciale, mai detaliat.

Cand apesi START TEST:
- **0-100 km/h** se cronometreaza
- **0-60 mph** (96.56 km/h) — pentru petrolheads care vor numarul american
- **0-200 km/h** — pentru masini puternice
- **1/4 MILE** (402.336 m, integrat din viteza) — timpul + viteza-trap (cat aveai cand ai trecut linia)
- **60-0 km/h** si **100-0 km/h** — distanta de oprire. Voltera detecteaza automat ca incepe franarea (viteza scade brusc cu peste 0.5 km/h tick), incepe sa integreze distanta pana cand viteza ajunge sub 5 km/h, apoi incadreaza rezultatul in 60-0 sau 100-0 dupa viteza initiala.

**Cardul mare central** arata viteza live in cifre uriase, plus max speed, distanta totala parcursa in test si timpul scurs.

### OBD Terminal

Pentru hackeri si tehnicieni. E un prompt unde poti trimite comenzi crude la ELM327.

Sus vezi statusul (CONECTAT / NECONECTAT) si numarul de linii din log. In mijloc e log-ul, cu trei tipuri de linii:
- `>>` cyan = comanda trimisa (TX)
- `<<` verde = raspuns (RX)
- `!!` rosu = eroare (timeout, NO DATA, BUS BUSY etc.)

Toate liniile sunt selectabile, le poti copia.

**Quick commands** — o bara orizontala cu butoane care trimit comenzi des folosite:
- `ATZ` — reset
- `ATI` — identifica adaptorul
- `ATRV` — tensiunea bateriei
- `ATSP0` — auto protocol
- `ATDP` — protocolul curent
- `0100` — PID-uri suportate 01-20
- `010C` — RPM
- `010D` — viteza
- `0105` — coolant
- `0902` — VIN
- `03` — coduri stocate
- `07` — coduri pending

In input-ul de jos poti scrie orice comanda valida ELM327 sau OBD. Apesi SEND si primesti raspunsul. Util pentru: testat un PID specific, debug cand un senzor nu raspunde, verificat ca adaptorul vorbeste, scos info din masini exotice care nu au PID-uri standard.

### History

Sesiunile (drumurile) salvate prezentate cronologic, cu un grafic de "monthly km" sus si o lista de carduri cu fiecare drum (data, distanta, viteza max, numar de coduri, durata). E view-ul "agenda" — pentru detalii pe un drum anume, intri in **Trip Analysis** si selectezi drumul de acolo.

### Settings

Toate butoanele de configurare:

**AFISARE:**
- Tema intunecata (default da, recomandat noaptea)
- Pastreaza ecranul aprins (cat timp aplicatia e deschisa)
- Unitati imperiale (mph, °F, mpg in loc de km/h, °C, L/100)
- Frecventa actualizare — slider 1-20 Hz. Default 5 Hz e ok pentru majoritatea cazurilor. Daca aduci tableta foarte aproape de adaptor si ai cablu bun de OBD, poti urca la 10-15 Hz pentru gauge-uri mai fluide. Peste 15 Hz, ELM327 incepe sa rateze raspunsuri.

**CONEXIUNE:**
- Conectare automata — la deschiderea aplicatiei reia ultimul adaptor folosit
- WiFi adaptor — IP-ul si portul. Salvezi cu butonul Save, te deconectezi cu Disconnect.

**LOGGING & TRASEE:**
- CSV automat — daca pornit, fiecare drum se salveaza si ca CSV in folderul de documente al aplicatiei (cu PID-uri si timestamp-uri)
- Sterge traseele salvate — buton de panic-button, sterge toate drumurile inregistrate
- Sterge cache vehicul — sterge VIN-ul si datele NHTSA decoded

**COPILOT AI:**
- Cheie OpenAI — pentru integrarea cu ChatGPT (functie viitoare unde poti pune intrebari despre coduri si masina). Cheia ramane local pe tableta, nu se trimite niciodata altundeva, doar la API-ul OpenAI cand chemi efectiv copilotul.

**DESPRE:**
- Versiunea, descrierea aplicatiei.

### About

Un dialog mic cu versiunea curenta, descrierea, stack-ul folosit. Nimic ascuns aici.

---

## Ce se intampla pe dedesubt

### Cum vorbeste cu masina

ELM327 e un microchip vechi care interpreteaza comenzi text si traduce in sus si in jos catre magistrala CAN/J1850/KWP/ISO9141 a masinii. Voltera trimite text gen `010C\r` (Mode 01, PID 0x0C, return), ELM-ul interogheaza masina, raspunde cu `41 0C 1A F8`. Voltera ignora primul byte (0x41 = 0x40 + Mode 01, confirmare), apoi PID-ul (0x0C), apoi ia bytes-urile de date (0x1A, 0xF8) si le decodeaza dupa formula PID-ului — pentru RPM e `(byte1 * 256 + byte2) / 4`, deci `(26 * 256 + 248) / 4 = 1726 RPM`.

Asta se intampla pentru fiecare PID, de 5 ori pe secunda (default), pentru 9 PID-uri standard pe dashboard. Algoritmul de polling e in `LiveDataProvider`: o bucla async care pune un Timer la fiecare 200ms, intreaba toate PID-urile in serie, salveaza ultimele valori si o coada de istoric (ultimele 240 de mostre per PID, adica 48 de secunde la 5 Hz).

### Cum citeste codurile

Mode 03 returneaza coduri stocate. Raspunsul vine ca `43 03 03 01 04 20 01 71`:
- `43` = Mode 03 echo
- `03` = numarul de coduri (3)
- Apoi 3 perechi de bytes: `03 01`, `04 20`, `01 71`

Fiecare pereche se decodeaza ca DTC astfel:
- Bitii 7-6 ai primului byte = litera (0=P, 1=C, 2=B, 3=U)
- Bitii 5-4 = prima cifra
- Bitii 3-0 = a doua cifra
- Tot al doilea byte = ultimele 2 cifre

`03 01` → letterBits=0 (P), digit1=0, digit2=3, lo=01 → **P0301**
`04 20` → P0420
`01 71` → P0171

Apoi codul se cauta in `DtcDatabase` (peste 200 de intrari) si daca e gasit, capata descriere, severitate si solutie. Daca nu e in baza, primesti un fallback inteligent care iti spune categoria (P/B/C/U) si daca e generic sau specific producatorului.

### Cum calculeaza consumul

Consumul nu vine direct din masina — masina nu raporteaza un PID "L/100". Voltera il deduce din MAF (mass air flow, debit de aer in g/s):

```
fuel_g_per_s = MAF / AFR
litri_per_s = fuel_g_per_s / densitate_benzina
litri_per_h = litri_per_s * 3600
L_100km = litri_per_h / viteza_km_per_h * 100
```

Cu AFR (raport stoichiometric aer/combustibil) = 14.7 si densitatea benzinei = 750 g/L. Pentru diesel teoretic ar fi alti coeficienti dar diferenta e mica. Daca masina e la idle (viteza < 5 km/h), formula iese in afara, asa ca afisam direct **L/h** ca rata absoluta. Tot din litri totali x 2.31 kg = CO₂ in kg (factorul de emisie standard pentru benzina).

### Cum sintetizeaza traseul

Fiecare 250ms in timpul unui trip:
- Citeste viteza, RPM, MAF etc.
- Calculeaza acceleratia (delta v / delta t)
- Pune un mic random pe heading (directia)
- Calculeaza dx = cos(heading) * viteza_m/s * dt si dy similar
- Adauga la pozitia curenta

Asa, Voltera "deseneaza" un drum cu lungimea reala parcursa, dar cu o forma fictiva. Daca vrei harta reala adauga `geolocator` la pubspec si pluginul GPS — codul accepta deja overrideuri, doar serviciul `LocationService` are nevoie de implementare reala (acum e stub).

### Cum salveaza datele

- **SharedPreferences** (local pe tableta):
  - Setarile aplicatiei (tema, refresh, etc.)
  - VIN-ul si datele decode NHTSA (cache)
  - WiFi host/port
  - Lista de trasee salvate (JSON serialized, cele mai noi 30)
  - Cheia OpenAI
- **Folderul de documente al aplicatiei:**
  - CSV-uri logate (daca CSV automat e pornit) — un fisier per sesiune cu timestamp, lat, lon, gps_speed, plus o coloana per PID

Nimic nu pleaca de pe tableta in afara cererilor catre NHTSA (pentru decode VIN) si OpenAI (pentru CoPilot, daca ai pus cheia). Restul ramane local.

---

## Modul Demo

E facut sa-ti permita sa vezi aplicatia complet fara sa fii in masina sau sa ai adaptor. Activezi din ecranul de conectare, alegi **Demo Vehicle**.

Ce simuleaza:
- **RPM** care plimba target-ul intre 800 si 5300 rpm cu Random, dar cu interpolare lina (0.15 factor pe tick) — pare un motor real
- **Viteza** derivata din RPM (treapta presupusa)
- **Coolant** care oscileaza in jur de 78°C cu sin pe milisecunde
- **Throttle** Random 40-120 (din 255), echivalent ~16-47%
- **Engine load** Random 50-170, echivalent ~20-67%
- **MAF** Random 0-1.8 g/s la idle, scaleaza cu RPM in real
- **Battery** fix la 14.420V (perfect)
- **Fuel level** la 70%
- **VIN-ul** raportat e `1HGCM82633A004352` (un Honda Accord 2003 — ales pentru ca e VIN-ul "standard" de teste din NHTSA)
- **Coduri** Mode 03: 3 stocate (P0301, P0420, P0171)
- **Coduri** Mode 07: 1 pending (P0455)

Toate ecranele primesc valorile astea ca si cum ar fi de pe masina reala.

---

## Probleme frecvente

**"Conectare esuata: timeout"**
- Verifica ca esti pe WiFi-ul ESP32-ului, nu pe alt WiFi/4G
- Verifica IP-ul si portul in setari (default `192.168.0.10:35000`, dar unele firmware-uri folosesc `192.168.4.1:35000`)
- Adaptorul e alimentat? OBD-ul da 12V doar cand contactul e pus
- Daca tocmai ai pornit ESP32-ul, asteapta 10 secunde sa-si urce stack-ul WiFi

**"NO DATA" la coduri**
- E ok daca masina chiar nu are coduri — Voltera afiseaza "TOTUL OK"
- Daca o masina cu becul aprins raspunde NO DATA, probabil e pe un protocol exotic (manufacturer-specific) si ELM-ul ieftin nu il prinde. Foloseste Terminal-ul cu `ATSP6` (CAN 11/500) sau alte protocoale manual.

**Heatmap ramane "rece" pe motor cald**
- Necesita ECT (PID 0x05). Daca masina nu raporteaza ECT (rar dar se intampla), heatmap-ul nu are date. Verifica in Live Sensors daca ECT are valoare.

**Track Mode nu cronometreaza 0-100**
- Masina trebuie sa porneasca de la oprit (sub 5 km/h) si sa atinga 100 km/h fara sa se opreasca cronometrul. Cronometrul porneste la apasarea butonului START SESSION, nu la apasarea pedalei.

**Trip Analysis arata "Astept date..."**
- Trip-ul are nevoie de minim 2 mostre ca sa deseneze o linie. Masina trebuie sa polleze date OBD, deci trebuie sa fii conectat. Daca e demo, ar trebui sa apara imediat.

**Aplicatia se inchide singura**
- Pe Android, daca tableta intra in standby si nu ai bifat **Pastreaza ecranul aprins** in setari, sistemul poate inchide procesul. Bifeaza optiunea si tine tableta alimentata.

**Vad numere ciudate la consum**
- Consumul e estimare din MAF. Daca senzorul MAF raporteaza valori absurde (foarte murdar, defect, sau lipsa cu totul si masina foloseste MAP+IAT pentru calcul speed-density), consumul iese pe langa. Curata MAF-ul cu spray dedicat sau verifica daca masina ta are senzor MAF deloc.

---

## Stack tehnic (pe scurt)

- **Flutter 3.19+** / Dart 3.3+
- **Provider** pentru state management
- **Syncfusion gauges** + **fl_chart** pentru cadrane si grafice
- **flutter_svg** pentru desenul masinii
- **flutter_animate** + **shimmer** pentru tranzitii si efecte
- **shared_preferences** pentru persistenta locala
- **path_provider** + **csv** pentru CSV logging
- **dio** pentru API-uri (NHTSA, OpenAI)
- **intl** pentru formatare numere si date

Codul e impartit in:
- `core/` — modelele, conexiunea TCP, parser-ul ELM327, catalogul de PID-uri, baza de DTC-uri
- `providers/` — starea aplicatiei (connection, live data, diagnostics, trips, vehicle, settings)
- `screens/` — ecranele principale (dashboard, codes, track, eco, more, plus toate sub-ecranele)
- `widgets/` — componente reutilizate (gauge-uri, carduri, status pill, heatmap, butoane racing)
- `theme/` — culorile si tipografia (Orbitron pentru cifre, Rajdhani pentru text)

---

## Ce urmeaza (idei)

- Integrare GPS reala (cu plugin geolocator — codul accepta deja, e doar nevoie de implementare in `LocationService`)
- CoPilot AI activ — chat cu OpenAI care vede live ce face masina si te ajuta sa diagnostichezi
- Export al unui drum ca PDF cu hartie + statistici (pentru dosare service sau dosare track day)
- Mod "drag race" cu countdown, semafor si rezultate detaliate per launch
- Mai multe coduri in baza locala (acum sunt ~200, ideal ar fi 500+)
- Suport Bluetooth Classic pentru adaptoarele clasice ELM327 (necesita plugin nativ separat)
- iOS build (codul ar trebui sa mearga, n-a fost testat)

---

Voltera nu e perfecta, dar incearca sa fie un instrument cinstit pentru cineva care vrea sa-si inteleaga masina fara sa plateasca un abonament sau sa permita unei aplicatii cloud sa-i fure datele. Daca o folosesti si ai idei sau gasesti un bug, deschide o issue in repo.
