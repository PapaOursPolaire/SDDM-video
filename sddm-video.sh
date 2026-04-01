papaours@papaours:~$ # Cloner le dépôt
git clone https://github.com/PapaOursPolaire/SDDM-video.git
cd SDDM-video

# Lancer le script en root
sudo bash sddm-video.sh
fatal : le chemin de destination 'SDDM-video' existe déjà et n'est pas un répertoire vide.
[sudo] Mot de passe de papaours : 
  ✔  Pre-flight : toutes les vérifications sont passées.

╔═══════════════════════════════════════════════════════╗
║   SDDM Video Background  v2  —  PapaOursPolaire       ║
╚═══════════════════════════════════════════════════════╝


[1/8] Nettoyage des configurations précédentes...
  ➜  /etc/sddm.conf présent mais sans [Theme] — laissé intact
  ➜  Suppression de /etc/sddm.conf.d/zzz-sddm-video.conf
  ➜  Suppression de l'ancien thème : sddm-video
  ✔  Nettoyage terminé.

[2/8] Installation de SDDM...
  ➜  Gestionnaire : apt
Lecture des listes de paquets... Fait
Construction de l'arbre des dépendances... Fait
Lecture des informations d'état... Fait      
sddm est déjà la version la plus récente (0.21.0+git20250502.4fe234b-2).
unzip est déjà la version la plus récente (6.0-29).
Le paquet suivant a été installé automatiquement et n'est plus nécessaire :
  linux-image-6.12.63+deb13-amd64
Veuillez utiliser « sudo apt autoremove » pour le supprimer.
0 mis à jour, 0 nouvellement installés, 0 à enlever et 0 non mis à jour.
  ✔  SDDM installé : /usr/bin/sddm

[3/8] Détection de la version Qt du greeter SDDM...
  ✔  Greeter Qt6 trouvé : /usr/bin/sddm-greeter-qt6
  ✔  Version Qt sélectionnée : Qt6

[4/8] Installation des dépendances QtMultimedia...
Lecture des listes de paquets... Fait
Construction de l'arbre des dépendances... Fait
Lecture des informations d'état... Fait      
qml6-module-qtmultimedia est déjà la version la plus récente (6.8.2-8).
qml6-module-qtquick-controls est déjà la version la plus récente (6.8.2+dfsg-7).
qt6-multimedia-dev est déjà la version la plus récente (6.8.2-8).
Le paquet suivant a été installé automatiquement et n'est plus nécessaire :
  linux-image-6.12.63+deb13-amd64
Veuillez utiliser « sudo apt autoremove » pour le supprimer.
0 mis à jour, 0 nouvellement installés, 0 à enlever et 0 non mis à jour.
Lecture des listes de paquets... Fait
Construction de l'arbre des dépendances... Fait
Lecture des informations d'état... Fait      
gstreamer1.0-plugins-good est déjà la version la plus récente (1.26.2-1).
gstreamer1.0-plugins-bad est déjà la version la plus récente (1.26.2-3).
gstreamer1.0-plugins-ugly est déjà la version la plus récente (1.26.3-4).
gstreamer1.0-libav est déjà la version la plus récente (1.26.2-1).
gstreamer1.0-tools est déjà la version la plus récente (1.26.2-2).
Le paquet suivant a été installé automatiquement et n'est plus nécessaire :
  linux-image-6.12.63+deb13-amd64
Veuillez utiliser « sudo apt autoremove » pour le supprimer.
0 mis à jour, 0 nouvellement installés, 0 à enlever et 0 non mis à jour.
  ✔  Dépendances QtMultimedia installées.

[5/8] Sélection de la vidéo de fond...
  ➜  Formats acceptés : mp4, webm, avi, mkv, mov, gif

  Appuyez sur Entrée / Annulez le sélecteur pour utiliser la vidéo par défaut du dépôt (default.mp4).

  ➜  Ouverture du sélecteur de fichiers (kdialog)...
  ✔  Vidéo sélectionnée : background.mp4 (mp4)

[6/8] Création du thème SDDM...
  ➜  Copie de la vidéo vers /usr/share/sddm/themes/sddm-video/background.mp4 ...
  ✔  Vidéo installée : background.mp4
  ✔  theme.conf mis à jour : background=background.mp4
  ➜  Téléchargement des assets graphiques...
  ➜  Téléchargement de l'archive ZIP du dépôt pour extraire loginterminalc.png...
  ⚠  Téléchargement échoué — génération d'un PNG de secours pour loginterminalc.png
  ✔  PNG de secours généré : loginterminalc.png (4,0K)
  ➜  Téléchargement de l'archive ZIP du dépôt pour extraire angle-down.png...
  ⚠  Téléchargement échoué — génération d'un PNG de secours pour angle-down.png
  ✔  PNG de secours généré : angle-down.png (4,0K)
  ✔  metadata.desktop écrit (Qt6)
  ✔  theme.conf.user prêt (commentaires uniquement)
  ✔  Main.qml Qt6 écrit.
  ✔  Permissions du thème appliquées.

