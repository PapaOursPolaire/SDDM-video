#!/bin/bash
# =============================================================================
#  sddm-video.sh  v3.1  —  by PapaOursPolaire
#  Thème SDDM avec vidéo en arrière-plan — Qt5/Qt6 — universel
#
#  Distributions supportées :
#    Debian / Ubuntu / Linux Mint / Pop!_OS
#    Arch Linux / Manjaro / EndeavourOS
#    Fedora / RHEL / AlmaLinux / Rocky Linux
#    openSUSE Tumbleweed / Leap
#    Void Linux / Alpine Linux / Gentoo (portage)
#    NixOS (mode impératif)
#    Solus / Clear Linux / Slackware (expérimental)
#
#  Usage :
#    sudo bash sddm-video.sh                # installation complète
#    sudo bash sddm-video.sh --change-video # changer la vidéo uniquement
#         bash sddm-video.sh --diagnose     # diagnostic sans sudo
#         bash sddm-video.sh --uninstall    # désinstallation propre
#
#  CORRECTIFS v3.1 :
#    - Branche corrigée : Projets (était "main")
#    - set -e supprimé pour éviter les sorties prématurées silencieuses
#    - Chemin ZIP corrigé : SDDM-video-Projets/ (était SDDM-video-main/)
#    - Collecte de warnings pour le rapport de log
#    - Génération d'un rapport de log complet en fin d'installation
#    - Vérification des conflits de config avant et après écriture
# =============================================================================

# NOTE : on utilise -uo pipefail sans -e pour éviter qu'une erreur non fatale
# (ex. téléchargement d'un asset optionnel) stoppe l'installation en silence.
# Chaque appel critique utilise || die() explicitement.
set -uo pipefail

# ─── Constantes ───────────────────────────────────────────────────────────────
readonly THEME_NAME="sddm-video"
readonly THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
readonly CONF_DIR="/etc/sddm.conf.d"
# zzz- préfixe garantit la lecture EN DERNIER (ordre alpha), après kde_settings.conf
readonly CONF_FILE="${CONF_DIR}/zzz-sddm-video.conf"
readonly SDDM_CONF_LEGACY="/etc/sddm.conf"
# CORRECTION v3.1 : les trois URLs pointent sur la branche "Projets" (pas "main")
readonly REPO_BRANCH="Projets"
readonly REPO_RAW="https://raw.githubusercontent.com/PapaOursPolaire/SDDM-video/${REPO_BRANCH}"
readonly REPO_LFS="https://media.githubusercontent.com/media/PapaOursPolaire/SDDM-video/${REPO_BRANCH}"
readonly REPO_ZIP="https://github.com/PapaOursPolaire/SDDM-video/archive/refs/heads/${REPO_BRANCH}.zip"
# Nom du dossier dans l'archive ZIP (GitHub nomme le dossier "NomRepo-NomBranche")
readonly REPO_ZIP_DIR="SDDM-video-${REPO_BRANCH}"
readonly SCRIPT_VERSION="3.1"
readonly BACKUP_SUFFIX=".bak.sddm-video"
readonly INSTALL_LOG="/var/log/sddm-video-install.log"

# Variables globales
QT_VERSION=""
PKG_MANAGER=""
VIDEO_PATH=""
FILENAME=""
REAL_USER=""
REAL_HOME=""

# Tableau pour collecter tous les warnings/erreurs pendant l'installation
INSTALL_WARNINGS=()

# ─── Couleurs (désactivées si pas de TTY) ─────────────────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m'; YEL='\033[1;33m'; GRN='\033[0;32m'
    CYN='\033[0;36m'; BLD='\033[1m'; NC='\033[0m'
else
    RED=''; YEL=''; GRN=''; CYN=''; BLD=''; NC=''
fi

info()  { echo -e "  ${CYN}➜${NC}  $*"; }
ok()    { echo -e "  ${GRN}✔${NC}  $*"; }
warn()  {
    echo -e "  ${YEL}⚠${NC}  $*"
    INSTALL_WARNINGS+=("WARN: $*")
}
die()   {
    echo -e "  ${RED}✘${NC}  $*" >&2
    INSTALL_WARNINGS+=("ERREUR FATALE: $*")
    # Tenter de générer le log même en cas d'erreur fatale
    generate_log_report 2>/dev/null || true
    exit 1
}
step()  { echo ""; echo -e "${CYN}[$1]${NC} ${BLD}$2${NC}"; }
banner(){ echo ""; echo -e "${CYN}${1}${NC}"; }

# ─── Résolution de l'utilisateur réel (sous sudo) ─────────────────────────────
resolve_real_user() {
    REAL_USER="${SUDO_USER:-}"
    if [[ -z "$REAL_USER" ]]; then
        REAL_USER=$(logname 2>/dev/null || true)
    fi
    if [[ -z "$REAL_USER" ]] || [[ "$REAL_USER" == "root" ]]; then
        REAL_USER=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' || echo "")
    fi
    if [[ -n "$REAL_USER" ]]; then
        REAL_HOME=$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6 || echo "")
    fi
}

# =============================================================================
#  DÉTECTION DU GESTIONNAIRE DE PAQUETS
# =============================================================================
detect_pkg_manager() {
    if   command -v apt-get  &>/dev/null; then PKG_MANAGER="apt"
    elif command -v pacman   &>/dev/null; then PKG_MANAGER="pacman"
    elif command -v dnf      &>/dev/null; then PKG_MANAGER="dnf"
    elif command -v zypper   &>/dev/null; then PKG_MANAGER="zypper"
    elif command -v xbps-install &>/dev/null; then PKG_MANAGER="xbps"
    elif command -v apk      &>/dev/null; then PKG_MANAGER="apk"
    elif command -v emerge   &>/dev/null; then PKG_MANAGER="portage"
    elif command -v nix-env  &>/dev/null; then PKG_MANAGER="nix"
    elif command -v eopkg    &>/dev/null; then PKG_MANAGER="eopkg"
    elif command -v swupd    &>/dev/null; then PKG_MANAGER="swupd"
    else PKG_MANAGER=""
    fi
}

# Wrapper d'installation générique
pkg_install() {
    local primary=() fallback=() is_fallback=0
    for arg in "$@"; do
        if [[ "$arg" == "--" ]]; then is_fallback=1; continue; fi
        [[ $is_fallback -eq 0 ]] && primary+=("$arg") || fallback+=("$arg")
    done

    local install_ok=0
    case "$PKG_MANAGER" in
        apt)     DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${primary[@]}" 2>/dev/null && install_ok=1 || true ;;
        pacman)  pacman -Sy --noconfirm --needed "${primary[@]}" 2>/dev/null && install_ok=1 || true ;;
        dnf)     dnf install -y "${primary[@]}" 2>/dev/null && install_ok=1 || true ;;
        zypper)  zypper install -y --no-recommends "${primary[@]}" 2>/dev/null && install_ok=1 || true ;;
        xbps)    xbps-install -Sy "${primary[@]}" 2>/dev/null && install_ok=1 || true ;;
        apk)     apk add --no-cache "${primary[@]}" 2>/dev/null && install_ok=1 || true ;;
        portage) emerge --ask=n "${primary[@]}" 2>/dev/null && install_ok=1 || true ;;
        eopkg)   eopkg install -y "${primary[@]}" 2>/dev/null && install_ok=1 || true ;;
        swupd)   swupd bundle-add "${primary[@]}" 2>/dev/null && install_ok=1 || true ;;
        nix)     warn "NixOS : installez manuellement : ${primary[*]}"; return 0 ;;
        "")      warn "Gestionnaire inconnu — installation manuelle requise : ${primary[*]}"; return 0 ;;
    esac

    if [[ $install_ok -eq 0 ]] && [[ ${#fallback[@]} -gt 0 ]]; then
        case "$PKG_MANAGER" in
            apt)     DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${fallback[@]}" 2>/dev/null || true ;;
            pacman)  pacman -Sy --noconfirm --needed "${fallback[@]}" 2>/dev/null || true ;;
            dnf)     dnf install -y "${fallback[@]}" 2>/dev/null || true ;;
            zypper)  zypper install -y --no-recommends "${fallback[@]}" 2>/dev/null || true ;;
            *)       true ;;
        esac
    fi
    return 0
}

# =============================================================================
#  PRE-FLIGHT
# =============================================================================
preflight_checks() {
    local errors=0

    [[ "${BASH_VERSINFO[0]}" -lt 4 ]] && {
        echo -e "  ${RED}✘${NC}  Bash 4.0+ requis (actuel : $BASH_VERSION)" >&2
        (( errors++ )) || true
    }

    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        echo -e "  ${RED}✘${NC}  curl ou wget requis" >&2
        (( errors++ )) || true
    fi

    detect_pkg_manager
    [[ -z "$PKG_MANAGER" ]] && {
        warn "Gestionnaire de paquets non reconnu — installation manuelle des dépendances requise"
    }

    [[ ! -d "/usr/share/sddm" ]] && [[ ! -d "/usr/share" ]] && {
        echo -e "  ${RED}✘${NC}  /usr/share non accessible en écriture" >&2
        (( errors++ )) || true
    }

    [[ $errors -gt 0 ]] && die "$errors problème(s) bloquant(s). Corrigez avant de relancer."
    ok "Pre-flight OK (gestionnaire : ${PKG_MANAGER:-inconnu})"
}

