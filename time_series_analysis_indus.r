# =============================================================================
# ANALYSE ET PRÉVISION DE SÉRIES TEMPORELLES 


# ── 0. CHARGEMENT DES PACKAGES ET CONFIGURATION ──────────────────────────────
packages_requis <- c("readxl", "tseries", "forecast", "ggplot2", 
                     "strucchange", "zoo", "Metrics")

for(pkg in packages_requis) {
  if(!require(pkg, character.only = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

# Création du dossier de sortie
if (!dir.exists("rapport_plots_pro")) dir.create("rapport_plots_pro")

# Helpers pour la sauvegarde des graphiques (Version Anti-Crash)
save_gg <- function(p, name, w=10, h=6) {
  if(is.null(p)) return(warning("Graphique vide, sauvegarde ignorée."))
  print(p)
  ggsave(filename=paste0("rapport_plots_pro/", name, ".png"), plot=p, 
         width=w, height=h, dpi=300, bg="white")
}

save_base <- function(name, w=1000, h=600) {
  # On vérifie qu'un graphique est bien actif avant de copier
  if(dev.cur() > 1) { 
    dev.copy(png, filename=paste0("rapport_plots_pro/", name, ".png"), 
             width=w, height=h, res=100)
    dev.off() # Ferme uniquement le fichier PNG, pas l'écran RStudio
  } else {
    warning("Aucun graphique à sauvegarder.")
  }
}
cat("=== DÉMARRAGE DE L'ANALYSE ===\n\n")

# ── 1. PRÉPARATION DES DONNÉES (AVEC FALLBACK SÉCURISÉ) ──────────────────────
fichier <- "value of real estate constructions.xlsx"

if (file.exists(fichier)) {
  cat(">> Chargement du fichier Excel...\n")
  df <- read_excel(fichier, col_names = FALSE)
  serie_ts <- ts(df[[2]], start = c(1982, 1), frequency = 12)
} else {
  cat(">> Fichier introuvable. GÉNÉRATION DE DONNÉES SIMULÉES (pour test)...\n")
  # Simulation d'une série avec croissance exponentielle, saisonnalité et un krach
  set.seed(42)
  t <- 1:400
  sais <- 20 * sin(2 * pi * t / 12)
  trend <- exp(0.01 * t) + 100
  krach <- ifelse(t >= 250, -80, 0) # Rupture vers l'observation 250
  bruit <- rnorm(400, 0, 10)
  serie_simulee <- trend + sais + krach + bruit
  serie_simulee[serie_simulee <= 10] <- 10 # Éviter les valeurs négatives
  serie_ts <- ts(serie_simulee, start = c(1982, 1), frequency = 12)
}

# =============================================================================
# PHASE 1 : DIAGNOSTIC STATISTIQUE (ÉTAT DES LIEUX)
# =============================================================================

# 1.1 Visualisation brute
p1 <- autoplot(serie_ts) +
  ggtitle("Série Originale : Évolution dans le temps") +
  xlab("Temps") + ylab("Valeur") +
  theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face="bold"))
save_gg(p1, "01a_Serie_Originale")

# 1.2 Décomposition de la série (Tendance, Saisonnalité, Bruit)
cat("=== DÉCOMPOSITION DE LA SÉRIE (STL) ===\n")
cat(">> Séparation des composantes pour analyse visuelle...\n\n")
# STL (Seasonal and Trend decomposition using Loess) est privilégié car il est 
# robuste aux valeurs extrêmes (krachs) contraiment à decompose().
decomp_stl <- stl(serie_ts, s.window = "periodic", robust = TRUE)

p1b <- autoplot(decomp_stl) +
  ggtitle("Décomposition STL (Tendance, Saisonnalité, Résidus)") +
  theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face="bold"))
save_gg(p1b, "01b_Decomposition_STL", w=10, h=8)

# 1.3 Test de Stabilité de la Variance (Hétéroscédasticité)
cat("=== DIAGNOSTIC DE VARIANCE ===\n")

# Calcule l'écart-type par année
sds_annuels <- aggregate(as.numeric(serie_ts), list(floor(time(serie_ts))), sd)

# Sécurité : On retire les 'NA' (années avec 1 seule observation)
sds_valides <- na.omit(sds_annuels$x)

# --- CORRECTION DU FORTIFY ERROR ICI ---
# ggplot2 exige un data.frame, pas un vecteur numérique. On crée un tableau propre.
df_sds <- data.frame(
  Annee = sds_annuels$Group.1[!is.na(sds_annuels$x)],
  x = as.numeric(sds_valides)
)

p1c_var <- ggplot(df_sds, aes(x = Annee, y = x)) +
  geom_line(color = "darkred", linewidth = 1) +
  geom_point(color = "darkred", size = 2) +
  geom_smooth(method = "lm", linetype = "dashed", color = "black", se = FALSE) +
  ggtitle("Évolution de la Volatilité Annuelle (Écart-type)", 
          subtitle = "Une tendance à la hausse justifie mathématiquement le passage au LOG") +
  xlab("Année") + ylab("Écart-type des valeurs") +
  theme_minimal()

save_gg(p1c_var, "01c_Evolution_Variance")
# ----------------------------------------

# Sécurité : Éviter la division par zéro si la variance est nulle une année
min_sd <- min(sds_valides)
if(min_sd == 0) min_sd <- 0.0001 

ratio_var <- max(sds_valides) / min_sd

cat(sprintf("Ratio Max/Min de l'écart-type annuel : %.2f\n", ratio_var))

# Sécurité finale sur le NA (au cas où ratio_var serait quand même non valide)
if(is.na(ratio_var) || ratio_var <= 2) {
  cat(">> Décision : Variance stable (Série additive) ou données insuffisantes.\n")
  cat(">> Action   : Pas de transformation log nécessaire.\n\n")
  serie_travail <- serie_ts
  label_y <- "Valeur"
  ratio_var <- 1 # On force une valeur <= 2 pour la suite du script
} else {
  cat(">> Décision : La variance explose (Série multiplicative).\n")
  cat(">> Action   : Transformation LOGARITHMIQUE appliquée pour stabiliser la variance.\n\n")
  serie_travail <- log(serie_ts)
  label_y <- "Log(Valeur)"
}
# --- VISUEL APRÈS LOG ---
p1c <- autoplot(serie_travail) +
  ggtitle("Série après Transformation Logarithmique", 
          subtitle = "La variance et la tendance ont été stabilisées") + # <-- TOUT EST DANS GGITRE
  xlab("Temps") + ylab("Log(Valeur)") +
  theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face="bold", color="darkgreen"),
        plot.subtitle = element_text(size=11, face="italic"))