[7/8] Écriture de la configuration SDDM...
  ✔  Config écrite : /etc/sddm.conf.d/zzz-sddm-video.conf
  ➜  im-config détecté — désactivation de la méthode d'entrée XIM...
  ⚠  im-config -n none a échoué (peut nécessiter une session graphique)
  ➜  Correction de /home/papaours/.xinputrc (était : run_im none)
  ✔  /home/papaours/.xinputrc → run_im none
  ✔  Script plasma env écrit : /home/papaours/.config/plasma-workspace/env/99-unset-im-xim.sh
  ✔  Couverture systemd-logind : /etc/environment.d/60-no-ibus-xim.conf
  ⚠  /etc/sddm.conf présent sans [Theme] — laissé intact

  ➜  Fichiers de config SDDM actifs dans /etc/sddm.conf.d/ :
    fallout-theme.conf
    kde_settings.conf
    zzz-sddm-video.conf

[8/8] Activation du service SDDM...
  ➜  Désactivation de gdm...
  ➜  Désactivation de gdm3...
Synchronizing state of sddm.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable sddm
  ✔  Service SDDM activé au démarrage.

╔═══════════════════════════════════════════════════════╗
║   Installation terminée avec succès !                 ║
╚═══════════════════════════════════════════════════════╝

  Qt version  : Qt6
  Vidéo       : background.mp4
  Thème       : /usr/share/sddm/themes/sddm-video
  Config      : /etc/sddm.conf.d/zzz-sddm-video.conf

  Pour changer la vidéo plus tard :
    sudo bash sddm-video.sh --change-video
  ou éditez directement :
    /usr/share/sddm/themes/sddm-video/theme.conf  (ligne : background=nomdevideo.mp4)

  Pour tester le thème SANS redémarrer :
    sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/sddm-video

  Redémarrer SDDM maintenant ? [o/N] : n

papaours@papaours:~/SDDM-video$ # Qt6
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/sddm-video

# Qt5
sddm-greeter --test-mode --theme /usr/share/sddm/themes/sddm-video
High-DPI autoscaling Enabled
Reading from "/usr/local/share/wayland-sessions/plasma.desktop"
Reading from "/usr/share/wayland-sessions/plasma.desktop"
Reading from "/usr/local/share/xsessions/plasmax11.desktop"
Reading from "/usr/share/xsessions/plasmax11.desktop"
Loading theme configuration from "/usr/share/sddm/themes/sddm-video/theme.conf"
Socket error:  "QLocalSocket::connectToServer : Nom invalide"
Loading file:///usr/share/sddm/themes/sddm-video/Main.qml...
qt.multimedia.ffmpeg: Using Qt multimedia with FFmpeg version 7.1.3-0+deb13u1 GPL version 2 or later
qt.multimedia.ffmpeg: Available HW decoding frameworks:
Failed to open VDPAU backend libvdpau_nvidia.so: Ne peut ouvrir le fichier d'objet partagé: Aucun fichier ou dossier de ce nom
qt.multimedia.ffmpeg:      vaapi
qt.multimedia.ffmpeg:      vulkan
qt.multimedia.ffmpeg: Available HW encoding frameworks:
qt.multimedia.ffmpeg:      vaapi
qt.multimedia.ffmpeg:      vulkan
Both point size and pixel size set. Using pixel size.
Both point size and pixel size set. Using pixel size.
file:///usr/lib/x86_64-linux-gnu/qt6/qml/SddmComponents/ComboBox.qml:107:9: QML Image: Cannot open: file:///usr/lib/x86_64-linux-gnu/qt6/qml/SddmComponents/angle-down.png
file:///usr/lib/x86_64-linux-gnu/qt6/qml/SddmComponents/ComboBox.qml:107:9: QML Image: Cannot open: file:///usr/lib/x86_64-linux-gnu/qt6/qml/SddmComponents/angle-down.png
Adding view for "DP-1" QRect(0,0 1920x1080)
[aac @ 0x562175549480] Could not update timestamps for skipped samples.
[h264 @ 0x5621739a7e00] No support for codec h264 profile 578.
[h264 @ 0x5621739a7e00] Failed setup for format vaapi: hwaccel initialisation returned error.
bash: sddm-greeter : commande introuvable
papaours@papaours:~/SDDM-video$ 