# =============================================================================
#  GÉNÉRATION DU RAPPORT DE LOG COMPLET
# =============================================================================
generate_log_report() {
    # Cette fonction est appelée en fin d'installation (succès ou échec).
    # Elle écrit /var/log/sddm-video-install.log avec toutes les infos utiles.

    # Créer le fichier de log (lisible par root uniquement)
    mkdir -p "$(dirname "$INSTALL_LOG")" 2>/dev/null || true
    : > "$INSTALL_LOG" 2>/dev/null || return 0
    chmod 600 "$INSTALL_LOG" 2>/dev/null || true

    {
        echo "============================================================"
        echo "  SDDM Video v${SCRIPT_VERSION} — Rapport d'installation"
        echo "  Généré le : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Branche repo : ${REPO_BRANCH}"
        echo "============================================================"
        echo ""

        echo "── Système ──────────────────────────────────────────────────"
        echo "OS      : $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo inconnu)"
        echo "Kernel  : $(uname -a 2>/dev/null || echo inconnu)"
        echo "Arch    : $(uname -m 2>/dev/null || echo inconnu)"
        echo "PKG MGR : ${PKG_MANAGER:-inconnu}"
        echo "Qt ver  : ${QT_VERSION:-non détecté}"
        echo "Vidéo   : ${FILENAME:-non définie}"
        echo ""

        echo "── /etc/os-release ──────────────────────────────────────────"
        cat /etc/os-release 2>/dev/null || echo "(absent)"
        echo ""

        echo "── Greeter SDDM trouvé ──────────────────────────────────────"
        find /usr -name "sddm-greeter*" -type f 2>/dev/null || echo "(aucun)"
        echo ""

        echo "── Service SDDM ─────────────────────────────────────────────"
        if command -v systemctl &>/dev/null; then
            echo "is-active  : $(systemctl is-active  sddm 2>/dev/null || echo inconnu)"
            echo "is-enabled : $(systemctl is-enabled sddm 2>/dev/null || echo inconnu)"
        else
            echo "(systemctl absent)"
        fi
        echo ""

        echo "── Fichiers du thème installé ───────────────────────────────"
        if [[ -d "$THEME_DIR" ]]; then
            ls -lah "$THEME_DIR" 2>/dev/null || echo "(ls échoué)"
        else
            echo "DOSSIER ABSENT : $THEME_DIR"
        fi
        echo ""

        echo "── Contenu de theme.conf ────────────────────────────────────"
        cat "${THEME_DIR}/theme.conf" 2>/dev/null || echo "(absent)"
        echo ""

        echo "── Contenu de metadata.desktop ──────────────────────────────"
        cat "${THEME_DIR}/metadata.desktop" 2>/dev/null || echo "(absent)"
        echo ""

        echo "── Contenu de ${CONF_FILE} ──────────────────────────────────"
        cat "$CONF_FILE" 2>/dev/null || echo "(absent)"
        echo ""

        echo "── Tous les .conf dans ${CONF_DIR}/ ─────────────────────────"
        if [[ -d "$CONF_DIR" ]]; then
            for f in "$CONF_DIR"/*.conf; do
                [[ -f "$f" ]] || continue
                echo "--- $(basename "$f") ---"
                cat "$f" 2>/dev/null || true
                echo ""
            done
        else
            echo "(dossier absent)"
        fi

        echo "── /etc/sddm.conf (legacy) ──────────────────────────────────"
        if [[ -f "$SDDM_CONF_LEGACY" ]]; then
            cat "$SDDM_CONF_LEGACY"
        else
            echo "(absent — bien)"
        fi
        echo ""

        echo "── Modules QtMultimedia QML ─────────────────────────────────"
        find /usr/lib /usr/lib64 2>/dev/null -maxdepth 6 -type d -name "QtMultimedia" 2>/dev/null | grep -E 'qml' | head -10 || echo "(aucun trouvé)"
        echo ""

        echo "── Variables d'environnement pertinentes ────────────────────"
        echo "QT_IM_MODULE   : ${QT_IM_MODULE:-<vide>}"
        echo "GTK_IM_MODULE  : ${GTK_IM_MODULE:-<vide>}"
        echo "XMODIFIERS     : ${XMODIFIERS:-<vide>}"
        echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-<vide>}"
        echo "DISPLAY        : ${DISPLAY:-<vide>}"
        echo ""

        echo "── Journalctl SDDM (50 dernières lignes) ────────────────────"
        if command -v journalctl &>/dev/null; then
            journalctl -u sddm -b --no-pager -n 50 2>/dev/null || echo "(journalctl échoué)"
        else
            echo "(journalctl absent)"
            [[ -f /var/log/sddm.log ]] && tail -50 /var/log/sddm.log || true
        fi
        echo ""

        echo "── Warnings et erreurs collectés pendant l'installation ─────"
        if [[ ${#INSTALL_WARNINGS[@]} -eq 0 ]]; then
            echo "(aucun warning)"
        else
            for w in "${INSTALL_WARNINGS[@]}"; do
                echo "  $w"
            done
        fi
        echo ""

        echo "============================================================"
        echo "  Fin du rapport"
        echo "============================================================"
    } >> "$INSTALL_LOG" 2>/dev/null || true

    echo -e "  ${CYN}📋${NC}  Rapport de log complet : ${BLD}${INSTALL_LOG}${NC}"
}

# =============================================================================
#  MODE --diagnose
# =============================================================================
run_diagnose() {
    local SEP="─────────────────────────────────────────────────────────"
    dhead() { echo ""; echo -e "${CYN}${SEP}${NC}"; echo -e "${CYN}  $*${NC}"; echo -e "${CYN}${SEP}${NC}"; }
    dok()   { echo -e "  ${GRN}✔${NC}  $*"; }
    dwarn() { echo -e "  ${YEL}⚠${NC}  $*"; }
    derr()  { echo -e "  ${RED}✘  $*${NC}"; }
    dinfo() { echo -e "  ${CYN}→${NC}  $*"; }

    detect_pkg_manager

    echo ""
    echo -e "${CYN}╔══════════════════════════════════════════════════════╗"
    echo -e "║   SDDM Video v${SCRIPT_VERSION} — Diagnostic                   ║"
    echo -e "╚══════════════════════════════════════════════════════╝${NC}"

    # ── 1. Système ──
    dhead "1. Système"
    dinfo "OS     : $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo inconnu)"
    dinfo "Kernel : $(uname -r)"
    dinfo "Arch   : $(uname -m)"
    dinfo "PKG    : ${PKG_MANAGER:-inconnu}"
    dinfo "Repo   : branche '${REPO_BRANCH}'"
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        dinfo "Session : Wayland (${WAYLAND_DISPLAY})"
    elif [[ -n "${DISPLAY:-}" ]]; then
        dinfo "Session : X11 (${DISPLAY})"
    else
        dwarn "Session : aucune variable graphique (script hors session ?)"
    fi

    # ── 2. SDDM binaire ──
    dhead "2. SDDM — binaire et greeter"
    if command -v sddm &>/dev/null; then
        dok "sddm : $(command -v sddm)"
    else
        derr "sddm introuvable dans PATH"
    fi

    local found_greeter="" found_qt=""
    local greeter_paths_qt6=(
        /usr/bin/sddm-greeter-qt6
        /usr/libexec/sddm-greeter-qt6
        /usr/lib/x86_64-linux-gnu/libexec/sddm-greeter-qt6
        /usr/lib/aarch64-linux-gnu/libexec/sddm-greeter-qt6
        /usr/lib/arm-linux-gnueabihf/libexec/sddm-greeter-qt6
        /usr/lib/sddm/sddm-greeter-qt6
        /usr/lib/libexec/sddm-greeter-qt6
        /usr/lib64/libexec/sddm-greeter-qt6
        /usr/lib/qt6/libexec/sddm-greeter-qt6
    )
    local greeter_paths_qt5=(
        /usr/bin/sddm-greeter
        /usr/bin/sddm-greeter-qt5
        /usr/libexec/sddm-greeter
        /usr/lib/x86_64-linux-gnu/libexec/sddm-greeter
        /usr/lib/aarch64-linux-gnu/libexec/sddm-greeter
        /usr/lib/sddm/sddm-greeter-qt5
        /usr/lib/libexec/sddm-greeter
        /usr/lib64/libexec/sddm-greeter
    )

    for p in "${greeter_paths_qt6[@]}"; do
        [[ -f "$p" ]] && { found_greeter="$p"; found_qt="6"; break; }
    done
    if [[ -z "$found_greeter" ]]; then
        for p in "${greeter_paths_qt5[@]}"; do
            [[ -f "$p" ]] && { found_greeter="$p"; found_qt="5"; break; }
        done
    fi
    if [[ -z "$found_greeter" ]]; then
        found_greeter=$(find /usr -name "sddm-greeter*" -type f 2>/dev/null | head -1 || true)
        [[ -n "$found_greeter" ]] && found_qt="?"
    fi

    if [[ -n "$found_greeter" ]]; then
        dok "Greeter Qt${found_qt} : $found_greeter"
    else
        derr "Aucun greeter sddm trouvé — SDDM ne peut pas afficher de thème"
    fi

    # Service
    if command -v systemctl &>/dev/null; then
        local st en
        st=$(systemctl is-active  sddm 2>/dev/null || echo "inconnu")
        en=$(systemctl is-enabled sddm 2>/dev/null || echo "inconnu")
        [[ "$st" == "active"  ]] && dok  "Service : actif"         || dwarn "Service : $st"
        [[ "$en" == "enabled" ]] && dok  "Démarrage auto : activé" || dwarn "Démarrage auto : $en"
    elif command -v rc-service &>/dev/null; then
        rc-service sddm status &>/dev/null && dok "Service OpenRC : actif" || dwarn "Service OpenRC : inactif"
    elif command -v sv &>/dev/null; then
        sv status sddm &>/dev/null && dok "Service runit : actif" || dwarn "Service runit : inactif"
    fi

    # ── 3. Conflit de configuration ──
    dhead "3. Fichiers de configuration SDDM (ordre alpha)"
    local our_conf_found=0 kde_conf="" wins=1

    echo ""
    dinfo "Fichiers dans ${CONF_DIR}/ :"
    if [[ -d "$CONF_DIR" ]]; then
        while IFS= read -r f; do
            local tl
            tl=$(grep -E '^\s*Current\s*=' "$f" 2>/dev/null | tail -1 || true)
            if [[ -n "$tl" ]]; then
                echo -e "    ${YEL}$(basename "$f")${NC}  ←  $tl"
            else
                echo    "    $(basename "$f")"
            fi
            [[ "$f" == "$CONF_FILE" ]] && our_conf_found=1
            [[ "$(basename "$f")" == "kde_settings.conf" ]] && kde_conf="$f"
        done < <(find "$CONF_DIR" -maxdepth 1 -name "*.conf" 2>/dev/null | sort)
    else
        dwarn "${CONF_DIR}/ absent"
    fi

    if [[ -f "$SDDM_CONF_LEGACY" ]]; then
        local theme_etc
        theme_etc=$(grep -E '^\s*Current\s*=' "$SDDM_CONF_LEGACY" 2>/dev/null | tail -1 || true)
        echo -e "    ${RED}/etc/sddm.conf${NC}  (PRIORITÉ ABSOLUE)  ←  ${theme_etc:-aucun Current=}"
        wins=0
    fi

    echo ""
    if [[ $our_conf_found -eq 0 ]]; then
        derr "Notre config ${CONF_FILE} est ABSENTE → thème non appliqué"
        dinfo "Correction : sudo bash sddm-video.sh"
    else
        if [[ -n "$kde_conf" ]]; then
            local our_base kde_base
            our_base=$(basename "$CONF_FILE"); kde_base=$(basename "$kde_conf")
            if [[ "$our_base" > "$kde_base" ]]; then
                dok "'$our_base' sort après '$kde_base' → notre config gagne ✓"
            else
                derr "CONFLIT : '$kde_base' écrase notre thème (ordre alpha)"
                dinfo "Correction : sudo bash sddm-video.sh (renomme en zzz-)"
            fi
        fi
        [[ $wins -eq 0 ]] && derr "/etc/sddm.conf présent → écrase tout conf.d/" || dok "Pas de /etc/sddm.conf conflictuel"
    fi

    # ── 4. Thème installé ──
    dhead "4. Thème sddm-video — fichiers"
    if [[ ! -d "$THEME_DIR" ]]; then
        derr "Dossier absent : $THEME_DIR"
        dinfo "Correction : sudo bash sddm-video.sh"
    else
        dok "Dossier thème : $THEME_DIR"
        echo ""
        local -A expected=(
            ["Main.qml"]="QML principal"
            ["theme.conf"]="config vidéo"
            ["metadata.desktop"]="identifiant thème"
            ["loginterminalc.png"]="image panneau"
        )
        for fname in "${!expected[@]}"; do
            if [[ -f "$THEME_DIR/$fname" ]]; then
                local sz; sz=$(du -h "$THEME_DIR/$fname" | cut -f1)
                if head -c 50 "$THEME_DIR/$fname" 2>/dev/null | grep -q "git-lfs"; then
                    derr "$fname ($sz) — POINTEUR LFS, pas le vrai fichier !"
                else
                    dok "$fname ($sz)"
                fi
            else
                derr "$fname ABSENT — ${expected[$fname]}"
            fi
        done

        if [[ -f "$THEME_DIR/angle-down.png" ]]; then
            ok "angle-down.png présent dans le thème"
        else
            local sddm_arrow
            sddm_arrow=$(find /usr/lib -name "angle-down.png" 2>/dev/null | head -1 || true)
            if [[ -n "$sddm_arrow" ]]; then
                dok "angle-down.png trouvé dans SddmComponents : $sddm_arrow"
                dinfo "Le warning dans les logs est cosmétique"
            else
                dwarn "angle-down.png absent (avertissement cosmétique dans les logs)"
            fi
        fi

        echo ""
        if [[ -f "$THEME_DIR/theme.conf" ]]; then
            local bg; bg=$(grep -E '^\s*background\s*=' "$THEME_DIR/theme.conf" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]' || true)
            if [[ -n "$bg" ]]; then
                if [[ -f "$THEME_DIR/$bg" ]]; then
                    local vsz; vsz=$(du -h "$THEME_DIR/$bg" | cut -f1)
                    if head -c 50 "$THEME_DIR/$bg" 2>/dev/null | grep -q "git-lfs"; then
                        derr "Vidéo '$bg' ($vsz) — POINTEUR LFS !"
                    else
                        dok "Vidéo '$bg' présente ($vsz)"
                    fi
                else
                    derr "Vidéo '$bg' déclarée mais ABSENTE"
                    dinfo "Correction : sudo bash sddm-video.sh --change-video"
                fi
            else
                dwarn "Aucune entrée background= dans theme.conf"
            fi
        fi

        if [[ -f "$THEME_DIR/metadata.desktop" ]]; then
            local pname; pname=$(grep -i 'X-KDE-PluginInfo-Name' "$THEME_DIR/metadata.desktop" 2>/dev/null | cut -d= -f2- | tr -d ' ' || true)
            if [[ "$pname" == "$THEME_NAME" ]]; then
                dok "X-KDE-PluginInfo-Name='$pname' ✓"
            else
                derr "X-KDE-PluginInfo-Name='$pname' ≠ '$THEME_NAME' → SDDM ignorera ce thème"
            fi
        fi
    fi

    # ── 5. QtMultimedia ──
    dhead "5. QtMultimedia — modules QML"
    local qt_found=0
    while IFS= read -r qml_path; do
        [[ -d "$qml_path" ]] && { dok "Module QML : $qml_path"; qt_found=1; }
    done < <(find /usr/lib /usr/lib64 2>/dev/null -maxdepth 6 -type d -name "QtMultimedia" 2>/dev/null | grep -E 'qml' | head -5 || true)

    [[ $qt_found -eq 0 ]] && {
        derr "Aucun module QtMultimedia QML trouvé → fond noir ou vidéo muette"
        dinfo "apt    : sudo apt install qml6-module-qtmultimedia"
        dinfo "pacman : sudo pacman -S qt6-multimedia"
        dinfo "dnf    : sudo dnf install qt6-qtmultimedia"
    }

    # ── 6. GStreamer et FFmpeg backend ──
    dhead "6. Décodeurs vidéo (GStreamer / FFmpeg)"

    if command -v gst-inspect-1.0 &>/dev/null; then
        dok "gst-inspect-1.0 disponible"
        for plugin in avdec_h264 avdec_h265 vp8dec vp9dec; do
            gst-inspect-1.0 "$plugin" &>/dev/null 2>&1 && dok "  codec : $plugin" || dwarn "  codec absent : $plugin"
        done
    else
        dwarn "gst-inspect-1.0 absent — GStreamer peut manquer"
    fi

    # ── 7. Détection VAAPI ──
    dhead "7. Accélération matérielle VAAPI"
    if command -v vainfo &>/dev/null; then
        if vainfo &>/dev/null 2>&1; then
            dok "VAAPI opérationnel : $(vainfo 2>/dev/null | grep 'Driver version' | head -1 | xargs || echo 'OK')"
        else
            dwarn "VAAPI présent mais non fonctionnel"
            dinfo "GPU Intel : sudo apt install intel-media-va-driver"
            dinfo "GPU AMD   : sudo apt install mesa-va-drivers"
            dinfo "GPU NVIDIA: sudo apt install libva-nvidia-driver (si disponible)"
            dinfo ""
            dinfo "IMPORTANT : les erreurs VAAPI dans les logs sddm-greeter-qt6 sont"
            dinfo "souvent BÉNIGNES — QtMultimedia se rabat automatiquement sur le"
            dinfo "décodage logiciel (CPU). La vidéo peut tout de même s'afficher."
        fi
    else
        dwarn "vainfo absent — impossible de diagnostiquer VAAPI"
        dinfo "sudo apt install vainfo  /  sudo pacman -S libva-utils"
    fi

    # ── 8. IBus ──
    dhead "8. IBus / QT_IM_MODULE"
    local ibus_found=0
    local -a files_to_check=(
        /etc/environment
        /etc/profile
        /etc/profile.d/ibus.sh
        /etc/profile.d/im-config.sh
        /usr/share/im-config/data/ibus.conf
        "${REAL_HOME:-/root}/.pam_environment"
        "${REAL_HOME:-/root}/.profile"
        "${REAL_HOME:-/root}/.xprofile"
        "${REAL_HOME:-/root}/.config/plasma-workspace/env/ibus.sh"
        "${REAL_HOME:-/root}/.config/environment.d/ibus.conf"
        "$SDDM_CONF_LEGACY"
    )
    for f in "${CONF_DIR}"/*.conf; do [[ -f "$f" ]] && files_to_check+=("$f"); done
    for f in /etc/environment.d/*.conf; do [[ -f "$f" ]] && files_to_check+=("$f"); done

    for f in "${files_to_check[@]}"; do
        [[ -f "$f" ]] || continue
        if grep -qE 'QT_IM_MODULE|GTK_IM_MODULE' "$f" 2>/dev/null; then
            dwarn "Trouvé dans : $f"
            grep -nE 'QT_IM_MODULE|GTK_IM_MODULE' "$f" | while IFS= read -r m; do echo "       $m"; done
            ibus_found=1
        fi
    done
    [[ $ibus_found -eq 0 ]] && dok "Aucune variable IBus dans les fichiers statiques"

    for var in QT_IM_MODULE GTK_IM_MODULE XMODIFIERS; do
        local val="${!var:-}"
        [[ -n "$val" ]] && dwarn "$var=$val (env courant)" || dok "$var non définie"
    done

    # ── 9. Logs SDDM ──
    dhead "9. Logs SDDM récents"
    if command -v journalctl &>/dev/null; then
        journalctl -u sddm -b --no-pager -n 40 2>/dev/null | while IFS= read -r line; do
            if echo "$line" | grep -qiE 'error|fail|crash|fatal'; then
                echo -e "  ${RED}$line${NC}"
            elif echo "$line" | grep -qiE 'warn|ibus|im_module|theme|Current|vaapi|vdpau'; then
                echo -e "  ${YEL}$line${NC}"
            else
                echo    "  $line"
            fi
        done
    else
        dwarn "journalctl absent — consultez /var/log/sddm.log ou /var/log/messages"
        [[ -f /var/log/sddm.log ]] && tail -30 /var/log/sddm.log || true
    fi

    # ── 10. Conseil VAAPI ──
    dhead "10. Résumé VAAPI / décodage H.264"
    dinfo "Les erreurs 'Failed to upload decode parameters' / 'hardware accelerator"
    dinfo "failed to decode picture' sont des AVERTISSEMENTS de fallback FFmpeg."
    dinfo "QtMultimedia tente VAAPI, échoue, puis décode en logiciel (CPU)."
    dinfo "La vidéo s'affiche quand même SAUF si aucun décodeur logiciel H.264 n'est"
    dinfo "disponible. Pour forcer le soft-decoding dès le départ, créez :"
    dinfo "  /etc/sddm.conf.d/zzz-vaapi-disable.conf"
    echo ""
    dinfo "Pour désactiver complètement VAAPI pour SDDM :"
    echo "    sudo mkdir -p /etc/sddm.conf.d"
    echo "    echo '[General]' | sudo tee /etc/sddm.conf.d/zzz-novaapi.conf"
    echo "    echo 'EnvironmentFile=/etc/sddm-env' | sudo tee -a /etc/sddm.conf.d/zzz-novaapi.conf"
    echo "    echo 'LIBVA_DRIVER_NAME=' | sudo tee /etc/sddm-env"
    echo ""

    # ── 11. Rapport de log ──
    dhead "11. Rapport de log complet"
    if [[ -f "$INSTALL_LOG" ]]; then
        dinfo "Dernier rapport disponible : $INSTALL_LOG"
        dinfo "Taille : $(du -h "$INSTALL_LOG" | cut -f1)"
    else
        dwarn "Aucun rapport de log trouvé (lancez l'installation complète d'abord)"
    fi

    exit 0
}

if [[ "${1:-}" == "--diagnose" ]]; then
    resolve_real_user
    run_diagnose
fi

# =============================================================================
#  MODE --uninstall
# =============================================================================
run_uninstall() {
    [[ $EUID -ne 0 ]] && die "sudo requis pour désinstaller."
    warn "Désinstallation du thème sddm-video..."

    rm -rf "$THEME_DIR"
    rm -f  "$CONF_FILE"
    rm -f  "/etc/environment.d/60-no-ibus-xim.conf"

    if [[ -f "${SDDM_CONF_LEGACY}${BACKUP_SUFFIX}" ]] && [[ ! -f "$SDDM_CONF_LEGACY" ]]; then
        mv "${SDDM_CONF_LEGACY}${BACKUP_SUFFIX}" "$SDDM_CONF_LEGACY"
        ok "/etc/sddm.conf restauré depuis la sauvegarde"
    fi

    if [[ -f /tmp/sddm-video-prev-dm ]]; then
        local prev_dm; prev_dm=$(cat /tmp/sddm-video-prev-dm)
        command -v systemctl &>/dev/null && systemctl enable "$prev_dm" 2>/dev/null && \
            ok "DM précédent réactivé : $prev_dm" || true
        rm -f /tmp/sddm-video-prev-dm
    fi

    ok "Désinstallation terminée. Redémarrez SDDM : sudo systemctl restart sddm"
    exit 0
}

if [[ "${1:-}" == "--uninstall" ]]; then run_uninstall; fi

# =============================================================================
#  VÉRIFICATION ROOT
# =============================================================================
[[ $EUID -ne 0 ]] && die "sudo requis : sudo bash $0  (ou --diagnose sans sudo)"

resolve_real_user
detect_pkg_manager
preflight_checks

# ─── Bannière ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYN}╔═══════════════════════════════════════════════════════╗"
echo -e "║   SDDM Video Background  v${SCRIPT_VERSION}  —  PapaOursPolaire  ║"
echo -e "╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
info "Branche repo : ${REPO_BRANCH}"
echo ""

# =============================================================================
#  TÉLÉCHARGEMENT VIDÉO PAR DÉFAUT
# =============================================================================
download_default_video() {
    local default_name="default.mp4"
    local default_dest="/tmp/sddm-video-default-$$.mp4"

    info "Téléchargement de la vidéo par défaut depuis le dépôt (branche ${REPO_BRANCH})..."
    local success=1

    if command -v curl &>/dev/null; then
        curl -fL --max-time 300 --progress-bar \
            "${REPO_LFS}/${default_name}" -o "$default_dest" 2>&1 && success=0 || true
    elif command -v wget &>/dev/null; then
        wget --timeout=300 --show-progress -q \
            "${REPO_LFS}/${default_name}" -O "$default_dest" 2>&1 && success=0 || true
    fi

    if [[ $success -eq 0 ]] && [[ -s "$default_dest" ]]; then
        if head -c 50 "$default_dest" 2>/dev/null | grep -q "git-lfs"; then
            rm -f "$default_dest"
            die "Pointeur LFS reçu au lieu du binaire. Vérifiez que Git LFS est actif sur le dépôt."
        fi
        VIDEO_PATH="$default_dest"
        ok "Vidéo par défaut téléchargée : $(du -h "$default_dest" | cut -f1)"
    else
        rm -f "$default_dest" 2>/dev/null || true
        die "Téléchargement échoué. Vérifiez votre connexion internet."
    fi
}

# =============================================================================
#  SÉLECTION DE LA VIDÉO
# =============================================================================
select_video() {
    VIDEO_PATH=""
    local dialog_user="${REAL_USER:-${SUDO_USER:-$USER}}"
    local has_display=0
    [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && has_display=1

    echo -e "  ${CYN}Appuyez sur Entrée / Annulez le sélecteur pour utiliser la vidéo par défaut (default.mp4).${NC}"
    echo ""

    if [[ $has_display -eq 1 ]]; then
        if command -v kdialog &>/dev/null; then
            info "Sélecteur graphique : kdialog"
            VIDEO_PATH=$(sudo -u "$dialog_user" kdialog \
                --getopenfilename "${REAL_HOME:-$HOME}" \
                "*.mp4 *.webm *.avi *.mkv *.mov *.gif" \
                --title "Sélectionnez votre vidéo — Annulez pour default.mp4" \
                2>/dev/null) || VIDEO_PATH=""
        fi
        if [[ -z "$VIDEO_PATH" ]] && command -v zenity &>/dev/null; then
            info "Sélecteur graphique : zenity"
            VIDEO_PATH=$(sudo -u "$dialog_user" zenity \
                --file-selection \
                --title="Sélectionnez votre vidéo" \
                --file-filter="Vidéos | *.mp4 *.webm *.avi *.mkv *.mov *.gif" \
                2>/dev/null) || VIDEO_PATH=""
        fi
        if [[ -z "$VIDEO_PATH" ]] && command -v yad &>/dev/null; then
            info "Sélecteur graphique : yad"
            VIDEO_PATH=$(sudo -u "$dialog_user" yad \
                --file --title="Sélectionnez votre vidéo" \
                2>/dev/null) || VIDEO_PATH=""
        fi
    fi

    if [[ -z "$VIDEO_PATH" ]]; then
        echo -e "  Chemin vers votre vidéo (laisser vide = default.mp4) :"
        read -rp "  → " VIDEO_PATH || VIDEO_PATH=""
    fi

    VIDEO_PATH="${VIDEO_PATH%$'\n'}"
    VIDEO_PATH=$(echo "$VIDEO_PATH" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")

    if [[ -z "$VIDEO_PATH" ]]; then
        info "Aucune vidéo choisie → téléchargement de default.mp4"
        download_default_video
        return
    fi

    [[ ! -f "$VIDEO_PATH" ]] && die "Fichier introuvable : '$VIDEO_PATH'"

    local ext="${VIDEO_PATH##*.}"
    ext="${ext,,}"
    case "$ext" in
        mp4|webm|avi|mkv|mov|gif) ;;
        *) die "Format '$ext' non supporté. Formats acceptés : mp4, webm, avi, mkv, mov, gif" ;;
    esac

    ok "Vidéo sélectionnée : $(basename "$VIDEO_PATH") ($ext)"
}

# =============================================================================
#  INSTALLATION DE LA VIDÉO
# =============================================================================
install_video() {
    FILENAME=$(basename "$VIDEO_PATH" | tr ' ' '_' | tr -cd '[:alnum:]._-')
    local dest="${THEME_DIR}/${FILENAME}"

    if [[ -f "${THEME_DIR}/theme.conf" ]]; then
        local old_bg
        old_bg=$(grep -E '^background=' "${THEME_DIR}/theme.conf" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]' || true)
        if [[ -n "$old_bg" && "$old_bg" != "$FILENAME" && -f "${THEME_DIR}/${old_bg}" ]]; then
            info "Suppression ancienne vidéo : $old_bg"
            rm -f "${THEME_DIR}/${old_bg}" || true
        fi
    fi

    if [[ "$VIDEO_PATH" == /tmp/* ]]; then
        mv "$VIDEO_PATH" "$dest" || die "Impossible de déplacer la vidéo vers $dest"
    else
        cp "$VIDEO_PATH" "$dest" || die "Impossible de copier la vidéo vers $dest"
    fi
    chmod 644 "$dest"
    ok "Vidéo installée : $FILENAME"

    if [[ -f "${THEME_DIR}/theme.conf" ]]; then
        sed -i "s|^background=.*|background=${FILENAME}|" "${THEME_DIR}/theme.conf"
    else
        printf '[General]\nbackground=%s\n' "$FILENAME" > "${THEME_DIR}/theme.conf"
    fi
    ok "theme.conf → background=${FILENAME}"
}

# =============================================================================
#  TÉLÉCHARGEMENT ASSETS
# =============================================================================
_is_lfs_pointer() {
    local f="$1"
    local sz; sz=$(wc -c < "$f" 2>/dev/null || echo 0)
    [[ $sz -lt 500 ]] && head -c 80 "$f" 2>/dev/null | grep -q "git-lfs"
}

download_asset() {
    local asset="$1"
    local dest="${THEME_DIR}/${asset}"
    local success=1
    local tried_urls=""

    # Essai 1 : raw GitHub (branche Projets)
    local url1="${REPO_RAW}/${asset}"
    tried_urls="${tried_urls}  - RAW  : ${url1}\n"
    if command -v curl &>/dev/null; then
        curl -fsSL --max-time 20 "$url1" -o "$dest" 2>/dev/null && success=0 || true
    elif command -v wget &>/dev/null; then
        wget -q --timeout=20 "$url1" -O "$dest" 2>/dev/null && success=0 || true
    fi
    if [[ $success -eq 0 ]] && _is_lfs_pointer "$dest"; then
        rm -f "$dest"; success=1
        tried_urls="${tried_urls}    → pointeur LFS reçu, essai suivant\n"
    fi

    # Essai 2 : media LFS (branche Projets)
    if [[ $success -ne 0 ]]; then
        local url2="${REPO_LFS}/${asset}"
        tried_urls="${tried_urls}  - LFS  : ${url2}\n"
        if command -v curl &>/dev/null; then
            curl -fsSL --max-time 30 "$url2" -o "$dest" 2>/dev/null && success=0 || true
        elif command -v wget &>/dev/null; then
            wget -q --timeout=30 "$url2" -O "$dest" 2>/dev/null && success=0 || true
        fi
        if [[ $success -eq 0 ]] && _is_lfs_pointer "$dest"; then
            rm -f "$dest"; success=1
            tried_urls="${tried_urls}    → pointeur LFS reçu, essai suivant\n"
        fi
    fi

    # Essai 3 : archive ZIP complète (branche Projets)
    # CORRECTION v3.1 : le dossier dans le ZIP est SDDM-video-Projets/ et non SDDM-video-main/
    if [[ $success -ne 0 ]]; then
        local zip_tmp="/tmp/sddm-video-repo-$$.zip"
        local zip_dir="/tmp/sddm-video-repo-$$"
        local zip_ok=1
        tried_urls="${tried_urls}  - ZIP  : ${REPO_ZIP}  (dossier interne: ${REPO_ZIP_DIR}/)\n"
        if command -v curl &>/dev/null; then
            curl -fsSL --max-time 120 "$REPO_ZIP" -o "$zip_tmp" 2>/dev/null && zip_ok=0 || true
        elif command -v wget &>/dev/null; then
            wget -q --timeout=120 "$REPO_ZIP" -O "$zip_tmp" 2>/dev/null && zip_ok=0 || true
        fi
        if [[ $zip_ok -eq 0 ]] && [[ -s "$zip_tmp" ]]; then
            if command -v unzip &>/dev/null; then
                mkdir -p "$zip_dir"
                # CORRECTION v3.1 : utiliser REPO_ZIP_DIR (SDDM-video-Projets)
                unzip -q "$zip_tmp" "${REPO_ZIP_DIR}/${asset}" -d "$zip_dir" 2>/dev/null || true
                if [[ -f "${zip_dir}/${REPO_ZIP_DIR}/${asset}" ]]; then
                    mv "${zip_dir}/${REPO_ZIP_DIR}/${asset}" "$dest" && success=0 || true
                fi
                rm -rf "$zip_dir" 2>/dev/null || true
            elif command -v python3 &>/dev/null; then
                python3 - "$zip_tmp" "${REPO_ZIP_DIR}/${asset}" "$dest" <<'PYEOF' 2>/dev/null && success=0 || true
import sys, zipfile, shutil
zip_path, inner_name, dest_path = sys.argv[1], sys.argv[2], sys.argv[3]
with zipfile.ZipFile(zip_path) as z:
    if inner_name in z.namelist():
        with z.open(inner_name) as src, open(dest_path, 'wb') as dst:
            shutil.copyfileobj(src, dst)
    else:
        # Chercher l'asset sans tenir compte du dossier racine (robustesse)
        matches = [n for n in z.namelist() if n.endswith('/' + inner_name.split('/')[-1])]
        if matches:
            with z.open(matches[0]) as src, open(dest_path, 'wb') as dst:
                shutil.copyfileobj(src, dst)
        else:
            sys.exit(1)
PYEOF
            fi
        fi
        rm -f "$zip_tmp" 2>/dev/null || true
        rm -rf "$zip_dir" 2>/dev/null || true
    fi

    if [[ $success -eq 0 ]] && [[ -s "$dest" ]]; then
        chmod 644 "$dest"
        ok "Téléchargé : $asset ($(du -h "$dest" | cut -f1))"
        INSTALL_WARNINGS+=("INFO: asset '$asset' téléchargé avec succès depuis la branche ${REPO_BRANCH}")
        return 0
    else
        rm -f "$dest" 2>/dev/null || true
        warn "Impossible de télécharger '$asset' depuis la branche '${REPO_BRANCH}'. URLs tentées :"
        echo -e "$tried_urls"
        INSTALL_WARNINGS+=("WARN: échec téléchargement '$asset' — branche ${REPO_BRANCH} — URLs: $(echo -e "$tried_urls" | tr '\n' ' ')")
        return 1
    fi
}

# =============================================================================
#  GÉNÉRATION PNG FALLBACK
# =============================================================================
generate_fallback_png() {
    local asset="$1"
    local dest="${THEME_DIR}/${asset}"

    python3 - "$dest" "$asset" <<'PYEOF'
import sys, struct, zlib

dest = sys.argv[1]
asset = sys.argv[2] if len(sys.argv) > 2 else ""

def mk_chunk(tag, data):
    raw = tag + data
    return struct.pack('>I', len(data)) + raw + struct.pack('>I', zlib.crc32(raw) & 0xffffffff)

if "angle-down" in asset:
    W, H = 20, 12
    def px(x, y, W, H):
        mid = W // 2
        if y < H and abs(x - mid) <= y:
            return (200, 200, 200, 230)
        return (0, 0, 0, 0)
else:
    W, H = 400, 300
    def px(x, y, W, H):
        r = int(20 + (x / W) * 15)
        g = int(20 + (y / H) * 10)
        b = 30
        a = int(180 + (x / W) * 50)
        if (5 < x < W-5 and 5 < y < H-5) and not (8 < x < W-8 and 8 < y < H-8):
            return (100, 200, 100, 200)
        return (r, g, b, a)

rows = b""
for y in range(H):
    row = b"\x00"
    for x in range(W):
        pixel = px(x, y, W, H)
        row += bytes([pixel[0], pixel[1], pixel[2], pixel[3]])
    rows += row
idat = zlib.compress(rows, 9)
png = (b"\x89PNG\r\n\x1a\n"
       + mk_chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0))
       + mk_chunk(b"IDAT", idat)
       + mk_chunk(b"IEND", b""))
with open(dest, "wb") as f:
    f.write(png)
PYEOF
    if [[ -s "$dest" ]]; then
        ok "PNG fallback généré : $asset"
        INSTALL_WARNINGS+=("WARN: '$asset' généré en fallback (non récupéré depuis le repo)")
    else
        warn "Génération PNG échouée pour $asset"
        INSTALL_WARNINGS+=("ERREUR: impossible de générer le PNG fallback pour '$asset'")
    fi
}

# =============================================================================
#  REDÉMARRAGE SDDM (défini tôt pour usage dans --change-video)
# =============================================================================
_restart_sddm() {
    if command -v systemctl &>/dev/null; then
        systemctl restart sddm 2>/dev/null && \
            ok "SDDM redémarré ($(systemctl is-active sddm 2>/dev/null || echo 'état inconnu'))" || \
            warn "Redémarrage SDDM échoué — faites-le manuellement"
    elif command -v rc-service &>/dev/null; then
        rc-service sddm restart 2>/dev/null && ok "SDDM redémarré (OpenRC)" || \
            warn "Redémarrage OpenRC échoué"
    elif command -v sv &>/dev/null; then
        sv restart /var/service/sddm 2>/dev/null && ok "SDDM redémarré (runit)" || \
            warn "Redémarrage runit échoué"
    else
        warn "Impossible de redémarrer SDDM automatiquement — faites-le manuellement"
    fi
}

# =============================================================================
#  MODE --change-video
# =============================================================================
if [[ "${1:-}" == "--change-video" ]]; then
    echo -e "${CYN}  Mode : changement de vidéo uniquement${NC}"
    [[ ! -d "$THEME_DIR" ]] && die "Thème non installé. Lancez d'abord l'installation complète."
    select_video
    install_video
    echo ""
    ok "Vidéo mise à jour."
    read -rp "  Redémarrer SDDM maintenant ? [o/N] : " REP || REP=""
    if [[ "$REP" =~ ^[Oo]$ ]]; then
        _restart_sddm
    fi
    exit 0
fi

# =============================================================================
#  ÉTAPE 1 — Nettoyage
# =============================================================================
step "1/8" "Nettoyage des installations précédentes..."

if [[ -f "$SDDM_CONF_LEGACY" ]]; then
    if grep -q '^\[Theme\]' "$SDDM_CONF_LEGACY" 2>/dev/null; then
        warn "/etc/sddm.conf contient [Theme] — sauvegarde en ${SDDM_CONF_LEGACY}${BACKUP_SUFFIX}"
        [[ -f "${SDDM_CONF_LEGACY}${BACKUP_SUFFIX}" ]] || \
            cp "$SDDM_CONF_LEGACY" "${SDDM_CONF_LEGACY}${BACKUP_SUFFIX}" || true
        grep -v '^\[Theme\]' "$SDDM_CONF_LEGACY" | \
            sed '/^\s*Current\s*=/d' > "${SDDM_CONF_LEGACY}.tmp" && \
            mv "${SDDM_CONF_LEGACY}.tmp" "$SDDM_CONF_LEGACY" || true
        ok "Section [Theme] retirée de /etc/sddm.conf (original sauvegardé)"
    else
        info "/etc/sddm.conf présent sans [Theme] — laissé intact"
    fi
fi

for old_conf in \
    "${CONF_DIR}/sddm-video.conf" \
    "${CONF_DIR}/zzz-sddm-video.conf"
do
    [[ -f "$old_conf" ]] && { rm -f "$old_conf" && info "Supprimé : $old_conf"; } || true
done

for t in video-bg sddm-video video custom; do
    [[ -d "/usr/share/sddm/themes/$t" ]] && {
        rm -rf "/usr/share/sddm/themes/$t"
        info "Ancien thème supprimé : $t"
    } || true
done

ok "Nettoyage terminé."

# =============================================================================
#  ÉTAPE 2 — Installation SDDM
# =============================================================================
step "2/8" "Installation de SDDM..."

case "$PKG_MANAGER" in
    apt)
        apt-get update -qq || true
        DEBIAN_FRONTEND=noninteractive apt-get install -y sddm unzip 2>/dev/null || \
        DEBIAN_FRONTEND=noninteractive apt-get install -y sddm 2>/dev/null || true
        ;;
    pacman)
        pacman -Sy --noconfirm --needed sddm unzip || true ;;
    dnf)
        dnf install -y sddm unzip || true ;;
    zypper)
        zypper install -y sddm unzip || true ;;
    xbps)
        xbps-install -Sy sddm unzip || true ;;
    apk)
        apk add --no-cache sddm unzip || true ;;
    portage)
        emerge --ask=n x11-misc/sddm app-arch/unzip 2>/dev/null || true ;;
    eopkg)
        eopkg install -y sddm unzip 2>/dev/null || true ;;
    swupd)
        swupd bundle-add sddm 2>/dev/null || true ;;
    nix)
        warn "NixOS : ajoutez services.xserver.displayManager.sddm.enable = true dans configuration.nix" ;;
    "")
        warn "Gestionnaire inconnu — installez SDDM manuellement" ;;
esac

command -v sddm &>/dev/null || die "SDDM toujours absent après installation."
ok "SDDM installé : $(command -v sddm)"

# =============================================================================
#  ÉTAPE 3 — Détection Qt
# =============================================================================
step "3/8" "Détection de la version Qt du greeter SDDM..."

_find_greeter() {
    local name="$1"
    local paths=(
        /usr/bin/$name
        /usr/libexec/$name
        /usr/lib/sddm/$name
        /usr/lib/libexec/$name
        /usr/lib64/libexec/$name
        /usr/lib/qt6/libexec/$name
    )
    for mdir in /usr/lib/*-linux-gnu*/libexec /usr/lib/*-linux-*/libexec; do
        [[ -d "$mdir" ]] && paths+=("${mdir}/${name}")
    done
    for p in "${paths[@]}"; do
        [[ -f "$p" ]] && { echo "$p"; return 0; }
    done
    find /usr /opt 2>/dev/null -name "$name" -type f 2>/dev/null | head -1 || true
    return 0
}

for greeter_name in sddm-greeter-qt6 sddm-greeter-qt5 sddm-greeter; do
    p=$(_find_greeter "$greeter_name")
    if [[ -n "$p" ]]; then
        case "$greeter_name" in
            *qt6*) QT_VERSION="6" ;;
            *qt5*) QT_VERSION="5" ;;
            *)
                if ldd "$p" 2>/dev/null | grep -q 'libQt6'; then QT_VERSION="6"
                elif ldd "$p" 2>/dev/null | grep -q 'libQt5'; then QT_VERSION="5"
                else QT_VERSION="6"
                fi ;;
        esac
        ok "Greeter Qt${QT_VERSION} : $p"
        break
    fi
