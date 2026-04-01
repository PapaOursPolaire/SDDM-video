#!/bin/bash
# =============================================================================
#  sddm-video.sh  v3.3  —  by PapaOursPolaire
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
#  Usage (méthode recommandée) :
#    git clone https://github.com/PapaOursPolaire/SDDM-video.git
#    cd SDDM-video
#    sudo bash sddm-video.sh                # installation complète
#    sudo bash sddm-video.sh --change-video # changer la vidéo uniquement
#         bash sddm-video.sh --diagnose     # diagnostic sans sudo
#         bash sddm-video.sh --uninstall    # désinstallation propre
#
#  CORRECTIFS v3.3 :
#    - SCRIPT_DIR résolu via realpath + PWD pour fonctionner avec
#      "sudo bash sddm-video.sh" depuis le dossier du repo cloné.
#    - BASH_SOURCE[0] seul est insuffisant avec sudo bash : on complète
#      avec $PWD si le chemin n'est pas absolu.
#    - Suppression totale de angle-down.png (QML Qt5, Qt6, vérifications,
#      diagnostic, log, fallback) — fichier retiré du projet.
#    - set -uo pipefail remplacé par set -o pipefail (nounset supprimé)
#      pour éviter les crashs silencieux sur variables optionnelles.
#    - generate_log_report protégé contre les crashs précoces.
#    - Logs toujours générés, même en cas d'erreur fatale.
# =============================================================================

set -o pipefail

