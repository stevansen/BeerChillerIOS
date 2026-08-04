# Výpočetní model

Aplikace počítá dobu chlazení piva v lednici nebo mrazáku pomocí modelu **BeerCHILLER Calibrated V2**.

Model je praktické přiblížení. Používá počáteční teplotu, cílovou teplotu, teplotu zařízení, obal, objem a polohu. Skutečné spotřebiče mohou chladit rychleji nebo pomaleji kvůli proudění vzduchu, kontaktním plochám, naplnění a otevírání dveří.

## 1. Teplotní rozdíl

Rozhodujici hodnotou je teplotni rozdil mezi pivem a zarizenim:

\[
\Delta = T - T_D
\]

Kde:

- \(T\): aktualni teplota piva
- \(T_D\): teplota lednice nebo mrazaku

Na zacatku plati:

\[
\Delta_0 = T_0 - T_D
\]

Cilova teplota je popsana jako bezrozmerny pomer:

\[
\theta = \frac{T_Z - T_D}{T_0 - T_D}
\]

Kde:

- \(T_0\): pocatecni teplota piva
- \(T_Z\): cilova teplota
- \(\theta\): bezrozmerny pomer cilove teploty

## 2. Teplotně závislý přenos tepla

Chlazeni se zpomaluje, kdyz se pivo blizi teplote spotrebice. BeerCHILLER to modeluje malym empirickym exponentem:

\[
n = 0.15
\]

Tepelny tok je priblizne umerny:

\[
\dot Q \sim \Delta^{1+n}
\]

Z toho vychazi rovnice chlazeni:

\[
\frac{d\Delta}{dt} = -k \cdot \Delta^{1+n}
\]

## 3. Časový vzorec

Po oddeleni promennych je cas od pocatecniho rozdilu \(\Delta_0\) k cilovemu rozdilu \(\Delta_Z\):

\[
t \sim \Delta_0^{-n} \cdot \frac{\theta^{-n}-1}{n}
\]

Aplikace pouziva referencni teplotni rozdil, aby konstanty zustaly snadno kalibrovatelne:

\[
\Delta_{ref}=25K
\]

## 4. Konečný vzorec aplikace

Aplikace pouziva:

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

Vypocteny cas se zaokrouhluje nahoru na cele minuty:

\[
t_{app}=\lceil t \rceil
\]

Pokud vznikne kladny cas mensi nez jedna minuta, aplikace zobrazi alespon 1 minutu.

## 5. Konstanty

Globalni kalibrace je:

\[
n = 0.15
\]

\[
\Delta_{ref}=25K
\]

Zakladni hodnoty pro \(\tau_0\):

| Obal | Objem | \(\tau_0\) |
|---|---:|---:|
| Lahev | 0.33 l | 87 min |
| Lahev | 0.5 l | 110 min |
| Lahev | 1.0 l | 155 min |
| Plechovka | 0.33 l | 85 min |
| Plechovka | 0.5 l | 105 min |

Faktory zarizeni:

| Zarizeni | \(f_D\) |
|---|---:|
| Lednice | 1.00 |
| Mrazak | 0.84 |

Faktory polohy:

| Obal | Nastojato | Nalezato |
|---|---:|---:|
| Lahev | 1.00 | 0.95 |
| Plechovka | 1.00 | 0.92 |

## 6. Korekce studeného startu pro skleněné lahve v mrazáku

BeerChiller Calibrated V2.1 rozsiruje model V2 o interni korekcni faktor pro sklenene lahve v mrazaku, kdyz pivo zacina uz relativne chladne. Faktor plati jen pro lahve v mrazaku, ne pro plechovky a ne pro lednici.

Od pocatecni teploty 24 stupnu Celsia zustava faktor 1,00. Pri 16 stupnich Celsia nebo mene stoupne na 1,70. Mezi temito hodnotami se plynule interpoluje. Teple merici rady tak zustavaji beze zmeny, zatimco kratke chlazeni v mrazaku s nizkou pocatecni teplotou je realistictejsi.

## 7. Teplota během timeru

Behem aktivniho timeru aplikace pouziva stejnou krivku opacnym smerem, aby odhadla aktualni teplotu piva:

\[
\theta(t)=
\left(
1+n\cdot\frac{t}{\tau_{eff}}
\right)^{-1/n}
\]

\[
T(t)=T_D+(T_0-T_D)\cdot\theta(t)
\]

Zde je \(\tau_{eff}\) kalibrovany casovy faktor z \(\tau_0\), \(f_D\), \(f_P\) a korekce teplotniho rozdilu.

## 8. Pravidla platnosti

Aplikace nezobrazuje nekonecne, zaporne ani nevypocitatelne casy.

- Pokud \(T_0 \le T_Z\), pivo je uz dostatecne studene.
- Pokud \(T_Z \le T_D\), cilove teploty nelze smysluplne dosahnout.
- Pokud \(\Delta_0 \le 0\), vstup je neplatny.
- Platny je pouze rozsah \(0 < \theta < 1\).

## 9. Kalibrace

Model je kalibrovan hlavne podle mereni sklenene lahve 0.33 l.

Lednice pri asi 5.3 stupne Celsia a pocatecni teplote 32.94 stupne Celsia:

| Cilova teplota | Namerene casy | Model V2.1 |
|---:|---:|---:|
| 12 stupnu Celsia | asi 134 min | 136 min |
| 10 stupnu Celsia | asi 172 min | 174 min |
| 8 stupnu Celsia | asi 239 min | 239 min |

Mrazak pri asi -17.5 stupne Celsia a pocatecni teplote 39.5 stupne Celsia:

| Cilova teplota | Namerene casy | Model V2.1 |
|---:|---:|---:|
| 6 stupnu Celsia | asi 61 min | 62 min |

## 10. Omezení modelu

Vypocet nezohlednuje:

- namrazu
- krystalizacni teplo
- fazove zmeny
- trepani nebo pohyb piva
- presne proudění vzduchu v zarizeni
- ruzne tvary lahvi
- presne kontaktni plochy s polici
- karton, tasky nebo dalsi izolaci

Blizko bodu mrazu je vypocet mene spolehlivy. Pro bezne teploty piti, jako 8 stupnu Celsia nebo 6 stupnu Celsia, je model praktickym priblizenim.

## Příklad

Sklenena lahev 0.33 l z 39.5 stupne Celsia na 6 stupnu Celsia v mrazaku pri -17.5 stupne Celsia dava:

\[
t_{app} \approx 62\,\text{min}
\]
