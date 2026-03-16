#!/bin/bash
# =============================================================================
#  sddm-video.sh  v2  —  by PapaOursPolaire
#  Thème SDDM avec vidéo en arrière-plan — Qt5/Qt6 — Debian/Arch/Fedora/openSUSE
#
#  Fonctionnalités :
#    ✔ Vidéo par défaut (default.mp4) téléchargée automatiquement depuis le dépôt
#    ✔ Vidéo personnalisée sélectionnable — annulez le sélecteur pour garder default.mp4
#    ✔ Vidéo configurable via theme.conf (sans réinstaller)
#    ✔ Interface SDDM complète : session, disposition clavier, login/reboot/shutdown
#    ✔ Panneau loginterminalc.png récupéré depuis le dépôt GitHub
#    ✔ Compatibilité Wayland ET X11 (auto-détection)
#    ✔ Qt5 et Qt6 (sélection automatique)
#    ✔ Installation des dépendances QtMultimedia + GStreamer
#    ✔ Suppression de l'alerte IBus Wayland (QT_IM_MODULE/GTK_IM_MODULE)
#    ✔ Mode --change-video pour changer la vidéo sans réinstaller
#    ✔ Mode --diagnose  pour inspecter toute la config SDDM + IBus + Qt
#
#  Usage :
#    sudo bash sddm-video.sh               # installation complète
#    sudo bash sddm-video.sh --change-video  # juste changer la vidéo
#         bash sddm-video.sh --diagnose     # diagnostic (sans sudo nécessaire)
# =============================================================================

set -euo pipefail

# ─── Constantes ──────────────────────────────────────────────────────────────
readonly THEME_NAME="sddm-video"
readonly THEME_DIR="/usr/share/sddm/themes/$THEME_NAME"
readonly CONF_DIR="/etc/sddm.conf.d"
# CRITIQUE : les fichiers conf.d sont lus en ordre alphabétique et les derniers
# écrasent les premiers. KDE System Settings écrit "kde_settings.conf" (k < s < z).
# Notre fichier doit donc s'appeler "zzz-..." pour être lu EN DERNIER et gagner.
readonly CONF_FILE="$CONF_DIR/zzz-sddm-video.conf"
readonly REPO_RAW="https://raw.githubusercontent.com/PapaOursPolaire/SDDM-video/main"
# GitHub LFS : les fichiers binaires lourds (>1 Mo) sont stockés via Git LFS.
# raw.githubusercontent.com ne retourne que le fichier pointeur texte (~130 octets).
# Il faut passer par media.githubusercontent.com pour obtenir le vrai binaire.
readonly REPO_LFS="https://media.githubusercontent.com/media/PapaOursPolaire/SDDM-video/main"

QT_VERSION=""
VIDEO_PATH=""
FILENAME=""

# ─── Couleurs ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YEL='\033[1;33m'; GRN='\033[0;32m'; CYN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "  ${CYN}➜${NC}  $*"; }
ok()    { echo -e "  ${GRN}✔${NC}  $*"; }
warn()  { echo -e "  ${YEL}⚠${NC}  $*"; }
die()   { echo -e "  ${RED}✘${NC}  $*" >&2; exit 1; }
step()  { echo ""; echo -e "${CYN}[$1]${NC} $2"; }

# ─── Vérification root ───────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    die "Ce script doit être exécuté en root : sudo bash $0"
fi

# ─── Pre-flight : vérifications avant de toucher au système ──────────────────
preflight_checks() {
    local errors=0

    # Bash 4.0+ requis (${var,,} pour la mise en minuscules)
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        echo -e "  ${RED}✘${NC}  Bash 4.0+ requis (version actuelle : $BASH_VERSION)" >&2
        errors=$((errors + 1))
    fi

    # curl ou wget requis (téléchargement vidéo par défaut + assets)
    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        echo -e "  ${RED}✘${NC}  curl ou wget requis — installez l'un ou l'autre :" >&2
        echo -e "       apt : sudo apt-get install curl" >&2
        echo -e "       pacman : sudo pacman -S curl" >&2
        errors=$((errors + 1))
    fi

    # systemctl requis pour activer/désactiver les services
    if ! command -v systemctl &>/dev/null; then
        echo -e "  ${YEL}⚠${NC}  systemctl absent — l'activation automatique de SDDM sera ignorée." >&2
        # Avertissement seulement, pas un blocage
    fi

    # Un gestionnaire de paquets connu doit être présent
    if ! command -v apt-get &>/dev/null && \
       ! command -v pacman  &>/dev/null && \
       ! command -v dnf     &>/dev/null && \
       ! command -v zypper  &>/dev/null; then
        echo -e "  ${RED}✘${NC}  Gestionnaire de paquets non reconnu (apt/pacman/dnf/zypper requis)." >&2
        errors=$((errors + 1))
    fi

    # /usr/share/sddm/themes doit être accessible en écriture (via root)
    if [[ ! -w "/usr/share/sddm" ]] && [[ ! -w "/usr/share" ]]; then
        echo -e "  ${RED}✘${NC}  /usr/share/sddm n'est pas accessible en écriture." >&2
        errors=$((errors + 1))
    fi

    if [[ $errors -gt 0 ]]; then
        echo "" >&2
        die "$errors problème(s) bloquant(s) détecté(s). Corrigez-les avant de relancer."
    fi

    ok "Pre-flight : toutes les vérifications sont passées."
}

