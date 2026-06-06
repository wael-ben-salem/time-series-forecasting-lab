# =============================================================================
# BLOC 1 : BIBLIOTHÈQUES ET CHARGEMENT DES DONNÉES
# =============================================================================

# 1. Nettoyage de l'environnement (On repart de zéro)
rm(list=ls())

# 2. Chargement des bibliothèques nécessaires
# Si une erreur survient ici, installe le package manquant (install.packages("nom"))
library(readxl)      # Pour lire le fichier Excel
library(forecast)    # Pour les outils de séries temporelles
library(ggplot2)     # Pour les graphiques
library(ggfortify)   # Pour le support autoplot
library(zoo)         # Pour les calculs glissants
library(tsoutliers)  # Pour la méthode Additive Outliers (AO)
library(tseries)     # Pour les tests statistiques

# 3. Importation du fichier
# Note : Le fichier doit être dans le même dossier que ton script R
file_path <- "Industrial Production food  S C11.xlsx"

if (file.exists(file_path)) {
  df <- read_excel(file_path, col_names = FALSE)
  
  # Conversion forcée en numérique (colonne 2)
  # On s'assure qu'aucun texte ne bloque les calculs
  valeurs_numeriques <- as.numeric(df[[2]])
  
  # Création de l'objet Time Series
  # Start : Janvier 1982 | Fréquence : 12 (Mensuel)
  serie_ts <- ts(valeurs_numeriques, start = c(1982, 1), frequency = 12)
  
  cat(">> Données chargées avec succès.\n")
  cat(">> Nombre d'observations :", length(serie_ts), "\n")
  
} else {
  stop("ERREUR : Le fichier Excel est introuvable dans le dossier actuel.")
}

# Vérification rapide (affiche les 6 premières lignes)
print(head(serie_ts))


# =============================================================================
# BLOC 2 : VISUALISATIONS INDIVIDUELLES (ORIGINAL, ZOOM, DÉCOMPOSITION)
# =============================================================================

# 1. GRAPHIQUE ORIGINAL (Plein écran)
p_original <- autoplot(serie_ts, color = "black") +
  ggtitle("1. Série Temporelle Complète (Production Alimentaire)") +
  xlab("Années") + ylab("Indice") +
  theme_minimal()

# Affichage et Sauvegarde
print(p_original)
ggsave("mes_graphiques/01_serie_originale.png", p_original, width = 10, height = 6)


# 2. GRAPHIQUE ZOOM (Focus sur la structure des cycles)
n_obs <- length(serie_ts)
milieu <- floor(n_obs / 2)
serie_zoom <- window(serie_ts, 
                     start = time(serie_ts)[milieu - 24], 
                     end = time(serie_ts)[milieu + 24])

df_zoom <- data.frame(
  Date = as.numeric(time(serie_zoom)),
  Valeur = as.numeric(serie_zoom)
)

p_zoom <- ggplot(df_zoom, aes(x = Date, y = Valeur)) +
  geom_line(color = "blue", size = 0.8) +
  geom_point(color = "blue", size = 1.5) +
  ggtitle("2. Zoom sur 4 ans (Analyse de la Saisonnalité)") +
  xlab("Temps") + ylab("Indice") +
  theme_minimal()

# Affichage et Sauvegarde
print(p_zoom)
ggsave("mes_graphiques/02_zoom_saisonnier.png", p_zoom, width = 10, height = 6)


# 3. DÉCOMPOSITION STL (Analyse des composantes)
# s.window = "periodic" : On suppose que la saisonnalité ne change pas de forme
# robust = TRUE : Protège contre les pics aberrants (outliers)
decomp_stl <- stl(serie_ts, s.window = "periodic", robust = TRUE)

p_decomp <- autoplot(decomp_stl) +
  ggtitle("3. Décomposition STL (Tendance, Saisonnalité, Résidus)") +
  theme_minimal()

# Affichage et Sauvegarde
print(p_decomp)

# Sauvegarde spécifique pour la décomposition (format PNG car autoplot.stl est complexe)
png("mes_graphiques/03_decomposition_stl.png", width = 1000, height = 800, res = 100)
print(p_decomp)
dev.off()

cat(">> Les 3 graphiques ont été générés séparément.\n")
cat(">> Utilise les flèches bleues (Précédent/Suivant) dans l'onglet 'Plots' pour naviguer.\n")

# =============================================================================
# BLOC 3 : ANALYSE DE LA VARIANCE (VOLATILITÉ CONTINUE)
# =============================================================================