done

if [[ -z "$QT_VERSION" ]]; then
    case "$PKG_MANAGER" in
        apt)
            dpkg -l sddm-greeter-qt6 2>/dev/null | grep -q "^ii" && QT_VERSION="6" || true
            [[ -z "$QT_VERSION" ]] && dpkg -l sddm-greeter 2>/dev/null | grep -q "^ii" && QT_VERSION="5" || true
            ;;
        pacman|xbps|apk) QT_VERSION="6" ;;
        dnf)
            rpm -q sddm-qt6 &>/dev/null && QT_VERSION="6" || QT_VERSION="5" ;;
        zypper)
            rpm -q libsddm-qt6 &>/dev/null && QT_VERSION="6" || QT_VERSION="5" ;;
        portage)
            equery uses sddm 2>/dev/null | grep -q 'qt6' && QT_VERSION="6" || QT_VERSION="5" ;;
    esac
fi

if [[ -z "$QT_VERSION" ]] && [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    case "${VERSION_CODENAME:-}${VERSION_ID:-}${ID:-}" in
        trixie|forky|noble|*24.04*|*25.04*|*38*|*39*|*40*|*41*|*42*|arch|manjaro|endeavouros|opensuse-tumbleweed)
            QT_VERSION="6" ;;
        bookworm|jammy|*22.04*|*20.04*|bullseye|buster|*36*|*37*|opensuse-leap)
            QT_VERSION="5" ;;
        *)  QT_VERSION="6" ;;
    esac
    info "Qt déduit via /etc/os-release (${PRETTY_NAME:-}) : Qt${QT_VERSION}"
