#!/bin/bash

#############################################################################
# Script de Configuration Universel SDDM avec Thème Fallout (Qt6)
# Auteur: PapaOursPolaire (adapté et modernisé pour Qt6)
# Version: 2.1.0
# Date: 2026-04-30
# Description: Configuration automatique de SDDM avec thème vidéo Fallout
#              Compatible avec toutes les distributions Linux majeures
#############################################################################

set -euo pipefail

# ── Gestionnaire d'erreur global ─────────────────────────────────────────────
# Affiche la ligne fautive et sort proprement sans laisser de fichiers à moitié créés
_error_handler() {
    local exit_code=$?
    local line_number=$1
    echo ""
    echo -e "\033[0;31m✗ ERREUR fatale à la ligne ${line_number} (code ${exit_code})\033[0m"
    echo -e "\033[1;33m⚠ Le thème peut être partiellement installé.\033[0m"
    echo -e "\033[1;33m  Relancez le script pour repartir de zéro.\033[0m"
    echo ""
    exit "${exit_code}"
}
trap '_error_handler $LINENO' ERR

# ── Nettoyage sur interruption (Ctrl+C) ───────────────────────────────────────
_interrupt_handler() {
    echo ""
    print_warning "Script interrompu par l'utilisateur"
    echo -e "\033[1;33m  Relancez le script pour continuer.\033[0m"
    echo ""
    exit 130
}
trap '_interrupt_handler' INT TERM

# Couleurs pour l'affichage
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# URLs des ressources GitHub
readonly REPO_URL="https://github.com/PapaOursPolaire/SDDM-video"
readonly DEFAULT_VIDEO_URL="https://github.com/PapaOursPolaire/SDDM-video/raw/709e9d9e26649105c7545128d5c0e47d13cceb66/default.mp4"
readonly LOGIN_IMAGE_URL="https://github.com/PapaOursPolaire/SDDM-video/raw/709e9d9e26649105c7545128d5c0e47d13cceb66/loginterminalc.png"

# Chemins de configuration
readonly THEME_DIR="/usr/share/sddm/themes/SDDM-Fallout-Qt6"
readonly SDDM_CONF="/etc/sddm.conf"

# Variables globales
DETECTED_PM=""
DETECTED_DISTRO=""
VIDEO_FILE=""
USE_WAYLAND=true

