# Modelo de cálculo

La app calcula el tiempo de enfriamiento de la cerveza en el frigorífico o el congelador con el modelo **BeerCHILLER Calibrated V2**.

El modelo es una aproximación práctica. Usa la temperatura inicial, la temperatura deseada, la temperatura del aparato, el recipiente, el volumen y la posición. Los aparatos reales pueden enfriar más rápido o más lento por el flujo de aire, las superficies de contacto, la carga y las aperturas de la puerta.

## 1. Diferencia de temperatura

El valor determinante es la diferencia de temperatura entre la cerveza y el aparato:

\[
\Delta = T - T_D
\]

Donde:

- \(T\): temperatura actual de la cerveza
- \(T_D\): temperatura del frigorífico o congelador

Al inicio:

\[
\Delta_0 = T_0 - T_D
\]

La temperatura deseada se expresa como una relación adimensional:

\[
\theta = \frac{T_Z - T_D}{T_0 - T_D}
\]

Donde:

- \(T_0\): temperatura inicial de la cerveza
- \(T_Z\): temperatura deseada
- \(\theta\): relación adimensional de la temperatura deseada

## 2. Transferencia de calor dependiente de la temperatura

El enfriamiento se ralentiza cuando la cerveza se acerca a la temperatura del aparato. BeerCHILLER lo modela con un pequeño exponente empírico:

\[
n = 0.15
\]

El flujo de calor se aproxima como proporcional a:

\[
\dot Q \sim \Delta^{1+n}
\]

Esto da la ecuación de enfriamiento:

\[
\frac{d\Delta}{dt} = -k \cdot \Delta^{1+n}
\]

## 3. Fórmula del tiempo

Tras separar las variables, el tiempo desde la diferencia inicial \(\Delta_0\) hasta la diferencia deseada \(\Delta_Z\) es:

\[
t \sim \Delta_0^{-n} \cdot \frac{\theta^{-n}-1}{n}
\]

La app usa una diferencia de temperatura de referencia para que las constantes sean fáciles de calibrar:

\[
\Delta_{ref}=25K
\]

## 4. Fórmula final de la app

La app usa:

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

El tiempo calculado se redondea hacia arriba a minutos completos:

\[
t_{app}=\lceil t \rceil
\]

Si aparece un tiempo positivo inferior a un minuto, la app muestra al menos 1 minuto.

## 5. Constantes

La calibración global es:

\[
n = 0.15
\]

\[
\Delta_{ref}=25K
\]

Valores base para \(\tau_0\):

| Recipiente | Volumen | \(\tau_0\) |
|---|---:|---:|
| Botella | 0.33 l | 87 min |
| Botella | 0.5 l | 110 min |
| Botella | 1.0 l | 155 min |
| Lata | 0.33 l | 85 min |
| Lata | 0.5 l | 105 min |

Factores del aparato:

| Aparato | \(f_D\) |
|---|---:|
| Frigorífico | 1.00 |
| Congelador | 0.84 |

Factores de posición:

| Recipiente | Vertical | Horizontal |
|---|---:|---:|
| Botella | 1.00 | 0.95 |
| Lata | 1.00 | 0.92 |

## 6. Correccion de inicio frio para botellas en el congelador

BeerChiller Calibrated V2.1 amplia el modelo V2 con un factor interno para botellas de vidrio en el congelador cuando la cerveza ya empieza relativamente fria. El factor solo se aplica a botellas en el congelador, no a latas ni al refrigerador.

A partir de 24 grados Celsius de temperatura inicial el factor se mantiene en 1,00. A 16 grados Celsius o menos sube a 1,70. Entre esos valores se interpola suavemente. Asi las mediciones con cerveza caliente no cambian, mientras que los enfriamientos cortos en congelador con inicio frio son mas realistas.

## 7. Temperatura durante el temporizador

Durante un temporizador activo, la app usa la misma curva en sentido inverso para estimar la temperatura actual de la cerveza:

\[
\theta(t)=
\left(
1+n\cdot\frac{t}{\tau_{eff}}
\right)^{-1/n}
\]

\[
T(t)=T_D+(T_0-T_D)\cdot\theta(t)
\]

Aquí, \(\tau_{eff}\) es el factor de tiempo calibrado a partir de \(\tau_0\), \(f_D\), \(f_P\) y la corrección de la diferencia de temperatura.

## 8. Reglas de validez

La app no muestra tiempos infinitos, negativos o no calculables.

- Si \(T_0 \le T_Z\), la cerveza ya está suficientemente fría.
- Si \(T_Z \le T_D\), la temperatura deseada no se puede alcanzar de forma significativa.
- Si \(\Delta_0 \le 0\), la entrada no es válida.
- Solo es válido \(0 < \theta < 1\).

## 9. Calibración

El modelo está calibrado principalmente con mediciones de una botella de vidrio de 0.33 l.

Frigorífico a unos 5.3 grados Celsius y temperatura inicial de 32.94 grados Celsius:

| Temperatura deseada | Tiempo medido | Modelo V2.1 |
|---:|---:|---:|
| 12 grados Celsius | aprox. 134 min | 136 min |
| 10 grados Celsius | aprox. 172 min | 174 min |
| 8 grados Celsius | aprox. 239 min | 239 min |

Congelador a unos -17.5 grados Celsius y temperatura inicial de 39.5 grados Celsius:

| Temperatura deseada | Tiempo medido | Modelo V2.1 |
|---:|---:|---:|
| 6 grados Celsius | aprox. 61 min | 62 min |

## 10. Límites del modelo

El cálculo no considera:

- formación de hielo
- calor de cristalización
- cambios de fase
- sacudidas o movimiento de la cerveza
- flujo de aire exacto en el aparato
- diferentes formas de botella
- superficies exactas de contacto con el estante
- cartón, bolsas o aislamiento adicional

Cerca del punto de congelación el cálculo es menos fiable. Para temperaturas normales de consumo, como 8 grados Celsius o 6 grados Celsius, el modelo es una aproximación práctica.

## Ejemplo

Una botella de vidrio de 0.33 l de 39.5 grados Celsius a 6 grados Celsius en un congelador a -17.5 grados Celsius da:

\[
t_{app} \approx 62\,\text{min}
\]