fi

[[ -z "$QT_VERSION" ]] && { QT_VERSION="6"; warn "Qt non détecté — Qt6 assumé"; }
ok "Qt version retenue : Qt${QT_VERSION}"

# =============================================================================
#  ÉTAPE 4 — Dépendances QtMultimedia + décodeurs
# =============================================================================
step "4/8" "Installation des dépendances QtMultimedia / GStreamer..."

install_multimedia_deps() {
    case "$PKG_MANAGER" in
        apt)
            if [[ "$QT_VERSION" == "6" ]]; then
                pkg_install qml6-module-qtmultimedia qml6-module-qtquick-controls -- \
                            qml6-module-qtmultimedia
            else
                pkg_install qml-module-qtmultimedia qml-module-qtquick-controls2
            fi
            pkg_install \
                gstreamer1.0-plugins-good \
                gstreamer1.0-plugins-bad \
                gstreamer1.0-plugins-ugly \
                gstreamer1.0-libav \
                gstreamer1.0-tools \
                -- \
                gstreamer1.0-plugins-good \
                gstreamer1.0-libav
            pkg_install mesa-va-drivers -- libva2 || true
            pkg_install libva-drm2 || true
            ;;
        pacman)
            if [[ "$QT_VERSION" == "6" ]]; then
                pkg_install qt6-multimedia
            else
                pkg_install qt5-multimedia
            fi
            pkg_install \
                gst-libav \
                gst-plugins-good \
                gst-plugins-bad \
                gst-plugins-ugly \
                libva-mesa-driver
            ;;
        dnf)
            if [[ "$QT_VERSION" == "6" ]]; then
                pkg_install qt6-qtmultimedia
            else
                pkg_install qt5-qtmultimedia
            fi
            pkg_install \
                gstreamer1-plugins-good \
                gstreamer1-plugins-bad-free \
                gstreamer1-libav \
                -- \
                gstreamer1-plugins-good
            pkg_install mesa-va-drivers libva || true
            ;;
        zypper)
            if [[ "$QT_VERSION" == "6" ]]; then
                pkg_install libQt6Multimedia6 qml6-module-qtmultimedia
            else
                pkg_install libQt5Multimedia5 qml-module-qtmultimedia
            fi
            pkg_install \
                gstreamer-plugins-good \
                gstreamer-plugins-bad \
                gstreamer-plugins-libav \
                -- \
                gstreamer-plugins-good
            pkg_install mesa-libva libva2 || true
            ;;
        xbps)
            pkg_install qt6-multimedia gst-libav gst-plugins-good gst-plugins-bad || true
            ;;
        apk)
            pkg_install qt6-qtmultimedia gstreamer gst-plugins-good gst-libav || true
            ;;
        portage)
            warn "Gentoo : assurez-vous des USE flags : media-libs/gst-plugins-base +X +opengl"
            warn "         media-video/ffmpeg +encode +network"
            emerge --ask=n media-libs/gst-plugins-bad media-libs/gst-plugins-ugly 2>/dev/null || true
            ;;
        nix)
            warn "NixOS : ajoutez dans configuration.nix :"
            warn "  environment.systemPackages = with pkgs; [ qt6.qtmultimedia gst_all_1.gstreamer"
            warn "    gst_all_1.gst-plugins-good gst_all_1.gst-libav ];"
            ;;
        "")
            warn "Gestionnaire inconnu — installez manuellement : qt6-multimedia gstreamer gst-plugins-good gst-libav" ;;
    esac
}

