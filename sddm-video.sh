
═══════════════════════════════════════════════════════════════
  CONFIGURATION SDDM - THÈME FALLOUT (Qt6)
═══════════════════════════════════════════════════════════════

Script de configuration universel SDDM
Version 2.0.0 - Qt6
Auteur: PapaOursPolaire

[sudo] Mot de passe de papaours : 

═══════════════════════════════════════════════════════════════
  DÉTECTION DU GESTIONNAIRE DE PAQUETS
═══════════════════════════════════════════════════════════════

✓ Détecté : Debian / Ubuntu / Linux Mint
ℹ Gestionnaire : apt

═══════════════════════════════════════════════════════════════
  VÉRIFICATION DE LA COMPATIBILITÉ SDDM
═══════════════════════════════════════════════════════════════

ℹ Version SDDM détectée : 
✓ Qt6 détecté
✓ SDDM est compatible avec ce système

═══════════════════════════════════════════════════════════════
  INSTALLATION DES DÉPENDANCES
═══════════════════════════════════════════════════════════════

ℹ Mise à jour des dépôts...
Réception de : 1 http://security.debian.org/debian-security trixie-security InRelease [43,4 kB]
Atteint : 3 http://deb.debian.org/debian trixie InRelease                                                          
Réception de : 4 http://security.debian.org/debian-security trixie-security/main amd64 Packages [129 kB]           
Réception de : 5 http://deb.debian.org/debian trixie-updates InRelease [47,3 kB]                                   
Atteint : 2 https://repository.spotify.com stable InRelease                                                        
Réception de : 6 https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version InRelease [14,8 kB]           
Atteint : 7 https://repo.jellyfin.org/debian trixie InRelease                          
234 ko réceptionnés en 1s (418 ko/s)                
2 paquets peuvent être mis à jour. Exécutez « apt list --upgradable » pour les voir.
ℹ Installation via apt...
sddm est déjà la version la plus récente (0.21.0+git20250502.4fe234b-2).
qml6-module-qtmultimedia est déjà la version la plus récente (6.8.2-8).
qml6-module-qtquick est déjà la version la plus récente (6.8.2+dfsg-7).
qml6-module-qtquick passé en « installé manuellement ».
qml6-module-qtquick-controls est déjà la version la plus récente (6.8.2+dfsg-7).
qml6-module-qtquick-layouts est déjà la version la plus récente (6.8.2+dfsg-7).
qml6-module-qtquick-layouts passé en « installé manuellement ».
libqt6multimedia6 est déjà la version la plus récente (6.8.2-8).
libqt6multimedia6 passé en « installé manuellement ».
gstreamer1.0-plugins-good est déjà la version la plus récente (1.26.2-1).
gstreamer1.0-plugins-bad est déjà la version la plus récente (1.26.2-3+deb13u1).
curl est déjà la version la plus récente (8.14.1-2+deb13u2).
wget est déjà la version la plus récente (1.25.0-2).
Le paquet suivant a été installé automatiquement et n'est plus nécessaire :
  libwoff1
Veuillez utiliser « sudo apt autoremove » pour le supprimer.

Sommaire :
  Mise à niveau de : 0. Installation de : 0Supprimé : 0. Non mis à jour : 2
✓ Dépendances installées

═══════════════════════════════════════════════════════════════
  SÉLECTION DE LA VIDÉO DE FOND
═══════════════════════════════════════════════════════════════

Options disponibles :
  1) Utiliser la vidéo par défaut (téléchargement depuis GitHub)
  2) Sélectionner une vidéo personnalisée
  3) Utiliser un fond statique (image)

Votre choix [1-3] : 1
ℹ Téléchargement de la vidéo par défaut...

═══════════════════════════════════════════════════════════════
  CRÉATION DU RÉPERTOIRE DU THÈME
═══════════════════════════════════════════════════════════════

ℹ Création du répertoire /usr/share/sddm/themes/SDDM-Fallout-Qt6
✓ Répertoire créé

═══════════════════════════════════════════════════════════════
  TÉLÉCHARGEMENT DES RESSOURCES
═══════════════════════════════════════════════════════════════

ℹ Téléchargement de l'image de login...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100  135k  100  135k    0     0   235k      0 --:--:-- --:--:-- --:--:--  235k
✓ Image de login téléchargée
ℹ Téléchargement de la vidéo par défaut...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100 60.1M  100 60.1M    0     0  16.4M      0  0:00:03  0:00:03 --:--:-- 28.6M
✓ Vidéo par défaut téléchargée
✓ Ressources téléchargées
ℹ Création de metadata.desktop...
✓ metadata.desktop créé
ℹ Création de theme.conf...
✓ theme.conf créé
ℹ Création de Main.qml (Qt6)...
✓ Main.qml créé (Qt6)

═══════════════════════════════════════════════════════════════
  CONFIGURATION DE SDDM
═══════════════════════════════════════════════════════════════

ℹ Sauvegarde de l'ancienne configuration...

Serveur d'affichage :
  1) Wayland (recommandé pour les systèmes modernes)
  2) X11 (pour compatibilité maximale)
Votre choix [1-2] : 1
ℹ Création de /etc/sddm.conf...
✓ Configuration SDDM créée (serveur: wayland)

═══════════════════════════════════════════════════════════════
  ACTIVATION DU SERVICE SDDM
═══════════════════════════════════════════════════════════════

ℹ Désactivation de gdm...
The unit files have no installation config (WantedBy=, RequiredBy=, UpheldBy=,
Also=, or Alias= settings in the [Install] section, and DefaultInstance= for
template units). This means they are not meant to be enabled or disabled using systemctl.
 
Possible reasons for having these kinds of units are:
• A unit may be statically enabled by being symlinked from another unit's
  .wants/, .requires/, or .upholds/ directory.
• A unit's purpose may be to act as a helper for some other unit which has
  a requirement dependency on it.
• A unit may be started when needed via activation (socket, path, timer,
  D-Bus, udev, scripted systemctl call, ...).
• In case of template units, the unit is meant to be enabled with some
  instance name specified.
ℹ Activation de SDDM...
Synchronizing state of sddm.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable sddm
✓ SDDM activé

Voulez-vous tester le thème maintenant ? [O/n] : o
ℹ Test du thème SDDM...
⚠ Appuyez sur Ctrl+C pour quitter le mode test
./sddm-video.sh: ligne 839: sddm-greeter : commande introuvable
papaours@papaours:~$ 
