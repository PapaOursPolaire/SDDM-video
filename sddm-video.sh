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
            print_info "Installation via apt..."
            # qt6-multimedia-qml est le nom correct sur Ubuntu 22.04+
            sudo apt install -y \
                sddm \
                qt6-multimedia-qml \
                qml6-module-qtquick \
                qml6-module-qtquick-controls \
                qml6-module-qtquick-layouts \
                libqt6multimedia6 \
                gstreamer1.0-plugins-good \
                gstreamer1.0-plugins-bad \
                gstreamer1.0-plugins-ugly \
                curl wget
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
 * Thème SDDM Fallout — Qt6 pur (sans dépendance KDE/Plasma)
 * Auteur  : PapaOursPolaire
 * Version : 2.1 Qt6
 * Licence : GPL-3.0
 *
 * Disposition :
 *   - Vidéo plein écran en boucle (background.mp4)
 *     fallback image loginterminalc.png si la vidéo échoue
 *   - Horloge haut-droite (Timer inliné, pas de Clock externe)
 *   - Panneau login : loginterminalc.png comme fond du panneau,
 *     centré verticalement, ancré à droite
 ***************************************************************************/

import QtQuick
import QtQuick.Controls
import QtMultimedia
import SddmComponents 2.0

Rectangle {
    id: container
    width:  Screen.width
    height: Screen.height

    LayoutMirroring.enabled:       Qt.locale().textDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property int sessionIndex: session.currentIndex

    // ─── TextConstants SDDM (labels localisés) ────────────────────────────
    TextConstants { id: textConstants }

    // ─── FOND VIDÉO Qt6 ───────────────────────────────────────────────────
    Item {
        id: videoBackground
        anchors.fill: parent

        MediaPlayer {
            id: videoPlayer
            source: Qt.resolvedUrl("background.mp4")
            loops:  MediaPlayer.Infinite

            audioOutput: AudioOutput {
                muted:  false
                volume: 0.3
            }
            videoOutput: videoOutputItem

            Component.onCompleted: videoPlayer.play()

            onErrorOccurred: function(error, errorString) {
                console.warn("Vidéo introuvable ou invalide :", errorString)
                fallbackImage.visible = true
            }
        }

        VideoOutput {
            id: videoOutputItem
            anchors.fill: parent
            // fillMode n'existe pas sur VideoOutput Qt6 — le crop est géré
            // par les dimensions du parent qui couvre tout l'écran
        }

        // Image de secours plein écran si la vidéo ne charge pas
        Image {
            id: fallbackImage
            anchors.fill: parent
            source:   "loginterminalc.png"
            fillMode: Image.PreserveAspectCrop
            visible:  false
        }
    }

    // Overlay sombre léger pour la lisibilité
    Rectangle {
        anchors.fill: parent
        color:   "black"
        opacity: 0.25
    }

    // ─── HORLOGE haut-droite (Timer inliné, pas de composant Clock externe) ─
    Item {
        id: clockItem
        anchors.top:        parent.top
        anchors.right:      parent.right
        anchors.topMargin:  40
        anchors.rightMargin: 40
        width:  timeLabel.implicitWidth
        height: timeLabel.implicitHeight + dateLabel.implicitHeight + 6

        property string currentTime: Qt.formatTime(new Date(), "hh:mm:ss")
        property string currentDate: Qt.formatDate(new Date(), "dddd, MMMM d yyyy")

        Timer {
            interval: 1000
            running:  true
            repeat:   true
            onTriggered: {
                clockItem.currentTime = Qt.formatTime(new Date(), "hh:mm:ss")
                clockItem.currentDate = Qt.formatDate(new Date(), "dddd, MMMM d yyyy")
            }
        }

        Column {
            anchors.right: parent.right

            Text {
                id:   timeLabel
                text: clockItem.currentTime
                color: "#eaf5c4"
                font.family:    "Consolas"
                font.bold:       true
                font.pixelSize:  90
                horizontalAlignment: Text.AlignRight
            }

            Text {
                id:   dateLabel
                text: clockItem.currentDate
                color: "#eaf5c4"
                font.family:    "Lucida Console"
                font.bold:       true
                font.pixelSize:  30
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // ─── PANNEAU DE CONNEXION ──────────────────────────────────────────────
    // loginterminalc.png est l'image de fond du panneau,
    // positionnée en-dessous des champs de saisie (z inférieur)
    Image {
        id: loginTerminal
        anchors.verticalCenter: parent.verticalCenter
        anchors.right:          parent.right
        anchors.rightMargin:    50
        width:  Math.max(400, mainColumn.implicitWidth  + 60)
        height: Math.max(350, mainColumn.implicitHeight + 60)
        source:   "loginterminalc.png"
        fillMode: Image.PreserveAspectFit

        // ─ Contenu du panneau ────────────────────────────────────────────
        Column {
            id: mainColumn
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.85

            // Titre façon terminal Pip-Boy
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:  "ROBCO INDUSTRIES UNIFIED OPERATING SYSTEM"
                color: "#88FF88"
                font.pixelSize: 12
                font.family:    "Monospace"
                wrapMode: Text.WordWrap
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            // ── Nom d'utilisateur ─────────────────────────────────────
            Column {
                width: parent.width
                spacing: 4

                Text {
                    text:  textConstants.userName
                    color: "#88FF88"
                    font.bold:       true
                    font.pixelSize:  12
                    font.family:     "Monospace"
                }

                TextField {
                    id:     name
                    width:  parent.width
                    height: 30
                    text:   userModel.lastUser
                    color:  "#88FF88"
                    font.pixelSize: 14
                    font.family:    "Monospace"
                    selectByMouse:  true

                    background: Rectangle {
                        color:        "transparent"
                        border.color: "#88FF88"
                        border.width: 1
                    }

                    KeyNavigation.backtab: rebootButton
                    KeyNavigation.tab:     password

                    Keys.onReturnPressed: sddm.login(name.text, password.text, sessionIndex)
                    Keys.onEnterPressed:  sddm.login(name.text, password.text, sessionIndex)
                }
            }

            // ── Mot de passe ──────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 4

                Text {
                    text:  textConstants.password
                    color: "#88FF88"
                    font.bold:      true
                    font.pixelSize: 12
                    font.family:    "Monospace"
                }

                TextField {
                    id:        password
                    width:     parent.width
                    height:    30
                    color:     "#88FF88"
                    font.pixelSize: 14
                    font.family:    "Monospace"
                    echoMode:  TextInput.Password
                    selectByMouse: true

                    background: Rectangle {
                        color:        "transparent"
                        border.color: "#88FF88"
                        border.width: 1
                    }

                    KeyNavigation.backtab: name
                    KeyNavigation.tab:     session

                    Keys.onReturnPressed: sddm.login(name.text, password.text, sessionIndex)
                    Keys.onEnterPressed:  sddm.login(name.text, password.text, sessionIndex)
                }
            }

            // ── Session + Layout ──────────────────────────────────────
            Row {
                width:   parent.width
                spacing: 10

                Column {
                    width:   parent.width * 0.6
                    spacing: 4
                    anchors.bottom: parent.bottom

                    Text {
                        text:  textConstants.session
                        color: "#88FF88"
                        font.bold:      true
                        font.pixelSize: 12
                        font.family:    "Monospace"
                        wrapMode: TextEdit.WordWrap
                    }

                    ComboBox {
                        id:     session
                        width:  parent.width
                        height: 30
                        font.pixelSize: 14
                        font.family:    "Monospace"
                        model:        sessionModel
                        currentIndex: sessionModel.lastIndex

                        KeyNavigation.backtab: password
                        KeyNavigation.tab:     layoutBox
                    }
                }

                Column {
                    width:   parent.width * 0.35
                    spacing: 4
                    anchors.bottom: parent.bottom

                    Text {
                        text:  textConstants.layout
                        color: "#88FF88"
                        font.bold:      true
                        font.pixelSize: 12
                        font.family:    "Monospace"
                        wrapMode: TextEdit.WordWrap
                    }

                    LayoutBox {
                        id:     layoutBox
                        width:  parent.width
                        height: 30
                        font.pixelSize: 14
                        font.family:    "Monospace"
                        color:     "transparent"
                        arrowIcon: "angle-down.png"

                        KeyNavigation.backtab: session
                        KeyNavigation.tab:     loginButton
                    }
                }
            }

            // ── Message d'erreur ──────────────────────────────────────
            Text {
                id: errorMessage
                anchors.horizontalCenter: parent.horizontalCenter
                text:    ""
                color:   "red"
                font.pixelSize: 10
                font.family:    "Monospace"
                visible: text !== ""
            }

            // ── Boutons Login / Reboot / Power ────────────────────────
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Button {
                    id:     loginButton
                    text:   textConstants.login
                    width:  73
                    height: 75
                    anchors.top:       parent.bottom
                    anchors.topMargin: -24

                    contentItem: Text {
                        text:  parent.text
                        color: "#00FF00"
                        font.bold:      true
                        font.pixelSize: 16
                        font.family:    "Monospace"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    background: Rectangle {
                        color:        "transparent"
                        border.color: "#00FF00"
                        border.width: 2
                        radius: 3
                    }

                    onClicked: sddm.login(name.text, password.text, sessionIndex)

                    KeyNavigation.backtab: layoutBox
                    KeyNavigation.tab:     shutdownButton

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    sddm.login(name.text, password.text, sessionIndex)
                        // laisser les autres événements clavier remonter
                        onPressed: (mouse) => mouse.accepted = false
                    }
                }

                Button {
                    id:     rebootButton
                    text:   textConstants.reboot
                    width:  73
                    height: 75
                    anchors.top:       parent.bottom
                    anchors.topMargin: -24

                    contentItem: Text {
                        text:  parent.text
                        color: "#FFFF00"
                        font.bold:      true
                        font.pixelSize: 16
                        font.family:    "Monospace"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    background: Rectangle {
                        color:        "transparent"
                        border.color: "#FFFF00"
                        border.width: 2
                        radius: 3
                    }

                    onClicked: sddm.reboot()

                    KeyNavigation.backtab: shutdownButton
                    KeyNavigation.tab:     name

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    sddm.reboot()
                        onPressed: (mouse) => mouse.accepted = false
                    }
                }

                Button {
                    id:     shutdownButton
                    text:   "Power"
                    width:  73
                    height: 75
                    anchors.top:       parent.bottom
                    anchors.topMargin: -24

                    contentItem: Text {
                        text:  parent.text
                        color: "#FF0000"
                        font.bold:      true
                        font.pixelSize: 16
                        font.family:    "Monospace"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    background: Rectangle {
                        color:        "transparent"
                        border.color: "#FF0000"
                        border.width: 2
                        radius: 3
                    }

                    onClicked: sddm.powerOff()

                    KeyNavigation.backtab: loginButton
                    KeyNavigation.tab:     rebootButton

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    sddm.powerOff()
                        onPressed: (mouse) => mouse.accepted = false
                    }
                }
            }
        }
    }

    // ─── Connexions SDDM ──────────────────────────────────────────────────
    Connections {
        target: sddm

        function onLoginSucceeded() {
            errorMessage.color = "steelblue"
            errorMessage.text  = textConstants.loginSucceeded
        }

        function onLoginFailed() {
            password.text     = ""
            errorMessage.color = "red"
            errorMessage.text  = textConstants.loginFailed
        }

        function onInformationMessage(message) {
            errorMessage.color = "red"
            errorMessage.text  = message
        }
    }

    Component.onCompleted: {
        if (name.text === "")
            name.focus = true
        else
            password.focus = true
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
            sddm-greeter-qt6 --test-mode --theme "$THEME_DIR"
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
    echo -e "${BLUE}Serveur d'affichage :${NC}      $([ "$USE_WAYLAND" = true ] && echo "Wayland" || echo "X11")"
    echo ""

    [[ -f "$THEME_DIR/background.mp4"     ]] && echo -e "${GREEN}✓${NC} Vidéo de fond      : background.mp4"
    [[ -f "$THEME_DIR/loginterminalc.png" ]] && echo -e "${GREEN}✓${NC} Fond panneau login : loginterminalc.png"
    echo -e "${GREEN}✓${NC} Main.qml Qt6       : créé (sans dépendance KDE)"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  PROCHAINES ÉTAPES${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} Redémarrez pour activer SDDM"
    echo -e "${YELLOW}2.${NC} Le thème Fallout sera appliqué automatiquement"
    echo -e "${YELLOW}3.${NC} Pour tester manuellement :"
    echo -e "   ${CYAN}sddm-greeter --test-mode --theme $THEME_DIR${NC}"
    echo ""

    # FIX : compgen au lieu du glob dans [[ ]]
    if compgen -G "${SDDM_CONF}.backup."* &>/dev/null; then
        echo -e "${BLUE}Backup disponible :${NC} ${SDDM_CONF}.backup.*"
    fi

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Bienvenue dans le Wasteland !${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
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
    if [[ $EUID -ne 0 ]] && ! sudo -v; then
        print_error "Ce script nécessite les privilèges sudo"
        exit 1
    fi

    detect_package_manager

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

    select_video_file

    if create_theme_directory; then
        download_resources
        create_metadata_file
        create_theme_conf
        create_main_qml
        configure_sddm_conf
        enable_sddm_service
        print_final_summary
    else
        print_warning "Installation annulée ou thème existant conservé"
        exit 0
    fi
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