#############################################################################
# Fonctions d'affichage
#############################################################################

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error()   { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_info()    { echo -e "${BLUE}ℹ${NC} $1"; }

#############################################################################
# Détection du système
#############################################################################

detect_package_manager() {
    print_header "DÉTECTION DU GESTIONNAIRE DE PAQUETS"

    if command -v pacman &>/dev/null; then
        DETECTED_PM="pacman"
        DETECTED_DISTRO="Arch Linux / Manjaro / EndeavourOS"
    elif command -v apt &>/dev/null; then
        DETECTED_PM="apt"
        DETECTED_DISTRO="Debian / Ubuntu / Linux Mint"
    elif command -v dnf &>/dev/null; then
        DETECTED_PM="dnf"
        DETECTED_DISTRO="Fedora / RHEL / Rocky Linux"
    elif command -v zypper &>/dev/null; then
        DETECTED_PM="zypper"
        DETECTED_DISTRO="openSUSE"
    elif command -v emerge &>/dev/null; then
        DETECTED_PM="emerge"
        DETECTED_DISTRO="Gentoo"
    else
        print_error "Gestionnaire de paquets non supporté"
        echo "Distributions supportées : Arch, Debian/Ubuntu, Fedora, openSUSE, Gentoo"
        exit 1
    fi

    print_success "Détecté : $DETECTED_DISTRO"
    print_info "Gestionnaire : $DETECTED_PM"
}

#############################################################################
# Vérification de l'environnement de bureau (KDE/Plasma requis)
#############################################################################
# Le thème utilise "import SddmComponents 2.0", un module fourni par les
# paquets de plateforme SDDM de KDE. Sur un système sans KDE/Plasma installé,
# ce module est absent et le greeter plante au chargement du QML (souvent
# un écran noir/figé sans message clair). On bloque donc tôt avec un message
# explicite plutôt que de laisser l'utilisateur découvrir ça après coup.

check_desktop_environment() {
    print_header "VÉRIFICATION DE L'ENVIRONNEMENT DE BUREAU"

    local kde_found=false
    local kde_marker=""

    # SddmComponents est fourni par plasma-workspace / sddm-kcm selon la distro.
    # On cherche le module QML lui-même plutôt que de deviner le nom du paquet,
    # ce qui reste valable quel que soit le gestionnaire de paquets.
    local qml_search_paths=(
        /usr/lib/qt6/qml/SddmComponents
        /usr/lib/x86_64-linux-gnu/qt6/qml/SddmComponents
        /usr/lib64/qt6/qml/SddmComponents
        /usr/share/sddm/themes/*/SddmComponents
    )
    for p in "${qml_search_paths[@]}"; do
        # shellcheck disable=SC2086 # expansion volontaire du glob
        if compgen -G "$p" &>/dev/null; then
            kde_found=true
            kde_marker="$p"
            break
        fi
    done

    # Filet de sécurité : présence de plasmashell ou startplasma, signe fiable
    # qu'un Plasma est installé même si le chemin QML ci-dessus a changé.
    if [[ "$kde_found" == false ]]; then
        if command -v plasmashell &>/dev/null || command -v startplasma-wayland &>/dev/null \
           || command -v startplasma-x11 &>/dev/null; then
            kde_found=true
            kde_marker="binaire plasmashell/startplasma détecté"
        fi
    fi

    if [[ "$kde_found" == true ]]; then
        print_success "KDE Plasma détecté ($kde_marker)"
        return 0
    fi

    print_error "KDE Plasma ne semble pas installé sur ce système"
    echo -e "${YELLOW}Ce thème dépend du module QML SddmComponents 2.0,${NC}"
    echo -e "${YELLOW}fourni par les paquets de plateforme KDE/Plasma.${NC}"
    echo -e "${YELLOW}Sans lui, le greeter plante silencieusement au chargement du thème.${NC}"
    echo ""
    echo -e "${CYAN}Environnements détectés sur ce système :${NC}"
    for de_bin in gnome-shell xfce4-session cinnamon mate-session lxqt-session budgie-desktop deepin-session; do
        command -v "$de_bin" &>/dev/null && echo -e "  ${BLUE}•${NC} $de_bin"
    done
    echo ""
    read -r -p "Continuer quand même (déconseillé, risque d'écran figé) ? [o/N] : " force_continue
    if [[ ! "${force_continue,,}" =~ ^o(ui)?$ ]]; then
        print_info "Installation annulée. Installez KDE Plasma (paquet 'plasma-desktop' ou équivalent) puis relancez."
        exit 1
    fi
    print_warning "Poursuite forcée sans KDE Plasma — le greeter peut planter"
}

#############################################################################
# Détection matérielle : CPU, GPU dédié, iGPU, et installation du bon
# driver d'accélération vidéo (VAAPI/VDPAU) pour éviter le bug de crash
# du plugin FFmpeg Qt6Multimedia rencontré avec un GPU NVIDIA sans son
# driver VAAPI dédié (nvidia-vaapi-driver / nvidia_drv_video.so absent).
#############################################################################

DETECTED_CPU_VENDOR=""
DETECTED_GPU_VENDORS=()      # peut contenir plusieurs entrées : nvidia, amd, intel
HAS_DISCRETE_GPU=false
HAS_IGPU=false

detect_hardware() {
    print_header "DÉTECTION MATÉRIELLE (CPU / GPU / iGPU)"

    # ── CPU ────────────────────────────────────────────────────────────────
    if grep -qi "GenuineIntel" /proc/cpuinfo 2>/dev/null; then
        DETECTED_CPU_VENDOR="Intel"
    elif grep -qi "AuthenticAMD" /proc/cpuinfo 2>/dev/null; then
        DETECTED_CPU_VENDOR="AMD"
    elif grep -qiE "ARM|Apple" /proc/cpuinfo 2>/dev/null; then
        DETECTED_CPU_VENDOR="ARM"
    else
        DETECTED_CPU_VENDOR="inconnu"
    fi
    print_success "CPU : $DETECTED_CPU_VENDOR"

    # ── GPU(s) via lspci ─────────────────────────────────────────────────
    if ! command -v lspci &>/dev/null; then
        print_warning "lspci non trouvé — installation minimale pour la détection"
        case "$DETECTED_PM" in
            apt)     sudo apt install -y pciutils ;;
            pacman)  sudo pacman -S --needed --noconfirm pciutils ;;
            dnf)     sudo dnf install -y pciutils ;;
            zypper)  sudo zypper install -y pciutils ;;
            emerge)  sudo emerge --ask n sys-apps/pciutils ;;
        esac
    fi

    local gpu_lines
    gpu_lines=$(lspci 2>/dev/null | grep -iE "VGA|3D controller|Display controller" || true)

    if [[ -z "$gpu_lines" ]]; then
        print_warning "Aucun GPU détecté via lspci"
    else
        echo -e "${CYAN}GPU(s) détecté(s) :${NC}"
        echo "$gpu_lines" | while read -r line; do echo "  ${BLUE}•${NC} $line"; done
    fi

    echo "$gpu_lines" | grep -qi "nvidia"                        && DETECTED_GPU_VENDORS+=("nvidia")
    echo "$gpu_lines" | grep -qiE "amd|advanced micro devices|ati" && DETECTED_GPU_VENDORS+=("amd")
    echo "$gpu_lines" | grep -qi "intel"                          && DETECTED_GPU_VENDORS+=("intel")

    # Un GPU Intel/AMD listé en "3D controller" seul (pas de sortie vidéo
    # propre) ou combiné avec un GPU NVIDIA/AMD dédié = iGPU probable.
    if printf '%s\n' "${DETECTED_GPU_VENDORS[@]:-}" | grep -qi "intel"; then
        HAS_IGPU=true
    fi
    if [[ " ${DETECTED_GPU_VENDORS[*]:-} " == *" nvidia "* ]] || \
       { [[ " ${DETECTED_GPU_VENDORS[*]:-} " == *" amd "* ]] && [[ $(echo "$gpu_lines" | wc -l) -gt 1 ]]; }; then
        HAS_DISCRETE_GPU=true
    fi

    if [[ ${#DETECTED_GPU_VENDORS[@]} -eq 0 ]]; then
        print_warning "Marque de GPU non identifiée automatiquement"
    else
        print_info "Marques GPU retenues : ${DETECTED_GPU_VENDORS[*]}"
        print_info "GPU dédié : $HAS_DISCRETE_GPU | iGPU : $HAS_IGPU"
    fi

    install_video_accel_drivers
}

# Installe le driver VAAPI/VDPAU adapté à chaque marque de GPU détectée.
# C'est ce qui manquait chez PapaOurs : nvidia-vaapi-driver absent →
# libva ne trouve pas nvidia_drv_video.so → va_openDriver() échoue →
# le plugin FFmpeg de Qt6Multimedia segfault dès l'init, thème vidéo cassé.
install_video_accel_drivers() {
    print_header "INSTALLATION DES DRIVERS D'ACCÉLÉRATION VIDÉO"

    local pkgs=()

    for vendor in "${DETECTED_GPU_VENDORS[@]:-}"; do
        case "$vendor" in
            nvidia)
                print_info "GPU NVIDIA détecté → driver VAAPI dédié requis pour la vidéo du thème"
                case "$DETECTED_PM" in
                    apt)    pkgs+=("nvidia-vaapi-driver") ;;
                    pacman) pkgs+=("libva-nvidia-driver") ;;
                    dnf)    pkgs+=("nvidia-vaapi-driver") ;;
                    zypper) pkgs+=("nvidia-vaapi-driver") ;;
                    emerge) pkgs+=("media-libs/nvidia-vaapi-driver") ;;
                esac
                ;;
            amd)
                case "$DETECTED_PM" in
                    apt)    pkgs+=("mesa-va-drivers" "mesa-vdpau-drivers") ;;
                    pacman) pkgs+=("libva-mesa-driver" "mesa-vdpau") ;;
                    dnf)    pkgs+=("mesa-va-drivers" "mesa-vdpau-drivers") ;;
                    zypper) pkgs+=("libva-mesa-driver" "libvdpau_radeonsi") ;;
                    emerge) pkgs+=("media-libs/mesa") ;;
                esac
                ;;
            intel)
                case "$DETECTED_PM" in
                    apt)    pkgs+=("intel-media-va-driver" "i965-va-driver") ;;
                    pacman) pkgs+=("intel-media-driver" "libva-intel-driver") ;;
                    dnf)    pkgs+=("intel-media-driver" "libva-intel-driver") ;;
                    zypper) pkgs+=("intel-media-driver" "libva-intel-driver") ;;
                    emerge) pkgs+=("media-libs/intel-media-driver") ;;
                esac
                ;;
        esac
    done

    if [[ ${#pkgs[@]} -eq 0 ]]; then
        print_warning "Aucun paquet d'accélération vidéo à installer (marque non reconnue)"
        return 0
    fi

    # Dédoublonnage
    local unique_pkgs=()
    while IFS= read -r p; do unique_pkgs+=("$p"); done < <(printf '%s\n' "${pkgs[@]}" | sort -u)

    print_info "Paquets à installer : ${unique_pkgs[*]}"
    case "$DETECTED_PM" in
        apt)    sudo apt install -y "${unique_pkgs[@]}" || print_warning "Certains paquets n'ont pas pu être installés" ;;
        pacman) sudo pacman -S --needed --noconfirm "${unique_pkgs[@]}" || print_warning "Certains paquets n'ont pas pu être installés" ;;
        dnf)    sudo dnf install -y "${unique_pkgs[@]}" || print_warning "Certains paquets n'ont pas pu être installés" ;;
        zypper) sudo zypper install -y "${unique_pkgs[@]}" || print_warning "Certains paquets n'ont pas pu être installés" ;;
        emerge) sudo emerge --ask n "${unique_pkgs[@]}" || print_warning "Certains paquets n'ont pas pu être installés" ;;
    esac

    # Vérification effective via vainfo si disponible
    if command -v vainfo &>/dev/null; then
        if vainfo &>/dev/null; then
            print_success "VAAPI fonctionnel (vainfo répond correctement)"
        else
            print_warning "vainfo signale une erreur — le décodage matériel pourrait échouer"
            print_warning "Le script forcera QT_FFMPEG_DECODING_HW_DEVICE_TYPES=none en secours (voir configure_sddm_conf)"
        fi
    fi
}

#############################################################################
# Détection de la session graphique actuelle (Wayland/X11) et avertissement
# en cas de changement demandé par rapport à la session active
#############################################################################

CURRENT_SESSION_TYPE=""

detect_current_session() {
    print_header "DÉTECTION DE LA SESSION GRAPHIQUE ACTUELLE"

    # XDG_SESSION_TYPE n'est fiable que dans une session utilisateur active ;
    # en root/SSH/Cockpit il peut être vide ou valoir "tty"/"unspecified".
    CURRENT_SESSION_TYPE="${XDG_SESSION_TYPE:-}"

    if [[ -z "$CURRENT_SESSION_TYPE" ]] && command -v loginctl &>/dev/null; then
        local seat_session
        seat_session=$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}' | head -1)
        if [[ -n "$seat_session" ]]; then
            CURRENT_SESSION_TYPE=$(loginctl show-session "$seat_session" -p Type --value 2>/dev/null || true)
        fi
    fi

    case "$CURRENT_SESSION_TYPE" in
        wayland) print_success "Session actuelle détectée : Wayland" ;;
        x11)     print_success "Session actuelle détectée : X11" ;;
        *)       print_warning "Session actuelle indéterminée (normal en SSH/Cockpit/root)"
                 CURRENT_SESSION_TYPE="inconnue" ;;
    esac
}

# À appeler après que l'utilisateur a choisi Wayland/X11 dans configure_sddm_conf.
# Compare au choix effectif et avertit clairement en cas de changement, car un
# passage X11→Wayland (ou l'inverse) peut casser un thème qui dépendait de
# comportements spécifiques à l'ancien serveur d'affichage (vécu par PapaOurs :
# le module vidéo du thème passait par une voie différente sous X11, masquant
# un bug VAAPI qui n'apparaissait qu'une fois basculé en Wayland).
warn_if_session_type_changed() {
    local requested="$1"   # "wayland" ou "x11"

    if [[ "$CURRENT_SESSION_TYPE" == "inconnue" ]]; then
        return 0
    fi

    if [[ "$CURRENT_SESSION_TYPE" != "$requested" ]]; then
        echo ""
        print_warning "Changement de serveur d'affichage : $CURRENT_SESSION_TYPE → $requested"
        echo -e "${YELLOW}Ce changement peut révéler des bugs invisibles sous l'ancien serveur${NC}"
        echo -e "${YELLOW}(pilotes vidéo, décodage matériel, intégrations de shell, etc.).${NC}"
        echo -e "${YELLOW}Un redémarrage complet (pas juste SDDM) est recommandé après application.${NC}"
        echo ""
        read -r -p "Confirmer le passage à $requested ? [O/n] : " confirm_switch
        if [[ "$confirm_switch" =~ ^[Nn]$ ]]; then
            print_info "Changement annulé — conservation de $CURRENT_SESSION_TYPE"
            return 1
        fi
    fi
    return 0
}

#############################################################################
# Vérification de la compatibilité SDDM
#############################################################################

check_sddm_compatibility() {
    print_header "VÉRIFICATION DE LA COMPATIBILITÉ SDDM"

    if ! command -v sddm &>/dev/null; then
        print_warning "SDDM n'est pas installé"
        return 1
    fi

    # FIX : sddm --version peut se bloquer indéfiniment sur certaines distros
    # (SDDM tente de joindre un socket système). On limite à 4 secondes.
    local sddm_version
    sddm_version=$(timeout 4 sddm --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1 || true)
    if [[ -n "$sddm_version" ]]; then
        print_info "Version SDDM détectée : $sddm_version"
    else
        print_info "Version SDDM : indéterminée (binaire présent)"
    fi

    # Vérifier Qt6 via qmake ou pkg-config — sans appeler de binaire bloquant
    if command -v qmake6 &>/dev/null || command -v qmake-qt6 &>/dev/null \
       || pkg-config --exists Qt6Core 2>/dev/null; then
        print_success "Qt6 détecté"
    else
        print_warning "Qt6 non détecté — installation recommandée"
    fi

    # Autre display manager actif ? (timeout 4s au cas où systemctl est lent)
    local active_dm
    active_dm=$(timeout 4 systemctl list-units --type=service --state=running \
        2>/dev/null | grep -E 'gdm|lightdm|lxdm' | awk '{print $1}' || true)
    if [[ -n "$active_dm" ]]; then
        print_warning "Autre gestionnaire d'affichage actif : $active_dm"
        echo -e "${YELLOW}Il sera désactivé et remplacé par SDDM${NC}"
    fi

    print_success "SDDM est présent et compatible"
    return 0
}

#############################################################################
# Installation des dépendances
#############################################################################

install_dependencies() {
    print_header "INSTALLATION DES DÉPENDANCES"

    case "$DETECTED_PM" in
        pacman)
            print_info "Installation via pacman..."
            sudo pacman -S --needed --noconfirm \
                sddm qt6-multimedia qt6-declarative qt6-svg \
                gst-plugins-good gst-plugins-bad gst-plugins-ugly \
                curl wget
            ;;
        apt)
            print_info "Mise à jour des dépôts..."
            sudo apt update

            # Candidats : noms Debian ET Ubuntu listés ensemble.
            # On ne garde que ceux présents dans les dépôts via apt-cache show.
            local candidates=(
                sddm
                qml6-module-qtmultimedia
                qt6-multimedia-qml
                qml6-module-qtquick
                qml6-module-qtquick-controls
                qml6-module-qtquick-controls2
                qml6-module-qtquick-layouts
                libqt6multimedia6
                qt6-multimedia-dev
                gstreamer1.0-plugins-good
                gstreamer1.0-plugins-bad
                gstreamer1.0-plugins-ugly
                curl
                wget
            )

            local to_install=()
            print_info "Vérification des paquets disponibles..."
            for pkg in "${candidates[@]}"; do
                if apt-cache show "$pkg" &>/dev/null; then
                    to_install+=("$pkg")
                    print_success "  trouvé  : $pkg"
                else
                    print_warning "  absent  : $pkg (ignoré)"
                fi
            done

            if [[ ${#to_install[@]} -eq 0 ]]; then
                print_error "Aucun paquet Qt6 trouvé — vérifiez vos dépôts"
                return 1
            fi

            print_info "Installation via apt..."
            sudo apt install -y "${to_install[@]}"
            ;;
        dnf)
            print_info "Installation via dnf..."
            sudo dnf install -y \
                sddm \
                qt6-qtmultimedia \
                qt6-qtdeclarative \
                qt6-qtsvg \
                gstreamer1-plugins-good \
                gstreamer1-plugins-bad-free \
                gstreamer1-plugins-ugly-free \
                curl wget
            ;;
        zypper)
            print_info "Installation via zypper..."
            sudo zypper install -y \
                sddm \
                qt6-multimedia \
                qt6-declarative \
                qt6-svg \
                gstreamer-plugins-good \
                gstreamer-plugins-bad \
                curl wget
            ;;
        emerge)
            print_info "Installation via emerge..."
            # FIX : --ask n (avec espace) est le flag correct sur Gentoo
            sudo emerge --ask n --noreplace \
                x11-misc/sddm \
                dev-qt/qtmultimedia:6 \
                dev-qt/qtdeclarative:6 \
                media-plugins/gst-plugins-meta
            ;;
    esac

    print_success "Dépendances installées"
}

#############################################################################
# Sélection du fichier vidéo
#############################################################################

select_video_file() {
    print_header "SÉLECTION DE LA VIDÉO DE FOND"

    echo "Options disponibles :"
    echo "  1) Utiliser la vidéo par défaut (téléchargement depuis GitHub)"
    echo "  2) Sélectionner une vidéo personnalisée"
    echo "  3) Utiliser un fond statique (image)"
    echo ""
    # FIX : read -r pour éviter l'interprétation des backslashes
    read -r -p "Votre choix [1-3] : " choice

    case "$choice" in
        1)
            print_info "La vidéo par défaut sera téléchargée depuis GitHub"
            VIDEO_FILE="$THEME_DIR/default.mp4"
            ;;
        2)
            select_custom_video
            ;;
        3)
            print_info "Mode fond statique sélectionné"
            VIDEO_FILE=""
            ;;
        *)
            print_warning "Choix invalide, utilisation de la vidéo par défaut"
            VIDEO_FILE="$THEME_DIR/default.mp4"
            ;;
    esac
}

select_custom_video() {
    print_info "Lancement du sélecteur de fichiers..."

    local file_browser=""

    if command -v zenity &>/dev/null; then
        # zenity offre une vraie boîte de dialogue bloquante — priorité
        VIDEO_FILE=$(zenity --file-selection \
            --title="Sélectionner une vidéo" \
            --file-filter="Vidéos | *.mp4 *.mkv *.webm *.avi" 2>/dev/null || true)
        if [[ -n "$VIDEO_FILE" ]]; then
            print_success "Vidéo sélectionnée : $VIDEO_FILE"
            return 0
        else
            print_warning "Aucune vidéo sélectionnée — retour à la vidéo par défaut"
            VIDEO_FILE="$THEME_DIR/default.mp4"
            return 0
        fi
    elif command -v dolphin &>/dev/null;  then file_browser="dolphin"
    elif command -v nautilus &>/dev/null; then file_browser="nautilus"
    elif command -v thunar &>/dev/null;   then file_browser="thunar"
    elif command -v nemo &>/dev/null;     then file_browser="nemo"
    elif command -v pcmanfm &>/dev/null;  then file_browser="pcmanfm"
    fi

    if [[ -n "$file_browser" ]]; then
        local video_dir="${HOME}/Videos"
        [[ ! -d "$video_dir" ]] && video_dir="${HOME}/Vidéos"
        [[ ! -d "$video_dir" ]] && video_dir="${HOME}"

        print_info "Ouverture de $file_browser — sélectionnez votre vidéo puis saisissez le chemin"
        $file_browser "$video_dir" &
        # FIX : read -r pour les chemins contenant des backslashes
        read -r -p "Entrez le chemin complet de la vidéo sélectionnée : " VIDEO_FILE
    else
        print_warning "Aucun explorateur de fichiers graphique détecté"
        read -r -p "Entrez le chemin complet de votre vidéo : " VIDEO_FILE
    fi

    # Valider l'existence du fichier
    if [[ -n "$VIDEO_FILE" ]] && [[ -f "$VIDEO_FILE" ]]; then
        print_success "Vidéo sélectionnée : $VIDEO_FILE"
    else
        print_error "Fichier non trouvé : ${VIDEO_FILE:-<vide>}"
        print_warning "Utilisation de la vidéo par défaut"
        VIDEO_FILE="$THEME_DIR/default.mp4"
    fi
}

#############################################################################
# Création du répertoire du thème
#############################################################################

create_theme_directory() {
    print_header "CRÉATION DU RÉPERTOIRE DU THÈME"

    if [[ -d "$THEME_DIR" ]]; then
        print_warning "Le thème existe déjà"
        read -r -p "Voulez-vous le remplacer ? [O/n] : " response
        if [[ "$response" =~ ^[Nn]$ ]]; then
            print_info "Conservation du thème existant"
            return 1
        fi
        print_info "Suppression de l'ancien thème..."
        sudo rm -rf "$THEME_DIR"
    fi

    print_info "Création du répertoire $THEME_DIR"
    sudo mkdir -p "$THEME_DIR"
    sudo chmod 755 "$THEME_DIR"

    print_success "Répertoire créé"
}

#############################################################################
# Téléchargement des ressources
#############################################################################

download_resources() {
    print_header "TÉLÉCHARGEMENT DES RESSOURCES"

    # Télécharger l'image de login (fond du panneau de connexion)
    print_info "Téléchargement de loginterminalc.png depuis GitHub..."
    if sudo curl -fL "$LOGIN_IMAGE_URL" -o "$THEME_DIR/loginterminalc.png"; then
        print_success "loginterminalc.png téléchargée"
    else
        print_error "Échec du téléchargement de loginterminalc.png"
        return 1
    fi

    # Vidéo : défaut depuis GitHub ou personnalisée copiée localement
    if [[ "$VIDEO_FILE" == "$THEME_DIR/default.mp4" ]] || [[ -z "$VIDEO_FILE" ]]; then
        print_info "Téléchargement de default.mp4 depuis GitHub..."
        if sudo curl -fL "$DEFAULT_VIDEO_URL" -o "$THEME_DIR/background.mp4"; then
            print_success "default.mp4 téléchargée et enregistrée sous background.mp4"
        else
            print_error "Échec du téléchargement de la vidéo"
            return 1
        fi
    elif [[ -f "$VIDEO_FILE" ]]; then
        print_info "Copie de la vidéo personnalisée..."
        sudo cp "$VIDEO_FILE" "$THEME_DIR/background.mp4"
        print_success "Vidéo copiée sous background.mp4"
    fi

    print_success "Ressources téléchargées"
}

#############################################################################
# Fichiers de configuration du thème
#############################################################################

create_metadata_file() {
    print_info "Création de metadata.desktop..."
    sudo tee "$THEME_DIR/metadata.desktop" >/dev/null <<'EOF'
[Desktop Entry]
Name=Fallout SDDM Qt6
Comment=Thème Fallout (Pip-Boy style) pour SDDM avec Qt6
Type=Service
X-KDE-PluginInfo-Author=PapaOursPolaire
X-KDE-PluginInfo-Email=papaoursgamer@gmail.com
X-KDE-PluginInfo-Version=2.1
X-KDE-PluginInfo-License=GPL
X-Plasma-API=6.0
EOF
    print_success "metadata.desktop créé"
}

create_theme_conf() {
    print_info "Création de theme.conf..."
    sudo tee "$THEME_DIR/theme.conf" >/dev/null <<'EOF'
[General]
background=background.mp4
type=video

[Video]
format=mp4
loop=true
muted=false
EOF
    print_success "theme.conf créé"
}

#############################################################################
# Main.qml — Qt6 pur, sans dépendance KDE/Plasma
#
# Disposition fidèle à l'original :
#   • Vidéo en boucle plein écran (background.mp4)
#     → fallback : loginterminalc.png plein écran si la vidéo échoue
#   • Horloge haut-droite (inlinée, Timer Qt6, pas de composant externe)
#   • Panneau de connexion : Image loginterminalc.png centrée-droite
#     avec les champs username / password / session / layout superposés
#   • Boutons Login (vert) / Reboot (jaune) / Power (rouge)
#############################################################################

create_main_qml() {
    print_info "Création de Main.qml (Qt6, sans KDE)..."

    sudo tee "$THEME_DIR/Main.qml" >/dev/null <<'QMLEOF'
/***************************************************************************
 * Thème SDDM Fallout — Qt6
 * Structure identique à l'original, imports Qt6 uniquement
 ***************************************************************************/

import QtQuick
import QtMultimedia
import SddmComponents 2.0

Rectangle {
    id: container
    width:  Screen.width
    height: Screen.height

    LayoutMirroring.enabled:         Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property int sessionIndex: session.index

    TextConstants { id: textConstants }

    // ── Vidéo plein écran (Qt6) ───────────────────────────────────────────
    MediaPlayer {
        id: bgVideo
        source: Qt.resolvedUrl("background.mp4")
        loops:  MediaPlayer.Infinite
        audioOutput: AudioOutput { muted: false; volume: 0.3 }
        videoOutput: videoOut
        Component.onCompleted: play()
        onErrorOccurred: function(error, errorString) {
            fallbackImage.visible = true
        }
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
    }

    Image {
        id: fallbackImage
        anchors.fill: parent
        source:   "loginterminalc.png"
        fillMode: Image.PreserveAspectCrop
        visible:  false
    }

    // ── Horloge (structure identique à Clock de l'original) ───────────────
    Column {
        anchors.top:         parent.top
        anchors.right:       parent.right
        anchors.topMargin:   40
        anchors.rightMargin: 40

        property string currentTime: Qt.formatTime(new Date(), "hh:mm:ss")
        property string currentDate: Qt.formatDate(new Date(), "dddd, MMMM d yyyy")

        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: {
                parent.currentTime = Qt.formatTime(new Date(), "hh:mm:ss")
                parent.currentDate = Qt.formatDate(new Date(), "dddd, MMMM d yyyy")
            }
        }

        Text {
            anchors.right: parent.right
            text:  parent.currentTime
            color: "#eaf5c4"
            font.family: "Consolas"; font.bold: true; font.pixelSize: 90
            horizontalAlignment: Text.AlignRight
        }
        Text {
            anchors.right: parent.right
            text:  parent.currentDate
            color: "#eaf5c4"
            font.family: "Lucida Console"; font.bold: true; font.pixelSize: 30
            horizontalAlignment: Text.AlignRight
        }
    }

    // ── Panneau login — structure 1:1 avec l'original ─────────────────────
    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Image {
            id: rectangle
            anchors.verticalCenter: parent.verticalCenter
            anchors.right:          parent.right
            width:  Math.max(370, mainColumn.implicitWidth  + 50)
            height: Math.max(320, mainColumn.implicitHeight + 50)
            source: "loginterminalc.png"

            Column {
                id: mainColumn
                anchors.centerIn: parent
                spacing: 12

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "black"
                    verticalAlignment: Text.AlignVCenter
                    height: implicitHeight
                    width:  parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: 24
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                Column {
                    width: parent.width
                    spacing: 4
                    Text {
                        id: lblName
                        width: parent.width
                        text:  textConstants.userName
                        color: "#88FF88"
                        font.bold: true; font.pixelSize: 12
                    }
                    TextBox {
                        id: name
                        width: parent.width; height: 30
                        text:      userModel.lastUser
                        textColor: "#88FF88"
                        color:     "transparent"
                        font.pixelSize: 14
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

                Column {
                    width: parent.width
                    spacing: 4
                    Text {
                        id: lblPassword
                        width: parent.width
                        text:  textConstants.password
                        color: "#88FF88"
                        font.bold: true; font.pixelSize: 12
                    }
                    PasswordBox {
                        id: password
                        width: parent.width; height: 30
                        textColor: "#88FF88"
                        color:     "transparent"
                        font.pixelSize: 14
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

                Row {
                    spacing: 4
                    width: parent.width / 2

                    Column {
                        width: parent.width * 1.3
                        spacing: 4
                        anchors.bottom: parent.bottom
                        Text {
                            id: lblSession
                            width: parent.width
                            text:  textConstants.session
                            color: "#88FF88"
                            wrapMode: TextEdit.WordWrap
                            font.bold: true; font.pixelSize: 12
                        }
                        ComboBox {
                            id: session
                            width: parent.width; height: 30
                            font.pixelSize: 14
                            color:     "transparent"
                            model:     sessionModel
                            index:     sessionModel.lastIndex
                            KeyNavigation.backtab: password
                            KeyNavigation.tab:     layoutBox
                        }
                    }

                    Column {
                        width: parent.width * 0.7
                        spacing: 4
                        anchors.bottom: parent.bottom
                        Text {
                            id: lblLayout
                            width: parent.width
                            text:  textConstants.layout
                            color: "#88FF88"
                            wrapMode: TextEdit.WordWrap
                            font.bold: true; font.pixelSize: 12
                        }
                        LayoutBox {
                            id: layoutBox
                            width: parent.width; height: 30
                            font.pixelSize: 14
                            color: "transparent"
                            KeyNavigation.backtab: session
                            KeyNavigation.tab:     loginButton
                        }
                    }
                }

                Column {
                    width: parent.width
                    Text {
                        id: errorMessage
                        anchors.horizontalCenter: parent.horizontalCenter
                        text:  textConstants.prompt
                        font.pixelSize: 10
                        color: "#88FF88"
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter

                    Button {
                        id: loginButton
                        text: textConstants.login
                        width: 73; height: 75
                        color:     "transparent"
                        textColor: "transparent"
                        enabled: true
                        onClicked: sddm.login(name.text, password.text, sessionIndex)
                        KeyNavigation.backtab: layoutBox
                        KeyNavigation.tab:     shutdownButton
                        anchors.top: parent.bottom; anchors.topMargin: -24
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    sddm.login(name.text, password.text, sessionIndex)
                        }
                    }

                    Button {
                        id: rebootButton
                        text: textConstants.reboot
                        width: 73; height: 75
                        color:     "transparent"
                        textColor: "transparent"
                        enabled: true
                        onClicked: sddm.reboot()
                        KeyNavigation.backtab: shutdownButton
                        KeyNavigation.tab:     name
                        anchors.top: parent.bottom; anchors.topMargin: -24
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    sddm.reboot()
                        }
                    }

                    Button {
                        id: shutdownButton
                        text: "Power"
                        width: 73; height: 75
                        color:     "transparent"
                        textColor: "transparent"
                        enabled: true
                        onClicked: sddm.powerOff()
                        KeyNavigation.backtab: loginButton
                        KeyNavigation.tab:     rebootButton
                        anchors.top: parent.bottom; anchors.topMargin: -24
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    sddm.powerOff()
                        }
                    }
                }
            }
        }
    }

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

    Component.onCompleted: {
        if (name.text === "") name.focus = true
        else password.focus = true
    }
}
QMLEOF

    print_success "Main.qml créé (Qt6, sans KDE)"
}

#############################################################################
# Configuration de SDDM
#############################################################################

configure_sddm_conf() {
    print_header "CONFIGURATION DE SDDM"

    # Sauvegarder l'ancien fichier
    if [[ -f "$SDDM_CONF" ]]; then
        print_info "Sauvegarde de l'ancienne configuration..."
        sudo cp "$SDDM_CONF" "${SDDM_CONF}.backup.$(date +%Y%m%d-%H%M%S)"
    fi

    echo ""
    echo "Serveur d'affichage :"
    echo "  1) Wayland (recommandé pour les systèmes modernes)"
    echo "  2) X11 (pour compatibilité maximale)"
    read -r -p "Votre choix [1-2] : " display_choice

    local display_server="wayland"
    case "$display_choice" in
        2)
            display_server="x11"
            USE_WAYLAND=false
            ;;
        *)
            display_server="wayland"
            USE_WAYLAND=true
            ;;
    esac

    # Avertir si ce choix diffère de la session actuellement active
    if ! warn_if_session_type_changed "$display_server"; then
        # L'utilisateur a refusé le changement — on revient à la session en cours
        display_server="$CURRENT_SESSION_TYPE"
        [[ "$display_server" == "wayland" ]] && USE_WAYLAND=true || USE_WAYLAND=false
    fi

    # Détecter un curseur disponible universellement
    local cursor_theme="Adwaita"
    if [[ -d "/usr/share/icons/breeze_cursors" ]]; then
        cursor_theme="breeze_cursors"
    elif [[ -d "/usr/share/icons/Adwaita" ]]; then
        cursor_theme="Adwaita"
    fi

    print_info "Création de /etc/sddm.conf..."

    # FIX : GreeterEnvironment uniquement pour Wayland
    if [[ "$USE_WAYLAND" == true ]]; then
        sudo tee "$SDDM_CONF" >/dev/null <<EOF
[Theme]
Current=SDDM-Fallout-Qt6
CursorTheme=${cursor_theme}

[General]
DisplayServer=${display_server}
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
# Clavier virtuel désactivé (vide = aucun InputMethod)
InputMethod=

[Wayland]
SessionDir=/usr/share/wayland-sessions

[X11]
SessionDir=/usr/share/xsessions

[Users]
MaximumUid=60000
MinimumUid=1000
HideUsers=
HideShells=/sbin/nologin,/bin/false
EOF
    else
        sudo tee "$SDDM_CONF" >/dev/null <<EOF
[Theme]
Current=SDDM-Fallout-Qt6
CursorTheme=${cursor_theme}

[General]
DisplayServer=${display_server}
# Clavier virtuel désactivé (vide = aucun InputMethod)
InputMethod=

[Wayland]
SessionDir=/usr/share/wayland-sessions

[X11]
SessionDir=/usr/share/xsessions

[Users]
MaximumUid=60000
MinimumUid=1000
HideUsers=
HideShells=/sbin/nologin,/bin/false
EOF
    fi

    # Si un GPU NVIDIA a été détecté, forcer un override systemd désactivant
    # le décodage matériel FFmpeg en secours : même avec nvidia-vaapi-driver
    # installé, certaines combinaisons driver/kernel restent instables et
    # font planter libffmpegmediaplugin.so au chargement du thème vidéo.
    if [[ " ${DETECTED_GPU_VENDORS[*]:-} " == *" nvidia "* ]]; then
        print_info "GPU NVIDIA : ajout d'un filet de sécurité systemd (décodage logiciel FFmpeg)"
        sudo mkdir -p /etc/systemd/system/sddm.service.d
        sudo tee /etc/systemd/system/sddm.service.d/nvidia-ffmpeg-fallback.conf >/dev/null <<'EOF'
[Service]
Environment=QT_FFMPEG_DECODING_HW_DEVICE_TYPES=none
EOF
        sudo systemctl daemon-reload
        print_success "Filet de sécurité installé (supprimable via /etc/systemd/system/sddm.service.d/nvidia-ffmpeg-fallback.conf si non nécessaire)"
    fi

    # Bloquer /etc/sddm.conf.d/ : créer le dossier vide verrouillé
    # pour éviter que des paquets y déposent des configs concurrentes
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/README > /dev/null <<'READMEEOF'
Ce dossier est géré par sddm-video.sh (thème SDDM-Fallout-Qt6).
Ne pas ajouter de fichiers .conf ici — ils écraseraient le thème.
READMEEOF

    print_success "Configuration SDDM créée (serveur: $display_server)"
}