install_multimedia_deps
ok "Dépendances QtMultimedia installées."

# =============================================================================
#  ÉTAPE 5 — Sélection de la vidéo
# =============================================================================
step "5/8" "Sélection de la vidéo de fond..."
select_video

# =============================================================================
#  ÉTAPE 6 — Création du thème
# =============================================================================
step "6/8" "Création du thème SDDM..."

mkdir -p "$THEME_DIR" || die "Impossible de créer $THEME_DIR"
install_video

# ── Assets graphiques ──
info "Téléchargement des assets graphiques (branche ${REPO_BRANCH})..."
download_asset "loginterminalc.png" || {
    warn "loginterminalc.png non récupéré depuis le repo — génération d'un PNG fallback"
    generate_fallback_png "loginterminalc.png"
}

SDDM_ARROW=$(find /usr/lib -name "angle-down.png" 2>/dev/null | head -1 || true)
if [[ -z "$SDDM_ARROW" ]]; then
    download_asset "angle-down.png" || generate_fallback_png "angle-down.png"
else
    cp "$SDDM_ARROW" "${THEME_DIR}/angle-down.png" 2>/dev/null || true
    ok "angle-down.png copié depuis SddmComponents"
fi

# ── metadata.desktop ──
cat > "${THEME_DIR}/metadata.desktop" <<EOF
[Desktop Entry]
Name=SDDM Video Background
Comment=Fond vidéo configurable pour SDDM — PapaOursPolaire
Type=Service
X-KDE-PluginInfo-Name=${THEME_NAME}
X-KDE-PluginInfo-Author=PapaOursPolaire
X-KDE-PluginInfo-Email=papaoursgamer@gmail.com
X-KDE-PluginInfo-Version=${SCRIPT_VERSION}
X-KDE-PluginInfo-License=GPL
EOF
[[ "$QT_VERSION" == "6" ]] && echo "QtVersion=6" >> "${THEME_DIR}/metadata.desktop"
ok "metadata.desktop écrit"