# 1. Calcul de la volatilité glissante (Écart-type sur 12 mois)
# On utilise na.rm=TRUE pour éviter les trous dans la ligne
vol_continue <- rollapply(serie_ts, width = 12, 
                          FUN = function(x) sd(x, na.rm = TRUE), 
                          fill = NA, align = "right")

# 2. Préparation des données pour ggplot
df_vol <- data.frame(
  Date = as.numeric(time(vol_continue)),
  SD = as.numeric(vol_continue)
)

# On retire les NAs pour que la ligne soit parfaitement continue
df_vol <- df_vol[!is.na(df_vol$SD), ]

# 3. Calcul de la volatilité moyenne pour la ligne de référence
moyenne_vol <- mean(df_vol$SD)

# 4. GRAPHIQUE DE LA VARIANCE AVEC RÉFÉRENCES
p_var <- ggplot(df_vol, aes(x = Date, y = SD)) +
  geom_line(color = "blue", size = 1) +             # Ligne de variance rouge
  geom_hline(yintercept = moyenne_vol, 
             linetype = "dashed", color = "red", size = 0.8) + # Réf: Moyenne
  geom_smooth(method = "lm", color = "black", 
              linetype = "dotted", se = FALSE) +   # Réf: Tendance de la variance
  annotate("text", x = min(df_vol$Date), y = moyenne_vol, 
           label = "Niveau Moyen", vjust = -1, hjust = 0) +
  ggtitle("3. Analyse de la Variance (Écart-type mobile 12 mois)") +
  xlab("Années") + ylab("Écart-type (Volatilité)") +
  theme_minimal()

# 5. TEST DE CORRÉLATION (DÉCISION LOG)
# On compare le niveau (moyenne glissante) à la variance
moy_continue <- rollapply(serie_ts, width = 12, FUN = mean, fill = NA, align = "right")
val_moy <- as.numeric(moy_continue[!is.na(moy_continue)])
val_vol <- as.numeric(vol_continue[!is.na(vol_continue)])

test_corr <- cor(val_moy, val_vol)

# Affichage
print(p_var)


# =============================================================================
# BLOC 4 : TRANSFORMATION LOGARITHMIQUE
# =============================================================================

# 1. Application du Logarithme
# On crée une nouvelle série 'serie_log'
serie_log <- log(serie_ts)

# 2. Création du visuel comparatif (Avant vs Après)
# Graphique de la série LOG
p_log <- autoplot(serie_log, color = "darkgreen") +
  ggtitle("4. Série après Transformation Logarithmique",
      subtitle = "La variance est désormais stabilisée (échelle log)") +
  xlab("Années") + ylab("Log(Indice)") +
  theme_minimal()

# 3. Comparaison visuelle immédiate
# On affiche la série originale et la série log pour voir la différence
grid.arrange(p_original + ggtitle("Série Originale (Variance instable)"), 
             p_log + ggtitle("Série Log (Variance stabilisée)"), 
             nrow = 2)

# 4. Mise à jour de la variable de travail
# À partir de maintenant, on travaille sur 'serie_log'
serie_travail <- serie_log

cat(">> Transformation Log effectuée.\n")
cat(">> Observe comme les oscillations à la fin de la série sont maintenant\n")
cat(">> proportionnelles au reste de la série.\n")

# =============================================================================
# BLOC 5 : DÉTECTION ET CORRECTION DES ADDITIVE OUTLIERS (AO)
# =============================================================================

if(!require(tsoutliers)) install.packages("tsoutliers")
library(tsoutliers)

cat(">> Recherche des chocs brutaux (Additive Outliers)...\n")

# 1. Détection automatique des AO sur la série LOG
# On utilise auto.arima à l'intérieur pour comprendre ce qui est 'normal' ou non
detect_ao <- tso(serie_log, 
                 types = c("AO"), # On cible uniquement les chocs isolés
                 maxit.iloop = 10,
                 tsmethod = "auto.arima")

# 2. Affichage des points détectés
cat("\n--- OUTLIERS DÉTECTÉS ---\n")
print(detect_ao$outliers)

# 3. Création de la série "Propre" (yadj = series adjusted)
serie_clean <- detect_ao$yadj

# 4. VISUALISATION DU NETTOYAGE
# On prépare les données pour comparer l'effet "avant/après"
df_clean <- data.frame(
  Date = as.numeric(time(serie_log)),
  Brute = as.numeric(serie_log),
  Nettoyee = as.numeric(serie_clean)
)