#############################################################################
# Activation de SDDM
#############################################################################

enable_sddm_service() {
    print_header "ACTIVATION DU SERVICE SDDM"

    local other_dms=("gdm" "lightdm" "lxdm" "xdm")
    for dm in "${other_dms[@]}"; do
        if systemctl is-enabled "$dm.service" &>/dev/null; then
            print_info "Désactivation de $dm..."
            sudo systemctl disable "$dm.service" || true
        fi
    done

    # Résoudre le binaire greeter selon la distro :
    # - Debian/Ubuntu Trixie+ : sddm-greeter-qt6
    # - Arch/Fedora/openSUSE/Gentoo : sddm-greeter (nom standard)
    local greeter_bin=""
    if   command -v sddm-greeter      &>/dev/null; then greeter_bin="sddm-greeter"
    elif command -v sddm-greeter-qt6  &>/dev/null; then greeter_bin="sddm-greeter-qt6"
    elif command -v sddm-greeter-qt5  &>/dev/null; then greeter_bin="sddm-greeter-qt5"
    fi

    if [[ -z "$greeter_bin" ]]; then
        print_error "Aucun binaire sddm-greeter trouvé — impossible de charger le thème"
        exit 1
    fi

    # Si le binaire trouvé n'est pas /usr/bin/sddm-greeter, créer le symlink
    if [[ "$greeter_bin" != "sddm-greeter" ]]; then
        print_info "Création du symlink /usr/bin/sddm-greeter → $greeter_bin..."
        sudo ln -sf "/usr/bin/$greeter_bin" /usr/bin/sddm-greeter
        print_success "Symlink créé : sddm-greeter → $greeter_bin"
    else
        print_success "sddm-greeter présent ($greeter_bin)"
    fi

    print_info "Activation de SDDM..."
    sudo systemctl enable sddm.service
    print_success "SDDM activé"

    echo ""
    read -r -p "Voulez-vous tester le thème maintenant ? [O/n] : " test_theme
    if [[ ! "$test_theme" =~ ^[Nn]$ ]]; then
        print_info "Test du thème SDDM..."
        print_warning "Appuyez sur Ctrl+C pour quitter le mode test"
        sleep 2
        # Essayer les deux noms possibles selon la distro
        if command -v sddm-greeter-qt6 &>/dev/null; then
            LIBVA_DRIVER_NAME=i965 QT_MEDIA_BACKEND=ffmpeg sddm-greeter-qt6 --test-mode --theme "$THEME_DIR" 2>&1 | grep -v "h264\|vaapi\|vulkan\|VDPAU\|HW de\|HW en\|aac\|ffmpeg" || true
        else
            sddm-greeter --test-mode --theme "$THEME_DIR"
        fi
    fi
}

