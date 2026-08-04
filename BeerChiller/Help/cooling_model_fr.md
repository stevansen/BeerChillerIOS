# Modèle de calcul

L'application calcule le temps de refroidissement de la bière dans un réfrigérateur ou un congélateur avec le modèle **BeerCHILLER Calibrated V2**.

Le modèle est une approximation pratique. Il utilise la température initiale, la température cible, la température de l'appareil, le contenant, le volume et la position. En pratique, les appareils peuvent refroidir plus vite ou plus lentement selon le flux d'air, les surfaces de contact, le chargement et les ouvertures de porte.

## 1. Différence de température

La valeur déterminante est la différence de température entre la bière et l'appareil:

\[
\Delta = T - T_D
\]

Où:

- \(T\): température actuelle de la bière
- \(T_D\): température du réfrigérateur ou du congélateur

Au départ:

\[
\Delta_0 = T_0 - T_D
\]

La température cible est exprimée comme un rapport sans dimension:

\[
\theta = \frac{T_Z - T_D}{T_0 - T_D}
\]

Où:

- \(T_0\): température initiale de la bière
- \(T_Z\): température cible
- \(\theta\): rapport sans dimension de la température cible

## 2. Transfert thermique dépendant de la température

Le refroidissement ralentit lorsque la bière se rapproche de la température de l'appareil. BeerCHILLER modélise cela avec un petit exposant empirique:

\[
n = 0.15
\]

Le flux thermique est approximé comme proportionnel à:

\[
\dot Q \sim \Delta^{1+n}
\]

Cela donne l'équation de refroidissement:

\[
\frac{d\Delta}{dt} = -k \cdot \Delta^{1+n}
\]

## 3. Formule du temps

Après séparation des variables, le temps entre la différence initiale \(\Delta_0\) et la différence cible \(\Delta_Z\) est:

\[
t \sim \Delta_0^{-n} \cdot \frac{\theta^{-n}-1}{n}
\]

L'application utilise une différence de température de référence afin que les constantes restent faciles à calibrer:

\[
\Delta_{ref}=25K
\]

## 4. Formule finale de l'application

L'application utilise:

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

Le temps calculé est arrondi à la minute supérieure:

\[
t_{app}=\lceil t \rceil
\]

Si un temps positif inférieur à une minute apparaît, l'application affiche au moins 1 minute.

## 5. Constantes

La calibration globale est:

\[
n = 0.15
\]

\[
\Delta_{ref}=25K
\]

Valeurs de base pour \(\tau_0\):

| Contenant | Volume | \(\tau_0\) |
|---|---:|---:|
| Bouteille | 0.33 l | 87 min |
| Bouteille | 0.5 l | 110 min |
| Bouteille | 1.0 l | 155 min |
| Canette | 0.33 l | 85 min |
| Canette | 0.5 l | 105 min |

Facteurs de l'appareil:

| Appareil | \(f_D\) |
|---|---:|
| Réfrigérateur | 1.00 |
| Congélateur | 0.84 |

Facteurs de position:

| Contenant | Debout | Couché |
|---|---:|---:|
| Bouteille | 1.00 | 0.95 |
| Canette | 1.00 | 0.92 |

## 6. Correction de depart froid pour les bouteilles au congelateur

BeerChiller Calibrated V2.1 ajoute au modele V2 un facteur interne pour les bouteilles en verre au congelateur lorsque la biere est deja relativement fraiche au depart. Ce facteur ne s'applique qu'aux bouteilles au congelateur, pas aux canettes ni au refrigerateur.

A partir de 24 degres Celsius de temperature initiale, le facteur reste a 1,00. A 16 degres Celsius ou moins, il monte a 1,70. Entre les deux, l'interpolation est progressive. Les mesures avec une biere chaude restent donc inchangees, tandis que les passages courts au congelateur avec une temperature initiale basse deviennent plus realistes.

## 7. Température pendant le minuteur

Pendant un minuteur actif, l'application utilise la même courbe en sens inverse pour estimer la température actuelle de la bière:

\[
\theta(t)=
\left(
1+n\cdot\frac{t}{\tau_{eff}}
\right)^{-1/n}
\]

\[
T(t)=T_D+(T_0-T_D)\cdot\theta(t)
\]

Ici, \(\tau_{eff}\) est le facteur de temps calibré à partir de \(\tau_0\), \(f_D\), \(f_P\) et de la correction de différence de température.

## 8. Règles de validité

L'application n'affiche pas de temps infinis, négatifs ou non calculables.

- Si \(T_0 \le T_Z\), la bière est déjà assez froide.
- Si \(T_Z \le T_D\), la température cible n'est pas atteignable de façon significative.
- Si \(\Delta_0 \le 0\), l'entrée n'est pas valide.
- Seul \(0 < \theta < 1\) est valide.

## 9. Calibration

Le modèle est principalement calibré sur des mesures d'une bouteille en verre de 0.33 l.

Réfrigérateur à environ 5.3 degrés Celsius et température initiale de 32.94 degrés Celsius:

| Température cible | Temps mesuré | Modèle V2 |
|---:|---:|---:|
| 12 degrés Celsius | env. 134 min | 136 min |
| 10 degrés Celsius | env. 172 min | 174 min |
| 8 degrés Celsius | env. 239 min | 239 min |

Congélateur à environ -17.5 degrés Celsius et température initiale de 39.5 degrés Celsius:

| Température cible | Temps mesuré | Modèle V2 |
|---:|---:|---:|
| 6 degrés Celsius | env. 61 min | 62 min |

## 10. Limites du modèle

Le calcul ne prend pas en compte:

- formation de glace
- chaleur de cristallisation
- changements de phase
- secousses ou mouvement de la bière
- flux d'air exact dans l'appareil
- différentes formes de bouteilles
- surfaces de contact exactes avec l'étagère
- carton, sacs ou isolation supplémentaire

Près du point de congélation, le calcul devient moins fiable. Pour les températures normales de dégustation, comme 8 degrés Celsius ou 6 degrés Celsius, le modèle reste une approximation pratique.

## Exemple

Une bouteille en verre de 0.33 l de 39.5 degrés Celsius à 6 degrés Celsius dans un congélateur à -17.5 degrés Celsius donne:

\[
t_{app} \approx 62\,\text{min}
\]
