# Berekeningsmodel

De app berekent de koeltijd van bier in een koelkast of vriezer met het model **BeerCHILLER Calibrated V2**.

Het model is een praktische benadering. Het gebruikt de starttemperatuur, doeltemperatuur, apparaattemperatuur, verpakking, volume en positie. In de praktijk kunnen apparaten sneller of langzamer koelen door luchtstroming, contactoppervlakken, belading en het openen van de deur.

## 1. Temperatuurverschil

De bepalende waarde is het temperatuurverschil tussen bier en apparaat:

\[
\Delta = T - T_D
\]

Waarbij:

- \(T\): actuele biertemperatuur
- \(T_D\): temperatuur van koelkast of vriezer

Aan het begin geldt:

\[
\Delta_0 = T_0 - T_D
\]

De doeltemperatuur wordt beschreven als dimensieloze verhouding:

\[
\theta = \frac{T_Z - T_D}{T_0 - T_D}
\]

Waarbij:

- \(T_0\): starttemperatuur van het bier
- \(T_Z\): doeltemperatuur
- \(\theta\): dimensieloze verhouding voor de doeltemperatuur

## 2. Temperatuurafhankelijke warmteoverdracht

Het koelen vertraagt naarmate het bier dichter bij de apparaattemperatuur komt. BeerCHILLER modelleert dit met een kleine empirische exponent:

\[
n = 0.15
\]

De warmtestroom wordt bij benadering evenredig genomen met:

\[
\dot Q \sim \Delta^{1+n}
\]

Daaruit volgt de koelvergelijking:

\[
\frac{d\Delta}{dt} = -k \cdot \Delta^{1+n}
\]

## 3. Tijdformule

Na het scheiden van de variabelen volgt voor de tijd van het startverschil \(\Delta_0\) tot het doelverschil \(\Delta_Z\):

\[
t \sim \Delta_0^{-n} \cdot \frac{\theta^{-n}-1}{n}
\]

De app gebruikt een referentie-temperatuurverschil zodat de constanten eenvoudig te kalibreren blijven:

\[
\Delta_{ref}=25K
\]

## 4. Eindformule van de app

De app gebruikt:

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

De berekende tijd wordt naar boven afgerond op hele minuten:

\[
t_{app}=\lceil t \rceil
\]

Als een positieve tijd onder een minuut ontstaat, toont de app minimaal 1 minuut.

## 5. Constanten

De globale kalibratie is:

\[
n = 0.15
\]

\[
\Delta_{ref}=25K
\]

Basiswaarden voor \(\tau_0\):

| Verpakking | Volume | \(\tau_0\) |
|---|---:|---:|
| Fles | 0.33 l | 87 min |
| Fles | 0.5 l | 110 min |
| Fles | 1.0 l | 155 min |
| Blik | 0.33 l | 85 min |
| Blik | 0.5 l | 105 min |

Apparaatfactoren:

| Apparaat | \(f_D\) |
|---|---:|
| Koelkast | 1.00 |
| Vriezer | 0.84 |

Positiefactoren:

| Verpakking | Staand | Liggend |
|---|---:|---:|
| Fles | 1.00 | 0.95 |
| Blik | 1.00 | 0.92 |

## 6. Koude-startcorrectie voor glazen flessen in de vriezer

BeerChiller Calibrated V2.1 breidt het V2-model uit met een interne correctiefactor voor glazen flessen in de vriezer wanneer het bier al relatief koel begint. De factor geldt alleen voor flessen in de vriezer, niet voor blikjes en niet voor de koelkast.

Vanaf een starttemperatuur van 24 graden Celsius blijft de factor 1,00. Bij 16 graden Celsius of lager stijgt hij naar 1,70. Daartussen wordt vloeiend geinterpoleerd. Daardoor blijven warme meetreeksen gelijk, terwijl korte vriezerkoelingen met een koele starttemperatuur realistischer worden.

## 7. Temperatuur tijdens de timer

Tijdens een actieve timer gebruikt de app dezelfde curve achteruit om de actuele biertemperatuur te schatten:

\[
\theta(t)=
\left(
1+n\cdot\frac{t}{\tau_{eff}}
\right)^{-1/n}
\]

\[
T(t)=T_D+(T_0-T_D)\cdot\theta(t)
\]

Hier is \(\tau_{eff}\) de gekalibreerde tijdfactor uit \(\tau_0\), \(f_D\), \(f_P\) en de correctie voor het temperatuurverschil.

## 8. Geldigheidsregels

De app toont geen oneindige, negatieve of niet-berekenbare tijden.

- Als \(T_0 \le T_Z\), is het bier al koud genoeg.
- Als \(T_Z \le T_D\), is de doeltemperatuur niet zinvol bereikbaar.
- Als \(\Delta_0 \le 0\), is de invoer ongeldig.
- Alleen \(0 < \theta < 1\) is geldig.

## 9. Kalibratie

Het model is vooral gekalibreerd met metingen van een glazen fles van 0.33 l.

Koelkast bij ongeveer 5.3 graden Celsius en starttemperatuur 32.94 graden Celsius:

| Doeltemperatuur | Gemeten tijd | V2-model |
|---:|---:|---:|
| 12 graden Celsius | ca. 134 min | 136 min |
| 10 graden Celsius | ca. 172 min | 174 min |
| 8 graden Celsius | ca. 239 min | 239 min |

Vriezer bij ongeveer -17.5 graden Celsius en starttemperatuur 39.5 graden Celsius:

| Doeltemperatuur | Gemeten tijd | V2-model |
|---:|---:|---:|
| 6 graden Celsius | ca. 61 min | 62 min |

## 10. Grenzen van het model

De berekening houdt geen rekening met:

- ijsvorming
- kristallisatiewarmte
- faseovergangen
- schudden of beweging van het bier
- exacte luchtstroming in het apparaat
- verschillende flesvormen
- exacte contactvlakken met het schap
- karton, tassen of extra isolatie

Dicht bij het vriespunt wordt de berekening minder betrouwbaar. Voor normale drinktemperaturen zoals 8 graden Celsius of 6 graden Celsius is het model een praktische benadering.

## Voorbeeld

Een glazen fles van 0.33 l van 39.5 graden Celsius naar 6 graden Celsius in een vriezer van -17.5 graden Celsius geeft:

\[
t_{app} \approx 62\,\text{min}
\]