# ── theme.conf.user (surcharges utilisateur) ──
[[ ! -f "${THEME_DIR}/theme.conf.user" ]] && cat > "${THEME_DIR}/theme.conf.user" <<'EOF'
# Surcharges utilisateur — priorité sur theme.conf
# [General]
# background=mavideo.mp4
EOF

# ── Main.qml Qt6 ──────────────────────────────────────────────────────────────
if [[ "$QT_VERSION" == "6" ]]; then
    cat > "${THEME_DIR}/Main.qml" <<'QMLEOF'
// SDDM Video Background  v3.1  —  Main.qml  (Qt6)
// by PapaOursPolaire
//
// Vidéo configurable dans theme.conf : background=nomdevideo.mp4
// Pour changer : sudo bash sddm-video.sh --change-video

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

    // Résolution du chemin vidéo
    property string videoSrc: {
        var bg = config.background || ""
        if (bg.length === 0) return ""
        if (bg.indexOf("file://") === 0) return bg
        if (bg.indexOf("/") === 0)       return "file://" + bg
        return Qt.resolvedUrl(bg).toString()
    }

    TextConstants { id: textConstants }

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
            errorMessage.color = "orange"
            errorMessage.text  = message
        }
    }

    // ── Vidéo en arrière-plan ──────────────────────────────────────────────────
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
            console.warn("SDDM Video: erreur lecteur — " + errorString)
        }
    }

    // ── Overlay sombre ─────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#40000000"
    }

    // ── Horloge ────────────────────────────────────────────────────────────────
    Clock {
        id: clock
        anchors.top:         parent.top
        anchors.right:       parent.right
        anchors.topMargin:   40
        anchors.rightMargin: 40
        color: "#eaf5c4"
        timeFont { family: "Consolas"; bold: true; pixelSize: 90 }
        dateFont { family: "Lucida Console"; bold: true; pixelSize: 30 }
    }

    // ── Panneau de connexion ───────────────────────────────────────────────────
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

            Column {
                width: parent.width; spacing: 4
                Text { text: textConstants.userName; color: "#88FF88"; font.bold: true; font.pixelSize: 12 }
                TextBox {
                    id: name; width: parent.width; height: 30
                    text: userModel.lastUser; textColor: "#88FF88"
                    color: "transparent"; font.pixelSize: 14
                    KeyNavigation.backtab: rebootButton; KeyNavigation.tab: password
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(name.text, password.text, sessionIndex)
                            event.accepted = true
                        }
                    }
                }
            }

            Column {
                width: parent.width; spacing: 4
                Text { text: textConstants.password; color: "#88FF88"; font.bold: true; font.pixelSize: 12 }
                PasswordBox {
                    id: password; width: parent.width; height: 30
                    font.pixelSize: 14; textColor: "#88FF88"; color: "transparent"
                    KeyNavigation.backtab: name; KeyNavigation.tab: session
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(name.text, password.text, sessionIndex)
                            event.accepted = true
                        }
                    }
                }
            }

            Row {
                width: parent.width; spacing: 8
                Column {
                    width: (parent.width - 8) * 0.55; spacing: 4
                    Text { text: textConstants.session; color: "#88FF88"; font.bold: true; font.pixelSize: 12 }
                    ComboBox {
                        id: session; width: parent.width; height: 30
                        font.pixelSize: 14; color: "transparent"
                        arrowIcon: "angle-down.png"
                        model: sessionModel; index: sessionModel.lastIndex
                        KeyNavigation.backtab: password; KeyNavigation.tab: layoutBox
                    }
                }
                Column {
                    width: (parent.width - 8) * 0.45; spacing: 4
                    Text { text: textConstants.layout; color: "#88FF88"; font.bold: true; font.pixelSize: 12 }
                    LayoutBox {
                        id: layoutBox; width: parent.width; height: 30
                        font.pixelSize: 14; color: "transparent"
                        arrowIcon: "angle-down.png"
                        KeyNavigation.backtab: session; KeyNavigation.tab: loginButton
                    }
                }
            }

            Text {
                id: errorMessage
                anchors.horizontalCenter: parent.horizontalCenter
                text: textConstants.prompt; font.pixelSize: 10; color: "#88FF88"
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                Button {
                    id: loginButton; text: textConstants.login; width: 73; height: 75
                    color: "transparent"; textColor: "green"
                    onClicked: sddm.login(name.text, password.text, sessionIndex)
                    KeyNavigation.backtab: layoutBox; KeyNavigation.tab: shutdownButton
                }
                Button {
                    id: rebootButton; text: textConstants.reboot; width: 73; height: 75
                    color: "transparent"; textColor: "yellow"
                    onClicked: sddm.reboot()
                    KeyNavigation.backtab: shutdownButton; KeyNavigation.tab: name
                }
                Button {
                    id: shutdownButton; text: "Power"; width: 73; height: 75
                    color: "transparent"; textColor: "red"
                    onClicked: sddm.powerOff()
                    KeyNavigation.backtab: loginButton; KeyNavigation.tab: rebootButton
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

# ── Main.qml Qt5 ──────────────────────────────────────────────────────────────
else
    cat > "${THEME_DIR}/Main.qml" <<'QMLEOF'
// SDDM Video Background  v3.1  —  Main.qml  (Qt5)
// by PapaOursPolaire

import QtQuick 2.15
import QtMultimedia 5.15
import SddmComponents 2.0

Rectangle {
    id: container
    width:  Screen.width
    height: Screen.height
    color:  "black"

    LayoutMirroring.enabled:        Qt.locale().textDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property int sessionIndex: session.index

    property string videoSrc: {
        var bg = config.background || ""
        if (bg.length === 0) return ""
        if (bg.indexOf("file://") === 0) return bg
        if (bg.indexOf("/") === 0)       return "file://" + bg
        return Qt.resolvedUrl(bg).toString()
    }

    TextConstants { id: textConstants }

    Connections {
        target: sddm
        onLoginSucceeded: { errorMessage.color = "steelblue"; errorMessage.text = textConstants.loginSucceeded }
        onLoginFailed:    { password.text = ""; errorMessage.color = "red"; errorMessage.text = textConstants.loginFailed }
        onInformationMessage: { errorMessage.color = "orange"; errorMessage.text = message }
    }

    MediaPlayer {
        id: videoPlayer
        source:   container.videoSrc
        autoPlay: true; muted: true; loops: MediaPlayer.Infinite
    }

    VideoOutput {
        anchors.fill: parent
        source:       videoPlayer
        fillMode:     VideoOutput.PreserveAspectCrop
    }

    Rectangle { anchors.fill: parent; color: "#40000000" }

    Clock {
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: 40; anchors.rightMargin: 40
        color: "#eaf5c4"
        timeFont { family: "Consolas"; bold: true; pixelSize: 90 }
        dateFont { family: "Lucida Console"; bold: true; pixelSize: 30 }
    }

    Image {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right; anchors.rightMargin: 40
        source: "loginterminalc.png"
        width:  Math.max(370, mainColumn.implicitWidth  + 60)
        height: Math.max(320, mainColumn.implicitHeight + 60)
        fillMode: Image.Stretch

        Column {
            id: mainColumn; anchors.centerIn: parent; spacing: 12; width: parent.width - 60

            Column {
                width: parent.width; spacing: 4
                Text { text: textConstants.userName; color: "#88FF88"; font.bold: true; font.pixelSize: 12 }
                TextBox {
                    id: name; width: parent.width; height: 30; text: userModel.lastUser
                    textColor: "#88FF88"; color: "transparent"; font.pixelSize: 14
                    KeyNavigation.backtab: rebootButton; KeyNavigation.tab: password
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(name.text, password.text, sessionIndex); event.accepted = true
                        }
                    }
                }
            }

            Column {
                width: parent.width; spacing: 4
                Text { text: textConstants.password; color: "#88FF88"; font.bold: true; font.pixelSize: 12 }
                PasswordBox {
                    id: password; width: parent.width; height: 30
                    font.pixelSize: 14; textColor: "#88FF88"; color: "transparent"
                    KeyNavigation.backtab: name; KeyNavigation.tab: session
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(name.text, password.text, sessionIndex); event.accepted = true
                        }
                    }
                }
            }

            Row {
                width: parent.width; spacing: 8
                Column {
                    width: (parent.width - 8) * 0.55; spacing: 4
                    Text { text: textConstants.session; color: "#88FF88"; font.bold: true; font.pixelSize: 12 }
                    ComboBox {
                        id: session; width: parent.width; height: 30
                        font.pixelSize: 14; color: "transparent"; arrowIcon: "angle-down.png"
                        model: sessionModel; index: sessionModel.lastIndex
                        KeyNavigation.backtab: password; KeyNavigation.tab: layoutBox
                    }
                }
                Column {
                    width: (parent.width - 8) * 0.45; spacing: 4
                    Text { text: textConstants.layout; color: "#88FF88"; font.bold: true; font.pixelSize: 12 }
                    LayoutBox {
                        id: layoutBox; width: parent.width; height: 30
                        font.pixelSize: 14; color: "transparent"; arrowIcon: "angle-down.png"
                        KeyNavigation.backtab: session; KeyNavigation.tab: loginButton
                    }
                }
            }

            Text {
                id: errorMessage; anchors.horizontalCenter: parent.horizontalCenter
                text: textConstants.prompt; font.pixelSize: 10; color: "#88FF88"
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                Button {
                    id: loginButton; text: textConstants.login; width: 73; height: 75
                    color: "transparent"; textColor: "green"
                    onClicked: sddm.login(name.text, password.text, sessionIndex)
                    KeyNavigation.backtab: layoutBox; KeyNavigation.tab: shutdownButton
                }
                Button {
                    id: rebootButton; text: textConstants.reboot; width: 73; height: 75
                    color: "transparent"; textColor: "yellow"
                    onClicked: sddm.reboot()
                    KeyNavigation.backtab: shutdownButton; KeyNavigation.tab: name
                }
                Button {
                    id: shutdownButton; text: "Power"; width: 73; height: 75
                    color: "transparent"; textColor: "red"
                    onClicked: sddm.powerOff()
                    KeyNavigation.backtab: loginButton; KeyNavigation.tab: rebootButton
                }
            }
        }
    }

    Component.onCompleted: { if (name.text === "") name.focus = true; else password.focus = true }
}
QMLEOF
fi