p_ao <- ggplot(df_clean, aes(x = Date)) +
  geom_line(aes(y = Brute, color = "Log Original (avec choc)"), alpha = 0.4, size = 0.7) +
  geom_line(aes(y = Nettoyee, color = "Log Nettoyé (AO corrigés)"), size = 0.8) +
  scale_color_manual(values = c("Log Original (avec choc)" = "red", 
                                "Log Nettoyé (AO corrigés)" = "black")) +
  ggtitle("5. Correction par la méthode Additive Outliers (AO)" ,
      subtitle="La ligne noire montre la série débarrassée des chutes brutales") +
  theme_minimal() +
  theme(legend.position = "bottom")

# 5. Affichage
print(p_ao)

# Mise à jour de la variable de travail
serie_travail <- serie_clean

cat("\n>> Le choc a été absorbé.\n")
cat(">> La série 'serie_travail' est maintenant prête pour la décomposition.\n")



# =============================================================================
# BLOC 6 : STATIONNARITÉ ET IDENTIFICATION (ADF + ACF/PACF)
# =============================================================================

cat(">> Étape 6 : Analyse de la stationnarité et des corrélations...\n")

# 1. Test de Dickey-Fuller Augmenté (ADF)
# On vérifie si la série est stationnaire en moyenne (si elle a une tendance ou non)
test_adf <- adf.test(serie_travail)

cat("\n--- TEST ADF (SÉRIE NETTOYÉE) ---\n")
cat("p-value :", round(test_adf$p.value, 4), "\n")

# Interprétation
if(test_adf$p.value > 0.05) {
  cat("DÉCISION : p-value > 0.05. La série est NON-STATIONNAIRE.\n")
  cat("ACTION : Il faudra une différenciation (d=1).\n")
} else {
  cat("DÉCISION : p-value <= 0.05. La série est STATIONNAIRE.\n")
}

# 2. Calcul automatique du nombre de différenciations requises (d et D)
d_requis <- ndiffs(serie_travail)    # Pour la tendance
D_requis <- nsdiffs(serie_travail)   # Pour la saisonnalité

cat("\n--- DIFFÉRENCIATIONS REQUISES ---\n")
cat("Simple (d) :", d_requis, "\n")
cat("Saisonnière (D) :", D_requis, "\n")

# 3. Application des différenciations pour l'analyse ACF/PACF
# On crée une série 'serie_stat' qui doit être parfaitement plate
serie_stat <- serie_travail
if(D_requis > 0) serie_stat <- diff(serie_stat, lag = 12, differences = D_requis)
if(d_requis > 0) serie_stat <- diff(serie_stat, differences = d_requis)


# 1. Création du graphique de la série après différenciations (d et D)
# On utilise la variable 'serie_stat' calculée au bloc précédent
p_stat_finale <- autoplot(serie_stat, color = "#8e44ad") +
  # On ajoute une ligne horizontale à ZERO (la cible de la stationnarité)
  geom_hline(yintercept = 0, color = "red", linetype = "dashed", size = 0.8) +
  ggtitle("6.5 Série Stationnarisée (d=1, D=1)", 
          subtitle = "La tendance et la saisonnalité ont été retirées") +
  xlab("Années") + ylab("Valeur Différenciée") +
  theme_minimal()


# 2. Affichage du graphique
print(p_stat_finale)

# 3. Sauvegarde automatique
ggsave("mes_graphiques/06_serie_stationnarisee.png", p_stat_finale, width = 10, height = 6)

test_adf <- adf.test(serie_stat)

cat("\n--- TEST ADF (SÉRIE NETTOYÉE) ---\n")
cat("p-value :", round(test_adf$p.value, 4), "\n")

# Interprétation
if(test_adf$p.value > 0.05) {
  cat("DÉCISION : p-value > 0.05. La série est NON-STATIONNAIRE.\n")
  cat("ACTION : Il faudra une différenciation (d=1).\n")
} else {
  cat("DÉCISION : p-value <= 0.05. La série est STATIONNAIRE.\n")
}



# 4. GRAPHIQUE ACF / PACF (L'empreinte digitale du modèle)
# Ces graphiques servent à choisir les ordres p, q, P, Q du SARIMA
# On les affiche sur une seule page
png("mes_graphiques/06_acf_pacf.png", width = 1200, height = 800, res = 150)
par(mfrow=c(2,1))
Acf(serie_stat, lag.max = 36, main = "ACF (Identification des moyennes mobiles)")
Pacf(serie_stat, lag.max = 36, main = "PACF (Identification des autorégressions)")
par(mfrow=c(1,1))
dev.off()