save_gg(p1c, "01d_Serie_Log_Stabilisee")
cat(">> Graphique de la série log-transformée enregistré.\n")
# ---------------------------------

# 1.4 Détection Dynamique de Rupture Structurelle (Test Bai-Perron / CUSUM)
cat("=== DÉTECTION DE RUPTURE STRUCTURELLE ===\n")
bp_test <- breakpoints(serie_travail ~ time(serie_travail), breaks = 1)
date_rupture_idx <- bp_test$breakpoints
date_rupture <- time(serie_travail)[date_rupture_idx]

if(is.na(date_rupture)) {
  cat(">> Aucune rupture structurelle majeure détectée.\n")
  dummy_ts <- ts(rep(0, length(serie_travail)), start=start(serie_travail), frequency=12)
} else {
  cat(sprintf(">> Rupture majeure détectée en : %s\n", format(date_rupture, nsmall=2)))
  # Création d'une variable Dummy (Intervention variable) : 0 avant, 1 après
  dummy_vec <- ifelse(time(serie_travail) >= date_rupture, 1, 0)
  dummy_ts <- ts(dummy_vec, start=start(serie_travail), frequency=12)
  
  # Graphique illustrant la rupture
  par(mfrow=c(1,1))
  plot(serie_travail, main="Série avec Rupture Structurelle Détectée", ylab=label_y, col="black")
  abline(v=date_rupture, col="red", lwd=2, lty=2)
  text(x=date_rupture, y=min(serie_travail), labels="Krach / Rupture", pos=4, col="red")
  save_base("02_Detection_Rupture")
}

# =============================================================================
# PHASE 2 : LE SPLIT TRAIN / TEST (LA RÈGLE D'OR)
# =============================================================================
# On garde les 24 derniers mois pour évaluer la vraie puissance prédictive.
n_test <- 24
n_total <- length(serie_travail)

# Utilisation de window() pour conserver scrupuleusement les propriétés ts()
time_split <- time(serie_travail)[n_total - n_test]

# Split de la série
train_ts <- window(serie_travail, end = time_split)
test_ts  <- window(serie_travail, start = time(serie_travail)[n_total - n_test + 1])

# Split de la variable Dummy
train_xreg <- window(dummy_ts, end = time_split)
test_xreg  <- window(dummy_ts, start = time(serie_travail)[n_total - n_test + 1])

cat("\n=== SÉPARATION DES DONNÉES (BACKTESTING) ===\n")
cat(sprintf("Entraînement (Train) : %d observations\n", length(train_ts)))
cat(sprintf("Test (Test)          : %d observations (2 ans)\n\n", length(test_ts)))

# =============================================================================
# PHASE 3 : IDENTIFICATION BOX-JENKINS ET MODÉLISATION (SUR LE TRAIN SET)
# =============================================================================

cat("\n=== 3.1 TEST DE STATIONNARITÉ (Augmented Dickey-Fuller) ===\n")
# Le test ADF vérifie si la série brute possède une racine unitaire.
# H0 : La série possède une racine unitaire (elle est NON stationnaire)
# H1 : La série est stationnaire
adf_initial <- adf.test(train_ts)

cat(sprintf("Test ADF avant différenciation -> p-value : %.4f\n", adf_initial$p.value))
if(adf_initial$p.value > 0.05) {
  cat(">> Conclusion : p-value > 0.05 (On ne rejette pas H0).\n")
  cat(">> La série est NON STATIONNAIRE. Une différenciation sera nécessaire.\n")
} else {
  cat(">> Conclusion : p-value <= 0.05 (On rejette H0).\n")
  cat(">> La série est STATIONNAIRE. Une différenciation simple n'est peut-être pas requise.\n")
}


cat("\n=== 3.2 IDENTIFICATION VISUELLE (ACF / PACF) ===\n")
# Pour lire un ACF/PACF, la série DOIT être stationnaire.
# On demande aux algorithmes de valider mathématiquement le nombre de différenciations (d et D)
d_req <- ndiffs(train_ts)    # Calcule 'd' (Test KPSS par défaut)
D_req <- nsdiffs(train_ts)   # Calcule 'D' (Test OCSB pour la saisonnalité)

cat(sprintf("Différenciations requises calculées -> Simple (d) : %d | Saisonnière (D) : %d\n", d_req, D_req))

# On applique ces différenciations pour obtenir une série stationnaire temporaire (juste pour l'œil)
stat_ts <- train_ts
if(D_req > 0) stat_ts <- diff(stat_ts, lag=12, differences=D_req)
if(d_req > 0) stat_ts <- diff(stat_ts, differences=d_req)

# --- VISUEL DE LA SÉRIE STATIONNAIRE ---
# Ce graphique permet de confirmer visuellement que la série est prête pour l'ACF/PACF
p3b_stat <- autoplot(stat_ts) +
  geom_hline(yintercept = 0, color = "red", linetype = "dashed", linewidth = 0.8) +
 
  ggtitle("Série Stationnarisée (Après Différenciations)", 
    subtitle = sprintf("Objectif : Élimination de la tendance (d=%d) et de la saisonnalité (D=%d)", d_req, D_req)) +         
  xlab("Temps") + ylab("Valeur Différenciée") +
  theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face="bold", color="darkred"))

save_gg(p3b_stat, "03b_Serie_Stationnaire")
cat(">> Graphique de la série stationnarisée enregistré.\n")
# ----------------------------------------


