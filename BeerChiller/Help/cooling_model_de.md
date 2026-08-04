# Berechnungsmodell

Die App berechnet die Kühlzeit eines Bieres im Kühlschrank oder Gefrierschrank mit dem Modell **BeerChiller Calibrated V2.1**.

Das Modell ist eine praktische Näherung. Es verwendet Starttemperatur, Zieltemperatur, Gerätetemperatur, Gebinde, Volumen und Lage. Reale Geräte können durch Luftbewegung, Kontaktflächen, Beladung und Tür-Öffnungen schneller oder langsamer kühlen.

## 1. Temperaturdifferenz

Die treibende Größe ist die Temperaturdifferenz zwischen Bier und Gerät:

\[
\Delta = T - T_D
\]

Dabei bedeutet:

- \(T\): aktuelle Biertemperatur
- \(T_D\): Temperatur im Kühlschrank oder Gefrierschrank

Am Anfang gilt:

\[
\Delta_0 = T_0 - T_D
\]

Die Zieltemperatur wird als dimensionsloses Verhältnis beschrieben:

\[
\theta = \frac{T_Z - T_D}{T_0 - T_D}
\]

Dabei bedeutet:

- \(T_0\): Starttemperatur des Biers
- \(T_Z\): Zieltemperatur des Biers
- \(\theta\): dimensionsloses Zielverhältnis

## 2. Temperaturabhängiger Wärmeübergang

Beim Abkühlen wird die Wärmeabgabe kleiner, je näher das Bier an die Gerätetemperatur kommt. BeerChiller bildet das mit einem kleinen empirischen Exponenten ab:

\[
n = 0{,}15
\]

Der Wärmestrom wird damit näherungsweise proportional zu:

\[
\dot Q \sim \Delta^{1+n}
\]

Damit ergibt sich für die Abkühlung:

\[
\frac{d\Delta}{dt} = -k \cdot \Delta^{1+n}
\]

## 3. Zeitformel

Nach Trennung der Variablen ergibt sich für die Zeit von der Startdifferenz \(\Delta_0\) bis zur Zieldifferenz \(\Delta_Z\):

\[
t \sim \Delta_0^{-n} \cdot \frac{\theta^{-n}-1}{n}
\]

Damit die Konstanten robust kalibriert werden können, verwendet die App eine Referenz-Temperaturdifferenz:

\[
\Delta_{ref}=25K
\]

## 4. Finale App-Formel

Die App verwendet:

\[
t =
\tau_0
\cdot f_D
\cdot f_P
\cdot
\left(\frac{25}{T_0-T_D}\right)^{0{,}15}
\cdot
\frac{
\left(
\frac{T_Z-T_D}{T_0-T_D}
\right)^{-0{,}15}
-1
}{0{,}15}
\]

Die berechnete Zeit wird für die Anzeige auf volle Minuten aufgerundet:

\[
t_{app}=\lceil t \rceil
\]

Wenn eine positive Zeit kleiner als eine Minute entsteht, zeigt die App mindestens 1 Minute an.

## 5. Konstanten

Die globale Kalibrierung lautet:

\[
n = 0{,}15
\]

\[
\Delta_{ref}=25K
\]

Basiswerte für \(\tau_0\):

| Gebinde | Volumen | \(\tau_0\) |
|---|---:|---:|
| Flasche | 0,33 l | 87 min |
| Flasche | 0,5 l | 110 min |
| Flasche | 1,0 l | 155 min |
| Dose | 0,33 l | 85 min |
| Dose | 0,5 l | 105 min |

Gerätefaktoren:

| Gerät | \(f_D\) |
|---|---:|
| Kühlschrank | 1,00 |
| Gefrierschrank | 0,84 |

Lagefaktoren:

| Gebinde | stehend | liegend |
|---|---:|---:|
| Flasche | 1,00 | 0,95 |
| Dose | 1,00 | 0,92 |

## 6. Kaltstartkorrektur für Glasflaschen im Gefrierschrank

BeerChiller Calibrated V2.1 ergänzt das V2-Modell um einen internen Korrekturfaktor für Glasflaschen im Gefrierschrank, wenn das Bier bereits relativ kühl startet. Der Faktor gilt nur für Flaschen im Gefrierschrank, nicht für Dosen und nicht für den Kühlschrank.

Ab 24 Grad Celsius Starttemperatur bleibt der Faktor 1,00. Bei 16 Grad Celsius oder darunter steigt er auf 1,70. Dazwischen wird weich interpoliert. So bleibt das Verhalten bei warmen Messreihen unverändert, während kurze Gefrierfach-Läufe mit kalter Starttemperatur realistischer werden.

## 7. Temperatur während des Timers

Während eines laufenden Timers verwendet die App dieselbe Kurve rückwärts, um die aktuelle Biertemperatur zu schätzen:

\[
\theta(t)=
\left(
1+n\cdot\frac{t}{\tau_{eff}}
\right)^{-1/n}
\]

\[
T(t)=T_D+(T_0-T_D)\cdot\theta(t)
\]

Dabei ist \(\tau_{eff}\) der kalibrierte Zeitfaktor aus \(\tau_0\), \(f_D\), \(f_P\) und der Temperaturdifferenz-Korrektur.

## 8. Gültigkeitsregeln

Die App zeigt keine unendlichen, negativen oder nicht berechenbaren Zeiten an.

- Wenn \(T_0 \le T_Z\), ist das Bier bereits kalt genug.
- Wenn \(T_Z \le T_D\), ist die Zieltemperatur nicht sinnvoll erreichbar.
- Wenn \(\Delta_0 \le 0\), ist die Eingabe ungültig.
- Gültig ist nur \(0 < \theta < 1\).

## 9. Kalibrierung

Das Modell ist vor allem an Messreihen einer 0,33-l-Glasflasche kalibriert.

Kühlschrank bei etwa 5,3 Grad Celsius und Starttemperatur 32,94 Grad Celsius:

| Zieltemperatur | Messzeit | Modell V2 |
|---:|---:|---:|
| 12 Grad Celsius | ca. 134 min | 136 min |
| 10 Grad Celsius | ca. 172 min | 174 min |
| 8 Grad Celsius | ca. 239 min | 239 min |

Gefrierschrank bei etwa -17,5 Grad Celsius und Starttemperatur 39,5 Grad Celsius:

| Zieltemperatur | Messzeit | Modell V2 |
|---:|---:|---:|
| 6 Grad Celsius | ca. 61 min | 62 min |

## 10. Grenzen des Modells

Die Berechnung berücksichtigt nicht:

- Vereisung
- Kristallisationswärme
- Phasenänderung
- Schütteln oder Bewegung des Bieres
- exakte Luftströmung im Gerät
- unterschiedliche Flaschenformen
- genaue Kontaktflächen zur Ablage
- Karton, Tasche oder zusätzliche Isolation

Nahe am Gefrierpunkt wird die Berechnung unsicherer. Für normale Trinktemperaturen wie 8 Grad Celsius oder 6 Grad Celsius ist das Modell eine praktische Näherung.

## Beispiel

Eine 0,33-l-Glasflasche von 39,5 Grad Celsius auf 6 Grad Celsius im Gefrierschrank bei -17,5 Grad Celsius ergibt:

\[
t_{app} \approx 62\,\text{min}
\]
