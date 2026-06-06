# 📈 Analyse et Prévision de Série Temporelle — Production Alimentaire (S C11)

![Statistiques descriptives](assets1/01_statistiques_descriptives.png)

## 🎯 Objectif du projet

Ce projet présente une analyse complète d’une **série temporelle mensuelle de production alimentaire — S C11**.
L’objectif est de comprendre l’évolution historique de l’indice, détecter les composantes importantes de la série, construire un modèle de prévision robuste, puis produire des prévisions futures avec intervalles de confiance.

Le travail suit une démarche classique de modélisation en séries temporelles :

- diagnostic statistique de la série ;
- analyse de la tendance, de la saisonnalité et de la volatilité ;
- transformation logarithmique ;
- détection et correction des outliers additifs ;
- stationnarisation par différenciation ;
- identification ACF/PACF ;
- modélisation SARIMA ;
- validation sur un test set ;
- prévision finale sur 24 mois.

---

## 📊 Résumé des données

La série étudiée correspond à un indice mensuel de production alimentaire. Les statistiques descriptives montrent une série relativement stable, mais avec une tendance haussière sur le long terme.

| Indicateur | Valeur |
|---|---:|
| Observations | 627 |
| Période | Jan 1972 — Mar 2024 |
| Moyenne | 86.09 |
| Médiane | 90.72 |
| Minimum | 56.73 |
| Maximum | 105.37 |
| Écart-type | 12.96 |
| Croissance totale | +73.15% |
| Coefficient de variation | 15.05% |

**Interprétation :** la production alimentaire présente une croissance globale positive, avec une volatilité relativement faible et une tendance haussière assez stable.

---

## 🧠 Méthodologie générale

Le projet applique une démarche complète de type **Box-Jenkins** adaptée aux séries temporelles saisonnières.

```text
Données brutes
      ↓
Diagnostic statistique
      ↓
Transformation logarithmique
      ↓
Correction des outliers
      ↓
Décomposition STL
      ↓
Test de stationnarité ADF
      ↓
Différenciation simple et saisonnière
      ↓
Identification ACF / PACF
      ↓
Modélisation SARIMA
      ↓
Validation Train / Test
      ↓
Prévision finale
```

---

## 1️⃣ Diagnostic statistique

![Diagnostic statistique](assets1/02_diagnostic_statistique.png)

La première étape consiste à visualiser la série complète et un zoom sur une période plus courte.

On observe :

- une tendance générale à la hausse ;
- une saisonnalité régulière ;
- des fluctuations mensuelles répétitives ;
- quelques perturbations visibles sur certaines périodes.

Cette étape permet de comprendre la forme globale de la série avant toute modélisation.

---

## 2️⃣ Test de stabilité de la variance

![Test de stabilité de la variance](assets1/03_test_stabilite_variance.png)

L’analyse de la volatilité montre que l’écart-type mobile varie dans le temps. Même si la volatilité reste globalement contrôlée, certaines périodes présentent des pics.

**Décision :** une transformation logarithmique est appliquée afin de stabiliser la variance et de rendre la série plus exploitable pour un modèle SARIMA.

---

## 3️⃣ Transformation logarithmique

![Transformation logarithmique](assets1/04_transformation_logarithmique.png)

La transformation logarithmique permet de réduire l’effet des variations trop fortes et de stabiliser l’amplitude des fluctuations.

**Interprétation :** après le passage au log, la série devient plus régulière. Cela facilite ensuite la stationnarisation, la lecture des corrélations et la modélisation.

---

## 4️⃣ Détection et correction des outliers additifs

![Outliers additifs](assets1/05_detection_correction_outliers_AO.png)

Le projet utilise la méthode des **Additive Outliers (AO)** pour détecter les chocs ponctuels. Un outlier additif correspond à une valeur anormale isolée qui peut perturber l’estimation du modèle.

Dans ce cas, un choc est détecté autour de **2030:04** dans la série log-transformée.

**Objectif :** corriger ces valeurs extrêmes pour obtenir une série plus propre avant la modélisation.

---

## 5️⃣ Décomposition STL

![Décomposition STL](assets1/06_decomposition_STL.png)

