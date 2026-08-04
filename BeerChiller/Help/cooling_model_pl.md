# Model obliczeniowy

Aplikacja oblicza czas chłodzenia piwa w lodówce lub zamrażarce za pomocą modelu **BeerCHILLER Calibrated V2**.

Model jest praktycznym przybliżeniem. Uwzględnia temperaturę początkową, temperaturę docelową, temperaturę urządzenia, pojemnik, objętość i położenie. W praktyce urządzenia mogą chłodzić szybciej lub wolniej z powodu przepływu powietrza, powierzchni kontaktu, załadowania i otwierania drzwi.

## 1. Różnica temperatur

Wartoscia decydujaca jest roznica temperatur miedzy piwem a urzadzeniem:

\[
\Delta = T - T_D
\]

Gdzie:

- \(T\): aktualna temperatura piwa
- \(T_D\): temperatura lodowki lub zamrazarki

Na poczatku:

\[
\Delta_0 = T_0 - T_D
\]

Temperatura docelowa jest opisana jako bezwymiarowy stosunek:

\[
\theta = \frac{T_Z - T_D}{T_0 - T_D}
\]

Gdzie:

- \(T_0\): poczatkowa temperatura piwa
- \(T_Z\): temperatura docelowa
- \(\theta\): bezwymiarowy stosunek temperatury docelowej

## 2. Przenoszenie ciepła zależne od temperatury

Chlodzenie zwalnia, gdy piwo zbliza sie do temperatury urzadzenia. BeerCHILLER modeluje to za pomoca malego wykladnika empirycznego:

\[
n = 0.15
\]

Strumien ciepla jest przyblizany jako proporcjonalny do:

\[
\dot Q \sim \Delta^{1+n}
\]

Daje to rownanie chlodzenia:

\[
\frac{d\Delta}{dt} = -k \cdot \Delta^{1+n}
\]

## 3. Wzór czasu

Po rozdzieleniu zmiennych czas od roznicy poczatkowej \(\Delta_0\) do roznicy docelowej \(\Delta_Z\) wynosi:

\[
t \sim \Delta_0^{-n} \cdot \frac{\theta^{-n}-1}{n}
\]

Aplikacja uzywa referencyjnej roznicy temperatur, aby stale byly latwe do kalibracji:

\[
\Delta_{ref}=25K
\]

## 4. Końcowy wzór aplikacji

Aplikacja uzywa:

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

Obliczony czas jest zaokraglany w gore do pelnych minut:

\[
t_{app}=\lceil t \rceil
\]

Jesli pojawi sie dodatni czas krotszy niz minuta, aplikacja pokazuje co najmniej 1 minute.

## 5. Stałe

Globalna kalibracja to:

\[
n = 0.15
\]

\[
\Delta_{ref}=25K
\]

Wartosci bazowe dla \(\tau_0\):

| Pojemnik | Objetosc | \(\tau_0\) |
|---|---:|---:|
| Butelka | 0.33 l | 87 min |
| Butelka | 0.5 l | 110 min |
| Butelka | 1.0 l | 155 min |
| Puszka | 0.33 l | 85 min |
| Puszka | 0.5 l | 105 min |

Wspolczynniki urzadzenia:

| Urzadzenie | \(f_D\) |
|---|---:|
| Lodowka | 1.00 |
| Zamrazarka | 0.84 |

Wspolczynniki polozenia:

| Pojemnik | Stojaco | Lezaco |
|---|---:|---:|
| Butelka | 1.00 | 0.95 |
| Puszka | 1.00 | 0.92 |

## 6. Korekta zimnego startu dla szklanych butelek w zamrażarce

BeerChiller Calibrated V2.1 rozszerza model V2 o wewnetrzny wspolczynnik dla szklanych butelek w zamrazarce, gdy piwo startuje juz stosunkowo chlodne. Wspolczynnik dotyczy tylko butelek w zamrazarce, nie puszek i nie lodowki.

Od temperatury poczatkowej 24 stopnie Celsjusza wspolczynnik pozostaje 1,00. Przy 16 stopniach Celsjusza lub mniej rosnie do 1,70. Pomiedzy tymi wartosciami jest plynnie interpolowany. Dzieki temu pomiary dla cieplego piwa pozostaja bez zmian, a krotkie chlodzenie w zamrazarce z niska temperatura startowa jest bardziej realistyczne.

## 7. Temperatura podczas timera

Podczas aktywnego timera aplikacja uzywa tej samej krzywej w odwrotna strone, aby oszacowac aktualna temperature piwa:

\[
\theta(t)=
\left(
1+n\cdot\frac{t}{\tau_{eff}}
\right)^{-1/n}
\]

\[
T(t)=T_D+(T_0-T_D)\cdot\theta(t)
\]

Tutaj \(\tau_{eff}\) jest skalibrowanym wspolczynnikiem czasu z \(\tau_0\), \(f_D\), \(f_P\) oraz korekty roznicy temperatur.

## 8. Reguły poprawności

Aplikacja nie pokazuje czasow nieskonczonych, ujemnych ani niemozliwych do obliczenia.

- Jesli \(T_0 \le T_Z\), piwo jest juz wystarczajaco zimne.
- Jesli \(T_Z \le T_D\), temperatura docelowa nie jest realnie osiagalna.
- Jesli \(\Delta_0 \le 0\), dane wejsciowe sa niepoprawne.
- Poprawny jest tylko zakres \(0 < \theta < 1\).

## 9. Kalibracja

Model jest skalibrowany glownie na pomiarach szklanej butelki 0.33 l.

Lodowka przy okolo 5.3 stopnia Celsjusza i temperaturze poczatkowej 32.94 stopnia Celsjusza:

| Temperatura docelowa | Czas pomiaru | Model V2.1 |
|---:|---:|---:|
| 12 stopni Celsjusza | ok. 134 min | 136 min |
| 10 stopni Celsjusza | ok. 172 min | 174 min |
| 8 stopni Celsjusza | ok. 239 min | 239 min |

Zamrazarka przy okolo -17.5 stopnia Celsjusza i temperaturze poczatkowej 39.5 stopnia Celsjusza:

| Temperatura docelowa | Czas pomiaru | Model V2.1 |
|---:|---:|---:|
| 6 stopni Celsjusza | ok. 61 min | 62 min |

## 10. Ograniczenia modelu

Obliczenie nie uwzglednia:

- oblodzenia
- ciepla krystalizacji
- zmian fazowych
- potrzasania lub ruchu piwa
- dokladnego przeplywu powietrza w urzadzeniu
- roznych ksztaltow butelek
- dokladnych powierzchni kontaktu z polka
- kartonu, toreb lub dodatkowej izolacji

Blisko punktu zamarzania obliczenie staje sie mniej pewne. Dla normalnych temperatur picia, takich jak 8 stopni Celsjusza lub 6 stopni Celsjusza, model jest praktycznym przyblizeniem.

## Przykład

Szklana butelka 0.33 l od 39.5 stopni Celsjusza do 6 stopni Celsjusza w zamrazarce o temperaturze -17.5 stopni Celsjusza daje:

\[
t_{app} \approx 62\,\text{min}
\]