# ─── Répertoire du script = racine du repo cloné ──────────────────────────────
# "sudo bash sddm-video.sh" depuis SDDM-video/ :
#   BASH_SOURCE[0] peut valoir "sddm-video.sh" (sans chemin absolu).
#   On combine avec $PWD pour garantir un chemin absolu.
_raw_src="${BASH_SOURCE[0]:-$0}"
if [[ "$_raw_src" != /* ]]; then
    _raw_src="${PWD}/${_raw_src}"
fi
SCRIPT_DIR="$(cd "$(dirname "$_raw_src")" 2>/dev/null && pwd)"
# Dernier recours : on est forcément dans le bon dossier si l'utilisateur
# a suivi les instructions (cd SDDM-video && sudo bash sddm-video.sh)
[[ -z "$SCRIPT_DIR" ]] && SCRIPT_DIR="$PWD"

# ─── Constantes ───────────────────────────────────────────────────────────────
readonly THEME_NAME="sddm-video"
readonly THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
readonly CONF_DIR="/etc/sddm.conf.d"
readonly CONF_FILE="${CONF_DIR}/zzz-sddm-video.conf"
readonly SDDM_CONF_LEGACY="/etc/sddm.conf"
readonly SCRIPT_VERSION="3.3"
readonly BACKUP_SUFFIX=".bak.sddm-video"
readonly INSTALL_LOG="/var/log/sddm-video-install.log"

# URL de fallback réseau (utilisée SEULEMENT si le fichier est absent localement)
readonly REPO_BRANCH="Projets"
readonly REPO_LFS="https://media.githubusercontent.com/media/PapaOursPolaire/SDDM-video/${REPO_BRANCH}"

# Variables globales
QT_VERSION=""
PKG_MANAGER=""
VIDEO_PATH=""
FILENAME=""
REAL_USER=""
REAL_HOME=""
INSTALL_WARNINGS=()

# ─── Couleurs ─────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m'; YEL='\033[1;33m'; GRN='\033[0;32m'
    CYN='\033[0;36m'; BLD='\033[1m'; NC='\033[0m'
else
    RED=''; YEL=''; GRN=''; CYN=''; BLD=''; NC=''
fi

info()  { echo -e "  ${CYN}➜${NC}  $*"; }
ok()    { echo -e "  ${GRN}✔${NC}  $*"; }
warn()  { echo -e "  ${YEL}⚠${NC}  $*"; INSTALL_WARNINGS+=("WARN: $*"); }
die()   {
    echo -e "  ${RED}✘${NC}  $*" >&2
    INSTALL_WARNINGS+=("ERREUR FATALE: $*")
    generate_log_report 2>/dev/null || true
    exit 1
}
step()  { echo ""; echo -e "${CYN}[$1]${NC} ${BLD}$2${NC}"; }

# ─── Résolution de l'utilisateur réel (sous sudo) ─────────────────────────────
resolve_real_user() {
    REAL_USER="${SUDO_USER:-}"
    [[ -z "$REAL_USER" ]] && REAL_USER=$(logname 2>/dev/null || true)
    if [[ -z "$REAL_USER" ]] || [[ "$REAL_USER" == "root" ]]; then
        REAL_USER=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' || echo "")
    fi
    [[ -n "$REAL_USER" ]] && REAL_HOME=$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6 || echo "")
}

# =============================================================================
#  DÉTECTION DU GESTIONNAIRE DE PAQUETS
# =============================================================================
detect_pkg_manager() {
    if   command -v apt-get      &>/dev/null; then PKG_MANAGER="apt"
    elif command -v pacman       &>/dev/null; then PKG_MANAGER="pacman"
    elif command -v dnf          &>/dev/null; then PKG_MANAGER="dnf"
    elif command -v zypper       &>/dev/null; then PKG_MANAGER="zypper"
    elif command -v xbps-install &>/dev/null; then PKG_MANAGER="xbps"
    elif command -v apk          &>/dev/null; then PKG_MANAGER="apk"
    elif command -v emerge       &>/dev/null; then PKG_MANAGER="portage"
    elif command -v nix-env      &>/dev/null; then PKG_MANAGER="nix"
    elif command -v eopkg        &>/dev/null; then PKG_MANAGER="eopkg"
    elif command -v swupd        &>/dev/null; then PKG_MANAGER="swupd"
    else PKG_MANAGER=""
    fi
}

pkg_install() {
    local primary=() fallback=() is_fallback=0
    for arg in "$@"; do
        [[ "$arg" == "--" ]] && { is_fallback=1; continue; }
        [[ $is_fallback -eq 0 ]] && primary+=("$arg") || fallback+=("$arg")
    done
    local ok_flag=0
    case "$PKG_MANAGER" in
        apt)     DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${primary[@]}" 2>/dev/null && ok_flag=1 || true ;;
        pacman)  pacman -Sy --noconfirm --needed "${primary[@]}" 2>/dev/null && ok_flag=1 || true ;;
        dnf)     dnf install -y "${primary[@]}" 2>/dev/null && ok_flag=1 || true ;;
        zypper)  zypper install -y --no-recommends "${primary[@]}" 2>/dev/null && ok_flag=1 || true ;;
        xbps)    xbps-install -Sy "${primary[@]}" 2>/dev/null && ok_flag=1 || true ;;
        apk)     apk add --no-cache "${primary[@]}" 2>/dev/null && ok_flag=1 || true ;;
        portage) emerge --ask=n "${primary[@]}" 2>/dev/null && ok_flag=1 || true ;;
        eopkg)   eopkg install -y "${primary[@]}" 2>/dev/null && ok_flag=1 || true ;;
        swupd)   swupd bundle-add "${primary[@]}" 2>/dev/null && ok_flag=1 || true ;;
        nix)     warn "NixOS : installez manuellement : ${primary[*]}"; return 0 ;;
        "")      warn "Gestionnaire inconnu — installez manuellement : ${primary[*]}"; return 0 ;;
    esac
    if [[ $ok_flag -eq 0 ]] && [[ ${#fallback[@]} -gt 0 ]]; then
        case "$PKG_MANAGER" in
            apt)    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${fallback[@]}" 2>/dev/null || true ;;
            pacman) pacman -Sy --noconfirm --needed "${fallback[@]}" 2>/dev/null || true ;;
            dnf)    dnf install -y "${fallback[@]}" 2>/dev/null || true ;;
            zypper) zypper install -y --no-recommends "${fallback[@]}" 2>/dev/null || true ;;
            *)      true ;;
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
    detect_pkg_manager
    [[ -z "$PKG_MANAGER" ]] && warn "Gestionnaire de paquets non reconnu — installation manuelle des dépendances requise"
    [[ $errors -gt 0 ]] && die "$errors problème(s) bloquant(s). Corrigez avant de relancer."
    ok "Pre-flight OK (gestionnaire : ${PKG_MANAGER:-inconnu})"
    ok "Répertoire du repo local : ${SCRIPT_DIR}"
}

# =============================================================================
#  INSTALLATION D'UN ASSET DEPUIS LE REPO LOCAL
#
#  Priorité 1 : copier depuis SCRIPT_DIR/ (repo cloné localement) — CAS NORMAL
#  Priorité 2 : téléchargement LFS réseau — FALLBACK si clone absent
# =============================================================================
install_asset() {
    local asset="$1"
    local dest="${THEME_DIR}/${asset}"

    # ── Priorité 1 : repo local (git clone) ───────────────────────────────────
    if [[ -f "${SCRIPT_DIR}/${asset}" ]]; then
        local sz; sz=$(du -h "${SCRIPT_DIR}/${asset}" | cut -f1)
        cp "${SCRIPT_DIR}/${asset}" "$dest" || die "Impossible de copier ${asset} vers ${dest}"
        chmod 644 "$dest"
        ok "Copié depuis le repo local : ${asset} (${sz})"
        return 0
    fi

    # ── Priorité 2 : fallback réseau via LFS ──────────────────────────────────
    warn "${asset} absent dans ${SCRIPT_DIR}/ — tentative réseau (LFS)..."
    local dl_ok=1
    if command -v curl &>/dev/null; then
        curl -fsSL --max-time 60 "${REPO_LFS}/${asset}" -o "$dest" 2>/dev/null && dl_ok=0 || true
    elif command -v wget &>/dev/null; then
        wget -q --timeout=60 "${REPO_LFS}/${asset}" -O "$dest" 2>/dev/null && dl_ok=0 || true
    fi

    if [[ $dl_ok -eq 0 ]] && [[ -s "$dest" ]]; then
        # Détecter un pointeur LFS (texte < 500 octets)
        local sz; sz=$(wc -c < "$dest" 2>/dev/null || echo 0)
        if [[ $sz -lt 500 ]] && head -c 80 "$dest" 2>/dev/null | grep -q "git-lfs"; then
            rm -f "$dest"
            warn "${asset} : pointeur LFS reçu (pas le vrai fichier). Génération fallback."
            return 1
        fi
        chmod 644 "$dest"
        ok "Téléchargé (fallback réseau) : ${asset} ($(du -h "$dest" | cut -f1))"
        return 0
    fi

    rm -f "$dest" 2>/dev/null || true
    return 1
}

# =============================================================================
#  GÉNÉRATION PNG FALLBACK (dernier recours absolu)
# =============================================================================
generate_fallback_png() {
    local asset="$1"
    local dest="${THEME_DIR}/${asset}"
    python3 - "$dest" "$asset" <<'PYEOF'
import sys, struct, zlib
dest  = sys.argv[1]
asset = sys.argv[2] if len(sys.argv) > 2 else ""

def mk_chunk(tag, data):
    raw = tag + data
    return struct.pack('>I', len(data)) + raw + struct.pack('>I', zlib.crc32(raw) & 0xffffffff)

W, H = 400, 300
def px(x, y, W, H):
    r = int(10 + (x / W) * 10)
    g = int(30 + (y / H) * 20)
    b, a = 15, 200
    if (5 < x < W-5 and 5 < y < H-5) and not (8 < x < W-8 and 8 < y < H-8):
        return (60, 180, 80, 220)
    return (r, g, b, a)

rows = b""
for y in range(H):
    row = b"\x00"
    for x in range(W):
        row += bytes(px(x, y, W, H))
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
        INSTALL_WARNINGS+=("WARN: '$asset' généré en fallback — absent du repo local ET du réseau")
    else
        warn "Génération PNG fallback échouée pour $asset"
        INSTALL_WARNINGS+=("ERREUR: impossible de créer '$asset'")
    fi
}

# =============================================================================
#  RAPPORT DE LOG COMPLET
# =============================================================================
generate_log_report() {
    mkdir -p "$(dirname "$INSTALL_LOG")" 2>/dev/null || true
    : > "$INSTALL_LOG" 2>/dev/null || return 0
    chmod 600 "$INSTALL_LOG" 2>/dev/null || true
    {
        echo "============================================================"
        echo "  SDDM Video v${SCRIPT_VERSION} — Rapport d'installation"
        echo "  Généré le  : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Repo local : ${SCRIPT_DIR}"
        echo "============================================================"
        echo ""

        echo "── Système ──────────────────────────────────────────────────"
        echo "OS      : $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo inconnu)"
        echo "Kernel  : $(uname -a 2>/dev/null || echo inconnu)"
        echo "PKG MGR : ${PKG_MANAGER:-inconnu}"
        echo "Qt ver  : ${QT_VERSION:-non détecté}"
        echo "Vidéo   : ${FILENAME:-non définie}"
        echo ""

        echo "── Fichiers présents dans le repo local (${SCRIPT_DIR}/) ────"
        ls -lah "${SCRIPT_DIR}/" 2>/dev/null || echo "(ls échoué)"
        echo ""

        echo "── Fichiers installés dans le thème ─────────────────────────"
        ls -lah "${THEME_DIR}/" 2>/dev/null || echo "DOSSIER ABSENT : ${THEME_DIR}"
        echo ""

        echo "── theme.conf ───────────────────────────────────────────────"
        cat "${THEME_DIR}/theme.conf" 2>/dev/null || echo "(absent)"
        echo ""

        echo "── metadata.desktop ─────────────────────────────────────────"
        cat "${THEME_DIR}/metadata.desktop" 2>/dev/null || echo "(absent)"
        echo ""

        echo "── ${CONF_FILE} ─────────────────────────────────────────────"
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
        [[ -f "$SDDM_CONF_LEGACY" ]] && cat "$SDDM_CONF_LEGACY" || echo "(absent — bien)"
        echo ""

        echo "── Service SDDM ─────────────────────────────────────────────"
        if command -v systemctl &>/dev/null; then
            echo "is-active  : $(systemctl is-active  sddm 2>/dev/null || echo inconnu)"
            echo "is-enabled : $(systemctl is-enabled sddm 2>/dev/null || echo inconnu)"
        else
            echo "(systemctl absent)"
        fi
        echo ""

        echo "── Greeter SDDM ─────────────────────────────────────────────"
        find /usr -name "sddm-greeter*" -type f 2>/dev/null || echo "(aucun)"
        echo ""

        echo "── Modules QtMultimedia QML ─────────────────────────────────"
        find /usr/lib /usr/lib64 2>/dev/null -maxdepth 6 -type d -name "QtMultimedia" 2>/dev/null | grep -E 'qml' | head -10 || echo "(aucun)"
        echo ""

        echo "── Journalctl SDDM (50 dernières lignes) ────────────────────"
        if command -v journalctl &>/dev/null; then
            journalctl -u sddm -b --no-pager -n 50 2>/dev/null || echo "(journalctl échoué)"
        else
            [[ -f /var/log/sddm.log ]] && tail -50 /var/log/sddm.log || echo "(journalctl absent)"
        fi
        echo ""

        echo "── Variables d'environnement ────────────────────────────────"
        echo "QT_IM_MODULE   : ${QT_IM_MODULE:-<vide>}"
        echo "GTK_IM_MODULE  : ${GTK_IM_MODULE:-<vide>}"
        echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-<vide>}"
        echo "DISPLAY        : ${DISPLAY:-<vide>}"
        echo ""

        echo "── Warnings et erreurs collectés ────────────────────────────"
        if [[ ${#INSTALL_WARNINGS[@]} -eq 0 ]]; then
            echo "(aucun warning)"
        else
            for w in "${INSTALL_WARNINGS[@]}"; do echo "  $w"; done
        fi
        echo ""
        echo "============================================================"
        echo "  Fin du rapport"
        echo "============================================================"
    } >> "$INSTALL_LOG" 2>/dev/null || true

    echo -e "  ${CYN}📋${NC}  Rapport complet : ${BLD}${INSTALL_LOG}${NC}"
}

# =============================================================================
#  REDÉMARRAGE SDDM
# =============================================================================
_restart_sddm() {
    if command -v systemctl &>/dev/null; then
        systemctl restart sddm 2>/dev/null && \
            ok "SDDM redémarré ($(systemctl is-active sddm 2>/dev/null || echo 'état inconnu'))" || \
            warn "Redémarrage SDDM échoué — lancez manuellement : sudo systemctl restart sddm"
    elif command -v rc-service &>/dev/null; then
        rc-service sddm restart 2>/dev/null && ok "SDDM redémarré (OpenRC)" || warn "Redémarrage OpenRC échoué"
    elif command -v sv &>/dev/null; then
        sv restart /var/service/sddm 2>/dev/null && ok "SDDM redémarré (runit)" || warn "Redémarrage runit échoué"
    else
        warn "Init system non reconnu — redémarrez SDDM manuellement"
    fi
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

    dhead "1. Système"
    dinfo "OS         : $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo inconnu)"
    dinfo "Kernel     : $(uname -r)"
    dinfo "Arch       : $(uname -m)"
    dinfo "PKG        : ${PKG_MANAGER:-inconnu}"
    dinfo "Repo local : ${SCRIPT_DIR}"
    [[ -n "${WAYLAND_DISPLAY:-}" ]] && dinfo "Session : Wayland" || \
    { [[ -n "${DISPLAY:-}" ]] && dinfo "Session : X11" || dwarn "Session : aucune variable graphique"; }

    dhead "2. Fichiers dans le repo local"
    for f in loginterminalc.png default.mp4 sddm-video.sh; do
        if [[ -f "${SCRIPT_DIR}/${f}" ]]; then
            dok "${f} : $(du -h "${SCRIPT_DIR}/${f}" | cut -f1)"
        else
            derr "${f} ABSENT dans ${SCRIPT_DIR}/"
        fi
    done

    dhead "3. SDDM — service et greeter"
    command -v sddm &>/dev/null && dok "sddm : $(command -v sddm)" || derr "sddm introuvable"
    local found_greeter=""
    found_greeter=$(find /usr -name "sddm-greeter*" -type f 2>/dev/null | head -1 || true)
    [[ -n "$found_greeter" ]] && dok "Greeter : $found_greeter" || derr "Aucun greeter sddm trouvé"
    if command -v systemctl &>/dev/null; then
        local st en
        st=$(systemctl is-active  sddm 2>/dev/null || echo "inconnu")
        en=$(systemctl is-enabled sddm 2>/dev/null || echo "inconnu")
        [[ "$st" == "active"  ]] && dok  "Service : actif"         || dwarn "Service : $st"
        [[ "$en" == "enabled" ]] && dok  "Démarrage auto : activé" || dwarn "Démarrage auto : $en"
    fi

    dhead "4. Thème sddm-video installé"
    if [[ ! -d "$THEME_DIR" ]]; then
        derr "Dossier absent : $THEME_DIR → lancez l'installation"
    else
        dok "Dossier : $THEME_DIR"
        for fname in Main.qml theme.conf metadata.desktop loginterminalc.png; do
            if [[ -f "${THEME_DIR}/${fname}" ]]; then
                dok "  ${fname} ($(du -h "${THEME_DIR}/${fname}" | cut -f1))"
            else
                derr "  ${fname} ABSENT"
            fi
        done
        local bg; bg=$(grep -E '^\s*background\s*=' "${THEME_DIR}/theme.conf" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]' || true)
        if [[ -n "$bg" ]]; then
            [[ -f "${THEME_DIR}/${bg}" ]] && dok "  vidéo : ${bg} ($(du -h "${THEME_DIR}/${bg}" | cut -f1))" || derr "  vidéo '${bg}' déclarée mais ABSENTE"
        else
            dwarn "  Aucun background= dans theme.conf"
        fi
        local pname; pname=$(grep -i 'X-KDE-PluginInfo-Name' "${THEME_DIR}/metadata.desktop" 2>/dev/null | cut -d= -f2- | tr -d ' ' || true)
        [[ "$pname" == "$THEME_NAME" ]] && dok "  X-KDE-PluginInfo-Name='${pname}' ✓" || derr "  X-KDE-PluginInfo-Name='${pname}' ≠ '${THEME_NAME}'"
    fi

    dhead "5. Configuration SDDM"
    local our_conf_found=0
    if [[ -d "$CONF_DIR" ]]; then
        while IFS= read -r f; do
            local tl; tl=$(grep -E '^\s*Current\s*=' "$f" 2>/dev/null | tail -1 || true)
            [[ -n "$tl" ]] && echo -e "    ${YEL}$(basename "$f")${NC}  ←  $tl" || echo "    $(basename "$f")"
            [[ "$f" == "$CONF_FILE" ]] && our_conf_found=1
        done < <(find "$CONF_DIR" -maxdepth 1 -name "*.conf" 2>/dev/null | sort)
    else
        dwarn "${CONF_DIR}/ absent"
    fi
    [[ -f "$SDDM_CONF_LEGACY" ]] && {
        local t; t=$(grep -E '^\s*Current\s*=' "$SDDM_CONF_LEGACY" 2>/dev/null | tail -1 || true)
        echo -e "    ${RED}/etc/sddm.conf (PRIORITÉ ABSOLUE)${NC}  ←  ${t:-aucun Current=}"
    }
    [[ $our_conf_found -eq 0 ]] && derr "Notre config ${CONF_FILE} ABSENTE → thème non appliqué" || dok "Notre config présente et prioritaire (zzz-)"

    dhead "6. QtMultimedia"
    local qt_found=0
    while IFS= read -r p; do
        [[ -d "$p" ]] && { dok "Module QML : $p"; qt_found=1; }
    done < <(find /usr/lib /usr/lib64 2>/dev/null -maxdepth 6 -type d -name "QtMultimedia" 2>/dev/null | grep -E 'qml' | head -5 || true)
    [[ $qt_found -eq 0 ]] && derr "Aucun module QtMultimedia QML — la vidéo ne fonctionnera pas"

    dhead "7. Logs SDDM récents"
    if command -v journalctl &>/dev/null; then
        journalctl -u sddm -b --no-pager -n 30 2>/dev/null | while IFS= read -r line; do
            echo "$line" | grep -qiE 'error|fail|crash|fatal' && { echo -e "  ${RED}${line}${NC}"; continue; }
            echo "$line" | grep -qiE 'warn|theme|Current|vaapi'  && { echo -e "  ${YEL}${line}${NC}"; continue; }
            echo "  $line"
        done
    else
        dwarn "journalctl absent"
        [[ -f /var/log/sddm.log ]] && tail -20 /var/log/sddm.log || true
    fi

    dhead "8. Rapport de log"
    [[ -f "$INSTALL_LOG" ]] && dinfo "Disponible : $INSTALL_LOG ($(du -h "$INSTALL_LOG" | cut -f1))" || dwarn "Aucun rapport — lancez l'installation complète"

    exit 0
}

if [[ "${1:-}" == "--diagnose" ]]; then resolve_real_user; run_diagnose; fi

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
        ok "/etc/sddm.conf restauré"
    fi
    if [[ -f /tmp/sddm-video-prev-dm ]]; then
        local prev_dm; prev_dm=$(cat /tmp/sddm-video-prev-dm)
        command -v systemctl &>/dev/null && systemctl enable "$prev_dm" 2>/dev/null && ok "DM précédent réactivé : $prev_dm" || true
        rm -f /tmp/sddm-video-prev-dm
    fi
    ok "Désinstallation terminée. Relancez : sudo systemctl restart sddm"
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
info "Repo local : ${SCRIPT_DIR}"
echo ""

# =============================================================================
#  SÉLECTION DE LA VIDÉO
# =============================================================================
select_video() {
    VIDEO_PATH=""
    local dialog_user="${REAL_USER:-${SUDO_USER:-$USER}}"
    local has_display=0
    [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && has_display=1

    # Vidéo par défaut = default.mp4 dans le repo cloné
    local local_default="${SCRIPT_DIR}/default.mp4"

    echo -e "  ${CYN}Choisissez votre vidéo de fond.${NC}"
    echo -e "  ${CYN}Laissez vide / annulez pour utiliser default.mp4 du repo.${NC}"
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
                --file-selection --title="Sélectionnez votre vidéo" \
                --file-filter="Vidéos | *.mp4 *.webm *.avi *.mkv *.mov *.gif" \
                2>/dev/null) || VIDEO_PATH=""
        fi
        if [[ -z "$VIDEO_PATH" ]] && command -v yad &>/dev/null; then
            info "Sélecteur graphique : yad"
            VIDEO_PATH=$(sudo -u "$dialog_user" yad \
                --file --title="Sélectionnez votre vidéo" 2>/dev/null) || VIDEO_PATH=""
        fi
    fi

    if [[ -z "$VIDEO_PATH" ]]; then
        echo -e "  Chemin vers votre vidéo (laisser vide = default.mp4 du repo) :"
        read -rp "  → " VIDEO_PATH || VIDEO_PATH=""
    fi

    VIDEO_PATH="${VIDEO_PATH%$'\n'}"
    VIDEO_PATH=$(echo "$VIDEO_PATH" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")

    # Aucune vidéo choisie → utiliser default.mp4 local
    if [[ -z "$VIDEO_PATH" ]]; then
        if [[ -f "$local_default" ]]; then
            VIDEO_PATH="$local_default"
            ok "Vidéo par défaut (repo local) : default.mp4 ($(du -h "$local_default" | cut -f1))"
        else
            die "Aucune vidéo choisie et default.mp4 absent dans ${SCRIPT_DIR}/. Placez-y une vidéo ou choisissez-en une."
        fi
        return
    fi

    [[ ! -f "$VIDEO_PATH" ]] && die "Fichier introuvable : '${VIDEO_PATH}'"

    local ext="${VIDEO_PATH##*.}"; ext="${ext,,}"
    case "$ext" in
        mp4|webm|avi|mkv|mov|gif) ;;
        *) die "Format '${ext}' non supporté. Formats acceptés : mp4, webm, avi, mkv, mov, gif" ;;
    esac

    ok "Vidéo sélectionnée : $(basename "$VIDEO_PATH") (${ext})"
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

    cp "$VIDEO_PATH" "$dest" || die "Impossible de copier la vidéo vers ${dest}"
    chmod 644 "$dest"
    ok "Vidéo installée : ${FILENAME} ($(du -h "$dest" | cut -f1))"

    if [[ -f "${THEME_DIR}/theme.conf" ]]; then
        sed -i "s|^background=.*|background=${FILENAME}|" "${THEME_DIR}/theme.conf"
    else
        printf '[General]\nbackground=%s\n' "$FILENAME" > "${THEME_DIR}/theme.conf"
    fi
    ok "theme.conf → background=${FILENAME}"
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
    [[ "$REP" =~ ^[Oo]$ ]] && _restart_sddm
    exit 0
fi

# =============================================================================
#  ÉTAPE 1 — Nettoyage
# =============================================================================
step "1/8" "Nettoyage des installations précédentes..."

if [[ -f "$SDDM_CONF_LEGACY" ]]; then
    if grep -q '^\[Theme\]' "$SDDM_CONF_LEGACY" 2>/dev/null; then
        warn "/etc/sddm.conf contient [Theme] — sauvegarde et nettoyage"
        [[ -f "${SDDM_CONF_LEGACY}${BACKUP_SUFFIX}" ]] || cp "$SDDM_CONF_LEGACY" "${SDDM_CONF_LEGACY}${BACKUP_SUFFIX}" || true
        grep -v '^\[Theme\]' "$SDDM_CONF_LEGACY" | sed '/^\s*Current\s*=/d' > "${SDDM_CONF_LEGACY}.tmp" && \
            mv "${SDDM_CONF_LEGACY}.tmp" "$SDDM_CONF_LEGACY" || true
        ok "Section [Theme] retirée de /etc/sddm.conf"
    else
        info "/etc/sddm.conf présent sans [Theme] — laissé intact"
    fi
fi

for old_conf in "${CONF_DIR}/sddm-video.conf" "${CONF_DIR}/zzz-sddm-video.conf"; do
    [[ -f "$old_conf" ]] && { rm -f "$old_conf" && info "Supprimé : $old_conf"; } || true
done

for t in video-bg sddm-video video custom; do
    [[ -d "/usr/share/sddm/themes/$t" ]] && { rm -rf "/usr/share/sddm/themes/$t"; info "Ancien thème supprimé : $t"; } || true
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
        DEBIAN_FRONTEND=noninteractive apt-get install -y sddm 2>/dev/null || true ;;
    pacman)  pacman -Sy --noconfirm --needed sddm unzip || true ;;
    dnf)     dnf install -y sddm unzip || true ;;
    zypper)  zypper install -y sddm unzip || true ;;
    xbps)    xbps-install -Sy sddm unzip || true ;;
    apk)     apk add --no-cache sddm unzip || true ;;
    portage) emerge --ask=n x11-misc/sddm app-arch/unzip 2>/dev/null || true ;;
    eopkg)   eopkg install -y sddm unzip 2>/dev/null || true ;;
    swupd)   swupd bundle-add sddm 2>/dev/null || true ;;
    nix)     warn "NixOS : ajoutez services.xserver.displayManager.sddm.enable = true dans configuration.nix" ;;
    "")      warn "Gestionnaire inconnu — installez SDDM manuellement" ;;
esac

command -v sddm &>/dev/null || die "SDDM toujours absent après installation."
ok "SDDM installé : $(command -v sddm)"

# =============================================================================
#  ÉTAPE 3 — Détection Qt
# =============================================================================
step "3/8" "Détection de la version Qt du greeter SDDM..."

_find_greeter() {
    local name="$1"
    local paths=(/usr/bin/$name /usr/libexec/$name /usr/lib/sddm/$name /usr/lib/libexec/$name /usr/lib64/libexec/$name /usr/lib/qt6/libexec/$name)
    for mdir in /usr/lib/*-linux-gnu*/libexec /usr/lib/*-linux-*/libexec; do
        [[ -d "$mdir" ]] && paths+=("${mdir}/${name}")
    done
    for p in "${paths[@]}"; do [[ -f "$p" ]] && { echo "$p"; return 0; }; done
    find /usr /opt 2>/dev/null -name "$name" -type f 2>/dev/null | head -1 || true
}

for greeter_name in sddm-greeter-qt6 sddm-greeter-qt5 sddm-greeter; do
    p=$(_find_greeter "$greeter_name")
    if [[ -n "$p" ]]; then
        case "$greeter_name" in
            *qt6*) QT_VERSION="6" ;;
            *qt5*) QT_VERSION="5" ;;
            *)
                ldd "$p" 2>/dev/null | grep -q 'libQt6' && QT_VERSION="6" || \
                ldd "$p" 2>/dev/null | grep -q 'libQt5' && QT_VERSION="5" || QT_VERSION="6" ;;
        esac
        ok "Greeter Qt${QT_VERSION} : $p"; break
    fi