La décomposition STL sépare la série en quatre composantes :

- **Data** : la série observée ;
- **Trend** : la tendance de fond ;
- **Seasonal** : la saisonnalité mensuelle ;
- **Remainder** : les résidus ou variations non expliquées.

**Interprétation :** la tendance est globalement croissante, la saisonnalité est régulière et les résidus restent limités sauf quelques perturbations.

---

## 6️⃣ Détection de ruptures structurelles

![Ruptures structurelles](assets1/07_detection_ruptures_structurelles.png)

Une rupture structurelle signifie qu’un changement important s’est produit dans la dynamique de la série.

Le graphique met en évidence plusieurs points de rupture possibles :

- une première rupture autour de la fin des années 1990 ;
- une deuxième rupture autour de 2007 ;
- un effet lié à la période COVID autour de 2020.

**Interprétation :** ces ruptures montrent que le comportement de la série n’est pas totalement constant sur toute la période historique. Pour améliorer la précision finale, le modèle est ensuite entraîné principalement sur la période récente.

---

## 7️⃣ Stationnarité et identification

![Stationnarité et identification](assets1/08_stationnarite_identification.png)

Le test de Dickey-Fuller Augmenté donne une **p-value = 0.5322**.

Comme la p-value est supérieure à 0.05, on ne rejette pas l’hypothèse nulle de non-stationnarité.

**Conclusion :** la série n’est pas stationnaire au départ.

Le script indique :

- différenciation simple : **d = 1** ;
- différenciation saisonnière : **D = 1**.

---

## 8️⃣ Série après différenciation

![Après différenciation](assets1/09_apres_differenciation.png)

Après application des différenciations, la série oscille autour de zéro.

**Interprétation :** la tendance et la saisonnalité ont été retirées. La série devient plus adaptée à l’identification d’un modèle ARIMA/SARIMA.

---

## 9️⃣ Identification visuelle ACF / PACF

![ACF PACF](assets1/10_identification_acf_pacf.png)

L’ACF et la PACF permettent d’identifier les ordres du modèle :

- **ACF** : aide à choisir les termes MA, donc `q` et `Q` ;
- **PACF** : aide à choisir les termes AR, donc `p` et `P` ;
- les pics autour des multiples de 12 indiquent la saisonnalité mensuelle.

Cette étape prépare le choix du modèle SARIMA.

---

## 🔟 Division Train / Test

![Division train test](assets1/11_division_train_test.png)

Le projet applique une validation sur les données récentes :

- période d’apprentissage : données depuis 2010 jusqu’avant les 24 derniers mois ;
- période de test : les 24 derniers mois.

**Pourquoi ce choix ?** Les données anciennes peuvent contenir des régimes économiques différents. Le focus sur les données récentes rend le modèle plus pertinent pour prévoir le futur proche.

---

## 1️⃣1️⃣ Modélisation SARIMA

![Modélisation SARIMA](assets1/12_modelisation_SARIMA.png)

Le modèle sélectionné est :

```text
ARIMA(1,0,1)(0,1,1)[12] with drift
```

Cela signifie :

- `ARIMA(1,0,1)` : composante non saisonnière ;
- `(0,1,1)[12]` : composante saisonnière mensuelle ;
- `with drift` : le modèle prend en compte une tendance légère.

Les critères affichés sont :

- **AIC = -1597.77**
- **BIC = -1580.07**

Un AIC/BIC plus faible indique généralement un meilleur compromis entre qualité d’ajustement et complexité.

---

## 1️⃣2️⃣ Validation sur le test set

![Validation test set](assets1/13_validation_test_set.png)

Le modèle est testé sur les 24 mois cachés.

Résultat principal :

```text
MAPE = 2.61 %
```

**Interprétation :** le modèle fait en moyenne une erreur de seulement 2.61%. C’est une très bonne performance, car une erreur inférieure à 5% est généralement considérée comme excellente pour une prévision temporelle.

---

## 1️⃣3️⃣ Validation globale

![Validation globale](assets1/14_validation_globale.png)

Le graphique global compare :

- l’historique d’apprentissage ;
- les valeurs réelles du test set ;
- les prévisions du modèle.

