papaours@papaours:/media/papaours/dd9bf369-cd0a-45ba-ab83-8564f24da5df$ sudo ./sddm-video.sh --diagnose
[sudo] Mot de passe de papaours : 

╔═══════════════════════════════════════════════════════╗
║   SDDM Video — Diagnostic                            ║
╚═══════════════════════════════════════════════════════╝

─────────────────────────────────────────────────────────────────
  1. Système
─────────────────────────────────────────────────────────────────
  →  OS      : Debian GNU/Linux 13 (trixie)
  →  Kernel  : 6.12.74+deb13+1-amd64
  →  Arch    : x86_64
  →  Session : X11 (:1)

─────────────────────────────────────────────────────────────────
  2. SDDM — binaire et service
─────────────────────────────────────────────────────────────────
  ✔  sddm trouvé : /usr/bin/sddm
  ✔  Greeter Qt6 : /usr/bin/sddm-greeter-qt6
  ✔  Service actif
  ✔  Démarrage auto activé

─────────────────────────────────────────────────────────────────
  3. Fichiers de configuration SDDM (ordre de lecture = ordre alphabétique)
─────────────────────────────────────────────────────────────────

  →  Fichiers dans /etc/sddm.conf.d/ :
    /etc/sddm.conf.d/kde_settings.conf  ←  Current=Windows11-qt6
    /etc/sddm.conf.d/zzz-sddm-video.conf  ←  Current=sddm-video
    /etc/sddm.conf  (priorité maximale !)  ←  aucun Current=

  ✔  Notre fichier 'zzz-sddm-video.conf' sort APRÈS 'kde_settings.conf' → il gagne ✓
  ✘  /etc/sddm.conf présent — il écrase TOUT, y compris conf.d/
  →  Correction : sudo mv /etc/sddm.conf /etc/sddm.conf.bak

─────────────────────────────────────────────────────────────────
  4. Thème sddm-video — fichiers
─────────────────────────────────────────────────────────────────
  ✔  Dossier thème : /usr/share/sddm/themes/sddm-video

  ✔  metadata.desktop (4,0K)
  ✔  angle-down.png (4,0K)
  ✔  theme.conf (4,0K)
  ✔  loginterminalc.png (4,0K)
  ✔  Main.qml (12K)

  ✔  Vidéo 'default.mp4' présente (61M)

  ✔  X-KDE-PluginInfo-Name='sddm-video' correspond au dossier ✓

─────────────────────────────────────────────────────────────────
  5. QtMultimedia — modules QML (nécessaires pour la vidéo)
─────────────────────────────────────────────────────────────────
  ✔  Module QML trouvé : /usr/lib/x86_64-linux-gnu/qt6/qml/QtMultimedia

─────────────────────────────────────────────────────────────────
  6. GStreamer — décodeurs (H.264, VP8/VP9 pour MP4/WebM)
─────────────────────────────────────────────────────────────────
  ✔  gst-inspect-1.0 disponible
  ✔  Décodeur : avdec_h264
  ✔  Décodeur : avdec_h265
  ✔  Décodeur : vp8dec
  ✔  Décodeur : vp9dec

─────────────────────────────────────────────────────────────────
  7. IBus — recherche de QT_IM_MODULE / GTK_IM_MODULE
