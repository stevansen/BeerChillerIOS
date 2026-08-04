# Modello di calcolo

L'app calcola il tempo di raffreddamento della birra in frigorifero o in congelatore con il modello **BeerCHILLER Calibrated V2**.

Il modello è una stima pratica. Usa la temperatura iniziale, la temperatura desiderata, la temperatura dell'apparecchio, il contenitore, il volume e la posizione. Gli apparecchi reali possono raffreddare più rapidamente o più lentamente a causa del flusso d'aria, delle superfici di contatto, del carico e delle aperture dello sportello.

## 1. Differenza di temperatura

Il valore determinante è la differenza di temperatura tra birra e apparecchio:

\[
\Delta = T - T_D
\]

Dove:

- \(T\): temperatura attuale della birra
- \(T_D\): temperatura del frigorifero o del congelatore

All'inizio vale:

\[
\Delta_0 = T_0 - T_D
\]

La temperatura desiderata viene descritta come rapporto adimensionale:

\[
\theta = \frac{T_Z - T_D}{T_0 - T_D}
\]

Dove:

- \(T_0\): temperatura iniziale della birra
- \(T_Z\): temperatura desiderata
- \(\theta\): rapporto adimensionale della temperatura desiderata

## 2. Trasferimento di calore dipendente dalla temperatura

Il raffreddamento rallenta man mano che la birra si avvicina alla temperatura dell'apparecchio. BeerCHILLER lo modella con un piccolo esponente empirico:

\[
n = 0.15
\]

Il flusso di calore viene approssimato come proporzionale a:

\[
\dot Q \sim \Delta^{1+n}
\]

Da questo deriva l'equazione di raffreddamento:

\[
\frac{d\Delta}{dt} = -k \cdot \Delta^{1+n}
\]

## 3. Formula del tempo

Dopo la separazione delle variabili, il tempo dalla differenza iniziale \(\Delta_0\) alla differenza desiderata \(\Delta_Z\) è:

\[
t \sim \Delta_0^{-n} \cdot \frac{\theta^{-n}-1}{n}
\]

L'app usa una differenza di temperatura di riferimento, cosi le costanti rimangono facili da calibrare:

\[
\Delta_{ref}=25K
\]

## 4. Formula finale dell'app

L'app usa:

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

Il tempo calcolato viene arrotondato per eccesso a minuti interi:

\[
t_{app}=\lceil t \rceil
\]

Se risulta un tempo positivo inferiore a un minuto, l'app mostra almeno 1 minuto.

## 5. Costanti

La calibrazione globale è:

\[
n = 0.15
\]

\[
\Delta_{ref}=25K
\]

Valori base per \(\tau_0\):

| Contenitore | Volume | \(\tau_0\) |
|---|---:|---:|
| Bottiglia | 0.33 l | 87 min |
| Bottiglia | 0.5 l | 110 min |
| Bottiglia | 1.0 l | 155 min |
| Lattina | 0.33 l | 85 min |
| Lattina | 0.5 l | 105 min |

Fattori dell'apparecchio:

| Apparecchio | \(f_D\) |
|---|---:|
| Frigorifero | 1.00 |
| Congelatore | 0.84 |

Fattori di posizione:

| Contenitore | Verticale | Orizzontale |
|---|---:|---:|
| Bottiglia | 1.00 | 0.95 |
| Lattina | 1.00 | 0.92 |

## 6. Correzione per partenza fredda delle bottiglie in freezer

BeerChiller Calibrated V2.1 estende il modello V2 con un fattore interno per le bottiglie di vetro in freezer quando la birra parte gia relativamente fresca. Il fattore vale solo per le bottiglie in freezer, non per le lattine e non per il frigorifero.

Da 24 gradi Celsius di temperatura iniziale in su il fattore resta 1,00. A 16 gradi Celsius o meno sale a 1,70. Tra questi valori viene interpolato in modo graduale. Le misurazioni con birra calda restano quindi invariate, mentre i raffreddamenti brevi in freezer con partenza fresca diventano piu realistici.

## 7. Temperatura durante il timer

Durante un timer attivo, l'app usa la stessa curva al contrario per stimare la temperatura attuale della birra:

\[
\theta(t)=
\left(
1+n\cdot\frac{t}{\tau_{eff}}
\right)^{-1/n}
\]

\[
T(t)=T_D+(T_0-T_D)\cdot\theta(t)
\]

Qui \(\tau_{eff}\) è il fattore di tempo calibrato da \(\tau_0\), \(f_D\), \(f_P\) e dalla correzione della differenza di temperatura.

## 8. Regole di validità

L'app non mostra tempi infiniti, negativi o non calcolabili.

- Se \(T_0 \le T_Z\), la birra è già abbastanza fredda.
- Se \(T_Z \le T_D\), la temperatura desiderata non è raggiungibile in modo significativo.
- Se \(\Delta_0 \le 0\), l'input non è valido.
- È valido solo \(0 < \theta < 1\).

## 9. Calibrazione

Il modello è calibrato soprattutto su misurazioni con una bottiglia di vetro da 0.33 l.

Frigorifero a circa 5.3 gradi Celsius e temperatura iniziale 32.94 gradi Celsius:

| Temperatura desiderata | Tempo misurato | Modello V2.1 |
|---:|---:|---:|
| 12 gradi Celsius | circa 134 min | 136 min |
| 10 gradi Celsius | circa 172 min | 174 min |
| 8 gradi Celsius | circa 239 min | 239 min |

Congelatore a circa -17.5 gradi Celsius e temperatura iniziale 39.5 gradi Celsius:

| Temperatura desiderata | Tempo misurato | Modello V2.1 |
|---:|---:|---:|
| 6 gradi Celsius | circa 61 min | 62 min |

## 10. Limiti del modello

Il calcolo non considera:

- ghiaccio
- calore di cristallizzazione
- cambiamenti di fase
- scuotimento o movimento della birra
- flusso d'aria esatto nell'apparecchio
- forme diverse delle bottiglie
- superfici di contatto esatte con il ripiano
- cartone, borse o isolamento aggiuntivo

Vicino al punto di congelamento il calcolo diventa meno affidabile. Per temperature normali di consumo, come 8 gradi Celsius o 6 gradi Celsius, il modello è una stima pratica.

## Esempio

Una bottiglia di vetro da 0.33 l da 39.5 gradi Celsius a 6 gradi Celsius in un congelatore a -17.5 gradi Celsius richiede:

\[
t_{app} \approx 62\,\text{min}
\]
