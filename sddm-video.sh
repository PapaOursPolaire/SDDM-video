
═══════════════════════════════════════════════════════════════
  CONFIGURATION SDDM - THÈME FALLOUT (Qt6)
═══════════════════════════════════════════════════════════════

Script de configuration universel SDDM
Version 2.1.0 - Qt6
Auteur: PapaOursPolaire


═══════════════════════════════════════════════════════════════
  DÉTECTION DU GESTIONNAIRE DE PAQUETS
═══════════════════════════════════════════════════════════════

✓ Détecté : Debian / Ubuntu / Linux Mint
ℹ Gestionnaire : apt

═══════════════════════════════════════════════════════════════
  VÉRIFICATION DE LA COMPATIBILITÉ SDDM
═══════════════════════════════════════════════════════════════

ℹ Version SDDM : indéterminée (binaire présent)
✓ Qt6 détecté
✓ SDDM est présent et compatible

═══════════════════════════════════════════════════════════════
  INSTALLATION DES DÉPENDANCES
═══════════════════════════════════════════════════════════════

ℹ Mise à jour des dépôts...
Atteint : 1 http://security.debian.org/debian-security trixie-security InRelease
Atteint : 3 http://deb.debian.org/debian trixie InRelease                                                          
Atteint : 4 http://deb.debian.org/debian trixie-updates InRelease                                                  
Réception de : 5 https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version InRelease [14,8 kB]           
Atteint : 2 https://repository.spotify.com stable InRelease                                                        
Atteint : 6 https://repo.jellyfin.org/debian trixie InRelease                                              
14,8 ko réceptionnés en 1s (25,7 ko/s)              
2 paquets peuvent être mis à jour. Exécutez « apt list --upgradable » pour les voir.
ℹ Vérification des paquets disponibles...
✓   trouvé  : sddm
✓   trouvé  : qml6-module-qtmultimedia
⚠   absent  : qt6-multimedia-qml (ignoré)
✓   trouvé  : qml6-module-qtquick
✓   trouvé  : qml6-module-qtquick-controls
⚠   absent  : qml6-module-qtquick-controls2 (ignoré)
✓   trouvé  : qml6-module-qtquick-layouts
✓   trouvé  : libqt6multimedia6
✓   trouvé  : qt6-multimedia-dev
✓   trouvé  : gstreamer1.0-plugins-good
✓   trouvé  : gstreamer1.0-plugins-bad
✓   trouvé  : gstreamer1.0-plugins-ugly
✓   trouvé  : curl
✓   trouvé  : wget
ℹ Installation via apt...
sddm est déjà la version la plus récente (0.21.0+git20250502.4fe234b-2).
qml6-module-qtmultimedia est déjà la version la plus récente (6.8.2-8).
qml6-module-qtquick est déjà la version la plus récente (6.8.2+dfsg-7).
qml6-module-qtquick-controls est déjà la version la plus récente (6.8.2+dfsg-7).
qml6-module-qtquick-layouts est déjà la version la plus récente (6.8.2+dfsg-7).
libqt6multimedia6 est déjà la version la plus récente (6.8.2-8).
qt6-multimedia-dev est déjà la version la plus récente (6.8.2-8).
gstreamer1.0-plugins-good est déjà la version la plus récente (1.26.2-1).
gstreamer1.0-plugins-bad est déjà la version la plus récente (1.26.2-3+deb13u1).
gstreamer1.0-plugins-ugly est déjà la version la plus récente (1.26.3-4+deb13u1).
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
ℹ La vidéo par défaut sera téléchargée depuis GitHub

═══════════════════════════════════════════════════════════════
  CRÉATION DU RÉPERTOIRE DU THÈME
═══════════════════════════════════════════════════════════════

⚠ Le thème existe déjà
Voulez-vous le remplacer ? [O/n] : o
ℹ Suppression de l'ancien thème...
ℹ Création du répertoire /usr/share/sddm/themes/SDDM-Fallout-Qt6
✓ Répertoire créé

═══════════════════════════════════════════════════════════════
  TÉLÉCHARGEMENT DES RESSOURCES
═══════════════════════════════════════════════════════════════

ℹ Téléchargement de loginterminalc.png depuis GitHub...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100  135k  100  135k    0     0   521k      0 --:--:-- --:--:-- --:--:--  521k
✓ loginterminalc.png téléchargée
ℹ Téléchargement de default.mp4 depuis GitHub...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100 60.1M  100 60.1M    0     0  41.7M      0  0:00:01  0:00:01 --:--:-- 48.4M
✓ default.mp4 téléchargée et enregistrée sous background.mp4
✓ Ressources téléchargées
ℹ Création de metadata.desktop...
✓ metadata.desktop créé
ℹ Création de theme.conf...
✓ theme.conf créé
ℹ Création de Main.qml (Qt6, sans KDE)...
✓ Main.qml créé (Qt6, sans KDE)

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
High-DPI autoscaling Enabled
Reading from "/usr/share/wayland-sessions/plasma.desktop"
Reading from "/usr/share/xsessions/plasmax11.desktop"
Loading theme configuration from "/usr/share/sddm/themes/SDDM-Fallout-Qt6/theme.conf"
Socket error:  "QLocalSocket::connectToServer : Nom invalide"
Loading file:///usr/share/sddm/themes/SDDM-Fallout-Qt6/Main.qml...
file:///usr/share/sddm/themes/SDDM-Fallout-Qt6/Main.qml:261:25: Cannot assign to non-existent property "currentIndex" 
                             currentIndex: sessionModel.lastIndex 
                             ^
file:///usr/share/sddm/themes/SDDM-Fallout-Qt6/Main.qml:261:25: Cannot assign to non-existent property "currentIndex" 
                             currentIndex: sessionModel.lastIndex 
                             ^
Fallback to embedded theme
file:///usr/lib/x86_64-linux-gnu/qt6/qml/SddmComponents/Background.qml:35:5: QML Image: Cannot open: qrc:/theme/background.mp4
Adding view for "DP-1" QRect(0,0 1920x1080)