done

if [[ -z "$QT_VERSION" ]]; then
    case "$PKG_MANAGER" in
        apt)
            dpkg -l sddm-greeter-qt6 2>/dev/null | grep -q "^ii" && QT_VERSION="6" || true
            [[ -z "$QT_VERSION" ]] && dpkg -l sddm-greeter 2>/dev/null | grep -q "^ii" && QT_VERSION="5" || true ;;
        pacman|xbps|apk) QT_VERSION="6" ;;
        dnf)     rpm -q sddm-qt6 &>/dev/null && QT_VERSION="6" || QT_VERSION="5" ;;
        zypper)  rpm -q libsddm-qt6 &>/dev/null && QT_VERSION="6" || QT_VERSION="5" ;;
        portage) equery uses sddm 2>/dev/null | grep -q 'qt6' && QT_VERSION="6" || QT_VERSION="5" ;;
    esac
fi

if [[ -z "$QT_VERSION" ]] && [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    case "${VERSION_CODENAME:-}${VERSION_ID:-}${ID:-}" in
        trixie|forky|noble|*24.04*|*25.04*|*38*|*39*|*40*|*41*|*42*|arch|manjaro|endeavouros|opensuse-tumbleweed) QT_VERSION="6" ;;
        bookworm|jammy|*22.04*|*20.04*|bullseye|buster|*36*|*37*|opensuse-leap) QT_VERSION="5" ;;
        *) QT_VERSION="6" ;;
    esac
    info "Qt déduit via /etc/os-release (${PRETTY_NAME:-}) : Qt${QT_VERSION}"
