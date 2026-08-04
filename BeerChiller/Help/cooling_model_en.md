# Calculation model

The app calculates beer cooling time in a refrigerator or freezer with **BeerChiller Calibrated V2.1**.

The model is a practical approximation. It uses the starting temperature, target temperature, device temperature, container, volume, and position. Real appliances can cool faster or slower because of airflow, contact surfaces, loading, and door openings.

## 1. Temperature difference

The driving value is the temperature difference between beer and appliance:

\[
\Delta = T - T_D
\]

Where:

- \(T\): current beer temperature
- \(T_D\): refrigerator or freezer temperature

At the start:

\[
\Delta_0 = T_0 - T_D
\]

The target temperature is written as a dimensionless ratio:

\[
\theta = \frac{T_Z - T_D}{T_0 - T_D}
\]

Where:

- \(T_0\): starting beer temperature
- \(T_Z\): target beer temperature
- \(\theta\): dimensionless target ratio

## 2. Temperature-dependent heat transfer

As the beer gets closer to the appliance temperature, cooling slows down. BeerChiller models this with a small empirical exponent:

\[
n = 0.15
\]

The heat flow is approximated as proportional to:

\[
\dot Q \sim \Delta^{1+n}
\]

This gives the cooling equation:

\[
\frac{d\Delta}{dt} = -k \cdot \Delta^{1+n}
\]

## 3. Time formula

After separating the variables, the time from the starting difference \(\Delta_0\) to the target difference \(\Delta_Z\) is:

\[
t \sim \Delta_0^{-n} \cdot \frac{\theta^{-n}-1}{n}
\]

The app uses a reference temperature difference so the constants remain easy to calibrate:

\[
\Delta_{ref}=25K
\]

## 4. Final app formula

The app uses:

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

The calculated time is rounded up to full minutes:

\[
t_{app}=\lceil t \rceil
\]

If a positive time below one minute occurs, the app shows at least 1 minute.

## 5. Constants

The global calibration is:

\[
n = 0.15
\]

\[
\Delta_{ref}=25K
\]

Base values for \(\tau_0\):

| Container | Volume | \(\tau_0\) |
|---|---:|---:|
| Bottle | 0.33 l | 87 min |
| Bottle | 0.5 l | 110 min |
| Bottle | 1.0 l | 155 min |
| Can | 0.33 l | 85 min |
| Can | 0.5 l | 105 min |

Device factors:

| Device | \(f_D\) |
|---|---:|
| Refrigerator | 1.00 |
| Freezer | 0.84 |

Position factors:

| Container | Standing | Lying |
|---|---:|---:|
| Bottle | 1.00 | 0.95 |
| Can | 1.00 | 0.92 |

## 6. Cold-start correction for glass bottles in the freezer

BeerChiller Calibrated V2.1 extends the V2 model with an internal correction factor for glass bottles in the freezer when the beer already starts relatively cool. The factor applies only to bottles in the freezer, not to cans and not to the refrigerator.

From 24 degrees Celsius starting temperature upward the factor remains 1.00. At 16 degrees Celsius or below it rises to 1.70. Between those values it is interpolated smoothly. This keeps warm calibration runs unchanged while making short freezer runs with a cool starting temperature more realistic.

## 7. Temperature during the timer

During an active timer, the app uses the same curve in reverse to estimate the current beer temperature:

\[
\theta(t)=
\left(
1+n\cdot\frac{t}{\tau_{eff}}
\right)^{-1/n}
\]

\[
T(t)=T_D+(T_0-T_D)\cdot\theta(t)
\]

Here, \(\tau_{eff}\) is the calibrated time factor from \(\tau_0\), \(f_D\), \(f_P\), and the temperature-difference correction.

## 8. Validity rules

The app does not display infinite, negative, or non-computable times.

- If \(T_0 \le T_Z\), the beer is already cold enough.
- If \(T_Z \le T_D\), the target temperature is not meaningfully reachable.
- If \(\Delta_0 \le 0\), the input is invalid.
- Only \(0 < \theta < 1\) is valid.

## 9. Calibration

The model is mainly calibrated against measurements from a 0.33 l glass bottle.

Refrigerator at about 5.3 degrees Celsius and starting temperature 32.94 degrees Celsius:

| Target temperature | Measured time | V2.1 model |
|---:|---:|---:|
| 12 degrees Celsius | about 134 min | 136 min |
| 10 degrees Celsius | about 172 min | 174 min |
| 8 degrees Celsius | about 239 min | 239 min |

Freezer at about -17.5 degrees Celsius and starting temperature 39.5 degrees Celsius:

| Target temperature | Measured time | V2.1 model |
|---:|---:|---:|
| 6 degrees Celsius | about 61 min | 62 min |

## 10. Model limits

The calculation does not consider:

- icing
- crystallization heat
- phase changes
- shaking or movement of the beer
- exact airflow in the appliance
- different bottle shapes
- exact contact surfaces with the shelf
- cardboard, bags, or additional insulation

Near the freezing point the calculation becomes less reliable. For normal drinking temperatures such as 8 degrees Celsius or 6 degrees Celsius, the model is a practical approximation.

## Example

A 0.33 l glass bottle from 39.5 degrees Celsius to 6 degrees Celsius in a freezer at -17.5 degrees Celsius gives:

\[
t_{app} \approx 62\,\text{min}
\]
