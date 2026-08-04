# Model izračuna

Aplikacija izračunava vrijeme hlađenja piva u hladnjaku ili zamrzivaču pomoću modela **BeerCHILLER Calibrated V2**.

Model je praktična aproksimacija. Koristi početnu temperaturu, ciljnu temperaturu, temperaturu uređaja, ambalažu, volumen i položaj. U stvarnim uvjetima uređaji mogu hladiti brže ili sporije zbog protoka zraka, kontaktnih površina, napunjenosti i otvaranja vrata.

## 1. Razlika temperature

Odlučujuca vrijednost je razlika temperature izmedu piva i uredaja:

\[
\Delta = T - T_D
\]

Gdje:

- \(T\): trenutna temperatura piva
- \(T_D\): temperatura hladnjaka ili zamrzivaca

Na pocetku vrijedi:

\[
\Delta_0 = T_0 - T_D
\]

Ciljna temperatura opisuje se kao bezdimenzijski omjer:

\[
\theta = \frac{T_Z - T_D}{T_0 - T_D}
\]

Gdje:

- \(T_0\): pocetna temperatura piva
- \(T_Z\): ciljna temperatura
- \(\theta\): bezdimenzijski omjer ciljne temperature

## 2. Prijenos topline ovisan o temperaturi

Hladenje se usporava kako se pivo priblizava temperaturi uredaja. BeerCHILLER to modelira malim empirijskim eksponentom:

\[
n = 0.15
\]

Toplinski tok se priblizno uzima kao proporcionalan:

\[
\dot Q \sim \Delta^{1+n}
\]

Iz toga slijedi jednadzba hladenja:

\[
\frac{d\Delta}{dt} = -k \cdot \Delta^{1+n}
\]

## 3. Formula vremena

Nakon razdvajanja varijabli, vrijeme od pocetne razlike \(\Delta_0\) do ciljne razlike \(\Delta_Z\) je:

\[
t \sim \Delta_0^{-n} \cdot \frac{\theta^{-n}-1}{n}
\]

Aplikacija koristi referentnu temperaturnu razliku kako bi konstante ostale jednostavne za kalibraciju:

\[
\Delta_{ref}=25K
\]

## 4. Konačna formula aplikacije

Aplikacija koristi:

\[
t =
\tau_0
\cdot f_D
\cdot f_P
\cdot
\left(\frac{25}{T_0-T_D}\right)^{0.15}
\cdot
\frac{
\left(
\frac{T_Z-T_D}{T_0-T_D}
\right)^{-0.15}
-1
}{0.15}
\]

Izracunato vrijeme zaokruzuje se prema gore na pune minute:

\[
t_{app}=\lceil t \rceil
\]

Ako nastane pozitivno vrijeme manje od jedne minute, aplikacija prikazuje najmanje 1 minutu.

## 5. Konstante

Globalna kalibracija je:

\[
n = 0.15
\]

\[
\Delta_{ref}=25K
\]

Osnovne vrijednosti za \(\tau_0\):

| Ambalaza | Volumen | \(\tau_0\) |
|---|---:|---:|
| Boca | 0.33 l | 87 min |
| Boca | 0.5 l | 110 min |
| Boca | 1.0 l | 155 min |
| Limenka | 0.33 l | 85 min |
| Limenka | 0.5 l | 105 min |

Faktori uredaja:

| Uredaj | \(f_D\) |
|---|---:|
| Hladnjak | 1.00 |
| Zamrzivac | 0.84 |

Faktori polozaja:

| Ambalaza | Uspravno | Polegnuto |
|---|---:|---:|
| Boca | 1.00 | 0.95 |
| Limenka | 1.00 | 0.92 |

## 6. Korekcija hladnog starta za staklene boce u zamrzivaču

BeerChiller Calibrated V2.1 prosiruje model V2 internim korekcijskim faktorom za staklene boce u zamrzivacu kada pivo vec pocinje relativno hladno. Faktor vrijedi samo za boce u zamrzivacu, ne za limenke i ne za hladnjak.

Od pocetne temperature 24 stupnja Celzija faktor ostaje 1,00. Na 16 stupnjeva Celzija ili nize raste na 1,70. Izmedu tih vrijednosti interpolira se glatko. Time topla mjerenja ostaju nepromijenjena, a kratka hladenja u zamrzivacu s hladnim startom postaju realnija.

## 7. Temperatura tijekom timera

Tijekom aktivnog timera aplikacija koristi istu krivulju unatrag kako bi procijenila trenutnu temperaturu piva:

\[
\theta(t)=
\left(
1+n\cdot\frac{t}{\tau_{eff}}
\right)^{-1/n}
\]

\[
T(t)=T_D+(T_0-T_D)\cdot\theta(t)
\]

Ovdje je \(\tau_{eff}\) kalibrirani vremenski faktor iz \(\tau_0\), \(f_D\), \(f_P\) i korekcije temperaturne razlike.

## 8. Pravila valjanosti

Aplikacija ne prikazuje beskonacna, negativna ili neizracunljiva vremena.

- Ako je \(T_0 \le T_Z\), pivo je vec dovoljno hladno.
- Ako je \(T_Z \le T_D\), ciljna temperatura nije smisleno dostizna.
- Ako je \(\Delta_0 \le 0\), unos nije valjan.
- Vrijedi samo raspon \(0 < \theta < 1\).

## 9. Kalibracija

Model je uglavnom kalibriran prema mjerenjima staklene boce od 0.33 l.

Hladnjak na oko 5.3 stupnja Celzija i pocetna temperatura 32.94 stupnja Celzija:

| Ciljna temperatura | Izmjereno vrijeme | Model V2.1 |
|---:|---:|---:|
| 12 stupnjeva Celzija | oko 134 min | 136 min |
| 10 stupnjeva Celzija | oko 172 min | 174 min |
| 8 stupnjeva Celzija | oko 239 min | 239 min |

Zamrzivac na oko -17.5 stupnjeva Celzija i pocetna temperatura 39.5 stupnjeva Celzija:

| Ciljna temperatura | Izmjereno vrijeme | Model V2.1 |
|---:|---:|---:|
| 6 stupnjeva Celzija | oko 61 min | 62 min |

## 10. Ograničenja modela

Izracun ne uzima u obzir:

- zaledivanje
- toplinu kristalizacije
- fazne promjene
- tresenje ili pomicanje piva
- tocan protok zraka u uredaju
- razlicite oblike boca
- tocne kontaktne povrsine s policom
- karton, vrecice ili dodatnu izolaciju

Blizu tocke smrzavanja izracun postaje manje pouzdan. Za normalne temperature pijenja, kao 8 stupnjeva Celzija ili 6 stupnjeva Celzija, model je prakticna aproksimacija.

## Primjer

Staklena boca od 0.33 l od 39.5 stupnjeva Celzija do 6 stupnjeva Celzija u zamrzivacu na -17.5 stupnjeva Celzija daje:

\[
t_{app} \approx 62\,\text{min}
\]
