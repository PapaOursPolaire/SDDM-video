papaours@papaours:/media/papaours/dd9bf369-cd0a-45ba-ab83-8564f24da5df$ chmod +x sddm-video.sh
papaours@papaours:/media/papaours/dd9bf369-cd0a-45ba-ab83-8564f24da5df$ ./sddm-video.sh
  ✘  Ce script doit être exécuté en root : sudo bash ./sddm-video.sh
papaours@papaours:/media/papaours/dd9bf369-cd0a-45ba-ab83-8564f24da5df$ sudo ./sddm-video.sh
[sudo] Mot de passe de papaours : 
  ✔  Pre-flight : toutes les vérifications sont passées.

╔═══════════════════════════════════════════════════════╗
║   SDDM Video Background  v2  —  PapaOursPolaire       ║
╚═══════════════════════════════════════════════════════╝


[1/8] Nettoyage des configurations précédentes...
  ➜  Suppression de /etc/sddm.conf.d/sddm-video.conf
  ➜  Suppression de l'ancien thème : sddm-video
  ✔  Nettoyage terminé.

[2/8] Installation de SDDM...
  ➜  Gestionnaire : apt
Lecture des listes de paquets... Fait
Construction de l'arbre des dépendances... Fait
Lecture des informations d'état... Fait      
sddm est déjà la version la plus récente (0.21.0+git20250502.4fe234b-2).
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
  ✔  Vidéo sélectionnée : default.mp4 (mp4)

[6/8] Création du thème SDDM...
  ➜  Copie de la vidéo vers /usr/share/sddm/themes/sddm-video/default.mp4 ...
  ✔  Vidéo installée : default.mp4
  ✔  theme.conf mis à jour : background=default.mp4
  ➜  Téléchargement des assets graphiques...
  ⚠  Impossible de télécharger loginterminalc.png
  ⚠  loginterminalc.png absent — le panneau affichera un fond transparent
  ⚠  Impossible de télécharger angle-down.png
  ⚠  angle-down.png absent — les flèches des menus ne s'afficheront pas
  ✔  metadata.desktop écrit (Qt6)
  ✔  theme.conf.user prêt (commentaires uniquement)
  ✔  Main.qml Qt6 écrit.
  ✔  Permissions du thème appliquées.

[7/8] Écriture de la configuration SDDM...
  ✔  Config écrite : /etc/sddm.conf.d/zzz-sddm-video.conf
  ➜  Écriture du fichier de désactivation IBus XIM : /etc/environment.d/60-sddm-video-no-ibus-xim.conf
  ✔  Fichier IBus écrit : /etc/environment.d/60-sddm-video-no-ibus-xim.conf

  ➜  Fichiers de config SDDM actifs dans /etc/sddm.conf.d/ :
    kde_settings.conf
    zzz-sddm-video.conf
  ⚠  /etc/sddm.conf présent — il peut entrer en conflit avec /etc/sddm.conf.d/zzz-sddm-video.conf

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
  Vidéo       : default.mp4
  Thème       : /usr/share/sddm/themes/sddm-video
  Config      : /etc/sddm.conf.d/zzz-sddm-video.conf

  Pour changer la vidéo plus tard :
    sudo bash sddm-video.sh --change-video
  ou éditez directement :
    /usr/share/sddm/themes/sddm-video/theme.conf  (ligne : background=nomdevideo.mp4)

  Pour tester le thème SANS redémarrer :
    sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/sddm-video

  Redémarrer SDDM maintenant ? [o/N] : 