# Tracé des corrélogrammes (ACF / PACF)
par(mfrow=c(1,2))
acf(stat_ts, lag.max=36, main=sprintf("ACF - Série Stationnaire\n(d=%d, D=%d)", d_req, D_req), col="steelblue", lwd=2)
pacf(stat_ts, lag.max=36, main=sprintf("PACF - Série Stationnaire\n(d=%d, D=%d)", d_req, D_req), col="darkred", lwd=2)
save_base("03_ACF_PACF_Stationnaire", w=1200, h=500)
par(mfrow=c(1,1))

cat(">> Règle de lecture :\n")
cat("   - Si l'ACF se coupe net après Q lags et le PACF décroît -> Modèle MA(Q)\n")
cat("   - Si le PACF se coupe net après P lags et l'ACF décroît -> Modèle AR(P)\n")
cat("   - Des pics aux multiples de 12 (12, 24) indiquent la partie saisonnière (P, Q)\n\n")


cat("=== 3.3 COMPARAISON MANUELLE DES MODÈLES (AIC / BIC) ===\n")
# On va tester quelques modèles "logiques" en fonction des différenciations d et D
candidats <- list(
  c(1, d_req, 1, 0, D_req, 1),
  c(0, d_req, 1, 1, D_req, 0),
  c(1, d_req, 0, 1, D_req, 0),
  c(0, d_req, 0, 0, D_req, 1) # Modèle purement saisonnier
)

resultats_modeles <- data.frame(Modele=character(), AIC=numeric(), BIC=numeric(), stringsAsFactors=FALSE)

# Test manuel des candidats
for(cand in candidats) {
  nom_modele <- sprintf("SARIMAX(%d,%d,%d)(%d,%d,%d)[12]", cand[1], cand[2], cand[3], cand[4], cand[5], cand[6])
  tryCatch({
    fit <- Arima(train_ts, order=c(cand[1], cand[2], cand[3]), 
                 seasonal=list(order=c(cand[4], cand[5], cand[6]), period=12),
                 xreg=train_xreg)
    resultats_modeles <- rbind(resultats_modeles, data.frame(Modele=nom_modele, AIC=AIC(fit), BIC=BIC(fit)))
  }, error = function(e) { NULL }) # Si un modèle ne converge pas, on l'ignore
}


cat("=== 3.4 OPTIMISATION AUTO.ARIMA ===\n")
cat("Recherche exhaustive de l'algorithme (benchmark)...\n")
model_train <- auto.arima(train_ts, 
                          xreg = train_xreg,
                          seasonal = TRUE, 
                          stepwise = FALSE,       # Désactive l'heuristique (explore tout)
                          approximation = FALSE,  # Calcule les vrais AIC/BIC
                          trace = FALSE)

# Ajout du modèle gagnant de l'auto.arima au tableau
resultats_modeles <- rbind(resultats_modeles, 
                           data.frame(Modele=paste("AUTO:", as.character(model_train)), 
                                      AIC=AIC(model_train), 
                                      BIC=BIC(model_train)))

# Tri par AIC (le plus bas est le meilleur)
resultats_modeles <- resultats_modeles[order(resultats_modeles$AIC), ]

cat("\n--- TABLEAU COMPARATIF (Trié par AIC) ---\n")
print(resultats_modeles, row.names = FALSE)
cat("\n>> Pourquoi l'AIC et le BIC ?\n")
cat("   - AIC : Cherche le meilleur compromis entre l'ajustement aux données et la complexité.\n")
cat("   - BIC : Pénalise plus sévèrement la complexité (idéal pour éviter l'overfitting).\n")
cat(sprintf(">> Le modèle retenu pour les prévisions est : %s\n\n", as.character(model_train)))


# =============================================================================
# PHASE 4 : VALIDATION OUT-OF-SAMPLE (LE VERDICT)
# =============================================================================
cat("=== ÉVALUATION OUT-OF-SAMPLE (SUR LE FUTUR CACHÉ) ===\n")

# Prédiction sur la période de test
forecast_test <- forecast(model_train, h = n_test, xreg = test_xreg)

# Si on a loggué la série, il faut repasser en exponentielle pour lire de vraies erreurs !
if(ratio_var > 2) {
  valeurs_reelles_test <- exp(test_ts)
  valeurs_predites_test <- exp(forecast_test$mean)
} else {
  valeurs_reelles_test <- test_ts
  valeurs_predites_test <- forecast_test$mean
}

# Calcul rigoureux des métriques
erreur_absolue <- abs(valeurs_reelles_test - valeurs_predites_test)
mape <- mean(erreur_absolue / valeurs_reelles_test) * 100
rmse <- sqrt(mean((valeurs_reelles_test - valeurs_predites_test)^2))

cat(sprintf("RMSE (Erreur brute) : %.2f\n", rmse))
cat(sprintf("MAPE (Erreur %%)     : %.2f%%\n\n", mape))

if(mape < 5) cat(">> Superbe performance prédictive (<5%).\n") else if (mape < 15) cat(">> Modèle acceptable.\n") else cat(">> Attention, erreurs élevées.\n")

# Graphique de validation (Train + Test vs Pred)
# --- CORRECTION DU FORTIFY ERROR ICI ---
# On convertit tout explicitement avec `as.numeric()` pour éviter que ggplot2 ne s'étouffe sur les attributs de Time Series (`ts`)
df_val <- data.frame(
  Temps = as.numeric(c(time(train_ts), time(test_ts))),
  Reel = as.numeric(if(ratio_var > 2) exp(c(train_ts, test_ts)) else c(train_ts, test_ts)),
  Type = c(rep("Historique", length(train_ts)), rep("Réalité (Cachée)", length(test_ts))),
  Pred = as.numeric(c(rep(NA, length(train_ts)), valeurs_predites_test))
)

p3 <- ggplot(df_val, aes(x = Temps)) +
  geom_line(aes(y = Reel, color = Type), linewidth = 1) +
  geom_line(aes(y = Pred, color = "Prévision du Modèle"), linewidth = 1.2, linetype = "dashed") +
  scale_color_manual(values = c("Historique" = "black", "Réalité (Cachée)" = "grey50", "Prévision du Modèle" = "red")) +
  ggtitle("Validation Out-of-Sample : Prévision vs Réalité") +
  xlab("Temps") + ylab("Valeur d'origine") + theme_minimal(base_size = 14) +
  theme(legend.position="bottom", legend.title=element_blank())