fi

[[ -z "$QT_VERSION" ]] && { QT_VERSION="6"; warn "Qt non détecté — Qt6 assumé"; }
ok "Qt version retenue : Qt${QT_VERSION}"

# =============================================================================
#  ÉTAPE 4 — Dépendances QtMultimedia + décodeurs
# =============================================================================
step "4/8" "Installation des dépendances QtMultimedia / GStreamer..."

case "$PKG_MANAGER" in
    apt)
        if [[ "$QT_VERSION" == "6" ]]; then
            pkg_install qml6-module-qtmultimedia qml6-module-qtquick-controls -- qml6-module-qtmultimedia
        else
            pkg_install qml-module-qtmultimedia qml-module-qtquick-controls2
        fi
        pkg_install gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-tools -- gstreamer1.0-plugins-good gstreamer1.0-libav
        pkg_install mesa-va-drivers -- libva2 || true
        pkg_install libva-drm2 || true ;;
    pacman)
        [[ "$QT_VERSION" == "6" ]] && pkg_install qt6-multimedia || pkg_install qt5-multimedia
        pkg_install gst-libav gst-plugins-good gst-plugins-bad gst-plugins-ugly libva-mesa-driver ;;
    dnf)
        [[ "$QT_VERSION" == "6" ]] && pkg_install qt6-qtmultimedia || pkg_install qt5-qtmultimedia
        pkg_install gstreamer1-plugins-good gstreamer1-plugins-bad-free gstreamer1-libav -- gstreamer1-plugins-good
        pkg_install mesa-va-drivers libva || true ;;
    zypper)
        [[ "$QT_VERSION" == "6" ]] && pkg_install libQt6Multimedia6 qml6-module-qtmultimedia || pkg_install libQt5Multimedia5 qml-module-qtmultimedia
        pkg_install gstreamer-plugins-good gstreamer-plugins-bad gstreamer-plugins-libav -- gstreamer-plugins-good
        pkg_install mesa-libva libva2 || true ;;
    xbps)    pkg_install qt6-multimedia gst-libav gst-plugins-good gst-plugins-bad || true ;;
    apk)     pkg_install qt6-qtmultimedia gstreamer gst-plugins-good gst-libav || true ;;
    portage)
        warn "Gentoo : assurez-vous des USE flags : media-libs/gst-plugins-base +X +opengl"
        emerge --ask=n media-libs/gst-plugins-bad media-libs/gst-plugins-ugly 2>/dev/null || true ;;
    nix)     warn "NixOS : ajoutez qt6.qtmultimedia gst_all_1.gstreamer gst_all_1.gst-plugins-good gst_all_1.gst-libav" ;;
    "")      warn "Gestionnaire inconnu — installez manuellement : qt6-multimedia gstreamer gst-plugins-good gst-libav" ;;