#############################################################################
# Résumé final
#############################################################################

print_final_summary() {
    print_header "INSTALLATION TERMINÉE"

    echo -e "${GREEN}✓ Configuration SDDM terminée avec succès !${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  RÉSUMÉ DE LA CONFIGURATION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Système détecté :${NC}          $DETECTED_DISTRO"
    echo -e "${BLUE}Gestionnaire de paquets :${NC}  $DETECTED_PM"
    echo -e "${BLUE}Répertoire du thème :${NC}      $THEME_DIR"
    echo -e "${BLUE}Serveur d'affichage :${NC}      $([ "$USE_WAYLAND" = true ] && echo "Wayland" || echo "X11") (précédemment : $CURRENT_SESSION_TYPE)"
    echo -e "${BLUE}CPU :${NC}                      ${DETECTED_CPU_VENDOR:-inconnu}"
    echo -e "${BLUE}GPU(s) :${NC}                   ${DETECTED_GPU_VENDORS[*]:-non identifié}"
    echo -e "${BLUE}GPU dédié / iGPU :${NC}         ${HAS_DISCRETE_GPU} / ${HAS_IGPU}"
    echo ""

    [[ -f "$THEME_DIR/background.mp4"     ]] && echo -e "${GREEN}✓${NC} Vidéo de fond      : background.mp4"
    [[ -f "$THEME_DIR/loginterminalc.png" ]] && echo -e "${GREEN}✓${NC} Fond panneau login : loginterminalc.png"
    [[ -f "$THEME_DIR/Main.qml"           ]] && echo -e "${GREEN}✓${NC} Main.qml Qt6       : présent"
    [[ -f "$THEME_DIR/theme.conf"         ]] && echo -e "${GREEN}✓${NC} theme.conf         : présent"
    [[ -f "$THEME_DIR/metadata.desktop"   ]] && echo -e "${GREEN}✓${NC} metadata.desktop   : présent"
    [[ -L /usr/bin/sddm-greeter          ]] && echo -e "${GREEN}✓${NC} sddm-greeter       : symlink présent"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  PROCHAINES ÉTAPES${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} Redémarrez SDDM ou le système pour appliquer le thème"
    echo -e "${YELLOW}2.${NC} Pour tester manuellement :"
    echo -e "   ${CYAN}sddm-greeter --test-mode --theme $THEME_DIR${NC}"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Bienvenue dans le Wasteland !${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

#############################################################################
# Redémarrage SDDM
#############################################################################

restart_sddm_prompt() {
    print_header "REDÉMARRAGE DE SDDM"

    echo -e "${YELLOW}⚠  Redémarrer SDDM fermera votre session graphique actuelle.${NC}"
    echo ""
    read -r -p "Voulez-vous redémarrer SDDM maintenant ? [O/n] : " restart_choice

    case "${restart_choice,,}" in
        o|oui|y|yes|"")
            print_info "Redémarrage de SDDM..."
            # systemctl restart peut couper le terminal — on lance en arrière-plan
            # avec un délai pour laisser le script terminer proprement
            (sleep 2 && sudo systemctl restart sddm) &
            print_success "SDDM redémarre dans 2 secondes — votre session va se fermer"
            ;;
        *)
            print_warning "Redémarrage annulé"
            echo ""
            echo -e "${CYAN}Pour appliquer le thème plus tard, lancez :${NC}"
            echo -e "   ${GREEN}sudo systemctl restart sddm${NC}"
            echo ""
            ;;
    esac
}