save_gg(p3, "04_Validation_Out_Of_Sample")


# =============================================================================
# PHASE 3B : COMPARAISON COMPLÈTE DES MODÈLES D'IA GÉNÉRATIVE
# =============================================================================
cat("\n", paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("=== PHASE 3B : COMPARAISON COMPLÈTE DES MODÈLES D'IA GÉNÉRATIVE ===\n")
cat("\n", paste(rep("=", 80), collapse = ""), "\n", sep = "")

# Vérification des packages
if (!require(keras3)) {
  install.packages("keras3")
  library(keras3)
}

# Création d'un dossier pour les résultats des modèles IA
if (!dir.exists("rapport_plots_pro/IA_Models")) dir.create("rapport_plots_pro/IA_Models", recursive = TRUE)

# Fonction utilitaire pour sauvegarder les graphiques IA
save_ia_plot <- function(p, name, w=10, h=6) {
  if(is.null(p)) return(warning("Graphique vide, sauvegarde ignorée."))
  print(p)
  ggsave(filename=paste0("rapport_plots_pro/IA_Models/", name, ".png"), 
         plot=p, width=w, height=h, dpi=300, bg="white")
}

# ============================================================================
# PRÉPARATION COMMUNE POUR TOUS LES MODÈLES
# ============================================================================
cat("=== PRÉPARATION DES DONNÉES POUR TOUS LES MODÈLES IA ===\n")

# Extraction des résidus SARIMAX pour l'approche hybride
residus_train <- as.numeric(na.omit(residuals(model_train)))
residus_test <- as.numeric(test_ts) - as.numeric(valeurs_predites_test)

cat(sprintf("✓ Résidus SARIMAX - Train: %d | Test: %d\n", length(residus_train), length(residus_test)))

# Normalisation commune
normalize <- function(x) {
  return(list(scaled = scale(x), mean = mean(x), sd = sd(x), 
              center = attr(scale(x), "scaled:center"), 
              scale_attr = attr(scale(x), "scaled:scale")))
}

res_norm <- normalize(residus_train)
res_scaled <- res_norm$scaled[, 1]

# Préparation des séquences
look_back <- 12
create_sequences <- function(data, look_back = 12, target_future = FALSE) {
  X <- list()
  Y <- list()
  
  for(i in 1:(length(data) - look_back)) {
    X[[i]] <- data[i:(i + look_back - 1)]
    if(target_future) {
      Y[[i]] <- data[i + look_back]
    } else {
      Y[[i]] <- data[i + look_back]
    }
  }
  
  X_array <- array(unlist(X), dim = c(length(X), look_back, 1))
  Y_array <- array(unlist(Y), dim = c(length(Y), 1))
  
  return(list(X = X_array, Y = Y_array))
}

sequences <- create_sequences(res_scaled, look_back)

# Données pour les modèles non-hybrides
train_ts_scaled <- scale(as.numeric(train_ts))
test_ts_scaled <- (as.numeric(test_ts) - mean(as.numeric(train_ts))) / sd(as.numeric(train_ts))

train_seq <- create_sequences(train_ts_scaled[, 1], look_back)
test_seq_raw <- c(tail(train_ts_scaled[, 1], look_back), test_ts_scaled)
test_seq <- create_sequences(test_seq_raw, look_back)

cat(sprintf("✓ Données préparées - Train: %d séquences | Test: %d séquences\n", 
            dim(train_seq$X)[1], dim(test_seq$X)[1]))

# ============================================================================
# MODÈLE 1: LSTM HYBRIDE (SARIMAX + LSTM sur résidus)
# ============================================================================
cat("\n", paste(rep("-", 80), collapse = ""), "\n", sep = "")
cat("=== MODÈLE 1: LSTM HYBRIDE (SARIMAX + LSTM sur résidus) ===\n")
cat(paste(rep("-", 80), collapse = ""), "\n", sep = "")

# Construction du modèle LSTM pour résidus
model_lstm_hybrid <- keras_model_sequential() |>
  layer_lstm(units = 50, return_sequences = TRUE, input_shape = c(look_back, 1)) |>
  layer_dropout(0.2) |>
  layer_lstm(units = 30, return_sequences = FALSE) |>
  layer_dropout(0.2) |>
  layer_dense(units = 1)

model_lstm_hybrid |> compile(
  loss = "mse",
  optimizer = optimizer_adam(learning_rate = 0.001),
  metrics = list("mae")
)

early_stop <- callback_early_stopping(monitor = "val_loss", patience = 10, restore_best_weights = TRUE)

cat(">> Entraînement du LSTM Hybride...\n")
time_start <- Sys.time()
history_hybrid <- model_lstm_hybrid |> fit(
  x = sequences$X, y = sequences$Y,
  epochs = 100, batch_size = 32, validation_split = 0.2,
  callbacks = list(early_stop), verbose = 0
)
time_hybrid <- difftime(Sys.time(), time_start, units = "secs")

# Prédiction séquentielle des résidus
predict_residuals <- function(model, test_res, look_back, last_train, norm_params) {
  n_predict <- length(test_res)
  predictions <- numeric(n_predict)
  current_seq <- last_train
  
  for(i in 1:n_predict) {
    input_seq <- array(current_seq, dim = c(1, look_back, 1))
    pred_scaled <- model |> predict(input_seq, verbose = 0)
    predictions[i] <- pred_scaled[1, 1]
    if(i <= length(test_res)) {
      current_seq <- c(current_seq[-1], test_res[i])
    }
  }
  return(predictions * norm_params$sd + norm_params$mean)
}

res_test_scaled <- (residus_test - res_norm$mean) / res_norm$sd
last_train_res <- tail(res_scaled, look_back)

pred_res <- predict_residuals(model_lstm_hybrid, res_test_scaled, look_back, last_train_res, res_norm)

# Prédiction hybride
valeurs_predites_hybride <- valeurs_predites_test + pred_res

# Évaluation
if(ratio_var > 2) {
  real_test_model <- exp(test_ts)
  pred_hybrid <- exp(valeurs_predites_hybride)
  pred_sarimax <- exp(valeurs_predites_test)
} else {
  real_test_model <- test_ts
  pred_hybrid <- valeurs_predites_hybride
  pred_sarimax <- valeurs_predites_test
}

rmse_hybrid <- sqrt(mean((real_test_model - pred_hybrid)^2))
mape_hybrid <- mean(abs((real_test_model - pred_hybrid)/real_test_model)) * 100
rmse_sarimax <- sqrt(mean((real_test_model - pred_sarimax)^2))
mape_sarimax <- mean(abs((real_test_model - pred_sarimax)/real_test_model)) * 100

cat(sprintf("✓ LSTM Hybride - RMSE: %.2f | MAPE: %.2f%% | Temps: %.1fs\n", 
            rmse_hybrid, mape_hybrid, time_hybrid))

# ============================================================================
# MODÈLE 2: GAN (Generative Adversarial Network)
# ============================================================================
cat("\n", paste(rep("-", 80), collapse = ""), "\n", sep = "")
cat("=== MODÈLE 2: GAN (Generative Adversarial Network) ===\n")
cat(paste(rep("-", 80), collapse = ""), "\n", sep = "")

# Construction du GAN
latent_dim <- 50
build_generator <- function(latent_dim, output_dim) {
  model <- keras_model_sequential() |>
    layer_dense(units = 128, input_shape = latent_dim) |>
    layer_activation_leaky_relu(alpha = 0.2) |>
    layer_batch_normalization() |>
    layer_dropout(0.3) |>
    layer_dense(units = 256) |>
    layer_activation_leaky_relu(alpha = 0.2) |>
    layer_batch_normalization() |>
    layer_dropout(0.3) |>
    layer_dense(units = output_dim) |>
    layer_activation_tanh()
  return(model)
}

build_discriminator <- function(input_dim) {
  model <- keras_model_sequential() |>
    layer_dense(units = 256, input_shape = input_dim) |>
    layer_activation_leaky_relu(alpha = 0.2) |>
    layer_dropout(0.3) |>
    layer_dense(units = 128) |>
    layer_activation_leaky_relu(alpha = 0.2) |>
    layer_dropout(0.3) |>
    layer_dense(units = 1) |>
    layer_activation_sigmoid()
  return(model)
}

# Préparation données GAN
train_gan <- t(sapply(1:(length(train_ts_scaled)-look_back), function(i) {
  train_ts_scaled[i:(i+look_back-1)]
}))

generator <- build_generator(latent_dim, look_back)
discriminator <- build_discriminator(look_back)
discriminator |> compile(loss = 'binary_crossentropy', optimizer = optimizer_adam(0.0002, 0.5), metrics = 'accuracy')

discriminator$trainable <- FALSE
gan_input <- layer_input(shape = latent_dim)
gan_output <- generator(gan_input) |> discriminator()
gan <- keras_model(gan_input, gan_output)
gan |> compile(loss = 'binary_crossentropy', optimizer = optimizer_adam(0.0002, 0.5))

cat(">> Entraînement du GAN (cela peut prendre du temps)...\n")
time_start <- Sys.time()
batch_size <- 32
epochs_gan <- 200

for(epoch in 1:epochs_gan) {
  idx <- sample(1:nrow(train_gan), min(batch_size, nrow(train_gan)))
  real_data <- train_gan[idx, ]
  noise <- matrix(rnorm(nrow(real_data) * latent_dim), nrow = nrow(real_data))
  fake_data <- generator |> predict(noise, verbose = 0)
  
  d_loss_real <- discriminator |> train_on_batch(real_data, array(1, nrow(real_data)))
  d_loss_fake <- discriminator |> train_on_batch(fake_data, array(0, nrow(real_data)))
  
  noise <- matrix(rnorm(batch_size * latent_dim), nrow = batch_size)
  g_loss <- gan |> train_on_batch(noise, array(1, batch_size))
}

time_gan <- difftime(Sys.time(), time_start, units = "secs")

# Prédiction GAN
predict_gan <- function(last_seq, n_predict) {
  predictions <- numeric(n_predict)
  current_seq <- last_seq
  
  for(i in 1:n_predict) {
    noise <- matrix(rnorm(1, latent_dim), nrow = 1)
    gen_seq <- generator |> predict(noise, verbose = 0)
    predictions[i] <- gen_seq[1, look_back]
  }
  
  return(predictions)
}

pred_gan_scaled <- predict_gan(tail(train_ts_scaled, look_back), length(test_ts))
pred_gan <- pred_gan_scaled * sd(as.numeric(train_ts)) + mean(as.numeric(train_ts))
if(ratio_var > 2) pred_gan <- exp(pred_gan)

rmse_gan <- sqrt(mean((real_test_model - pred_gan)^2))
mape_gan <- mean(abs((real_test_model - pred_gan)/real_test_model)) * 100
cat(sprintf("✓ GAN - RMSE: %.2f | MAPE: %.2f%% | Temps: %.1fs\n", rmse_gan, mape_gan, time_gan))

# ============================================================================
# MODÈLE 3: VAE (Variational Autoencoder)
# ============================================================================
cat("\n", paste(rep("-", 80), collapse = ""), "\n", sep = "")
cat("=== MODÈLE 3: VAE (Variational Autoencoder) ===\n")
cat(paste(rep("-", 80), collapse = ""), "\n", sep = "")
latent_dim_vae <- 16
input_shape <- look_back

# Encodeur
encoder_input <- layer_input(shape = input_shape)
x <- encoder_input |>
  layer_dense(units = 64, activation = "relu") |>
  layer_dropout(0.2) |>
  layer_dense(units = 32, activation = "relu")

z_mean <- x |> layer_dense(latent_dim_vae)
z_log_var <- x |> layer_dense(latent_dim_vae)

# Échantillonnage
sampling <- function(args) {
  args <- args[[1]]
  z_mean <- args[, 1:latent_dim_vae]
  z_log_var <- args[, (latent_dim_vae+1):(2*latent_dim_vae)]
  epsilon <- k_random_normal(shape = c(k_shape(z_mean)[1], latent_dim_vae))
  return(z_mean + k_exp(z_log_var/2) * epsilon)
}

z <- layer_concatenate(list(z_mean, z_log_var)) |> layer_lambda(sampling)

# Décodeur
decoder_input <- layer_input(shape = latent_dim_vae)
decoder_output <- decoder_input |>
  layer_dense(units = 32, activation = "relu") |>
  layer_dense(units = 64, activation = "relu") |>
  layer_dense(units = input_shape, activation = "linear")

vae_output <- decoder_output(z)
vae <- keras_model(encoder_input, vae_output)

# Loss personnalisée
reconstruction_loss <- loss_mean_squared_error(encoder_input, vae_output)
kl_loss <- -0.5 * k_mean(1 + z_log_var - k_square(z_mean) - k_exp(z_log_var))
vae_loss <- k_mean(reconstruction_loss + 0.01 * kl_loss)

vae |> compile(optimizer = "adam", loss = vae_loss)

# Entraînement VAE
cat(">> Entraînement du VAE...\n")
time_start <- Sys.time()
history_vae <- vae |> fit(
  train_seq$X[, , 1], train_seq$X[, , 1],
  epochs = 100, batch_size = 32, validation_split = 0.2, verbose = 0
)
time_vae <- difftime(Sys.time(), time_start, units = "secs")

# Prédiction VAE
predict_vae <- function(model, last_seq, n_predict) {
  predictions <- numeric(n_predict)
  current_seq <- last_seq
  
  for(i in 1:n_predict) {
    input_seq <- array(current_seq, dim = c(1, look_back, 1))
    reconstructed <- model |> predict(input_seq, verbose = 0)
    predictions[i] <- reconstructed[1, look_back]
    current_seq <- c(current_seq[-1], predictions[i])
  }
  return(predictions)
}

decoder <- keras_model(decoder_input, decoder_output)
pred_vae_scaled <- predict_vae(vae, tail(train_ts_scaled, look_back), length(test_ts))
pred_vae <- pred_vae_scaled * sd(as.numeric(train_ts)) + mean(as.numeric(train_ts))
if(ratio_var > 2) pred_vae <- exp(pred_vae)

rmse_vae <- sqrt(mean((real_test_model - pred_vae)^2))
mape_vae <- mean(abs((real_test_model - pred_vae)/real_test_model)) * 100
cat(sprintf("✓ VAE - RMSE: %.2f | MAPE: %.2f%% | Temps: %.1fs\n", rmse_vae, mape_vae, time_vae))

# ============================================================================
# MODÈLE 4: TRANSFORMER (Attention Mechanism)
# ============================================================================
cat("\n", paste(rep("-", 80), collapse = ""), "\n", sep = "")
cat("=== MODÈLE 4: TRANSFORMER (Attention Mechanism) ===\n")
cat(paste(rep("-", 80), collapse = ""), "\n", sep = "")

transformer_encoder <- function(inputs, head_size, num_heads, ff_dim, dropout = 0.1) {
  attention <- layer_multi_head_attention(num_heads = num_heads, key_dim = head_size, dropout = dropout)(inputs, inputs)
  x <- layer_add()(list(inputs, attention))
  x <- layer_layer_normalization()(x)
  
  ff <- x |> layer_dense(units = ff_dim, activation = "relu") |> layer_dropout(dropout) |> layer_dense(units = tail_shape(inputs))
  x <- layer_add()(list(x, ff))
  x <- layer_layer_normalization()(x)
  return(x)
}

build_transformer <- function(look_back, n_features = 1) {
  inputs <- layer_input(shape = c(look_back, n_features))
  x <- inputs |> layer_dense(units = 64)
  x <- transformer_encoder(x, head_size = 64, num_heads = 4, ff_dim = 128)
  x <- transformer_encoder(x, head_size = 64, num_heads = 4, ff_dim = 128)
  x <- layer_flatten()(x)
  x <- layer_dense(units = 50, activation = "relu")(x)
  x <- layer_dropout(0.2)(x)
  outputs <- layer_dense(units = 1)(x)
  
  model <- keras_model(inputs = inputs, outputs = outputs)
  model |> compile(optimizer = optimizer_adam(learning_rate = 0.001), loss = "mse", metrics = c("mae"))
  return(model)
}

# Préparation données Transformer
train_seq_transformer <- array(train_seq$X, dim = c(dim(train_seq$X)[1], look_back, 1))
test_seq_transformer <- array(test_seq$X, dim = c(dim(test_seq$X)[1], look_back, 1))

transformer_model <- build_transformer(look_back)

cat(">> Entraînement du Transformer...\n")
time_start <- Sys.time()
history_transformer <- transformer_model |> fit(
  train_seq_transformer, train_seq$Y,
  epochs = 100, batch_size = 32, validation_split = 0.2, verbose = 0
)
time_transformer <- difftime(Sys.time(), time_start, units = "secs")

# Prédiction Transformer
pred_transformer_scaled <- transformer_model |> predict(test_seq_transformer, verbose = 0)
pred_transformer <- pred_transformer_scaled[, 1] * sd(as.numeric(train_ts)) + mean(as.numeric(train_ts))
if(ratio_var > 2) pred_transformer <- exp(pred_transformer)

rmse_transformer <- sqrt(mean((real_test_model - pred_transformer)^2))
mape_transformer <- mean(abs((real_test_model - pred_transformer)/real_test_model)) * 100
cat(sprintf("✓ Transformer - RMSE: %.2f | MAPE: %.2f%% | Temps: %.1fs\n", rmse_transformer, mape_transformer, time_transformer))

# ============================================================================
# TABLEAU COMPARATIF GLOBAL
# ============================================================================
cat(paste0(paste(rep("-", 80), collapse = ""), "\n"))
cat("=== TABLEAU COMPARATIF GLOBAL DES PERFORMANCES ===\n")
cat(paste(rep("-", 80), collapse = ""), "\n", sep = "")

# Création du tableau de résultats
results_all <- data.frame(
  Modèle = c("SARIMAX (Classique)", "LSTM Hybride", "GAN", "VAE", "Transformer"),
  RMSE = c(rmse_sarimax, rmse_hybrid, rmse_gan, rmse_vae, rmse_transformer),
  MAPE = c(mape_sarimax, mape_hybrid, mape_gan, mape_vae, mape_transformer),
  Temps_Entraînement_s = c(NA, as.numeric(time_hybrid), as.numeric(time_gan), as.numeric(time_vae), as.numeric(time_transformer))
)

# Tri par MAPE
results_all <- results_all[order(results_all$MAPE), ]

# Affichage
print(results_all, row.names = FALSE, digits = 2)

# ============================================================================
# VISUALISATIONS COMPARATIVES
# ============================================================================
cat("\n=== GÉNÉRATION DES VISUALISATIONS ===\n")

# Graphique 1: Barplot des MAPE
p_barplot <- ggplot(results_all, aes(x = reorder(Modèle, MAPE), y = MAPE, fill = Modèle)) +
  geom_bar(stat = "identity", alpha = 0.8) +
  geom_text(aes(label = sprintf("%.2f%%", MAPE)), vjust = -0.5, size = 3.5) +
  labs(title = "Comparaison des Performances - MAPE (%)",
       subtitle = "Plus le MAPE est bas, meilleur est le modèle",
       x = "Modèle", y = "MAPE (%)") +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "none",
        plot.title = element_text(face = "bold", hjust = 0.5)) +
  scale_fill_brewer(palette = "Set2")