esac

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

# ── Assets graphiques depuis le repo local ─────────────────────────────────────
info "Installation des assets graphiques depuis le repo local (${SCRIPT_DIR}/)..."

install_asset "loginterminalc.png" || {
    warn "loginterminalc.png : génération PNG fallback (absent localement et réseau)"
    generate_fallback_png "loginterminalc.png"
}

# ── metadata.desktop ──────────────────────────────────────────────────────────
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

[[ ! -f "${THEME_DIR}/theme.conf.user" ]] && cat > "${THEME_DIR}/theme.conf.user" <<'EOF'
# Surcharges utilisateur — priorité sur theme.conf
# [General]
# background=mavideo.mp4
EOF

# ── Main.qml Qt6 ──────────────────────────────────────────────────────────────
if [[ "$QT_VERSION" == "6" ]]; then
cat > "${THEME_DIR}/Main.qml" <<'QMLEOF'
// SDDM Video Background  v3.3  —  Main.qml  (Qt6)  —  PapaOursPolaire
import QtQuick 2.15
import QtMultimedia 6.0
import SddmComponents 2.0

Rectangle {
    id: container
    width:  Screen.width
    height: Screen.height
    color:  "black"

    LayoutMirroring.enabled:         Qt.locale().textDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property int    sessionIndex: session.index
    property string videoSrc: {
        var bg = config.background || ""
        if (bg.length === 0)             return ""
        if (bg.indexOf("file://") === 0) return bg
        if (bg.indexOf("/") === 0)       return "file://" + bg
        return Qt.resolvedUrl(bg).toString()
    }

    TextConstants { id: textConstants }

    Connections {
        target: sddm
        function onLoginSucceeded()            { errorMessage.color = "steelblue"; errorMessage.text = textConstants.loginSucceeded }
        function onLoginFailed()               { password.text = ""; errorMessage.color = "red"; errorMessage.text = textConstants.loginFailed }
        function onInformationMessage(message) { errorMessage.color = "orange"; errorMessage.text = message }
    }

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
        onErrorOccurred: function(error, errorString) { console.warn("SDDM Video: " + errorString) }
    }

    Rectangle { anchors.fill: parent; color: "#40000000" }

    Clock {
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: 40;   anchors.rightMargin: 40
        color: "#eaf5c4"
        timeFont { family: "Consolas";      bold: true; pixelSize: 90 }
        dateFont { family: "Lucida Console"; bold: true; pixelSize: 30 }
    }

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
                    text: userModel.lastUser; textColor: "#88FF88"; color: "transparent"; font.pixelSize: 14
                    KeyNavigation.backtab: rebootButton; KeyNavigation.tab: password
                    Keys.onPressed: function(event) {
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
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(name.text, password.text, sessionIndex); event.accepted = true
                        }
                    }
                }
            }

            Row {
                width: parent.width; spacing: 8
                Column {
                    width: parent.width; spacing: 4
                    Text { text: textConstants.session; color: "#88FF88"; font.bold: true; font.pixelSize: 12 }
                    ComboBox {
                        id: session; width: parent.width; height: 30
                        font.pixelSize: 14; color: "transparent"
                        model: sessionModel; index: sessionModel.lastIndex
                        KeyNavigation.backtab: password; KeyNavigation.tab: loginButton
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
                    KeyNavigation.backtab: session; KeyNavigation.tab: shutdownButton
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

# ── Main.qml Qt5 ──────────────────────────────────────────────────────────────
else
cat > "${THEME_DIR}/Main.qml" <<'QMLEOF'
// SDDM Video Background  v3.3  —  Main.qml  (Qt5)  —  PapaOursPolaire
import QtQuick 2.15
import QtMultimedia 5.15
import SddmComponents 2.0

Rectangle {
    id: container
    width: Screen.width; height: Screen.height; color: "black"
    LayoutMirroring.enabled: Qt.locale().textDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true
    property int    sessionIndex: session.index
    property string videoSrc: {
        var bg = config.background || ""
        if (bg.length === 0) return ""
        if (bg.indexOf("file://") === 0) return bg
        if (bg.indexOf("/") === 0) return "file://" + bg
        return Qt.resolvedUrl(bg).toString()
    }
    TextConstants { id: textConstants }
    Connections {
        target: sddm
        onLoginSucceeded:     { errorMessage.color = "steelblue"; errorMessage.text = textConstants.loginSucceeded }
        onLoginFailed:        { password.text = ""; errorMessage.color = "red"; errorMessage.text = textConstants.loginFailed }
        onInformationMessage: { errorMessage.color = "orange"; errorMessage.text = message }
    }
    MediaPlayer  { id: videoPlayer; source: container.videoSrc; autoPlay: true; muted: true; loops: MediaPlayer.Infinite }
    VideoOutput  { anchors.fill: parent; source: videoPlayer; fillMode: VideoOutput.PreserveAspectCrop }
    Rectangle    { anchors.fill: parent; color: "#40000000" }
    Clock {
        anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: 40; anchors.rightMargin: 40
        color: "#eaf5c4"
        timeFont { family: "Consolas"; bold: true; pixelSize: 90 }
        dateFont { family: "Lucida Console"; bold: true; pixelSize: 30 }
    }
    Image {
        anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 40
        source: "loginterminalc.png"
        width: Math.max(370, mainColumn.implicitWidth + 60); height: Math.max(320, mainColumn.implicitHeight + 60)
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
                    Keys.onPressed: { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { sddm.login(name.text, password.text, sessionIndex); event.accepted = true } }
                }
            }
            Column {
                width: parent.width; spacing: 4
                Text { text: textConstants.password; color: "#88FF88"; font.bold: true; font.pixelSize: 12 }
                PasswordBox {
                    id: password; width: parent.width; height: 30; font.pixelSize: 14; textColor: "#88FF88"; color: "transparent"
                    KeyNavigation.backtab: name; KeyNavigation.tab: session
                    Keys.onPressed: { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { sddm.login(name.text, password.text, sessionIndex); event.accepted = true } }
                }
            }
            Row {
                width: parent.width; spacing: 8
                Column {
                    width: parent.width; spacing: 4
                    Text { text: textConstants.session; color: "#88FF88"; font.bold: true; font.pixelSize: 12 }
                    ComboBox { id: session; width: parent.width; height: 30; font.pixelSize: 14; color: "transparent"; model: sessionModel; index: sessionModel.lastIndex; KeyNavigation.backtab: password; KeyNavigation.tab: loginButton }
                }
            }
            Text { id: errorMessage; anchors.horizontalCenter: parent.horizontalCenter; text: textConstants.prompt; font.pixelSize: 10; color: "#88FF88" }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                Button { id: loginButton;    text: textConstants.login;  width: 73; height: 75; color: "transparent"; textColor: "green";  onClicked: sddm.login(name.text, password.text, sessionIndex); KeyNavigation.backtab: session;        KeyNavigation.tab: shutdownButton }
                Button { id: rebootButton;   text: textConstants.reboot; width: 73; height: 75; color: "transparent"; textColor: "yellow"; onClicked: sddm.reboot();                                       KeyNavigation.backtab: shutdownButton; KeyNavigation.tab: name }
                Button { id: shutdownButton; text: "Power";              width: 73; height: 75; color: "transparent"; textColor: "red";    onClicked: sddm.powerOff();                                     KeyNavigation.backtab: loginButton;    KeyNavigation.tab: rebootButton }
            }
        }
    }
    Component.onCompleted: { if (name.text === "") name.focus = true; else password.focus = true }
}
QMLEOF
fi