# =============================================================================
#  MODE --diagnose : inspecte l'état réel de SDDM, du thème, de Qt, d'IBus
#  Pas besoin de root. Lance : bash sddm-video.sh --diagnose
# =============================================================================
run_diagnose() {
    SEP="─────────────────────────────────────────────────────────────────"
    dhead() { echo ""; echo -e "${CYN}${SEP}${NC}"; echo -e "${CYN}  $*${NC}"; echo -e "${CYN}${SEP}${NC}"; }
    dok()   { echo -e "  ${GRN}✔${NC}  $*"; }
    dwarn() { echo -e "  ${YEL}⚠${NC}  $*"; }
    derr()  { echo -e "  ${RED}✘  $*${NC}"; }
    dinfo() { echo -e "  ${CYN}→${NC}  $*"; }

    echo ""
    echo -e "${CYN}╔═══════════════════════════════════════════════════════╗"
    echo -e "║   SDDM Video — Diagnostic                            ║"
    echo -e "╚═══════════════════════════════════════════════════════╝${NC}"

    # ── 1. Système ──────────────────────────────────────────────────────────
    dhead "1. Système"
    dinfo "OS      : $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo inconnu)"
    dinfo "Kernel  : $(uname -r)"
    dinfo "Arch    : $(uname -m)"
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        dinfo "Session : Wayland (${WAYLAND_DISPLAY})"
    elif [[ -n "${DISPLAY:-}" ]]; then
        dinfo "Session : X11 (${DISPLAY})"
    else
        dwarn "Session : aucune variable DISPLAY/WAYLAND_DISPLAY — script lancé hors session graphique ?"
    fi

    # ── 2. SDDM binaire + service ────────────────────────────────────────────
    dhead "2. SDDM — binaire et service"
    if command -v sddm &>/dev/null; then
        dok "sddm trouvé : $(command -v sddm)"
    else
        derr "sddm introuvable dans le PATH"
    fi
    # Greeter — on cherche le fichier, on ne l'exécute PAS (sddm --version ouvre le greeter)
    local found_greeter="" found_qt=""
    for p in \
        /usr/bin/sddm-greeter-qt6 \
        /usr/libexec/sddm-greeter-qt6 \
        /usr/lib/x86_64-linux-gnu/libexec/sddm-greeter-qt6 \
        /usr/lib/sddm/sddm-greeter-qt6
    do
        if [[ -f "$p" ]]; then found_greeter="$p"; found_qt="6"; break; fi
    done
    if [[ -z "$found_greeter" ]]; then
        for p in \
            /usr/bin/sddm-greeter \
            /usr/bin/sddm-greeter-qt5 \
            /usr/libexec/sddm-greeter \
            /usr/lib/x86_64-linux-gnu/libexec/sddm-greeter
        do
            if [[ -f "$p" ]]; then found_greeter="$p"; found_qt="5"; break; fi
        done
    fi
    if [[ -n "$found_greeter" ]]; then
        dok "Greeter Qt${found_qt} : $found_greeter"
    else
        derr "Aucun greeter sddm trouvé — SDDM ne peut pas afficher de thème"
    fi
    if command -v systemctl &>/dev/null; then
        local st en
        st=$(systemctl is-active  sddm 2>/dev/null || echo "inconnu")
        en=$(systemctl is-enabled sddm 2>/dev/null || echo "inconnu")
        [[ "$st" == "active"  ]] && dok  "Service actif"           || dwarn "Service : $st"
        [[ "$en" == "enabled" ]] && dok  "Démarrage auto activé"   || dwarn "Démarrage auto : $en"
    fi

    # ── 3. Conflit de config — cause la plus fréquente du revert au thème défaut
    dhead "3. Fichiers de configuration SDDM (ordre de lecture = ordre alphabétique)"
    local our_conf_found=0 kde_conf="" our_wins=1
    echo ""
    dinfo "Fichiers dans $CONF_DIR/ :"
    if [[ -d "$CONF_DIR" ]]; then
        for f in $(ls -1 "$CONF_DIR"/*.conf 2>/dev/null | sort); do
            local theme_line
            theme_line=$(grep -E '^\s*Current\s*=' "$f" 2>/dev/null | tail -1 || true)
            if [[ -n "$theme_line" ]]; then
                echo -e "    ${YEL}$f${NC}  ←  $theme_line"
            else
                echo    "    $f"
            fi
            [[ "$f" == "$CONF_FILE" ]] && our_conf_found=1
            [[ "$(basename "$f")" == "kde_settings.conf" ]] && kde_conf="$f"
        done
    else
        dwarn "$CONF_DIR/ absent"
    fi
    # /etc/sddm.conf — lu EN PLUS, peut écraser conf.d
    if [[ -f /etc/sddm.conf ]]; then
        local theme_etc
        theme_etc=$(grep -E '^\s*Current\s*=' /etc/sddm.conf 2>/dev/null | tail -1 || true)
        echo -e "    ${RED}/etc/sddm.conf${NC}  (priorité maximale !)  ←  ${theme_etc:-aucun Current=}"
        our_wins=0
    fi
    echo ""
    # Analyse du gagnant
    if [[ $our_conf_found -eq 0 ]]; then
        derr "Notre config $CONF_FILE est ABSENTE → thème non appliqué"
        dinfo "Correction : sudo bash sddm-video.sh"
    else
        # Vérifier si notre fichier sort alphabétiquement après kde_settings.conf
        if [[ -n "$kde_conf" ]]; then
            local our_base kde_base
            our_base=$(basename "$CONF_FILE")
            kde_base=$(basename "$kde_conf")
            if [[ "$our_base" > "$kde_base" ]]; then
                dok "Notre fichier '$our_base' sort APRÈS '$kde_base' → il gagne ✓"
            else
                derr "CONFLIT : '$kde_base' sort APRÈS '$our_base' → KDE écrase notre thème !"
                derr "Cause du revert au thème par défaut après reboot."
                dinfo "Correction : sudo bash sddm-video.sh  (renomme en zzz-sddm-video.conf)"
            fi
        else
            dok "Pas de kde_settings.conf détecté"
        fi
        if [[ $our_wins -eq 0 ]]; then
            derr "/etc/sddm.conf présent — il écrase TOUT, y compris conf.d/"
            dinfo "Correction : sudo mv /etc/sddm.conf /etc/sddm.conf.bak"
        fi
    fi

    # ── 4. Thème installé ────────────────────────────────────────────────────
    dhead "4. Thème sddm-video — fichiers"
    if [[ ! -d "$THEME_DIR" ]]; then
        derr "Dossier absent : $THEME_DIR"
        dinfo "Correction : sudo bash sddm-video.sh"
    else
        dok "Dossier thème : $THEME_DIR"
        echo ""
        # Lister les fichiers avec taille et indiquer les manquants
        local -A expected=( ["Main.qml"]="QML principal" ["theme.conf"]="config vidéo" ["metadata.desktop"]="identifiant thème" ["loginterminalc.png"]="image du panneau" ["angle-down.png"]="icônes menus" )
        for fname in "${!expected[@]}"; do
            if [[ -f "$THEME_DIR/$fname" ]]; then
                local sz
                sz=$(du -h "$THEME_DIR/$fname" | cut -f1)
                # Détecter les pointeurs LFS (fichier texte de ~130 octets)
                if head -c 50 "$THEME_DIR/$fname" 2>/dev/null | grep -q "git-lfs"; then
                    derr "$fname ($sz) — POINTEUR LFS, pas le vrai fichier !"
                    dinfo "Correction : sudo bash sddm-video.sh --change-video"
                else
                    dok "$fname ($sz)"
                fi
            else
                derr "$fname ABSENT — ${expected[$fname]}"
            fi
        done
        # Vidéo référencée dans theme.conf
        echo ""
        if [[ -f "$THEME_DIR/theme.conf" ]]; then
            local bg
            bg=$(grep -E '^\s*background\s*=' "$THEME_DIR/theme.conf" 2>/dev/null | cut -d= -f2- | tr -d ' ')
            if [[ -n "$bg" ]]; then
                if [[ -f "$THEME_DIR/$bg" ]]; then
                    local vsz
                    vsz=$(du -h "$THEME_DIR/$bg" | cut -f1)
                    if head -c 50 "$THEME_DIR/$bg" 2>/dev/null | grep -q "git-lfs"; then
                        derr "Vidéo '$bg' ($vsz) — POINTEUR LFS !"
                        dinfo "Correction : sudo bash sddm-video.sh --change-video"
                    else
                        dok "Vidéo '$bg' présente ($vsz)"
                    fi
                else
                    derr "Vidéo '$bg' déclarée dans theme.conf mais ABSENTE du dossier"
                    dinfo "Correction : sudo bash sddm-video.sh --change-video"
                fi
            else
                dwarn "Aucune entrée background= dans theme.conf"
            fi
        fi
        # X-KDE-PluginInfo-Name
        echo ""
        if [[ -f "$THEME_DIR/metadata.desktop" ]]; then
            local pname
            pname=$(grep -i 'X-KDE-PluginInfo-Name' "$THEME_DIR/metadata.desktop" 2>/dev/null | cut -d= -f2- | tr -d ' ')
            if [[ -z "$pname" ]]; then
                derr "X-KDE-PluginInfo-Name manquant dans metadata.desktop → thème invisble pour SDDM"
                dinfo "Correction : sudo bash sddm-video.sh"
            elif [[ "$pname" != "$THEME_NAME" ]]; then
                derr "X-KDE-PluginInfo-Name='$pname' ≠ dossier='$THEME_NAME' → SDDM ignorera ce thème"
                dinfo "Correction : sudo bash sddm-video.sh"
            else
                dok "X-KDE-PluginInfo-Name='$pname' correspond au dossier ✓"
            fi
        else
            derr "metadata.desktop absent"
        fi
    fi

    # ── 5. QtMultimedia ──────────────────────────────────────────────────────
    dhead "5. QtMultimedia — modules QML (nécessaires pour la vidéo)"
    local qt_found=0
    for qml_path in \
        /usr/lib/qt6/qml/QtMultimedia \
        /usr/lib/x86_64-linux-gnu/qt6/qml/QtMultimedia \
        /usr/lib/qt/qml/QtMultimedia \
        /usr/lib64/qt6/qml/QtMultimedia \
        /usr/lib/qt5/qml/QtMultimedia \
        /usr/lib/x86_64-linux-gnu/qt5/qml/QtMultimedia
    do
        if [[ -d "$qml_path" ]]; then
            dok "Module QML trouvé : $qml_path"
            qt_found=1
        fi
    done
    if [[ $qt_found -eq 0 ]]; then
        derr "Aucun module QtMultimedia trouvé → vidéo muette / fond noir"
        dinfo "Correction Debian : sudo apt install qml6-module-qtmultimedia"
        dinfo "Correction Arch   : sudo pacman -S qt6-multimedia"
    fi

    # ── 6. GStreamer ──────────────────────────────────────────────────────────
    dhead "6. GStreamer — décodeurs (H.264, VP8/VP9 pour MP4/WebM)"
    if command -v gst-inspect-1.0 &>/dev/null; then
        dok "gst-inspect-1.0 disponible"
        for plugin in avdec_h264 avdec_h265 vp8dec vp9dec; do
            if gst-inspect-1.0 "$plugin" &>/dev/null 2>&1; then
                dok "Décodeur : $plugin"
            else
                dwarn "Décodeur absent : $plugin"
            fi
        done
    else
        dwarn "gst-inspect-1.0 introuvable — GStreamer peut ne pas être installé"
        dinfo "Correction Debian : sudo apt install gstreamer1.0-libav gstreamer1.0-plugins-good"
    fi

    # ── 7. IBus — origines de l'alerte Wayland ───────────────────────────────
    dhead "7. IBus — recherche de QT_IM_MODULE / GTK_IM_MODULE"
    local ibus_found=0
    local -a files_to_check=(
        /etc/environment
        /etc/profile
        /etc/profile.d/ibus.sh
        /etc/profile.d/ibus-x11.sh
        /etc/profile.d/im-config.sh
        /usr/share/im-config/data/ibus.conf
        "${HOME:-/root}/.pam_environment"
        "${HOME:-/root}/.profile"
        "${HOME:-/root}/.xprofile"
        "${HOME:-/root}/.bashrc"
        "${HOME:-/root}/.config/plasma-workspace/env/ibus.sh"
        "${HOME:-/root}/.config/plasma-workspace/env/im.sh"
        "${HOME:-/root}/.config/environment.d/ibus.conf"
        /etc/sddm.conf
    )
    for f in "$CONF_DIR"/*.conf; do [[ -f "$f" ]] && files_to_check+=("$f"); done
    for f in /etc/environment.d/*.conf; do [[ -f "$f" ]] && files_to_check+=("$f"); done

    for f in "${files_to_check[@]}"; do
        [[ -f "$f" ]] || continue
        if grep -qE 'QT_IM_MODULE|GTK_IM_MODULE' "$f" 2>/dev/null; then
            dwarn "Trouvé dans : $f"
            grep -nE 'QT_IM_MODULE|GTK_IM_MODULE' "$f" | while read -r m; do echo "       $m"; done
            ibus_found=1
        fi
    done
    if [[ $ibus_found -eq 0 ]]; then
        dok "Aucune variable IBus trouvée dans les fichiers statiques"
    else
        echo ""
        dinfo "Correction A : sudo im-config -n none  (désactive toute méthode d'entrée)"
        dinfo "Correction B : KDE Paramètres → Périphériques d'entrée → Clavier virtuel → IBus Wayland"
    fi
    # Variables dans l'env actuel
    echo ""
    dinfo "Variables dans l'environnement du processus courant :"
    for var in QT_IM_MODULE GTK_IM_MODULE XMODIFIERS; do
        local val="${!var:-}"
        [[ -n "$val" ]] && dwarn "$var=$val" || dok "$var (non définie)"
    done

    # ── 8. Logs SDDM récents ──────────────────────────────────────────────────
    dhead "8. Logs SDDM — 30 dernières lignes (erreurs en rouge, IBus en jaune)"
    if command -v journalctl &>/dev/null; then
        journalctl -u sddm -b --no-pager -n 30 2>/dev/null | while IFS= read -r line; do
            if echo "$line" | grep -qiE 'error|fail|crash|fatal'; then
                echo -e "  ${RED}$line${NC}"
            elif echo "$line" | grep -qiE 'warn|ibus|im_module|theme|Current'; then
                echo -e "  ${YEL}$line${NC}"
            else
                echo    "  $line"
            fi
        done
    else
        dwarn "journalctl absent"
    fi

    echo ""
    exit 0
}

if [[ "${1:-}" == "--diagnose" ]]; then run_diagnose; fi

preflight_checks

# ─── Bannière ────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYN}╔═══════════════════════════════════════════════════════╗"
echo -e "║   SDDM Video Background  v2  —  PapaOursPolaire       ║"
echo -e "╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
#  FONCTIONS UTILITAIRES
# =============================================================================

# ─── Téléchargement de la vidéo par défaut depuis le dépôt ──────────────────
download_default_video() {
    local default_name="default.mp4"
    local default_dest="/tmp/${default_name}"

    info "Téléchargement de la vidéo par défaut ($default_name) depuis le dépôt (Git LFS)..."
    local success=1

    # On utilise REPO_LFS (media.githubusercontent.com) et non REPO_RAW.
    # REPO_RAW retourne uniquement le fichier pointeur LFS (~130 octets de texte),
    # pas le binaire réel. media.githubusercontent.com sert le vrai contenu LFS.
    if command -v curl &>/dev/null; then
        curl -fL --max-time 300 --progress-bar \
            "$REPO_LFS/$default_name" -o "$default_dest" 2>&1 && success=0
    elif command -v wget &>/dev/null; then
        wget --timeout=300 --show-progress -q \
            "$REPO_LFS/$default_name" -O "$default_dest" 2>&1 && success=0
    else
        die "curl ou wget requis pour télécharger la vidéo par défaut."
    fi

    # Vérification que le fichier téléchargé est bien une vidéo et non un pointeur LFS.
    # Un pointeur LFS commence par "version https://git-lfs.github.com/spec/v1".
    if [[ $success -eq 0 ]] && [[ -s "$default_dest" ]]; then
        if head -c 50 "$default_dest" 2>/dev/null | grep -q "git-lfs"; then
            warn "Le fichier téléchargé est un pointeur LFS, pas la vraie vidéo."
            warn "Vérifiez que Git LFS est activé sur le dépôt GitHub et réessayez."
            rm -f "$default_dest"
            success=1
        fi
    fi

    if [[ $success -ne 0 ]] || [[ ! -s "$default_dest" ]]; then
        rm -f "$default_dest"
        die "Impossible de télécharger $default_name. Vérifiez votre connexion internet."
    fi

    VIDEO_PATH="$default_dest"
    ok "Vidéo par défaut téléchargée : $default_dest ($(du -h "$default_dest" | cut -f1))"
}

# ─── Sélection de la vidéo ───────────────────────────────────────────────────
select_video() {
    VIDEO_PATH=""

    echo -e "  ${CYN}Appuyez sur Entrée / Annulez le sélecteur pour utiliser la vidéo par défaut du dépôt (default.mp4).${NC}"
    echo ""

    # Essai kdialog (KDE)
    if command -v kdialog &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        info "Ouverture du sélecteur de fichiers (kdialog)..."
        VIDEO_PATH=$(sudo -u "${SUDO_USER:-$USER}" kdialog \
            --getopenfilename "${HOME:-/home}" \
            "*.mp4 *.webm *.avi *.mkv *.mov *.gif" \
            --title "Sélectionnez votre vidéo — Annulez pour utiliser default.mp4" 2>/dev/null) || VIDEO_PATH=""
    fi

    # Essai zenity (GTK/GNOME)
    if [[ -z "$VIDEO_PATH" ]] && command -v zenity &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        info "Ouverture du sélecteur de fichiers (zenity)..."
        VIDEO_PATH=$(sudo -u "${SUDO_USER:-$USER}" zenity \
            --file-selection \
            --title="Sélectionnez votre vidéo — Annulez pour utiliser default.mp4" \
            --file-filter="Vidéos | *.mp4 *.webm *.avi *.mkv *.mov *.gif" \
            2>/dev/null) || VIDEO_PATH=""
    fi

    # Essai yad
    if [[ -z "$VIDEO_PATH" ]] && command -v yad &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        info "Ouverture du sélecteur de fichiers (yad)..."
        VIDEO_PATH=$(sudo -u "${SUDO_USER:-$USER}" yad \
            --file \
            --title="Sélectionnez votre vidéo — Annulez pour utiliser default.mp4" \
            2>/dev/null) || VIDEO_PATH=""
    fi

    # Saisie manuelle si aucun sélecteur graphique
    if [[ -z "$VIDEO_PATH" ]]; then
        warn "Aucun sélecteur graphique disponible."
        echo -e "  Entrez le chemin vers votre vidéo, ou ${CYN}laissez vide${NC} pour utiliser default.mp4 :"
        read -rp "  Chemin : " VIDEO_PATH
    fi

    # ── Fallback : vidéo par défaut du dépôt ─────────────────────────────────
    if [[ -z "$VIDEO_PATH" ]]; then
        info "Aucune vidéo choisie → utilisation de default.mp4 depuis le dépôt."
        download_default_video
        return
    fi

    # Vérifications sur le fichier fourni par l'utilisateur
    [[ ! -f "$VIDEO_PATH" ]] && die "Fichier introuvable : '$VIDEO_PATH'"

    local ext="${VIDEO_PATH##*.}"
    ext="${ext,,}"
    case "$ext" in
        mp4|webm|avi|mkv|mov|gif) ;;
        *) die "Format '$ext' non supporté. Formats acceptés : mp4, webm, avi, mkv, mov, gif" ;;
    esac

    ok "Vidéo sélectionnée : $(basename "$VIDEO_PATH") ($ext)"
}

# ─── Copie/déplacement de la vidéo et mise à jour de theme.conf ──────────────
install_video() {
    # Nom de fichier nettoyé (espaces → underscores, caractères spéciaux retirés)
    FILENAME=$(basename "$VIDEO_PATH" | tr ' ' '_' | tr -cd '[:alnum:]._-')
    local dest="$THEME_DIR/$FILENAME"

    # Supprimer l'ancienne vidéo si elle change
    if [[ -f "$THEME_DIR/theme.conf" ]]; then
        local old_bg
        old_bg=$(grep -E '^background=' "$THEME_DIR/theme.conf" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]' || true)
        if [[ -n "$old_bg" && "$old_bg" != "$FILENAME" && -f "$THEME_DIR/$old_bg" ]]; then
            info "Suppression de l'ancienne vidéo : $old_bg"
            rm -f "$THEME_DIR/$old_bg"
        fi
    fi

    # Déplacement si le fichier vient de /tmp (téléchargé), copie sinon
    if [[ "$VIDEO_PATH" == /tmp/* ]]; then
        info "Déplacement de la vidéo vers $dest ..."
        mv "$VIDEO_PATH" "$dest"
    else
        info "Copie de la vidéo vers $dest ..."
        cp "$VIDEO_PATH" "$dest"
    fi
    chmod 644 "$dest"
    ok "Vidéo installée : $FILENAME"

    # Mise à jour de theme.conf
    if [[ -f "$THEME_DIR/theme.conf" ]]; then
        sed -i "s|^background=.*|background=$FILENAME|" "$THEME_DIR/theme.conf"
    else
        printf '[General]\nbackground=%s\n' "$FILENAME" > "$THEME_DIR/theme.conf"
    fi
    ok "theme.conf mis à jour : background=$FILENAME"
}


# =============================================================================
#  MODE --change-video : juste changer la vidéo, sans réinstaller
# =============================================================================
if [[ "${1:-}" == "--change-video" ]]; then
    echo -e "${CYN}  Mode : changement de vidéo uniquement${NC}"
    echo ""

    [[ ! -d "$THEME_DIR" ]] && die "Thème non installé. Lancez d'abord l'installation complète."

    select_video
    install_video

    echo ""
    echo -e "${GRN}  ✔  Vidéo mise à jour avec succès !${NC}"
    echo ""
    read -rp "  Redémarrer SDDM maintenant ? [o/N] : " REP
    if [[ "$REP" =~ ^[Oo]$ ]]; then
        systemctl restart sddm
        echo "  État SDDM : $(systemctl is-active sddm)"
    fi
    exit 0
fi

# =============================================================================
#  ÉTAPE 1 — Nettoyage ciblé (uniquement notre fichier de config)
# =============================================================================
step "1/8" "Nettoyage des configurations précédentes..."

# Supprimer UNIQUEMENT nos propres fichiers de config (ancien et nouveau nom)
for old_conf in "$CONF_DIR/sddm-video.conf" "$CONF_FILE"; do
    if [[ -f "$old_conf" ]]; then
        info "Suppression de $old_conf"
        rm -f "$old_conf"
    fi
done

# Supprimer les anciens thèmes qu'on a pu créer
for t in video-bg sddm-video video custom; do
    if [[ -d "/usr/share/sddm/themes/$t" ]]; then
        info "Suppression de l'ancien thème : $t"
        rm -rf "/usr/share/sddm/themes/$t"
    fi
done

ok "Nettoyage terminé."

# =============================================================================
#  ÉTAPE 2 — Installation de SDDM
# =============================================================================
step "2/8" "Installation de SDDM..."

if command -v apt-get &>/dev/null; then
    info "Gestionnaire : apt"
    apt-get update -qq
    apt-get install -y sddm 2>/dev/null || true
elif command -v pacman &>/dev/null; then
    info "Gestionnaire : pacman"
    pacman -Sy --noconfirm sddm
elif command -v dnf &>/dev/null; then
    info "Gestionnaire : dnf"
    dnf install -y sddm
elif command -v zypper &>/dev/null; then
    info "Gestionnaire : zypper"
    zypper install -y sddm
else
    die "Gestionnaire de paquets non reconnu (apt/pacman/dnf/zypper requis)."
fi

command -v sddm &>/dev/null || die "SDDM toujours absent après installation."
ok "SDDM installé : $(command -v sddm)"

# =============================================================================
#  ÉTAPE 3 — Détection de la version Qt
# =============================================================================
step "3/8" "Détection de la version Qt du greeter SDDM..."

# Recherche du greeter Qt6
for p in \
    /usr/bin/sddm-greeter-qt6 \
    /usr/libexec/sddm-greeter-qt6 \
    /usr/lib/x86_64-linux-gnu/libexec/sddm-greeter-qt6 \
    /usr/lib/aarch64-linux-gnu/libexec/sddm-greeter-qt6 \
    /usr/lib/sddm/sddm-greeter-qt6 \
    /usr/lib/libexec/sddm-greeter-qt6
do
    if [[ -f "$p" ]]; then
        QT_VERSION="6"
        ok "Greeter Qt6 trouvé : $p"
        break
    fi
done

# Recherche du greeter Qt5 si Qt6 non trouvé
if [[ -z "$QT_VERSION" ]]; then
    for p in \
        /usr/bin/sddm-greeter \
        /usr/bin/sddm-greeter-qt5 \
        /usr/libexec/sddm-greeter \
        /usr/lib/x86_64-linux-gnu/libexec/sddm-greeter \
        /usr/lib/aarch64-linux-gnu/libexec/sddm-greeter \
        /usr/lib/sddm/sddm-greeter-qt5
    do
        if [[ -f "$p" ]]; then
            QT_VERSION="5"
            ok "Greeter Qt5 trouvé : $p"
            break
        fi
    done
fi

# Fallback via dpkg
if [[ -z "$QT_VERSION" ]] && command -v dpkg &>/dev/null; then
    if dpkg -l sddm-greeter-qt6 2>/dev/null | grep -q "^ii"; then
        QT_VERSION="6"; info "Détecté via dpkg : sddm-greeter-qt6"
    elif dpkg -l sddm-greeter 2>/dev/null | grep -q "^ii"; then
        QT_VERSION="5"; info "Détecté via dpkg : sddm-greeter (Qt5)"
    fi
fi

# Fallback via rpm
if [[ -z "$QT_VERSION" ]] && command -v rpm &>/dev/null; then
    if rpm -q sddm-qt6 &>/dev/null 2>&1; then
        QT_VERSION="6"; info "Détecté via rpm : sddm-qt6"
    fi
fi

# Fallback via pacman
if [[ -z "$QT_VERSION" ]] && command -v pacman &>/dev/null; then
    # Arch utilise Qt6 par défaut depuis 2023
    QT_VERSION="6"; info "Arch Linux détecté → Qt6 par défaut"
fi

# Fallback via la distro
if [[ -z "$QT_VERSION" ]] && [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    case "${VERSION_CODENAME:-}${VERSION_ID:-}" in
        trixie|forky|noble|24.04|40|41|42) QT_VERSION="6" ;;
        bookworm|jammy|22.04|bullseye|focal|20.04) QT_VERSION="5" ;;
        *) QT_VERSION="6" ;;
    esac
    info "Déduit via distro (${PRETTY_NAME:-}): Qt${QT_VERSION}"
fi

[[ -z "$QT_VERSION" ]] && { QT_VERSION="6"; warn "Qt inconnu — Qt6 assumé par défaut"; }
ok "Version Qt sélectionnée : Qt${QT_VERSION}"

# =============================================================================
#  ÉTAPE 4 — Installation des dépendances QtMultimedia
# =============================================================================
step "4/8" "Installation des dépendances QtMultimedia..."

install_multimedia_deps() {
    if command -v apt-get &>/dev/null; then
        if [[ "$QT_VERSION" == "6" ]]; then
            # Modules QML Qt6
            apt-get install -y \
                qml6-module-qtmultimedia \
                qml6-module-qtquick-controls \
                qt6-multimedia-dev \
                2>/dev/null || \
            apt-get install -y \
                qml6-module-qtmultimedia \
                2>/dev/null || true
        else
            # Modules QML Qt5
            apt-get install -y \
                qml-module-qtmultimedia \
                qml-module-qtquick-controls2 \
                2>/dev/null || true
        fi
        # GStreamer — backend de décodage vidéo (MP4/H.264, WebM, etc.)
        # Indispensable sur Debian/Ubuntu pour que QtMultimedia puisse lire des vidéos.
        apt-get install -y \
            gstreamer1.0-plugins-good \
            gstreamer1.0-plugins-bad \
            gstreamer1.0-plugins-ugly \
            gstreamer1.0-libav \
            gstreamer1.0-tools \
            2>/dev/null || \
        apt-get install -y \
            gstreamer1.0-plugins-good \
            gstreamer1.0-libav \
            2>/dev/null || true

    elif command -v pacman &>/dev/null; then
        pacman -Sy --noconfirm --needed \
            qt6-multimedia \
            gst-libav \
            gst-plugins-good \
            gst-plugins-bad \
            gst-plugins-ugly \
            2>/dev/null || true

    elif command -v dnf &>/dev/null; then
        if [[ "$QT_VERSION" == "6" ]]; then
            dnf install -y qt6-qtmultimedia 2>/dev/null || true
        else
            dnf install -y qt5-qtmultimedia 2>/dev/null || true
        fi
        # GStreamer sur Fedora/RHEL
        dnf install -y \
            gstreamer1-plugins-good \
            gstreamer1-plugins-bad-free \
            gstreamer1-libav \
            gstreamer1-plugins-ugly-free \
            2>/dev/null || \
        dnf install -y \
            gstreamer1-plugins-good \
            gstreamer1-libav \
            2>/dev/null || true

    elif command -v zypper &>/dev/null; then
        # openSUSE
        zypper install -y \
            libQt6Multimedia6 \
            qml6-module-qtmultimedia \
            gstreamer-plugins-good \
            gstreamer-plugins-bad \
            gstreamer-plugins-libav \
            2>/dev/null || \
        zypper install -y \
            libQt6Multimedia6 \
            gstreamer-plugins-good \
            2>/dev/null || true
    fi
}

install_multimedia_deps
ok "Dépendances QtMultimedia installées."

# =============================================================================
#  ÉTAPE 5 — Sélection de la vidéo
# =============================================================================
step "5/8" "Sélection de la vidéo de fond..."
info "Formats acceptés : mp4, webm, avi, mkv, mov, gif"
echo ""

select_video

# =============================================================================
#  ÉTAPE 6 — Création du thème
# =============================================================================
step "6/8" "Création du thème SDDM..."

mkdir -p "$THEME_DIR"

# Copie de la vidéo + mise à jour theme.conf
install_video

# ── Téléchargement des assets graphiques depuis le dépôt ─────────────────────
download_asset() {
    local asset="$1"
    local dest="$THEME_DIR/$asset"
    local success=1
    local fsize=0

    # Essai 1 : raw.githubusercontent.com
    if command -v curl &>/dev/null; then
        curl -fsSL --max-time 20 "$REPO_RAW/$asset" -o "$dest" 2>/dev/null && success=0
    elif command -v wget &>/dev/null; then
        wget -q --timeout=20 "$REPO_RAW/$asset" -O "$dest" 2>/dev/null && success=0
    fi

    # Un pointeur LFS est du texte pur de ~130 octets commençant par "version https://git-lfs"
    # Un PNG valide fait toujours >1KB et commence par les octets magiques \x89PNG
    # → on rejette uniquement si le fichier est petit ET contient "git-lfs" en clair
    if [[ $success -eq 0 ]] && [[ -s "$dest" ]]; then
        fsize=$(wc -c < "$dest" 2>/dev/null || echo 0)
        if [[ $fsize -lt 500 ]] && head -c 80 "$dest" 2>/dev/null | grep -q "git-lfs"; then
            info "$asset est un pointeur LFS — tentative via media.githubusercontent.com..."
            rm -f "$dest"
            success=1
        fi
    fi

    # Essai 2 : media.githubusercontent.com (binaires LFS)
    if [[ $success -ne 0 ]]; then
        if command -v curl &>/dev/null; then
            curl -fsSL --max-time 30 "$REPO_LFS/$asset" -o "$dest" 2>/dev/null && success=0
        elif command -v wget &>/dev/null; then
            wget -q --timeout=30 "$REPO_LFS/$asset" -O "$dest" 2>/dev/null && success=0
        fi
        if [[ $success -eq 0 ]] && [[ -s "$dest" ]]; then
            fsize=$(wc -c < "$dest" 2>/dev/null || echo 0)
            if [[ $fsize -lt 500 ]] && head -c 80 "$dest" 2>/dev/null | grep -q "git-lfs"; then
                warn "$asset : toujours un pointeur LFS après media.githubusercontent.com"
                rm -f "$dest"; success=1
            fi
        fi
    fi

    if [[ $success -eq 0 ]] && [[ -s "$dest" ]]; then
        chmod 644 "$dest"
        ok "Téléchargé : $asset ($(du -h "$dest" | cut -f1))"
        return 0
    else
        rm -f "$dest" 2>/dev/null || true
        return 1
    fi
}

# ── Génération PNG de secours (Python stdlib, sans PIL) ───────────────────────
# Appelée si le téléchargement échoue. Produit des PNG minimaux mais fonctionnels.
generate_fallback_png() {
    local asset="$1"
    local dest="$THEME_DIR/$asset"

    python3 - "$dest" "$asset" <<'PYEOF'
import sys, struct, zlib

def write_png(filename, width, height, get_pixel):
    def chunk(tag, data):
        raw = tag + data
        return struct.pack('>I', len(data)) + raw + struct.pack('>I', zlib.crc32(raw) & 0xffffffff)
    # IHDR: width(4) height(4) bitdepth(1) colortype=6=RGBA(1) compression(1) filter(1) interlace(1)
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    rows = []
    for y in range(height):
        row = b'\x00'
        for x in range(width):
            row += bytes(get_pixel(x, y))
        rows.append(row)
    idat = zlib.compress(b''.join(rows), 9)
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', ihdr)
    png += chunk(b'IDAT', idat)
    png += chunk(b'IEND', b'')
    with open(filename, 'wb') as f:
        f.write(png)

dest = sys.argv[1]
asset = sys.argv[2]

if asset == 'angle-down.png':
    # 24x24 chevron blanc pointant vers le bas, fond transparent
    W, H = 24, 24
    pixels = set()
    for i in range(8):
        for t in range(2):   # épaisseur 2px
            pixels.add((4 + i + t,     7 + i))
            pixels.add((19 - i + t,    7 + i))
    def px(x, y):
        return (255, 255, 255, 220) if (x, y) in pixels else (0, 0, 0, 0)
    write_png(dest, W, H, px)

elif asset == 'loginterminalc.png':
    # 420x360 panneau terminal style Pip-Boy : fond sombre, bordure verte, effet CRT
    W, H = 420, 360
    BG    = (8,  18,  8, 210)   # fond vert très sombre semi-transparent
    BORD  = (0, 200,  0, 255)   # bordure verte vive
    INNER = (12, 28, 12, 200)   # fond intérieur légèrement plus clair
    SCAN  = (0,   0,  0,  18)   # lignes de balayage CRT (overlay sombre)
    B = 4   # épaisseur bordure
    def px(x, y):
        # Bordure extérieure
        if x < B or x >= W - B or y < B or y >= H - B:
            return BORD
        # Intérieur avec effet scanlines (une ligne sur deux légèrement assombrie)
        r, g, b, a = INNER
        if y % 2 == 0:
            a_scan = min(255, a + SCAN[3])
            return (max(0, r - 3), max(0, g - 3), max(0, b - 3), a_scan)
        return INNER
    write_png(dest, W, H, px)
PYEOF
    if [[ -s "$dest" ]]; then
        chmod 644 "$dest"
        ok "PNG de secours généré : $asset ($(du -h "$dest" | cut -f1))"
        return 0
    else
        warn "Impossible de générer $asset (Python3 requis)"
        return 1
    fi
}

info "Téléchargement des assets graphiques..."
download_asset "loginterminalc.png" || {
    warn "Téléchargement échoué — génération d'un PNG de secours pour loginterminalc.png"
    generate_fallback_png "loginterminalc.png"
}
download_asset "angle-down.png" || {
    warn "Téléchargement échoué — génération d'un PNG de secours pour angle-down.png"
    generate_fallback_png "angle-down.png"
}

# ── metadata.desktop ─────────────────────────────────────────────────────────
# CRITIQUE : X-KDE-PluginInfo-Name doit correspondre EXACTEMENT au nom du
# dossier du thème ($THEME_NAME). Sans ce champ, SDDM ne reconnaît pas le thème
# et retombe silencieusement sur le thème par défaut (interface blanche/grise).
if [[ "$QT_VERSION" == "6" ]]; then
    cat > "$THEME_DIR/metadata.desktop" <<EOF
[Desktop Entry]
Name=SDDM Video Background
Comment=Fond vidéo configurable pour SDDM — by PapaOursPolaire
Type=Service
X-KDE-PluginInfo-Name=$THEME_NAME
X-KDE-PluginInfo-Author=PapaOursPolaire
X-KDE-PluginInfo-Email=papaoursgamer@gmail.com
X-KDE-PluginInfo-Version=2.0
X-KDE-PluginInfo-License=GPL
QtVersion=6
EOF
else
    cat > "$THEME_DIR/metadata.desktop" <<EOF
[Desktop Entry]
Name=SDDM Video Background
Comment=Fond vidéo configurable pour SDDM — by PapaOursPolaire
Type=Service
X-KDE-PluginInfo-Name=$THEME_NAME
X-KDE-PluginInfo-Author=PapaOursPolaire
X-KDE-PluginInfo-Email=papaoursgamer@gmail.com
X-KDE-PluginInfo-Version=2.0
X-KDE-PluginInfo-License=GPL
EOF
fi
ok "metadata.desktop écrit (Qt${QT_VERSION})"

# ── theme.conf.user (persistance des préférences utilisateur) ─────────────────
# Ce fichier est lu EN PLUS de theme.conf par SDDM.
# L'utilisateur peut y mettre ses surcharges sans toucher au theme.conf d'origine.
[[ ! -f "$THEME_DIR/theme.conf.user" ]] && cat > "$THEME_DIR/theme.conf.user" <<'EOF'
# Surcharges utilisateur — ce fichier a priorité sur theme.conf
# Décommentez et modifiez les valeurs selon vos besoins.
#
# [General]
# background=mavideo.mp4     ← juste le nom de fichier, sans chemin
EOF
ok "theme.conf.user prêt (commentaires uniquement)"

# ── Main.qml — Qt6 ───────────────────────────────────────────────────────────
if [[ "$QT_VERSION" == "6" ]]; then
    cat > "$THEME_DIR/Main.qml" <<'QMLEOF'
// =============================================================================
//  SDDM Video Background  v2  —  Main.qml  (Qt6)
//  by PapaOursPolaire
//
//  La vidéo de fond se configure dans theme.conf :
//    [General]
//    background=nomdevideo.mp4
//
//  Pour changer la vidéo sans réinstaller :
//    sudo bash sddm-video.sh --change-video
// =============================================================================

import QtQuick 2.15
import QtMultimedia 6.0
import SddmComponents 2.0

Rectangle {
    id: container
    width:  Screen.width
    height: Screen.height
    color:  "black"

    LayoutMirroring.enabled:        Qt.locale().textDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property int sessionIndex: session.index

    // ── Résolution du chemin vidéo depuis theme.conf ─────────────────────────
    // config.background contient la valeur de background= dans theme.conf.
    // Qt.resolvedUrl() résout les chemins relatifs par rapport au dossier du thème.
    property string videoSrc: {
        var bg = config.background
        if (!bg || bg.length === 0) return ""
        if (bg.indexOf("file://") === 0) return bg
        if (bg.indexOf("/") === 0)       return "file://" + bg
        return Qt.resolvedUrl(bg).toString()
    }

    TextConstants { id: textConstants }

    // ── Connexions SDDM ───────────────────────────────────────────────────────
    Connections {
        target: sddm

        function onLoginSucceeded() {
            errorMessage.color = "steelblue"
            errorMessage.text  = textConstants.loginSucceeded
        }

        function onLoginFailed() {
            password.text      = ""
            errorMessage.color = "red"
            errorMessage.text  = textConstants.loginFailed
        }

        function onInformationMessage(message) {
            errorMessage.color = "red"
            errorMessage.text  = message
        }
    }

    // ── Vidéo en arrière-plan ─────────────────────────────────────────────────
    VideoOutput {
        id: videoOut
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    MediaPlayer {
        id: videoPlayer
        source:      container.videoSrc
        videoOutput: videoOut
        audioOutput: AudioOutput { muted: true }
        autoPlay:    true
        loops:       MediaPlayer.Infinite

        onErrorOccurred: function(error, errorString) {
            console.warn("SDDM Video: erreur lecteur —", errorString)
        }
    }

    // ── Overlay sombre (améliore la lisibilité du texte) ─────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#40000000"
    }

    // ── Horloge ───────────────────────────────────────────────────────────────
    Clock {
        id: clock
        anchors.top:         parent.top
        anchors.right:       parent.right
        anchors.topMargin:   40
        anchors.rightMargin: 40
        color: "#eaf5c4"

        timeFont {
            family:    "Consolas"
            bold:      true
            pixelSize: 90
        }
        dateFont {
            family:    "Lucida Console"
            bold:      true
            pixelSize: 30
        }
    }

    // ── Panneau de connexion ──────────────────────────────────────────────────
    Image {
        id: loginPanel
        anchors.verticalCenter: parent.verticalCenter
        anchors.right:          parent.right
        anchors.rightMargin:    40
        source:   "loginterminalc.png"
        width:    Math.max(370, mainColumn.implicitWidth  + 60)
        height:   Math.max(320, mainColumn.implicitHeight + 60)
        fillMode: Image.Stretch

        Column {
            id: mainColumn
            anchors.centerIn: parent
            spacing: 12
            width: parent.width - 60

            // ── Nom d'utilisateur ─────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 4

                Text {
                    text:            textConstants.userName
                    color:           "#88FF88"
                    font.bold:       true
                    font.pixelSize:  12
                }

                TextBox {
                    id:              name
                    width:           parent.width
                    height:          30
                    text:            userModel.lastUser
                    textColor:       "#88FF88"
                    color:           "transparent"
                    font.pixelSize:  14
                    KeyNavigation.backtab: rebootButton
                    KeyNavigation.tab:     password

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(name.text, password.text, sessionIndex)
                            event.accepted = true
                        }
                    }
                }
            }

            // ── Mot de passe ──────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 4

                Text {
                    text:           textConstants.password
                    color:          "#88FF88"
                    font.bold:      true
                    font.pixelSize: 12
                }

                PasswordBox {
                    id:             password
                    width:          parent.width
                    height:         30
                    font.pixelSize: 14
                    textColor:      "#88FF88"
                    color:          "transparent"
                    KeyNavigation.backtab: name
                    KeyNavigation.tab:     session

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(name.text, password.text, sessionIndex)
                            event.accepted = true
                        }
                    }
                }
            }

            // ── Session + Disposition clavier ─────────────────────────────
            Row {
                width:   parent.width
                spacing: 8

                Column {
                    width:   (parent.width - 8) * 0.55
                    spacing: 4

                    Text {
                        text:           textConstants.session
                        color:          "#88FF88"
                        font.bold:      true
                        font.pixelSize: 12
                    }

                    ComboBox {
                        id:             session
                        width:          parent.width
                        height:         30
                        font.pixelSize: 14
                        color:          "transparent"
                        arrowIcon:      "angle-down.png"
                        model:          sessionModel
                        index:          sessionModel.lastIndex
                        KeyNavigation.backtab: password
                        KeyNavigation.tab:     layoutBox
                    }
                }

                Column {
                    width:   (parent.width - 8) * 0.45
                    spacing: 4

                    Text {
                        text:           textConstants.layout
                        color:          "#88FF88"
                        font.bold:      true
                        font.pixelSize: 12
                    }

                    LayoutBox {
                        id:             layoutBox
                        width:          parent.width
                        height:         30
                        font.pixelSize: 14
                        color:          "transparent"
                        arrowIcon:      "angle-down.png"
                        KeyNavigation.backtab: session
                        KeyNavigation.tab:     loginButton
                    }
                }
            }

            // ── Message d'erreur / prompt ─────────────────────────────────
            Text {
                id:                  errorMessage
                anchors.horizontalCenter: parent.horizontalCenter
                text:                textConstants.prompt
                font.pixelSize:      10
                color:               "#88FF88"
            }

            // ── Boutons Login / Reboot / Shutdown ─────────────────────────
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Button {
                    id:        loginButton
                    text:      textConstants.login
                    width:     73;  height: 75
                    color:     "transparent"
                    textColor: "green"
                    onClicked: sddm.login(name.text, password.text, sessionIndex)
                    KeyNavigation.backtab: layoutBox
                    KeyNavigation.tab:     shutdownButton
                }

                Button {
                    id:        rebootButton
                    text:      textConstants.reboot
                    width:     73;  height: 75
                    color:     "transparent"
                    textColor: "yellow"
                    onClicked: sddm.reboot()
                    KeyNavigation.backtab: shutdownButton
                    KeyNavigation.tab:     name
                }

                Button {
                    id:        shutdownButton
                    text:      "Power"
                    width:     73;  height: 75
                    color:     "transparent"
                    textColor: "red"
                    onClicked: sddm.powerOff()
                    KeyNavigation.backtab: loginButton
                    KeyNavigation.tab:     rebootButton
                }
            }
        }
    }

    Component.onCompleted: {
        if (name.text === "") name.focus = true
        else password.focus = true
    }
}
QMLEOF

# ── Main.qml — Qt5 ───────────────────────────────────────────────────────────
else
    cat > "$THEME_DIR/Main.qml" <<'QMLEOF'
// =============================================================================
//  SDDM Video Background  v2  —  Main.qml  (Qt5)
//  by PapaOursPolaire
//
//  La vidéo de fond se configure dans theme.conf :
//    [General]
//    background=nomdevideo.mp4
//
//  Pour changer la vidéo sans réinstaller :
//    sudo bash sddm-video.sh --change-video
// =============================================================================

import QtQuick 2.15
import QtMultimedia 5.15
import SddmComponents 2.0

Rectangle {
    id: container
    width:  Screen.width
    height: Screen.height
    color:  "black"

    LayoutMirroring.enabled:         Qt.locale().textDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property int sessionIndex: session.index

    // ── Résolution du chemin vidéo depuis theme.conf ─────────────────────────
    property string videoSrc: {
        var bg = config.background
        if (!bg || bg.length === 0) return ""
        if (bg.indexOf("file://") === 0) return bg
        if (bg.indexOf("/") === 0)       return "file://" + bg
        return Qt.resolvedUrl(bg).toString()
    }

    TextConstants { id: textConstants }

    // ── Connexions SDDM ───────────────────────────────────────────────────────
    Connections {
        target: sddm

        onLoginSucceeded: {
            errorMessage.color = "steelblue"
            errorMessage.text  = textConstants.loginSucceeded
        }

        onLoginFailed: {
            password.text      = ""
            errorMessage.color = "red"
            errorMessage.text  = textConstants.loginFailed
        }

        onInformationMessage: {
            errorMessage.color = "red"
            errorMessage.text  = message
        }
    }

    // ── Vidéo en arrière-plan ─────────────────────────────────────────────────
    MediaPlayer {
        id:       videoPlayer
        source:   container.videoSrc
        autoPlay: true
        muted:    true
        loops:    MediaPlayer.Infinite
    }

    VideoOutput {
        anchors.fill: parent
        source:       videoPlayer
        fillMode:     VideoOutput.PreserveAspectCrop
    }

    // ── Overlay sombre ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#40000000"
    }

    // ── Horloge ───────────────────────────────────────────────────────────────
    Clock {
        id: clock
        anchors.top:         parent.top
        anchors.right:       parent.right
        anchors.topMargin:   40
        anchors.rightMargin: 40
        color: "#eaf5c4"

        timeFont {
            family:    "Consolas"
            bold:      true
            pixelSize: 90
        }
        dateFont {
            family:    "Lucida Console"
            bold:      true
            pixelSize: 30
        }
    }

    // ── Panneau de connexion ──────────────────────────────────────────────────
    Image {
        id: loginPanel
        anchors.verticalCenter: parent.verticalCenter
        anchors.right:          parent.right
        anchors.rightMargin:    40
        source:   "loginterminalc.png"
        width:    Math.max(370, mainColumn.implicitWidth  + 60)
        height:   Math.max(320, mainColumn.implicitHeight + 60)
        fillMode: Image.Stretch

        Column {
            id: mainColumn
            anchors.centerIn: parent
            spacing: 12
            width: parent.width - 60

            // ── Nom d'utilisateur ─────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 4

                Text {
                    text:           textConstants.userName
                    color:          "#88FF88"
                    font.bold:      true
                    font.pixelSize: 12
                }

                TextBox {
                    id:             name
                    width:          parent.width
                    height:         30
                    text:           userModel.lastUser
                    textColor:      "#88FF88"
                    color:          "transparent"
                    font.pixelSize: 14
                    KeyNavigation.backtab: rebootButton
                    KeyNavigation.tab:     password

                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(name.text, password.text, sessionIndex)
                            event.accepted = true
                        }
                    }
                }
            }

            // ── Mot de passe ──────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 4

                Text {
                    text:           textConstants.password
                    color:          "#88FF88"
                    font.bold:      true
                    font.pixelSize: 12
                }

                PasswordBox {
                    id:             password
                    width:          parent.width
                    height:         30
                    font.pixelSize: 14
                    textColor:      "#88FF88"
                    color:          "transparent"
                    KeyNavigation.backtab: name
                    KeyNavigation.tab:     session

                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(name.text, password.text, sessionIndex)
                            event.accepted = true
                        }
                    }
                }
            }

            // ── Session + Disposition clavier ─────────────────────────────
            Row {
                width:   parent.width
                spacing: 8

                Column {
                    width:   (parent.width - 8) * 0.55
                    spacing: 4

                    Text {
                        text:           textConstants.session
                        color:          "#88FF88"
                        font.bold:      true
                        font.pixelSize: 12
                    }

                    ComboBox {
                        id:             session
                        width:          parent.width
                        height:         30
                        font.pixelSize: 14
                        color:          "transparent"
                        arrowIcon:      "angle-down.png"
                        model:          sessionModel
                        index:          sessionModel.lastIndex
                        KeyNavigation.backtab: password
                        KeyNavigation.tab:     layoutBox
                    }
                }

                Column {
                    width:   (parent.width - 8) * 0.45
                    spacing: 4

                    Text {
                        text:           textConstants.layout
                        color:          "#88FF88"
                        font.bold:      true
                        font.pixelSize: 12
                    }

                    LayoutBox {
                        id:             layoutBox
                        width:          parent.width
                        height:         30
                        font.pixelSize: 14
                        color:          "transparent"
                        arrowIcon:      "angle-down.png"
                        KeyNavigation.backtab: session
                        KeyNavigation.tab:     loginButton
                    }
                }
            }

            // ── Message d'erreur / prompt ─────────────────────────────────
            Text {
                id:                  errorMessage
                anchors.horizontalCenter: parent.horizontalCenter
                text:                textConstants.prompt
                font.pixelSize:      10
                color:               "#88FF88"
            }

            // ── Boutons Login / Reboot / Shutdown ─────────────────────────
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Button {
                    id:        loginButton
                    text:      textConstants.login
                    width:     73;  height: 75
                    color:     "transparent"
                    textColor: "green"
                    onClicked: sddm.login(name.text, password.text, sessionIndex)
                    KeyNavigation.backtab: layoutBox
                    KeyNavigation.tab:     shutdownButton
                }

                Button {
                    id:        rebootButton
                    text:      textConstants.reboot
                    width:     73;  height: 75
                    color:     "transparent"
                    textColor: "yellow"
                    onClicked: sddm.reboot()
                    KeyNavigation.backtab: shutdownButton
                    KeyNavigation.tab:     name
                }

                Button {
                    id:        shutdownButton
                    text:      "Power"
                    width:     73;  height: 75
                    color:     "transparent"
                    textColor: "red"
                    onClicked: sddm.powerOff()
                    KeyNavigation.backtab: loginButton
                    KeyNavigation.tab:     rebootButton
                }
            }
        }
    }

    Component.onCompleted: {
        if (name.text === "") name.focus = true
        else password.focus = true
    }
}
QMLEOF
fi

ok "Main.qml Qt${QT_VERSION} écrit."

# Permissions du dossier thème
chmod -R 755 "$THEME_DIR"
find "$THEME_DIR" -type f -exec chmod 644 {} \;
ok "Permissions du thème appliquées."

# =============================================================================
#  ÉTAPE 7 — Configuration SDDM
# =============================================================================
step "7/8" "Écriture de la configuration SDDM..."

mkdir -p "$CONF_DIR"

# ── Détection du serveur d'affichage ─────────────────────────────────────────
# On ne force pas le DisplayServer pour éviter les écrans noirs.
# SDDM choisira automatiquement X11 ou Wayland selon le système.
# Si besoin, l'utilisateur peut ajouter DisplayServer=wayland ou x11 manuellement.
DISPLAY_SERVER_LINE=""
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    DISPLAY_SERVER_LINE="# DisplayServer=wayland  ← décommentez si nécessaire"
elif [[ -n "${DISPLAY:-}" ]]; then
    DISPLAY_SERVER_LINE="# DisplayServer=x11  ← décommentez si nécessaire"
else
    DISPLAY_SERVER_LINE="# DisplayServer=  ← wayland ou x11 — laissez vide pour auto-détection"
fi

cat > "$CONF_FILE" <<EOF
# Configuration SDDM — sddm-video v2 — PapaOursPolaire
# Généré le $(date '+%Y-%m-%d %H:%M:%S')
#
# Pour changer la vidéo de fond :
#   sudo bash sddm-video.sh --change-video
# Pour diagnostiquer un problème :
#   bash sddm-video.sh --diagnose

[General]
Numlock=on
$DISPLAY_SERVER_LINE
# InputMethod= vide : SDDM ne démarre aucune méthode d'entrée dans le greeter.
# Cela empêche IBus de s'initialiser hors contexte Wayland et évite l'alerte :
# "IBus should be called from the desktop session in Wayland".
InputMethod=

[Theme]
Current=$THEME_NAME

[Users]
MinimumUid=1000
MaximumUid=60000
EOF

ok "Config écrite : $CONF_FILE"

# ── Correction IBus Wayland ───────────────────────────────────────────────────
# L'alerte "IBus should be called from the desktop session in Wayland" ne vient
# PAS de SDDM — elle apparaît au démarrage de la session KDE Plasma.
# Cause : QT_IM_MODULE=ibus est injecté par im-config via PAM (pam_env ou
# /etc/X11/Xsession.d/) AVANT que Plasma démarre. Sous Wayland, IBus ne peut
# pas s'initialiser via XIM — il faut passer par "IBus Wayland" dans les réglages
# KDE, qui n'utilise PAS ces variables d'environnement.
#
# Stratégie multi-couches (la première couche qui bloque suffit) :
#   1. im-config -n none          → supprime l'injection à la source (PAM)
#   2. ~/.xinputrc = none         → fallback si im-config ne peut pas être relancé
#   3. plasma autostart script    → unset en dernier recours avant le démarrage Plasma
#   4. /etc/environment.d/        → couverture systemd-logind (sessions pures systemd)

REAL_USER="${SUDO_USER:-}"
REAL_HOME=""
if [[ -n "$REAL_USER" ]]; then
    REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6 2>/dev/null || echo "")
fi

# Couche 1 — im-config : désactive toute méthode d'entrée gérée par im-config
if command -v im-config &>/dev/null; then
    info "im-config détecté — désactivation de la méthode d'entrée XIM..."
    if [[ -n "$REAL_USER" ]]; then
        # Lancer im-config en tant que l'utilisateur réel, pas root
        sudo -u "$REAL_USER" im-config -n none 2>/dev/null && \
            ok "im-config -n none appliqué pour l'utilisateur '$REAL_USER'" || \
            warn "im-config -n none a échoué (peut nécessiter une session graphique)"
    else
        im-config -n none 2>/dev/null && ok "im-config -n none appliqué" || true
    fi
fi

# Couche 2 — ~/.xinputrc : le fichier lu directement par /etc/X11/Xsession.d/70im-config
if [[ -n "$REAL_HOME" ]] && [[ -d "$REAL_HOME" ]]; then
    XINPUTRC="$REAL_HOME/.xinputrc"
    if [[ -f "$XINPUTRC" ]]; then
        info "Correction de $XINPUTRC (était : $(cat "$XINPUTRC" 2>/dev/null | tr -d '\n'))"
        echo "run_im none" > "$XINPUTRC"
        chown "$REAL_USER" "$XINPUTRC"
        ok "$XINPUTRC → run_im none"
    else
        echo "run_im none" > "$XINPUTRC"
        chown "$REAL_USER" "$XINPUTRC"
        ok "$XINPUTRC créé → run_im none"
    fi
fi

# Couche 3 — Plasma autostart : script exécuté par KDE juste avant le démarrage
# de la session, APRÈS les scripts PAM. Dernière chance de nettoyer les variables.
if [[ -n "$REAL_HOME" ]] && [[ -d "$REAL_HOME" ]]; then
    PLASMA_ENV_DIR="$REAL_HOME/.config/plasma-workspace/env"
    mkdir -p "$PLASMA_ENV_DIR"
    cat > "$PLASMA_ENV_DIR/99-unset-im-xim.sh" <<'PLASMA_ENV'
#!/bin/sh
# Généré par sddm-video.sh
# Supprime les variables XIM pour éviter l'alerte IBus Wayland.
# Sous Wayland, la saisie IBus se configure via les Paramètres KDE,
# pas via ces variables d'environnement.
unset QT_IM_MODULE
unset GTK_IM_MODULE
unset XMODIFIERS
PLASMA_ENV
    chmod +x "$PLASMA_ENV_DIR/99-unset-im-xim.sh"
    chown -R "$REAL_USER" "$PLASMA_ENV_DIR"
    ok "Script plasma env écrit : $PLASMA_ENV_DIR/99-unset-im-xim.sh"
fi

# Couche 4 — environment.d : pour les sessions systemd-logind pures
mkdir -p /etc/environment.d
cat > "/etc/environment.d/60-no-ibus-xim.conf" <<'ENVEOF'
# Généré par sddm-video.sh
# Désactive les variables XIM — incompatibles avec Wayland input-method-v2
QT_IM_MODULE=
GTK_IM_MODULE=
ENVEOF
chmod 644 "/etc/environment.d/60-no-ibus-xim.conf"
ok "Couverture systemd-logind : /etc/environment.d/60-no-ibus-xim.conf"

# ── Gestion de /etc/sddm.conf
if [[ -f /etc/sddm.conf ]]; then
    # Si /etc/sddm.conf contient un [Theme], il écrase TOUT conf.d — on le neutralise
    if grep -q '^\[Theme\]' /etc/sddm.conf 2>/dev/null; then
        warn "/etc/sddm.conf contient [Theme] — il écrase conf.d, on le sauvegarde"
        mv /etc/sddm.conf /etc/sddm.conf.bak.sddm-video
        ok "Renommé en /etc/sddm.conf.bak.sddm-video (restaurable si besoin)"
    else
        warn "/etc/sddm.conf présent sans [Theme] — laissé intact"
    fi
fi

# Vérification : fichiers de config actifs dans conf.d
echo ""
info "Fichiers de config SDDM actifs dans $CONF_DIR/ :"
ls -1 "$CONF_DIR/" | while read -r f; do echo "    $f"; done

# =============================================================================
#  ÉTAPE 8 — Activation du service SDDM
# =============================================================================
step "8/8" "Activation du service SDDM..."

if systemctl --version &>/dev/null 2>&1; then
    # Désactiver les autres display managers
    for dm in gdm gdm3 lightdm lxdm xdm ly; do
        if systemctl is-enabled "$dm" &>/dev/null 2>&1; then
            info "Désactivation de $dm..."
            systemctl disable "$dm" 2>/dev/null || true
        fi
    done

    systemctl enable sddm
    systemctl set-default graphical.target
    ok "Service SDDM activé au démarrage."
else
    warn "systemd absent — activation manuelle requise."
fi

# =============================================================================
#  RÉSUMÉ FINAL
# =============================================================================
echo ""
echo -e "${CYN}╔═══════════════════════════════════════════════════════╗"
echo -e "║   Installation terminée avec succès !                 ║"
echo -e "╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GRN}Qt version  :${NC} Qt${QT_VERSION}"
echo -e "  ${GRN}Vidéo       :${NC} $FILENAME"
echo -e "  ${GRN}Thème       :${NC} $THEME_DIR"
echo -e "  ${GRN}Config      :${NC} $CONF_FILE"
echo ""
echo -e "  ${CYN}Pour changer la vidéo plus tard :${NC}"
echo -e "    sudo bash sddm-video.sh --change-video"
echo -e "  ${CYN}ou éditez directement :${NC}"
echo -e "    $THEME_DIR/theme.conf  (ligne : background=nomdevideo.mp4)"
echo ""
echo -e "  ${CYN}Pour tester le thème SANS redémarrer :${NC}"
if [[ "$QT_VERSION" == "6" ]]; then
    echo -e "    sddm-greeter-qt6 --test-mode --theme $THEME_DIR"
else
    echo -e "    sddm-greeter --test-mode --theme $THEME_DIR"
fi
echo ""

read -rp "  Redémarrer SDDM maintenant ? [o/N] : " REP
if [[ "$REP" =~ ^[Oo]$ ]]; then
    echo "  Redémarrage de SDDM..."
    systemctl restart sddm
    sleep 2
    STATUS=$(systemctl is-active sddm 2>/dev/null || echo "inconnu")
    echo -e "  État SDDM : ${GRN}${STATUS}${NC}"
fi

echo ""