save_ia_plot(p_barplot, "01_Comparison_MAPE", w = 10, h = 6)

# Graphique 2: Évolution temporelle de tous les modèles
df_all_models <- data.frame(
  Temps = as.numeric(time(test_ts)),
  Réel = as.numeric(real_test_model),
  SARIMAX = as.numeric(pred_sarimax),
  LSTM_Hybride = as.numeric(pred_hybrid),
  GAN = as.numeric(pred_gan),
  VAE = as.numeric(pred_vae),
  Transformer = as.numeric(pred_transformer)
)

df_long <- tidyr::pivot_longer(df_all_models, cols = -Temps, names_to = "Modèle", values_to = "Valeur")

p_time_series <- ggplot(df_long, aes(x = Temps, y = Valeur, color = Modèle, linetype = Modèle)) +
  geom_line(linewidth = 1) +
  scale_color_manual(values = c("Réel" = "black", "SARIMAX" = "#1f77b4", "LSTM_Hybride" = "#d62728",
                                "GAN" = "#2ca02c", "VAE" = "#ff7f0e", "Transformer" = "#9467bd")) +
  scale_linetype_manual(values = c("Réel" = "solid", "SARIMAX" = "dashed", "LSTM_Hybride" = "dotted",
                                   "GAN" = "dotdash", "VAE" = "longdash", "Transformer" = "twodash")) +
  labs(title = "Comparaison des Prédictions - Tous les Modèles",
       x = "Temps", y = "Valeur", color = "Modèle", linetype = "Modèle") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom", legend.box = "vertical",
        plot.title = element_text(face = "bold", hjust = 0.5)) +
  guides(color = guide_legend(nrow = 2), linetype = guide_legend(nrow = 2))