# Affichage direct à l'écran
par(mfrow=c(2,1))
Acf(serie_stat, lag.max = 36)
Pacf(serie_stat, lag.max = 36)
par(mfrow=c(1,1))

cat("\n>> Graphiques ACF/PACF générés.\n")

# =============================================================================
# BLOC 7 : SPLIT TRAIN / TEST (BACKTESTING)
# =============================================================================

# 1. Définition de l'horizon de test (24 mois = 2 ans)
h_test <- 24

# 2. Calcul du point de coupure
n_total <- length(serie_travail)
date_coupure <- time(serie_travail)[n_total - h_test]

# 3. Création des deux sets (Entraînement et Test)
# On utilise window() pour garder les propriétés temporelles
train_set <- window(serie_travail, end = date_coupure)
test_set  <- window(serie_travail, start = time(serie_travail)[n_total - h_test + 1])

# 4. VISUALISATION DU SPLIT
# On affiche les deux parties avec des couleurs différentes
df_split <- data.frame(
  Date = c(as.numeric(time(train_set)), as.numeric(time(test_set))),
  Valeur = c(as.numeric(train_set), as.numeric(test_set)),
  Type = c(rep("1. Apprentissage (Train)", length(train_set)), 
           rep("2. Réalité Cachée (Test)", length(test_set)))
)

p_split <- ggplot(df_split, aes(x = Date, y = Valeur, color = Type)) +
  geom_line(size = 0.8) +
  scale_color_manual(values = c("1. Apprentissage (Train)" = "black", 
                                "2. Réalité Cachée (Test)" = "red")) +
  ggtitle("7. Division des données pour Validation",
          subtitle = paste("Le modèle va apprendre sur la partie noire pour essayer de deviner la partie rouge")) +
  theme_minimal() +
  theme(legend.position = "bottom")

# 5. Affichage
print(p_split)

cat("\n--- INFOS SÉPARATION ---")
cat("\nTaille Train :", length(train_set), "mois")
cat("\nTaille Test  :", length(test_set), "mois (2 ans)")
cat("\n>> Si tu es prêt à lancer le calcul du modèle SARIMA, dis-moi 'OK'.\n")


# =============================================================================
# BLOC 7 (MODIFIÉ) : FOCUS SUR LES DONNÉES RÉCENTES (DEPUIS 2010)
# =============================================================================

# 1. TRONCATURE DE LA SÉRIE
# On ignore tout ce qui est avant Janvier 2010
serie_recent <- window(serie_travail, start = c(2010, 1))

# 2. DÉFINITION DU TEST (24 mois = 2 ans)
h_test <- 24
n_total_recent <- length(serie_recent)

# 3. CRÉATION DES SETS (Train de 2010 à fin-2ans | Test = les 2 derniers ans)
date_coupure <- time(serie_recent)[n_total_recent - h_test]

train_set <- window(serie_recent, end = date_coupure)
test_set  <- window(serie_recent, start = time(serie_recent)[n_total_recent - h_test + 1])

# 4. VISUALISATION DU SPLIT RÉCENT
df_split_recent <- data.frame(
  Date = c(as.numeric(time(train_set)), as.numeric(time(test_set))),
  Valeur = c(as.numeric(train_set), as.numeric(test_set)),
  Type = c(rep("1. Apprentissage (Train : 2010-2022)", length(train_set)), 
           rep("2. Réalité Cachée (Test : 2 derniers ans)", length(test_set)))
)

p_split_recent <- ggplot(df_split_recent, aes(x = Date, y = Valeur, color = Type)) +
  geom_line(size = 0.9) +
  scale_color_manual(values = c("1. Apprentissage (Train : 2010-2022)" = "black", 
                                "2. Réalité Cachée (Test : 2 derniers ans)" = "red")) +
  ggtitle("7. Division des données (Focus depuis 2010)",
          subtitle = "Les données antérieures à 2010 ont été exclues pour plus de pertinence") +
  theme_minimal() +
  theme(legend.position = "bottom")

# 5. Affichage
print(p_split_recent)