ok "Main.qml Qt${QT_VERSION} écrit."

# ── Vérification complète des fichiers installés ──────────────────────────────
echo ""
info "Vérification des fichiers du thème..."
nb_manquants=0
for check_f in Main.qml theme.conf metadata.desktop loginterminalc.png; do
    if [[ -f "${THEME_DIR}/${check_f}" ]]; then
        ok "  ${check_f}  ($(du -h "${THEME_DIR}/${check_f}" | cut -f1))"
    else
        warn "  MANQUANT : ${check_f}"
        nb_manquants=$((nb_manquants + 1))
    fi
done
bg_check=$(grep -E '^background=' "${THEME_DIR}/theme.conf" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]' || true)
if [[ -n "$bg_check" ]] && [[ -f "${THEME_DIR}/${bg_check}" ]]; then
    ok "  vidéo : ${bg_check}  ($(du -h "${THEME_DIR}/${bg_check}" | cut -f1))"
else
    warn "  vidéo '${bg_check}' déclarée mais absente"
    nb_manquants=$((nb_manquants + 1))
fi
[[ $nb_manquants -gt 0 ]] && warn "${nb_manquants} fichier(s) manquant(s) — consultez ${INSTALL_LOG}"

chmod -R 755 "$THEME_DIR"
find "$THEME_DIR" -type f -exec chmod 644 {} \;
ok "Permissions appliquées."