─────────────────────────────────────────────────────────────────
  ⚠  Trouvé dans : /etc/environment.d/60-no-ibus-xim.conf
       3:QT_IM_MODULE=
       4:GTK_IM_MODULE=
  ⚠  Trouvé dans : /etc/environment.d/60-sddm-video-no-ibus-xim.conf
       3:# Sous Wayland, QT_IM_MODULE et GTK_IM_MODULE ne doivent PAS être définis
       9:QT_IM_MODULE=
       10:GTK_IM_MODULE=

  →  Correction A : sudo im-config -n none  (désactive toute méthode d'entrée)
  →  Correction B : KDE Paramètres → Périphériques d'entrée → Clavier virtuel → IBus Wayland

  →  Variables dans l'environnement du processus courant :
  ✔  QT_IM_MODULE (non définie)
  ✔  GTK_IM_MODULE (non définie)
  ✔  XMODIFIERS (non définie)

─────────────────────────────────────────────────────────────────
  8. Logs SDDM — 30 dernières lignes (erreurs en rouge, IBus en jaune)
─────────────────────────────────────────────────────────────────
  mar 16 19:10:42 papaours sddm-helper[27139]: Writing cookie to "/tmp/xauth_TWJmsk"
  mar 16 19:10:42 papaours sddm-helper[27139]: Starting X11 session: "" "/usr/bin/sddm-greeter-qt6 --socket /tmp/sddm-:0-PtKFhh"
  mar 16 19:10:42 papaours sddm[27026]: Greeter session started successfully
  mar 16 19:10:42 papaours sddm[27026]: Message received from greeter: Connect
  mar 16 19:10:48 papaours sddm[27026]: Message received from greeter: Login
  mar 16 19:10:48 papaours sddm[27026]: Reading from "/usr/share/wayland-sessions/plasma.desktop"
  mar 16 19:10:48 papaours sddm[27026]: Session "/usr/share/wayland-sessions/plasma.desktop" selected, command: "/usr/lib/x86_64-linux-gnu/libexec/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland" for VT 1
  mar 16 19:10:48 papaours sddm[27336]: Detected locale "C" with character encoding "ANSI_X3.4-1968", which is not UTF-8.
  mar 16 19:10:48 papaours sddm[27336]: Qt depends on a UTF-8 locale, and has switched to "C.UTF-8" instead.
  mar 16 19:10:48 papaours sddm[27336]: If this causes problems, reconfigure your locale. See the locale(1) manual
  mar 16 19:10:48 papaours sddm[27336]: for more information.
  mar 16 19:10:48 papaours sddm-helper[27336]: [PAM] Starting...
  mar 16 19:10:48 papaours sddm-helper[27336]: [PAM] Authenticating...
  mar 16 19:10:48 papaours sddm-helper[27336]: [PAM] Preparing to converse...
  mar 16 19:10:48 papaours sddm-helper[27336]: [PAM] Conversation with 1 messages
  mar 16 19:10:48 papaours sddm-helper[27336]: gkr-pam: unable to locate daemon control file
  mar 16 19:10:48 papaours sddm-helper[27336]: gkr-pam: stashed password to try later in open session
  mar 16 19:10:48 papaours sddm-helper[27336]: [PAM] returning.
  mar 16 19:10:48 papaours sddm-helper[27336]: pam_kwallet5(sddm:auth): pam_kwallet5: pam_sm_authenticate
  mar 16 19:10:48 papaours sddm[27026]: Authentication for user  "papaours"  successful
  mar 16 19:10:48 papaours sddm-helper[27336]: pam_kwallet5(sddm:setcred): pam_kwallet5: pam_sm_setcred
  mar 16 19:10:48 papaours sddm-helper[27336]: pam_unix(sddm:session): session opened for user papaours(uid=1000) by papaours(uid=0)
  mar 16 19:10:48 papaours sddm-helper[27336]: gkr-pam: unlocked login keyring
  mar 16 19:10:48 papaours sddm-helper[27336]: pam_kwallet5(sddm:session): pam_kwallet5: pam_sm_open_session
  mar 16 19:10:48 papaours sddm[27026]: Auth: sddm-helper exited successfully
  mar 16 19:10:48 papaours sddm[27026]: Greeter stopped. SDDM::Auth::HELPER_SUCCESS
  mar 16 19:10:48 papaours sddm-helper[27336]: pam_env(sddm:session): deprecated reading of user environment enabled
  mar 16 19:10:48 papaours sddm-helper[27336]: Starting Wayland user session: "/etc/sddm/wayland-session" "/usr/lib/x86_64-linux-gnu/libexec/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland"
  mar 16 19:10:48 papaours sddm[27026]: Session started true
  mar 16 19:10:48 papaours sddm-helper[27336]: Failed to write utmpx:  No such file or directory

papaours@papaours:/media/papaours/dd9bf369-cd0a-45ba-ab83-8564f24da5df$ papaours@papaours:/media/papaours/dd9bf369-cd0a-45ba-ab83-8564f24da5df$ chmod +x sddm-video.sh
bash: papaours@papaours:/media/papaours/dd9bf369-cd0a-45ba-ab83-8564f24da5df$: Aucun fichier ou dossier de ce nom
bash: papaours@papaours:/media/papaours/dd9bf369-cd0a-45ba-ab83-8564f24da5df$: Aucun fichier ou dossier de ce nom
bash: [sudo] : commande introuvablecations sont passées.
bash: ✔ : commande introuvable
bash: ╔═══════════════════════════════════════════════════════╗ : commande introuvable
bash: ║ : commande introuvable —  PapaOursPolaire       ║
bash: ╚═══════════════════════════════════════════════════════╝ : commande introuvable
bash: [1/8]: Aucun fichier ou dossier de ce nom
bash: ➜ : commande introuvable
bash: ➜ : commande introuvableions précédentes...
bash: Lecture : commande introuvable/zzz-sddm-video.conf
bash: linux-image-6.12.63+deb13-amd64 : commande introuvable
bash: Veuillez : commande introuvable
bash: 0 : commande introuvable
bash: ✔ : commande introuvable
bash: [3/8]: Aucun fichier ou dossier de ce nom
bash: ✔ : commande introuvable.. Fait
bash: ✔ : commande introuvablependances... Fait
bash: [4/8]: Aucun fichier ou dossier de ce nom
bash: Lecture : commande introuvableente (0.21.0+git20250502.4fe234b-2).
bash: Construction : commande introuvablequement et n'est plus nécessaire :
bash: erreur de syntaxe près du symbole inattendu « ( »
bash: erreur de syntaxe près du symbole inattendu « ( »imer.
bash: erreur de syntaxe près du symbole inattendu « ( »0 non mis à jour.
bash: Le : commande introuvableddm
bash: Lecture : commande introuvable
bash: linux-image-6.12.63+deb13-amd64 : commande introuvable
bash: Veuillez : commande introuvabledm-greeter-qt6
bash: 0 : commande introuvable Qt6
bash: ✔ : commande introuvable
bash: [5/8]: Aucun fichier ou dossier de ce nom...
bash: ➜ : commande introuvable.. Fait
bash: erreur de syntaxe près du symbole inattendu « ( »
bash: erreur de syntaxe près du symbole inattendu « ( »
bash: erreur de syntaxe près du symbole inattendu « ( »cente (6.8.2-8).
bash: [6/8]: Aucun fichier ou dossier de ce nomn la plus récente (6.8.2+dfsg-7).
bash: ➜ : commande introuvable version la plus récente (6.8.2-8).
bash: ✔ : commande introuvablelé automatiquement et n'est plus nécessaire :
bash: ✔ : commande introuvabled64
bash: ➜ : commande introuvableutoremove » pour le supprimer.
bash: ⚠ : commande introuvablenstallés, 0 à enlever et 0 non mis à jour.
bash: erreur de syntaxe près du symbole inattendu « ( »
bash: erreur de syntaxe près du symbole inattendu « ( »
bash: erreur de syntaxe près du symbole inattendu « ( »
bash: ✔ : commande introuvabledéjà la version la plus récente (1.26.2-1).
bash: ✔ : commande introuvableéjà la version la plus récente (1.26.2-3).
bash: [7/8]: Aucun fichier ou dossier de ce noma plus récente (1.26.3-4).
bash: ✔ : commande introuvable version la plus récente (1.26.2-1).
bash: ➜ : commande introuvable version la plus récente (1.26.2-2).
bash: ./sddm-video.sh:: Aucun fichier ou dossier de ce nomplus nécessaire :
bash: papaours@papaours:/media/papaours/dd9bf369-cd0a-45ba-ab83-8564f24da5df$: Aucun fichier ou dossier de ce nom
papaours@papaours:/media/papaours/dd9bf369-cd0a-45ba-ab83-8564f24da5df$ 