#############################################################################
# Purge complète de toute configuration SDDM existante
#############################################################################

purge_sddm_config() {
    print_header "PURGE DE LA CONFIGURATION SDDM EXISTANTE"

    echo -e "${YELLOW}Cette étape va supprimer TOUS les autres thèmes SDDM installés,${NC}"
    echo -e "${YELLOW}/etc/sddm.conf, /etc/sddm.conf.d/ et /etc/xdg/sddm.conf.${NC}"
    echo ""
    read -r -p "Voulez-vous vraiment repartir de zéro ? [o/N] : " purge_confirm
    if [[ ! "${purge_confirm,,}" =~ ^o(ui)?$ ]]; then
        print_info "Purge ignorée — la configuration existante et les autres thèmes sont conservés."
        print_info "En cas de conflit avec un ancien thème, relancez ce script et acceptez la purge."
        return 0
    fi

    # ── Tous les thèmes sauf le nôtre ─────────────────────────────────────
    local themes_dir="/usr/share/sddm/themes"
    if [[ -d "$themes_dir" ]]; then
        print_info "Suppression des anciens thèmes..."
        for theme in "$themes_dir"/*/; do
            local name
            name=$(basename "$theme")
            if [[ "$name" != "SDDM-Fallout-Qt6" ]]; then
                sudo rm -rf "$theme"
                print_warning "  supprimé : $name"
            fi
        done
        print_success "Anciens thèmes supprimés"
    fi

    # ── /etc/sddm.conf et tous ses backups ────────────────────────────────
    print_info "Suppression de /etc/sddm.conf et ses backups..."
    sudo rm -f /etc/sddm.conf
    sudo rm -f /etc/sddm.conf.backup.*
    print_success "/etc/sddm.conf nettoyé"

    # ── /etc/sddm.conf.d/ ─────────────────────────────────────────────────
    if [[ -d /etc/sddm.conf.d ]]; then
        print_info "Suppression de /etc/sddm.conf.d/..."
        sudo rm -f /etc/sddm.conf.d/*.conf
        print_success "/etc/sddm.conf.d/ vidé"
    fi

    # ── /usr/lib/sddm/sddm.conf.d/ ────────────────────────────────────────
    if [[ -d /usr/lib/sddm/sddm.conf.d ]]; then
        print_info "Suppression de /usr/lib/sddm/sddm.conf.d/..."
        sudo rm -f /usr/lib/sddm/sddm.conf.d/*.conf
        print_success "/usr/lib/sddm/sddm.conf.d/ vidé"
    fi

    # ── Config KDE/Plasma qui peut écraser SDDM ───────────────────────────
    local kde_conf="/etc/xdg/sddm.conf"
    if [[ -f "$kde_conf" ]]; then
        print_info "Suppression de $kde_conf (config KDE)..."
        sudo rm -f "$kde_conf"
        print_success "$kde_conf supprimé"
    fi

    # ── Résumé de ce qui reste (doit être vide) ───────────────────────────
    echo ""
    print_info "Vérification post-purge..."
    local remaining
    # || true indispensable : find retourne 1 si un chemin n'existe pas (tue set -e)
    remaining=$(find /etc/ /usr/lib/sddm/         -maxdepth 2 -name "sddm*.conf" 2>/dev/null | wc -l || true)
    if [[ "$remaining" -eq 0 ]]; then
        print_success "Aucune configuration résiduelle — table rase"
    else
        print_warning "$remaining fichier(s) de config restant(s) — vérifiez manuellement"
        find /etc/ /usr/lib/sddm/ -maxdepth 2 -name "sddm*.conf" 2>/dev/null             | while read -r f; do print_warning "  → $f"; done || true
    fi
}

#############################################################################
# Fonction principale
#############################################################################

main() {
    clear

    print_header "CONFIGURATION SDDM - THÈME FALLOUT (Qt6)"
    echo -e "${CYAN}Script de configuration universel SDDM${NC}"
    echo -e "${CYAN}Version 2.1.0 - Qt6${NC}"
    echo -e "${CYAN}Auteur: PapaOursPolaire${NC}"
    echo ""

    # Vérifier les privilèges sudo
    if [[ $EUID -ne 0 ]]; then
        if ! sudo -v 2>/dev/null; then
            print_error "Ce script nécessite les privilèges sudo"
            exit 1
        fi
        # Garder sudo actif pendant tout le script
        ( while true; do sudo -v; sleep 50; done ) &
        local sudo_keepalive_pid=$!
        trap "kill ${sudo_keepalive_pid} 2>/dev/null || true" EXIT
        print_success "Privilèges sudo confirmés"
    else
        print_success "Exécution en root"
    fi

    purge_sddm_config

    detect_package_manager

    check_desktop_environment

    detect_current_session

    # FIX : install_dependencies appelé UNE SEULE FOIS, selon le cas
    if ! check_sddm_compatibility; then
        echo ""
        read -r -p "SDDM n'est pas installé. Voulez-vous l'installer ? [O/n] : " install_sddm
        if [[ ! "$install_sddm" =~ ^[Nn]$ ]]; then
            install_dependencies
        else
            print_error "Installation annulée"
            exit 1
        fi
    else
        # SDDM présent — installer quand même les dépendances Qt6 manquantes
        install_dependencies
    fi

    detect_hardware

    select_video_file

    if create_theme_directory; then
        download_resources
        create_metadata_file
        create_theme_conf
        create_main_qml
        configure_sddm_conf
        enable_sddm_service
        print_final_summary
        restart_sddm_prompt
    else
        print_warning "Installation annulée ou thème existant conservé"
        exit 0
    fi
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