# =============================================================================
#  ÉTAPE 7 — Configuration SDDM
# =============================================================================
step "7/8" "Écriture de la configuration SDDM..."

mkdir -p "$CONF_DIR" || die "Impossible de créer $CONF_DIR"

DISPLAY_SERVER_HINT="# DisplayServer=  ← laisser vide pour auto-détection"
[[ -n "${WAYLAND_DISPLAY:-}" ]] && DISPLAY_SERVER_HINT="# DisplayServer=wayland  ← décommentez si nécessaire"
[[ -n "${DISPLAY:-}" ]]         && DISPLAY_SERVER_HINT="# DisplayServer=x11  ← décommentez si nécessaire"

cat > "$CONF_FILE" <<EOF
# Configuration SDDM — sddm-video v${SCRIPT_VERSION} — PapaOursPolaire
# Généré le $(date '+%Y-%m-%d %H:%M:%S')
#
# Changer la vidéo : sudo bash sddm-video.sh --change-video
# Diagnostic       : bash sddm-video.sh --diagnose

[General]
Numlock=on
${DISPLAY_SERVER_HINT}
InputMethod=

[Theme]
Current=${THEME_NAME}

[Users]
MinimumUid=1000
MaximumUid=60000
EOF

ok "Config SDDM écrite : $CONF_FILE"