ok "Main.qml Qt${QT_VERSION} écrit."

# ── Vérification que tous les fichiers essentiels sont présents ──────────────
echo ""
info "Vérification des fichiers du thème..."
local_missing=0
for check_f in Main.qml theme.conf metadata.desktop loginterminalc.png; do
    if [[ -f "${THEME_DIR}/${check_f}" ]]; then
        local fsz; fsz=$(du -h "${THEME_DIR}/${check_f}" | cut -f1)
        ok "  ${check_f} (${fsz})"
    else
        warn "  MANQUANT : ${THEME_DIR}/${check_f}"
        local_missing=$((local_missing + 1))
    fi
done
[[ $local_missing -gt 0 ]] && warn "$local_missing fichier(s) manquant(s) dans le thème — l'apparence peut être dégradée"

chmod -R 755 "$THEME_DIR"
find "$THEME_DIR" -type f -exec chmod 644 {} \;
ok "Permissions appliquées."

# =============================================================================
#  ÉTAPE 7 — Configuration SDDM
# =============================================================================
step "7/8" "Écriture de la configuration SDDM..."

mkdir -p "$CONF_DIR" || die "Impossible de créer $CONF_DIR"

DISPLAY_SERVER_HINT=""
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    DISPLAY_SERVER_HINT="# DisplayServer=wayland  ← décommentez si nécessaire"
elif [[ -n "${DISPLAY:-}" ]]; then
    DISPLAY_SERVER_HINT="# DisplayServer=x11  ← décommentez si nécessaire"