save_ia_plot(p_time_series, "02_All_Models_TimeSeries", w = 14, h = 8)

# Graphique 3: Heatmap des erreurs
error_matrix <- data.frame(
  Modèle = results_all$Modèle,
  RMSE_Normalisé = results_all$RMSE / max(results_all$RMSE),
  MAPE_Normalisé = results_all$MAPE / max(results_all$MAPE)
)

error_long <- tidyr::pivot_longer(error_matrix, cols = c(RMSE_Normalisé, MAPE_Normalisé), 
                                  names_to = "Métrique", values_to = "Valeur")

p_heatmap <- ggplot(error_long, aes(x = Modèle, y = Métrique, fill = Valeur)) +
  geom_tile() +
  scale_fill_gradient(low = "steelblue", high = "darkred", labels = scales::percent) +
  geom_text(aes(label = sprintf("%.1f%%", Valeur * 100)), color = "white", size = 4) +
  labs(title = "Heatmap des Erreurs Normalisées",
       subtitle = "Plus la couleur est claire, meilleure est la performance",
       x = "Modèle", y = "Métrique", fill = "Erreur\nNormalisée") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", hjust = 0.5),
        axis.text.x = element_text(angle = 45, hjust = 1))

save_ia_plot(p_heatmap, "03_Error_Heatmap", w = 10, h = 6)