cat("\n--- NOUVELLES INFOS SÉPARATION ---")
cat("\nDébut de l'analyse : Janvier 2010")
cat("\nTaille Train       :", length(train_set), "mois")
cat("\nTaille Test        :", length(test_set), "mois (2 ans)")
cat("\n>> Les données de 1982 à 2009 sont ignorées.")
cat("\n>> Si tu es prêt à lancer le SARIMA sur cette base récente, dis-moi 'OK'.\n")

# =============================================================================
# BLOC 8 : MODÉLISATION AUTO.ARIMA ET VALIDATION (TEST SET)
# =============================================================================

cat(">> Étape 8 : Recherche du meilleur modèle SARIMA en cours...\n")

# 1. CALCUL DU MODÈLE (Recherche exhaustive)
# On utilise stepwise=FALSE et approximation=FALSE pour une recherche plus lente mais plus précise
fit_model <- auto.arima(train_set, 
                        seasonal = TRUE, 
                        stepwise = FALSE, 
                        approximation = FALSE)

# 2. AFFICHAGE DES PARAMÈTRES TROUVÉS
cat("\n--- MODÈLE SÉLECTIONNÉ ---\n")
print(fit_model)
# Note : (p,d,q) = partie tendance | (P,D,Q) = partie saisonnière

# 3. PRÉVISION SUR L'HORIZON DE TEST (24 mois)
forecast_test <- forecast(fit_model, h = h_test)

# 4. RETOUR À L'ÉCHELLE ORIGINALE (Inversion du Log)
# Puisqu'on a fait un Log, on doit faire un Exp pour comparer des vrais chiffres
reel_test <- exp(as.numeric(test_set))
pred_test <- exp(as.numeric(forecast_test$mean))
lim_inf   <- exp(as.numeric(forecast_test$lower[,2])) # Intervalle 95%
lim_sup   <- exp(as.numeric(forecast_test$upper[,2]))

# 5. CALCUL DE L'ERREUR (MAPE)
# Le MAPE donne l'erreur moyenne en pourcentage
mape_score <- mean(abs(reel_test - pred_test) / reel_test) * 100

# 6. GRAPHIQUE DE VALIDATION (RÉEL VS PRÉDIT)
df_valid <- data.frame(
  Date = as.numeric(time(test_set)),
  Reel = reel_test,
  Pred = pred_test,
  Inf_95 = lim_inf,
  Sup_95 = lim_sup
)

p_validation <- ggplot(df_valid, aes(x = Date)) +
  geom_ribbon(aes(ymin = Inf_95, ymax = Sup_95), fill = "blue", alpha = 0.1) + # Zone d'incertitude
  geom_line(aes(y = Reel, color = "Réalité (Test Set)"), size = 1) +
  geom_line(aes(y = Pred, color = "Prévision du Modèle"), linetype = "dashed", size = 1) +
  scale_color_manual(values = c("Réalité (Test Set)" = "black", 
                                "Prévision du Modèle" = "red")) +
  ggtitle("8. Validation : Réalité vs Prédiction (24 mois)",
          subtitle = paste("Erreur moyenne (MAPE) :", round(mape_score, 2), "%")) +
  theme_minimal() +
  theme(legend.position = "bottom")

# Affichage
print(p_validation)

cat("\n>> Performance :", round(mape_score, 2), "% d'erreur en moyenne.\n")
cat(">> Si l'erreur est < 5%, le modèle est excellent.\n")
cat(">> Si elle est < 10%, il est très bon.\n")

# =============================================================================
# BLOC 8.5 : VISUALISATION GLOBALE (HISTORIQUE + TEST + PRÉDICTION)
# =============================================================================

# 1. Préparation des données pour l'historique (Train)
df_hist_full <- data.frame(
  Date = as.numeric(time(train_set)),
  Valeur = exp(as.numeric(train_set)),
  Type = "1. Historique (Apprentissage)"
)

# 2. Préparation de la réalité (Test Set)
df_test_full <- data.frame(
  Date = as.numeric(time(test_set)),
  Valeur = exp(as.numeric(test_set)),
  Type = "2. Réalité (Test Set)"
)

# 3. Préparation de la prédiction
df_pred_full <- data.frame(
  Date = as.numeric(time(test_set)),
  Valeur = exp(as.numeric(forecast_test$mean)),
  Type = "3. Prévision du Modèle"
)