else
    DISPLAY_SERVER_HINT="# DisplayServer=  ← wayland ou x11 — laisser vide pour auto-détection"
fi

cat > "$CONF_FILE" <<EOF
# Configuration SDDM — sddm-video v${SCRIPT_VERSION} — PapaOursPolaire
# Généré le $(date '+%Y-%m-%d %H:%M:%S')
#
# Changer la vidéo : sudo bash sddm-video.sh --change-video
# Diagnostic       : bash sddm-video.sh --diagnose

[General]
Numlock=on
${DISPLAY_SERVER_HINT}
# InputMethod= vide : désactive IBus dans le greeter (évite l'alerte Wayland)
InputMethod=

[Theme]
Current=${THEME_NAME}

[Users]
MinimumUid=1000
MaximumUid=60000
EOF

ok "Config SDDM écrite : $CONF_FILE"

# ── Vérification des conflits de configuration après écriture ───────────────
echo ""
info "Vérification des conflits de configuration..."
conflict_found=0
if [[ -d "$CONF_DIR" ]]; then
    while IFS= read -r f; do
        [[ "$f" == "$CONF_FILE" ]] && continue
        local other_theme
        other_theme=$(grep -E '^\s*Current\s*=' "$f" 2>/dev/null | tail -1 | grep -v "^$" || true)
        if [[ -n "$other_theme" ]]; then
            local bname; bname=$(basename "$f")
            # Un fichier qui vient APRÈS zzz- alphabétiquement écraserait notre config
            if [[ "$bname" > "$(basename "$CONF_FILE")" ]]; then
                warn "CONFLIT DÉTECTÉ : '$bname' (vient après '$(basename "$CONF_FILE")') contient : $other_theme"
                warn "  → Ce fichier écrasera notre thème. Supprimez ou modifiez-le."
                conflict_found=1
            else
                info "Config co-existante (notre zzz- gagne) : $(basename "$f") — $other_theme"
            fi
        fi
    done < <(find "$CONF_DIR" -maxdepth 1 -name "*.conf" 2>/dev/null | sort)
fi
if [[ -f "$SDDM_CONF_LEGACY" ]] && grep -q '^\[Theme\]' "$SDDM_CONF_LEGACY" 2>/dev/null; then
    warn "CONFLIT : /etc/sddm.conf contient encore [Theme] — il a priorité absolue sur conf.d/"
    conflict_found=1
fi
[[ $conflict_found -eq 0 ]] && ok "Aucun conflit de configuration détecté."

# ── Correction IBus / Wayland ────────────────────────────────────────────────
if command -v im-config &>/dev/null && [[ -n "$REAL_USER" ]]; then
    sudo -u "$REAL_USER" im-config -n none 2>/dev/null && \
        ok "im-config -n none appliqué pour '$REAL_USER'" || \
        warn "im-config -n none a échoué (peut nécessiter une session graphique)"
fi

if [[ -n "$REAL_HOME" ]] && [[ -d "$REAL_HOME" ]]; then
    echo "run_im none" > "${REAL_HOME}/.xinputrc"
    chown "${REAL_USER}:$(id -gn "$REAL_USER" 2>/dev/null || echo "$REAL_USER")" \
        "${REAL_HOME}/.xinputrc" 2>/dev/null || chown "$REAL_USER" "${REAL_HOME}/.xinputrc" || true
    ok "~/.xinputrc → run_im none"

    local plasma_env_dir="${REAL_HOME}/.config/plasma-workspace/env"
    mkdir -p "$plasma_env_dir" 2>/dev/null || true
    cat > "${plasma_env_dir}/99-unset-im-xim.sh" <<'PLASMA_ENV'
#!/bin/sh
# sddm-video : supprime les variables XIM (alerte IBus Wayland)
unset QT_IM_MODULE
unset GTK_IM_MODULE
unset XMODIFIERS
PLASMA_ENV
    chmod +x "${plasma_env_dir}/99-unset-im-xim.sh"
    chown -R "$REAL_USER" "$plasma_env_dir" 2>/dev/null || true
    ok "Plasma autostart : ${plasma_env_dir}/99-unset-im-xim.sh"
fi

mkdir -p /etc/environment.d 2>/dev/null || true
cat > "/etc/environment.d/60-no-ibus-xim.conf" <<'ENVEOF'
# sddm-video : désactive les variables XIM incompatibles avec Wayland input-method-v2
QT_IM_MODULE=
GTK_IM_MODULE=
ENVEOF
chmod 644 "/etc/environment.d/60-no-ibus-xim.conf"
ok "systemd-logind : /etc/environment.d/60-no-ibus-xim.conf"

# ── Vérification finale /etc/sddm.conf ──────────────────────────────────────
if [[ -f "$SDDM_CONF_LEGACY" ]]; then
    if grep -q '^\[Theme\]' "$SDDM_CONF_LEGACY" 2>/dev/null; then
        warn "/etc/sddm.conf contient encore [Theme] — sauvegarde et neutralisation"
        cp "$SDDM_CONF_LEGACY" "${SDDM_CONF_LEGACY}${BACKUP_SUFFIX}" 2>/dev/null || true
        python3 - "$SDDM_CONF_LEGACY" <<'PYEOF' 2>/dev/null || mv "$SDDM_CONF_LEGACY" "${SDDM_CONF_LEGACY}.old"
import sys, re
path = sys.argv[1]
with open(path) as f:
    content = f.read()
content = re.sub(r'\[Theme\][^\[]*', '', content, flags=re.DOTALL)
with open(path, 'w') as f:
    f.write(content.strip() + '\n')
PYEOF
        ok "Section [Theme] retirée de /etc/sddm.conf"
    else
        info "/etc/sddm.conf sans [Theme] — laissé intact"
    fi
fi

echo ""
info "Configs SDDM actives dans ${CONF_DIR}/ :"
find "$CONF_DIR" -maxdepth 1 -name "*.conf" 2>/dev/null | sort | while IFS= read -r f; do
    local cur; cur=$(grep -E '^\s*Current\s*=' "$f" 2>/dev/null | tail -1 || true)
    if [[ -n "$cur" ]]; then
        echo -e "    ${YEL}$(basename "$f")${NC}  ←  $cur"
    else
        echo "    $(basename "$f")"
    fi
done

# =============================================================================
#  ÉTAPE 8 — Activation du service SDDM
# =============================================================================
step "8/8" "Activation du service SDDM..."

if command -v systemctl &>/dev/null && systemctl --version &>/dev/null 2>&1; then
    for dm in gdm gdm3 lightdm lxdm xdm ly; do
        if systemctl is-enabled "$dm" &>/dev/null 2>&1; then
            echo "$dm" > /tmp/sddm-video-prev-dm
            info "Désactivation de $dm..."
            systemctl disable --now "$dm" 2>/dev/null || true
        fi
    done
    systemctl enable sddm 2>/dev/null || true
    systemctl set-default graphical.target 2>/dev/null || true
    ok "SDDM activé au démarrage."

elif command -v rc-update &>/dev/null; then
    rc-update add sddm default 2>/dev/null && ok "SDDM ajouté au runlevel default (OpenRC)" || true

elif command -v sv &>/dev/null; then
    ln -sf /etc/sv/sddm /var/service/ 2>/dev/null && ok "SDDM activé (runit)" || true

elif command -v s6-rc &>/dev/null; then
    warn "s6 : activez manuellement le service sddm dans votre bundle s6"

else
    warn "Init system non reconnu — activation manuelle de SDDM requise"
fi

# =============================================================================
#  RÉSUMÉ FINAL
# =============================================================================
echo ""
echo -e "${CYN}╔═══════════════════════════════════════════════════════╗"
echo -e "║   Installation terminée avec succès !                 ║"
echo -e "╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GRN}Qt version :${NC} Qt${QT_VERSION}"
echo -e "  ${GRN}Vidéo      :${NC} $FILENAME"
echo -e "  ${GRN}Thème      :${NC} $THEME_DIR"
echo -e "  ${GRN}Config     :${NC} $CONF_FILE"
echo -e "  ${GRN}Distro     :${NC} $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo inconnue)"
echo -e "  ${GRN}Branche    :${NC} ${REPO_BRANCH}"
echo ""
echo -e "  ${CYN}Commandes utiles :${NC}"
echo -e "    sudo bash sddm-video.sh --change-video   # changer la vidéo"
echo -e "    bash sddm-video.sh --diagnose            # diagnostic"
echo -e "    sudo bash sddm-video.sh --uninstall      # désinstaller"
echo ""
echo -e "  ${CYN}Test sans redémarrer :${NC}"
if [[ "$QT_VERSION" == "6" ]]; then
    echo -e "    sddm-greeter-qt6 --test-mode --theme $THEME_DIR"
else
    echo -e "    sddm-greeter --test-mode --theme $THEME_DIR"
fi
echo ""
echo -e "  ${YEL}Note VAAPI :${NC} Les warnings 'hardware accelerator failed to decode' dans"
echo -e "  les logs du greeter sont NORMAUX si VAAPI n'est pas configuré."
echo -e "  QtMultimedia se rabat automatiquement sur le décodage logiciel (CPU)."
echo -e "  La vidéo s'affiche quand même. Voir --diagnose pour plus de détails."
echo ""

# ── Génération du rapport de log complet ────────────────────────────────────
generate_log_report

read -rp "  Redémarrer SDDM maintenant ? [o/N] : " REP || REP=""
if [[ "$REP" =~ ^[Oo]$ ]]; then
    _restart_sddm
fi

echo ""