# ============================================================================
# VERDICT FINAL ET RECOMMANDATIONS
# ============================================================================
cat(paste0(paste(rep("-", 80), collapse = ""), "\n"))
cat("=== VERDICT FINAL: ANALYSE COMPARATIVE ===\n")
cat(paste0(paste(rep("-", 80), collapse = ""), "\n"))

best_model <- results_all[which.min(results_all$MAPE), ]
worst_model <- results_all[which.max(results_all$MAPE), ]
improvement <- (min(results_all$MAPE[-1]) - results_all$MAPE[1]) / results_all$MAPE[1] * 100

cat(sprintf("🏆 MEILLEUR MODÈLE: %s\n", best_model$Modèle))
cat(sprintf("   → MAPE: %.2f%% | RMSE: %.2f\n", best_model$MAPE, best_model$RMSE))
cat(sprintf("\n📊 AMÉLIORATION par rapport à SARIMAX: %+.1f%%\n", improvement))
cat(sprintf("\n⏱️  TEMPS D'ENTRAÎNEMENT (plus rapide au plus performant):\n"))
time_rank <- results_all[order(results_all$Temps_Entraînement_s), ]
for(i in 1:nrow(time_rank)) {
  if(!is.na(time_rank$Temps_Entraînement_s[i])) {
    cat(sprintf("   %d. %s: %.1f secondes\n", i, time_rank$Modèle[i], time_rank$Temps_Entraînement_s[i]))
  }
}

# Recommandations
cat("\n", paste(rep("-", 80), collapse = ""), "\n", sep = "")
cat("=== RECOMMANDATIONS FINALES ===\n")
cat(paste0(paste(rep("-", 80), collapse = ""), "\n"))