La prévision suit correctement la réalité cachée, ce qui confirme la bonne capacité prédictive du modèle.

---

## 1️⃣4️⃣ Prévisions futures

![Table forecast](assets1/15_forecast_table.png)

Le tableau présente les premières prévisions avec un intervalle de confiance à 95%.

| Date | Prévision | IC inf. 95% | IC sup. 95% |
|---|---:|---:|---:|
| Apr 2034 | 99.27 | 97.29 | 101.29 |
| May 2034 | 98.40 | 96.22 | 100.64 |
| Jun 2034 | 101.71 | 99.26 | 104.22 |
| Jul 2034 | 97.66 | 95.16 | 100.22 |
| Aug 2034 | 101.73 | 98.99 | 104.54 |
| Sep 2034 | 101.65 | 98.80 | 104.59 |

---

## 1️⃣5️⃣ Prévision finale

![Prévision finale](assets1/16_prevision_finale.png)

Le modèle final est entraîné sur la période récente validée, puis utilisé pour prévoir les 24 prochains mois.

**Interprétation :**

- la prévision conserve la saisonnalité mensuelle ;
- la tendance reste globalement stable ;
- les bandes grises représentent l’incertitude ;
- plus l’horizon augmente, plus l’incertitude devient importante.

---

## 🏆 Résultats clés

| Élément | Résultat |
|---|---|
| Série étudiée | Production Alimentaire — S C11 |
| Fréquence | Mensuelle |
| Transformation | Logarithmique |
| Correction | Additive Outliers |
| Différenciation | d = 1, D = 1 |
| Modèle retenu | SARIMA / ARIMA(1,0,1)(0,1,1)[12] with drift |
| Validation | Test set de 24 mois |
| Performance | MAPE = 2.61% |
| Prévision | 24 mois |

---

## 🛠️ Technologies utilisées

- **R**
- `readxl`
- `forecast`
- `ggplot2`
- `ggfortify`
- `zoo`
- `tsoutliers`
- `tseries`
- `gridExtra`
- `lubridate`

---

## 📁 Structure du projet

```text
time-series-food-production/
│
├── README.md
├── time_series_analysis_alim.r
│
└── assets1/
    ├── 01_statistiques_descriptives.png
    ├── 02_diagnostic_statistique.png
    ├── 03_test_stabilite_variance.png
    ├── 04_transformation_logarithmique.png
    ├── 05_detection_correction_outliers_AO.png
    ├── 06_decomposition_STL.png
    ├── 07_detection_ruptures_structurelles.png
    ├── 08_stationnarite_identification.png
    ├── 09_apres_differenciation.png
    ├── 10_identification_acf_pacf.png
    ├── 11_division_train_test.png
    ├── 12_modelisation_SARIMA.png
    ├── 13_validation_test_set.png
    ├── 14_validation_globale.png
    ├── 15_forecast_table.png
    └── 16_prevision_finale.png
```

---

## ▶️ Exécution du projet

### 1. Installer les packages nécessaires

```r
install.packages(c(
  "readxl",
  "forecast",
  "ggplot2",
  "ggfortify",
  "zoo",
  "tsoutliers",
  "tseries",
  "gridExtra",
  "lubridate"
))
```

### 2. Placer le fichier Excel dans le même dossier que le script

Le script attend le fichier suivant :

```text
Industrial Production food  S C11.xlsx
```

### 3. Lancer l’analyse

```r
source("time_series_analysis_alim.r")
```

Les graphiques générés automatiquement seront enregistrés dans le dossier :

```text
mes_graphiques/
```

---

## 🧾 Conclusion

Ce projet montre une démarche complète et rigoureuse de prévision d’une série temporelle mensuelle.
La série de production alimentaire présente une tendance haussière, une saisonnalité claire et une volatilité relativement maîtrisée.

Après transformation logarithmique, correction des outliers et stationnarisation, le modèle SARIMA sélectionné obtient une excellente performance avec un **MAPE de 2.61%** sur les données de test.

Le modèle final peut donc être utilisé pour produire des prévisions à court et moyen terme avec une bonne fiabilité.

---

## 👤 Auteur

Projet réalisé dans le cadre d’une analyse de séries temporelles avec R.