# 4. GRAPHIQUE DE VALIDATION GLOBALE
p_globale <- ggplot() +
  # Zone d'incertitude (Intervalle 95%) sur la partie test uniquement
  geom_ribbon(data = df_valid, aes(x = Date, ymin = Inf_95, ymax = Sup_95), 
              fill = "red", alpha = 0.1) +
  # Ligne de l'historique
  geom_line(data = df_hist_full, aes(x = Date, y = Valeur, color = Type), size = 0.7) +
  # Ligne de la réalité cachée (Test)
  geom_line(data = df_test_full, aes(x = Date, y = Valeur, color = Type), size = 0.8) +
  # Ligne de la prédiction (en pointillés pour bien la distinguer)
  geom_line(data = df_pred_full, aes(x = Date, y = Valeur, color = Type), 
            linetype = "dashed", size = 0.8) +
  # Couleurs personnalisées
  scale_color_manual(values = c(
    "1. Historique (Apprentissage)" = "black",
    "2. Réalité (Test Set)" = "blue",
    "3. Prévision du Modèle" = "red"
  )) +
  ggtitle("8.5 Validation Globale du Modèle",
          subtitle = paste("Comparaison sur toute la période | MAPE :", round(mape_score, 2), "%")) +
  xlab("Années") + ylab("Valeur Originale") +
  theme_minimal() +
  theme(legend.position = "bottom", legend.title = element_blank())

# 5. Affichage
print(p_globale)

# Sauvegarde
ggsave("mes_graphiques/08_validation_globale.png", p_globale, width = 12, height = 7)

cat("\n>> Le graphique global a été généré.\n")
cat(">> Vérifie comment la ligne rouge (prédiction) se superpose à la bleue (test).\n")

# =============================================================================
# BLOC 9 (MODIFIÉ) : PRÉVISION FINALE (FOCUS 2010-2026)
# =============================================================================

cat(">> Étape 9 : Entraînement final (données depuis 2010) et projection...\n")

# 1. TRONCATURE FINALE DE LA SÉRIE NETTOYÉE
# On prend la série propre (AO corrigés) et on ne garde que depuis 2010
serie_final_recent <- window(serie_clean, start = c(2010, 1))

# 2. ENTRAÎNEMENT DU MODÈLE FINAL
# On applique la structure SARIMA validée au bloc précédent sur toute la période 2010-2024
final_fit <- Arima(serie_final_recent, model = fit_model)

# 3. PRÉVISION À 24 MOIS
horizon_futur <- 24
forecast_final <- forecast(final_fit, h = horizon_futur)

# 4. RETOUR À L'ÉCHELLE ORIGINALE (Inversion du Log)
# On repasse en exponentielle pour avoir les vraies valeurs de production
forecast_final$mean  <- exp(forecast_final$mean)
forecast_final$lower <- exp(forecast_final$lower)
forecast_final$upper <- exp(forecast_final$upper)
forecast_final$x     <- exp(forecast_final$x) # L'historique (depuis 2010)

# 5. GRAPHIQUE OFFICIEL (FOCUS RÉCENT)
p_final_zoom <- autoplot(forecast_final) +
  ggtitle("9. Prévisions Officielles (Base de données : 2010-2024)",
          subtitle = paste("Modèle SARIMA robuste :", as.character(fit_model))) +
  xlab("Années") + ylab("Valeur Originale") +
  theme_minimal() +
  theme(
    plot.title = element_text(face="bold", color = "darkblue", size = 14),
    axis.title = element_text(face="bold")
  )

# 6. TABLEAU DES PRÉVISIONS (6 PROCHAINS MOIS)
cat("\n--- PRÉVISIONS FUTURES (VRAIES VALEURS) ---\n")
df_futur <- data.frame(
  Date = format(date_decimal(as.numeric(head(time(forecast_final$mean), 6))), "%b %Y"),
  Prevision = round(as.numeric(head(forecast_final$mean, 6)), 2),
  Confiance_Inf_95 = round(as.numeric(head(forecast_final$lower[,2], 6)), 2),
  Confiance_Sup_95 = round(as.numeric(head(forecast_final$upper[,2], 6)), 2)
)
print(df_futur)

# 7. Affichage et Sauvegarde
print(p_final_zoom)
ggsave("mes_graphiques/09_prevision_finale_zoom.png", p_final_zoom, width = 12, height = 7)

cat("\n====================================================\n")
cat("ANALYSE TERMINÉE AVEC SUCCÈS\n")
cat("Période analysée : 2010 - 2024\n")
cat("Prévisions jusqu'à :", format(date_decimal(max(time(forecast_final$mean))), "%Y"), "\n")
cat("Tes visuels sont prêts dans le dossier 'mes_graphiques'.\n")
cat("====================================================\n")