if(best_model$Modèle == "Transformer") {
  cat("✅ RECOMMANDATION PRINCIPALE: UTILISER TRANSFORMER\n")
  cat("   → Meilleure performance pour les séquences temporelles complexes\n")
  cat("   → Idéal pour capturer les dépendances long terme\n")
  cat("   → À privilégier si vous avez suffisamment de données\n")
} else if(best_model$Modèle == "LSTM Hybride") {
  cat("✅ RECOMMANDATION PRINCIPALE: UTILISER LSTM HYBRIDE\n")
  cat("   → Excellent compromis performance/interprétabilité\n")
  cat("   → Capture les résidus non-linéaires du SARIMAX\n")
  cat("   → Recommandé pour les séries avec composantes mixtes\n")
} else if(best_model$Modèle == "GAN" || best_model$Modèle == "VAE") {
  cat("✅ RECOMMANDATION PRINCIPALE: UTILISER MODÈLE GÉNÉRATIF\n")
  cat("   → Idéal pour la génération de scénarios\n")
  cat("   → Utile pour l'analyse de sensibilité\n")
  cat("   → Bon pour les données avec distribution complexe\n")
} else {
  cat("⚠️  RECOMMANDATION: SARIMAX SUFFIT\n")
  cat("   → Les modèles IA n'apportent pas de gain significatif\n")
  cat("   → Privilégier la simplicité et l'interprétabilité\n")
}

cat("\n💡 RECOMMANDATIONS SECONDAIRES:\n")
if(results_all$MAPE[results_all$Modèle == "Transformer"] < results_all$MAPE[results_all$Modèle == "LSTM Hybride"]) {
  cat("   → Transformer comme modèle principal, LSTM Hybride comme backup\n")
} else {
  cat("   → LSTM Hybride comme modèle principal, Transformer comme backup\n")
}

if(results_all$MAPE[results_all$Modèle == "GAN"] < 2 * results_all$MAPE[1]) {
  cat("   → GAN utile pour l'augmentation de données et scénarios synthétiques\n")
}

cat(paste0(paste(rep("-", 80), collapse = ""), "\n"))
cat("=== FIN DE L'ANALYSE COMPARATIVE DES MODÈLES IA ===\n")
cat(paste(rep("=", 80), collapse = "") + "\n")

# Nettoyage de la mémoire
rm(model_lstm_hybrid, generator, discriminator, gan, vae, transformer_model)
gc()



# =============================================================================
# PHASE 5 : MODÈLE FINAL & CONTRÔLE TECHNIQUE (RÉSIDUS)
# =============================================================================
cat("\n=== ENTRAÎNEMENT DU MODÈLE DÉFINITIF ===\n")
# Puisque le modèle est validé, on l'entraîne avec TOUTE l'information disponible (Train + Test)
# On force l'architecture trouvée par auto.arima sur la totalité de la série.

model_final <- Arima(serie_travail, 
                     model = model_train, # Réutilise l'ordre (p,d,q)(P,D,Q)
                     xreg = dummy_ts)

residus <- residuals(model_final)

# 5.1 Test de Ljung-Box (Indépendance)
# Hypothèse Nulle (H0) : Les résidus sont un bruit blanc aléatoire (Ce qu'on veut)
lb_test <- Box.test(residus, lag=24, type="Ljung-Box", fitdf=length(model_final$coef))
cat(sprintf("Test Ljung-Box -> p-value = %.4f\n", lb_test$p.value))

# 5.2 Test de Normalité (Shapiro-Wilk)
shapiro_test <- shapiro.test(as.numeric(residus)[1:min(length(residus), 5000)])
cat(sprintf("Test Shapiro-Wilk -> p-value = %.4f\n\n", shapiro_test$p.value))

# Planche de graphiques pour les résidus
par(mfrow=c(2,2))
plot(residus, main="Résidus dans le temps", ylab="", col="steelblue")
abline(h=0, col="red", lty=2)
hist(residus, breaks=20, main="Distribution des Résidus", col="lightblue", border="white")
qqnorm(residus, main="QQ-Plot (Normalité)", col="steelblue"); qqline(residus, col="red", lwd=2)
acf(residus, main="ACF des Résidus (Bruit Blanc ?)", lag.max=36)
save_base("05_Diagnostics_Residus", w=1200, h=800)
par(mfrow=c(1,1)) # Reset

# =============================================================================
# PHASE 6 : LE FUTUR (PRÉVISION FINALE)
# =============================================================================
horizon <- 24 # Prévoir les 2 ans à venir

# Générer la variable Dummy pour le futur (La rupture persiste)
future_dummy <- if(!is.na(date_rupture)) rep(1, horizon) else rep(0, horizon)

# Prédiction
forecast_final <- forecast(model_final, h = horizon, xreg = future_dummy, level=c(80, 95))

# Ramener l'échelle du Log vers l'Original pour la lisibilité
if(ratio_var > 2) {
  forecast_final$mean  <- exp(forecast_final$mean)
  forecast_final$lower <- exp(forecast_final$lower)
  forecast_final$upper <- exp(forecast_final$upper)
  forecast_final$x     <- exp(forecast_final$x) # Série historique dans l'objet
}

p_final <- autoplot(forecast_final) +
  ggtitle(sprintf("Prévisions Officielles sur %d mois (SARIMAX)", horizon)) +
  xlab("Temps") + ylab("Valeur des Constructions") +
  theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face="bold", color="darkblue")) +
  guides(colour = guide_legend(title = "Série"))
save_gg(p_final, "06_Prevision_Finale", w=12, h=7)

cat("=== RÉSUMÉ DES PRÉVISIONS FUTURES (6 PROCHAINS MOIS) ===\n")
df_futur <- data.frame(
  Date = time(forecast_final$mean)[1:6],
  Prevision = round(as.numeric(forecast_final$mean)[1:6], 2),
  Pessimiste_95 = round(as.numeric(forecast_final$lower[1:6, 2]), 2),
  Optimiste_95 = round(as.numeric(forecast_final$upper[1:6, 2]), 2)
)
print(df_futur)

cat("\n=== ANALYSE TERMINÉE AVEC SUCCÈS ===\n")
cat(">> Tous les graphiques ont été générés dans le dossier 'rapport_plots_pro'.\n")