# ── Vérification et neutralisation des conflits ───────────────────────────────
echo ""
info "Vérification des conflits de configuration..."
conf_conflict=0
if [[ -d "$CONF_DIR" ]]; then
    while IFS= read -r f; do
        [[ "$f" == "$CONF_FILE" ]] && continue
        other_theme=$(grep -E '^\s*Current\s*=' "$f" 2>/dev/null | tail -1 || true)
        if [[ -n "$other_theme" ]]; then
            bname=$(basename "$f")
            if [[ "$bname" > "$(basename "$CONF_FILE")" ]]; then
                warn "CONFLIT : '$bname' vient APRÈS notre config et contient : $other_theme"
                warn "  → Supprimez ou renommez ce fichier pour que notre thème soit appliqué."
                conf_conflict=1
            else
                info "Co-existence OK (zzz- gagne) : ${bname} — ${other_theme}"
            fi
        fi
    done < <(find "$CONF_DIR" -maxdepth 1 -name "*.conf" 2>/dev/null | sort)
fi
if [[ -f "$SDDM_CONF_LEGACY" ]] && grep -q '^\[Theme\]' "$SDDM_CONF_LEGACY" 2>/dev/null; then
    warn "CONFLIT CRITIQUE : /etc/sddm.conf contient [Theme] (priorité absolue sur conf.d/)"
    conf_conflict=1
fi
[[ $conf_conflict -eq 0 ]] && ok "Aucun conflit de configuration."

# ── Correction IBus / Wayland ─────────────────────────────────────────────────
if command -v im-config &>/dev/null && [[ -n "${REAL_USER:-}" ]]; then
    sudo -u "$REAL_USER" im-config -n none 2>/dev/null && \
        ok "im-config -n none appliqué pour '$REAL_USER'" || \
        warn "im-config -n none a échoué (nécessite peut-être une session graphique)"
fi

if [[ -n "${REAL_HOME:-}" ]] && [[ -d "${REAL_HOME}" ]]; then
    echo "run_im none" > "${REAL_HOME}/.xinputrc"
    chown "${REAL_USER}:$(id -gn "$REAL_USER" 2>/dev/null || echo "$REAL_USER")" \
        "${REAL_HOME}/.xinputrc" 2>/dev/null || chown "$REAL_USER" "${REAL_HOME}/.xinputrc" || true
    ok "~/.xinputrc → run_im none"
    plasma_env_dir="${REAL_HOME}/.config/plasma-workspace/env"
    mkdir -p "$plasma_env_dir" 2>/dev/null || true
    cat > "${plasma_env_dir}/99-unset-im-xim.sh" <<'PLASMA_ENV'
#!/bin/sh
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
QT_IM_MODULE=
GTK_IM_MODULE=
ENVEOF
chmod 644 "/etc/environment.d/60-no-ibus-xim.conf"
ok "IBus/XIM désactivés dans /etc/environment.d/"

# ── Neutralisation finale /etc/sddm.conf ──────────────────────────────────────
if [[ -f "$SDDM_CONF_LEGACY" ]] && grep -q '^\[Theme\]' "$SDDM_CONF_LEGACY" 2>/dev/null; then
    warn "/etc/sddm.conf contient encore [Theme] — neutralisation..."
    cp "$SDDM_CONF_LEGACY" "${SDDM_CONF_LEGACY}${BACKUP_SUFFIX}" 2>/dev/null || true
    python3 - "$SDDM_CONF_LEGACY" <<'PYEOF' 2>/dev/null || mv "$SDDM_CONF_LEGACY" "${SDDM_CONF_LEGACY}.old"
import sys, re
path = sys.argv[1]
with open(path) as f: content = f.read()
content = re.sub(r'\[Theme\][^\[]*', '', content, flags=re.DOTALL)
with open(path, 'w') as f: f.write(content.strip() + '\n')
PYEOF
    ok "Section [Theme] retirée de /etc/sddm.conf"
fi

echo ""
info "Configs actives dans ${CONF_DIR}/ :"
find "$CONF_DIR" -maxdepth 1 -name "*.conf" 2>/dev/null | sort | while IFS= read -r f; do
    cur=$(grep -E '^\s*Current\s*=' "$f" 2>/dev/null | tail -1 || true)
    [[ -n "$cur" ]] && echo -e "    ${YEL}$(basename "$f")${NC}  ←  $cur" || echo "    $(basename "$f")"
done

# =============================================================================
#  ÉTAPE 8 — Activation du service SDDM
# =============================================================================
step "8/8" "Activation du service SDDM..."

if command -v systemctl &>/dev/null && systemctl --version &>/dev/null 2>&1; then
    for dm in gdm gdm3 lightdm lxdm xdm ly; do
        systemctl is-enabled "$dm" &>/dev/null 2>&1 && {
            echo "$dm" > /tmp/sddm-video-prev-dm
            info "Désactivation de $dm..."
            systemctl disable --now "$dm" 2>/dev/null || true
        } || true
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
    warn "Init system non reconnu — activez SDDM manuellement"
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
echo -e "  ${GRN}Vidéo      :${NC} ${FILENAME}"
echo -e "  ${GRN}Thème      :${NC} ${THEME_DIR}"
echo -e "  ${GRN}Config     :${NC} ${CONF_FILE}"
echo -e "  ${GRN}Distro     :${NC} $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo inconnue)"
echo ""
echo -e "  ${CYN}Commandes utiles :${NC}"
echo -e "    sudo bash sddm-video.sh --change-video   # changer la vidéo"
echo -e "    bash sddm-video.sh --diagnose            # diagnostic"
echo -e "    sudo bash sddm-video.sh --uninstall      # désinstaller"
echo ""
echo -e "  ${CYN}Test sans redémarrer :${NC}"
if [[ "$QT_VERSION" == "6" ]]; then
    echo -e "    sddm-greeter-qt6 --test-mode --theme ${THEME_DIR}"
else
    echo -e "    sddm-greeter --test-mode --theme ${THEME_DIR}"
fi
echo ""

generate_log_report

echo ""
read -rp "  Redémarrer SDDM maintenant ? [o/N] : " REP || REP=""
[[ "$REP" =~ ^[Oo]$ ]] && _restart_sddm
echo ""
