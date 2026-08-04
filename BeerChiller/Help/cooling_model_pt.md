# Modelo de cálculo

A app calcula o tempo de arrefecimento da cerveja no frigorífico ou congelador com o modelo **BeerChiller Calibrated V2.1**.

O modelo é uma aproximação prática. Usa a temperatura inicial, a temperatura alvo, a temperatura do aparelho, o recipiente, o volume e a posição. Na prática, os aparelhos podem arrefecer mais depressa ou mais devagar devido ao fluxo de ar, superfícies de contacto, carga e aberturas da porta.

## 1. Diferença de temperatura

O valor determinante é a diferença de temperatura entre a cerveja e o aparelho:

\[
\Delta = T - T_D
\]

Onde:

- \(T\): temperatura atual da cerveja
- \(T_D\): temperatura do frigorífico ou congelador

No início:

\[
\Delta_0 = T_0 - T_D
\]

A temperatura alvo é descrita como uma razão adimensional:

\[
\theta = \frac{T_Z - T_D}{T_0 - T_D}
\]

Onde:

- \(T_0\): temperatura inicial da cerveja
- \(T_Z\): temperatura alvo
- \(\theta\): razão adimensional da temperatura alvo

## 2. Transferência de calor dependente da temperatura

O arrefecimento abranda quando a cerveja se aproxima da temperatura do aparelho. O BeerCHILLER modela isto com um pequeno expoente empírico:

\[
n = 0.15
\]

O fluxo de calor é aproximado como proporcional a:

\[
\dot Q \sim \Delta^{1+n}
\]

Isto dá a equação de arrefecimento:

\[
\frac{d\Delta}{dt} = -k \cdot \Delta^{1+n}
\]

## 3. Fórmula do tempo

Depois de separar as variáveis, o tempo da diferença inicial \(\Delta_0\) até à diferença alvo \(\Delta_Z\) é:

\[
t \sim \Delta_0^{-n} \cdot \frac{\theta^{-n}-1}{n}
\]

A app usa uma diferença de temperatura de referência para manter as constantes fáceis de calibrar:

\[
\Delta_{ref}=25K
\]

## 4. Fórmula final da app

A app usa:

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

O tempo calculado é arredondado para cima para minutos inteiros:

\[
t_{app}=\lceil t \rceil
\]

Se ocorrer um tempo positivo inferior a um minuto, a app mostra pelo menos 1 minuto.

## 5. Constantes

A calibração global é:

\[
n = 0.15
\]

\[
\Delta_{ref}=25K
\]

Valores base para \(\tau_0\):

| Recipiente | Volume | \(\tau_0\) |
|---|---:|---:|
| Garrafa | 0.33 l | 87 min |
| Garrafa | 0.5 l | 110 min |
| Garrafa | 1.0 l | 155 min |
| Lata | 0.33 l | 85 min |
| Lata | 0.5 l | 105 min |

Fatores do aparelho:

| Aparelho | \(f_D\) |
|---|---:|
| Frigorífico | 1.00 |
| Congelador | 0.84 |

Fatores de posição:

| Recipiente | Em pé | Deitado |
|---|---:|---:|
| Garrafa | 1.00 | 0.95 |
| Lata | 1.00 | 0.92 |

## 6. Correção de início frio para garrafas no congelador

BeerChiller Calibrated V2.1 amplia o modelo V2 com um fator interno para garrafas de vidro no congelador quando a cerveja já começa relativamente fria. O fator vale apenas para garrafas no congelador, não para latas nem para o frigorífico.

A partir de 24 graus Celsius de temperatura inicial o fator permanece em 1,00. A 16 graus Celsius ou menos sobe para 1,70. Entre esses valores a interpolação é suave. Assim, as medições com cerveja quente permanecem iguais, enquanto arrefecimentos curtos no congelador com início frio ficam mais realistas.

## 7. Temperatura durante o temporizador

Durante um temporizador ativo, a app usa a mesma curva em sentido inverso para estimar a temperatura atual da cerveja:

\[
\theta(t)=
\left(
1+n\cdot\frac{t}{\tau_{eff}}
\right)^{-1/n}
\]

\[
T(t)=T_D+(T_0-T_D)\cdot\theta(t)
\]

Aqui, \(\tau_{eff}\) é o fator de tempo calibrado a partir de \(\tau_0\), \(f_D\), \(f_P\) e da correção da diferença de temperatura.

## 8. Regras de validade

A app não mostra tempos infinitos, negativos ou não calculáveis.

- Se \(T_0 \le T_Z\), a cerveja já está suficientemente fria.
- Se \(T_Z \le T_D\), a temperatura alvo não é significativamente atingível.
- Se \(\Delta_0 \le 0\), a entrada é inválida.
- Apenas \(0 < \theta < 1\) é válido.

## 9. Calibração

O modelo é calibrado principalmente com medições de uma garrafa de vidro de 0.33 l.

Frigorífico a cerca de 5.3 graus Celsius e temperatura inicial de 32.94 graus Celsius:

| Temperatura alvo | Tempo medido | Modelo V2.1 |
|---:|---:|---:|
| 12 graus Celsius | cerca de 134 min | 136 min |
| 10 graus Celsius | cerca de 172 min | 174 min |
| 8 graus Celsius | cerca de 239 min | 239 min |

Congelador a cerca de -17.5 graus Celsius e temperatura inicial de 39.5 graus Celsius:

| Temperatura alvo | Tempo medido | Modelo V2.1 |
|---:|---:|---:|
| 6 graus Celsius | cerca de 61 min | 62 min |

## 10. Limites do modelo

O cálculo não considera:

- formação de gelo
- calor de cristalização
- mudanças de fase
- agitação ou movimento da cerveja
- fluxo de ar exato no aparelho
- diferentes formatos de garrafa
- superfícies de contacto exatas com a prateleira
- cartão, sacos ou isolamento adicional

Perto do ponto de congelação, o cálculo torna-se menos fiável. Para temperaturas normais de consumo, como 8 graus Celsius ou 6 graus Celsius, o modelo é uma aproximação prática.

## Exemplo

Uma garrafa de vidro de 0.33 l de 39.5 graus Celsius para 6 graus Celsius num congelador a -17.5 graus Celsius resulta em:

\[
t_{app} \approx 62\,\text{min}
\]
