#!/bin/bash

#############################################################################
# Script de Configuration Universel SDDM avec Thème Fallout (Qt6)
# Auteur: PapaOursPolaire (adapté et modernisé pour Qt6)
# Version: 2.0.0
# Date: 2026-04-21
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

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

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
    
    # Vérifier si SDDM est installé
    if ! command -v sddm &>/dev/null; then
        print_warning "SDDM n'est pas installé"
        return 1
    fi
    
    # Vérifier la version de SDDM
    local sddm_version
    sddm_version=$(sddm --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
    print_info "Version SDDM détectée : $sddm_version"
    
    # Vérifier Qt6
    if command -v qmake6 &>/dev/null || command -v qmake-qt6 &>/dev/null; then
        print_success "Qt6 détecté"
    else
        print_warning "Qt6 non détecté - installation recommandée"
    fi
    
    # Vérifier si un autre display manager est actif
    local active_dm
    active_dm=$(systemctl list-units --type=service --state=running | grep -E 'gdm|lightdm|lxdm' | awk '{print $1}' || true)
    
    if [[ -n "$active_dm" ]]; then
        print_warning "Autre gestionnaire d'affichage actif : $active_dm"
        echo -e "${YELLOW}Il sera nécessaire de désactiver $active_dm et d'activer SDDM${NC}"
    fi
    
    print_success "SDDM est compatible avec ce système"
    return 0
}

#############################################################################
# Installation des dépendances
#############################################################################

install_dependencies() {
    print_header "INSTALLATION DES DÉPENDANCES"
    
    local packages=""
    
    case "$DETECTED_PM" in
        pacman)
            packages="sddm qt6-multimedia qt6-declarative qt6-svg gst-plugins-good gst-plugins-bad gst-plugins-ugly curl wget"
            print_info "Installation via pacman..."
            sudo pacman -S --needed --noconfirm $packages
            ;;
            
        apt)
            packages="sddm qml6-module-qtmultimedia qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts libqt6multimedia6 gstreamer1.0-plugins-good gstreamer1.0-plugins-bad curl wget"
            print_info "Mise à jour des dépôts..."
            sudo apt update
            print_info "Installation via apt..."
            sudo apt install -y $packages
            ;;
            
        dnf)
            packages="sddm qt6-qtmultimedia qt6-qtdeclarative qt6-qtsvg gstreamer1-plugins-good gstreamer1-plugins-bad curl wget"
            print_info "Installation via dnf..."
            sudo dnf install -y $packages
            ;;
            
        zypper)
            packages="sddm qt6-multimedia qt6-declarative qt6-svg gstreamer-plugins-good gstreamer-plugins-bad curl wget"
            print_info "Installation via zypper..."
            sudo zypper install -y $packages
            ;;
            
        emerge)
            packages="x11-misc/sddm dev-qt/qtmultimedia:6 dev-qt/qtdeclarative:6 media-plugins/gst-plugins-meta"
            print_info "Installation via emerge..."
            sudo emerge --ask=n $packages
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
    read -p "Votre choix [1-3] : " choice
    
    case "$choice" in
        1)
            print_info "Téléchargement de la vidéo par défaut..."
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
    
    # Détecter l'explorateur de fichiers disponible
    local file_browser=""
    
    if command -v dolphin &>/dev/null; then
        file_browser="dolphin"
    elif command -v nautilus &>/dev/null; then
        file_browser="nautilus"
    elif command -v thunar &>/dev/null; then
        file_browser="thunar"
    elif command -v nemo &>/dev/null; then
        file_browser="nemo"
    elif command -v pcmanfm &>/dev/null; then
        file_browser="pcmanfm"
    elif command -v zenity &>/dev/null; then
        # Utiliser zenity pour la sélection de fichier
        VIDEO_FILE=$(zenity --file-selection --title="Sélectionner une vidéo" --file-filter="Vidéos | *.mp4 *.mkv *.webm *.avi")
        if [[ -n "$VIDEO_FILE" ]]; then
            print_success "Vidéo sélectionnée : $VIDEO_FILE"
            return 0
        else
            print_warning "Aucune vidéo sélectionnée"
            return 1
        fi
    else
        print_warning "Aucun explorateur de fichiers graphique détecté"
        read -p "Entrez le chemin complet de votre vidéo : " VIDEO_FILE
    fi
    
    if [[ -n "$file_browser" ]] && [[ "$file_browser" != "zenity" ]]; then
        print_info "Utilisez l'explorateur $file_browser pour sélectionner votre vidéo"
        print_info "Formats supportés : .mp4, .mkv, .webm, .avi"
        
        # Ouvrir l'explorateur dans le dossier Vidéos de l'utilisateur
        local video_dir="${HOME}/Videos"
        [[ ! -d "$video_dir" ]] && video_dir="${HOME}/Vidéos"
        [[ ! -d "$video_dir" ]] && video_dir="${HOME}"
        
        $file_browser "$video_dir" &
        
        echo ""
        read -p "Entrez le chemin complet de la vidéo sélectionnée : " VIDEO_FILE
    fi
    
    # Vérifier que le fichier existe
    if [[ -n "$VIDEO_FILE" ]] && [[ -f "$VIDEO_FILE" ]]; then
        print_success "Vidéo sélectionnée : $VIDEO_FILE"
    else
        print_error "Fichier non trouvé : $VIDEO_FILE"
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
        read -p "Voulez-vous le remplacer ? [O/n] : " response
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
    
    # Télécharger l'image de login
    print_info "Téléchargement de l'image de login..."
    if sudo curl -fL "$LOGIN_IMAGE_URL" -o "$THEME_DIR/loginterminalc.png"; then
        print_success "Image de login téléchargée"
    else
        print_error "Échec du téléchargement de l'image de login"
        return 1
    fi
    
    # Télécharger ou copier la vidéo
    if [[ "$VIDEO_FILE" == "$THEME_DIR/default.mp4" ]]; then
        print_info "Téléchargement de la vidéo par défaut..."
        if sudo curl -fL "$DEFAULT_VIDEO_URL" -o "$THEME_DIR/background.mp4"; then
            print_success "Vidéo par défaut téléchargée"
        else
            print_error "Échec du téléchargement de la vidéo"
            return 1
        fi
    elif [[ -n "$VIDEO_FILE" ]] && [[ -f "$VIDEO_FILE" ]]; then
        print_info "Copie de la vidéo personnalisée..."
        sudo cp "$VIDEO_FILE" "$THEME_DIR/background.mp4"
        print_success "Vidéo copiée"
    fi
    
    print_success "Ressources téléchargées"
}

#############################################################################
# Création des fichiers de configuration
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
X-KDE-PluginInfo-Version=2.0
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

create_main_qml() {
    print_info "Création de Main.qml (Qt6)..."
    
    sudo tee "$THEME_DIR/Main.qml" >/dev/null <<'EOF'
/***************************************************************************
 * Thème SDDM Fallout - Adapté pour Qt6
 * Auteur: PapaOursPolaire
 * Version: 2.0 Qt6
 * License: GPL-3.0
 ***************************************************************************/

import QtQuick
import QtMultimedia
import org.kde.plasma.components as PlasmaComponents
import "components" as UserComponents

Rectangle {
    id: container
    
    width: Screen.width
    height: Screen.height
    
    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true
    
    property int sessionIndex: session.currentIndex
    
    // Arrière-plan vidéo (Qt6 MediaPlayer API)
    Item {
        id: videoBackground
        anchors.fill: parent
        
        // Lecteur vidéo Qt6
        MediaPlayer {
            id: videoPlayer
            source: Qt.resolvedUrl("background.mp4")
            audioOutput: AudioOutput {
                muted: false
                volume: 0.3
            }
            videoOutput: videoOutput
            loops: MediaPlayer.Infinite
            
            Component.onCompleted: {
                play()
            }
            
            onErrorOccurred: function(error, errorString) {
                console.error("Erreur vidéo:", errorString)
                fallbackImage.visible = true
            }
        }
        
        VideoOutput {
            id: videoOutput
            anchors.fill: parent
        }
        
        // Image de secours si la vidéo ne charge pas
        Image {
            id: fallbackImage
            anchors.fill: parent
            source: "loginterminalc.png"
            fillMode: Image.PreserveAspectCrop
            visible: false
        }
    }
    
    // Overlay semi-transparent
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.2
    }
    
    // Interface de connexion
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        
        // Horloge en haut à droite
        Clock {
            id: clock
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 40
            color: "#eaf5c4"
            
            timeFont.family: "Consolas"
            timeFont.bold: true
            timeFont.pixelSize: 90
            
            dateFont.family: "Lucida Console"
            dateFont.bold: true
            dateFont.pixelSize: 30
        }
        
        // Terminal de connexion
        Image {
            id: loginTerminal
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 50
            width: Math.max(400, mainColumn.implicitWidth + 60)
            height: Math.max(350, mainColumn.implicitHeight + 60)
            source: "loginterminalc.png"
            
            Column {
                id: mainColumn
                anchors.centerIn: parent
                spacing: 15
                width: parent.width * 0.85
                
                // Titre
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "ROBCO INDUSTRIES UNIFIED OPERATING SYSTEM"
                    color: "#88FF88"
                    font.pixelSize: 12
                    font.family: "Monospace"
                }
                
                // Nom d'utilisateur
                Column {
                    width: parent.width
                    spacing: 5
                    
                    Text {
                        text: "USERNAME"
                        color: "#88FF88"
                        font.bold: true
                        font.pixelSize: 14
                        font.family: "Monospace"
                    }
                    
                    TextField {
                        id: name
                        width: parent.width
                        height: 35
                        text: userModel.lastUser
                        color: "#88FF88"
                        font.pixelSize: 16
                        font.family: "Monospace"
                        
                        background: Rectangle {
                            color: "transparent"
                            border.color: "#88FF88"
                            border.width: 1
                        }
                        
                        KeyNavigation.backtab: rebootButton
                        KeyNavigation.tab: password
                        
                        Keys.onReturnPressed: sddm.login(name.text, password.text, sessionIndex)
                        Keys.onEnterPressed: sddm.login(name.text, password.text, sessionIndex)
                    }
                }
                
                // Mot de passe
                Column {
                    width: parent.width
                    spacing: 5
                    
                    Text {
                        text: "PASSWORD"
                        color: "#88FF88"
                        font.bold: true
                        font.pixelSize: 14
                        font.family: "Monospace"
                    }
                    
                    TextField {
                        id: password
                        width: parent.width
                        height: 35
                        color: "#88FF88"
                        font.pixelSize: 16
                        font.family: "Monospace"
                        echoMode: TextInput.Password
                        
                        background: Rectangle {
                            color: "transparent"
                            border.color: "#88FF88"
                            border.width: 1
                        }
                        
                        KeyNavigation.backtab: name
                        KeyNavigation.tab: session
                        
                        Keys.onReturnPressed: sddm.login(name.text, password.text, sessionIndex)
                        Keys.onEnterPressed: sddm.login(name.text, password.text, sessionIndex)
                    }
                }
                
                // Session et Layout
                Row {
                    width: parent.width
                    spacing: 10
                    
                    Column {
                        width: parent.width * 0.6
                        spacing: 5
                        
                        Text {
                            text: "SESSION"
                            color: "#88FF88"
                            font.bold: true
                            font.pixelSize: 14
                            font.family: "Monospace"
                        }
                        
                        ComboBox {
                            id: session
                            width: parent.width
                            height: 35
                            model: sessionModel
                            currentIndex: sessionModel.lastIndex
                            font.pixelSize: 14
                            font.family: "Monospace"
                            
                            KeyNavigation.backtab: password
                            KeyNavigation.tab: layoutBox
                        }
                    }
                    
                    Column {
                        width: parent.width * 0.35
                        spacing: 5
                        
                        Text {
                            text: "LAYOUT"
                            color: "#88FF88"
                            font.bold: true
                            font.pixelSize: 14
                            font.family: "Monospace"
                        }
                        
                        LayoutBox {
                            id: layoutBox
                            width: parent.width
                            height: 35
                            font.pixelSize: 14
                            font.family: "Monospace"
                            
                            KeyNavigation.backtab: session
                            KeyNavigation.tab: loginButton
                        }
                    }
                }
                
                // Message d'erreur
                Text {
                    id: errorMessage
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ""
                    color: "red"
                    font.pixelSize: 12
                    font.family: "Monospace"
                    visible: text !== ""
                }
                
                // Boutons d'action
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 15
                    
                    Button {
                        id: loginButton
                        text: "LOGIN"
                        width: 90
                        height: 40
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#00FF00"
                            font.bold: true
                            font.pixelSize: 16
                            font.family: "Monospace"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        background: Rectangle {
                            color: "transparent"
                            border.color: "#00FF00"
                            border.width: 2
                            radius: 3
                        }
                        
                        onClicked: sddm.login(name.text, password.text, sessionIndex)
                        
                        KeyNavigation.backtab: layoutBox
                        KeyNavigation.tab: shutdownButton
                    }
                    
                    Button {
                        id: rebootButton
                        text: "REBOOT"
                        width: 90
                        height: 40
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#FFFF00"
                            font.bold: true
                            font.pixelSize: 16
                            font.family: "Monospace"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        background: Rectangle {
                            color: "transparent"
                            border.color: "#FFFF00"
                            border.width: 2
                            radius: 3
                        }
                        
                        onClicked: sddm.reboot()
                        
                        KeyNavigation.backtab: shutdownButton
                        KeyNavigation.tab: name
                    }
                    
                    Button {
                        id: shutdownButton
                        text: "POWER"
                        width: 90
                        height: 40
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#FF0000"
                            font.bold: true
                            font.pixelSize: 16
                            font.family: "Monospace"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        background: Rectangle {
                            color: "transparent"
                            border.color: "#FF0000"
                            border.width: 2
                            radius: 3
                        }
                        
                        onClicked: sddm.powerOff()
                        
                        KeyNavigation.backtab: loginButton
                        KeyNavigation.tab: rebootButton
                    }
                }
            }
        }
    }
    
    // Connexions SDDM
    Connections {
        target: sddm
        
        function onLoginSucceeded() {
            errorMessage.text = ""
        }
        
        function onLoginFailed() {
            password.text = ""
            errorMessage.text = "LOGIN FAILED - ACCESS DENIED"
        }
    }
    
    Component.onCompleted: {
        if (name.text === "") {
            name.focus = true
        } else {
            password.focus = true
        }
    }
}
EOF
    
    print_success "Main.qml créé (Qt6)"
}

#############################################################################
# Configuration de SDDM
#############################################################################

configure_sddm_conf() {
    print_header "CONFIGURATION DE SDDM"
    
    # Sauvegarder l'ancien fichier si existe
    if [[ -f "$SDDM_CONF" ]]; then
        print_info "Sauvegarde de l'ancienne configuration..."
        sudo cp "$SDDM_CONF" "${SDDM_CONF}.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Demander le serveur d'affichage
    echo ""
    echo "Serveur d'affichage :"
    echo "  1) Wayland (recommandé pour les systèmes modernes)"
    echo "  2) X11 (pour compatibilité maximale)"
    read -p "Votre choix [1-2] : " display_choice
    
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
    
    print_info "Création de /etc/sddm.conf..."
    
    sudo tee "$SDDM_CONF" >/dev/null <<EOF
[Theme]
Current=SDDM-Fallout-Qt6
CursorTheme=breeze_cursors

[General]
DisplayServer=$display_server
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
    
    print_success "Configuration SDDM créée (serveur: $display_server)"
}

#############################################################################
# Activation de SDDM
#############################################################################

enable_sddm_service() {
    print_header "ACTIVATION DU SERVICE SDDM"
    
    # Désactiver les autres display managers
    local other_dms=("gdm" "lightdm" "lxdm" "xdm")
    for dm in "${other_dms[@]}"; do
        if systemctl is-enabled "$dm.service" &>/dev/null; then
            print_info "Désactivation de $dm..."
            sudo systemctl disable "$dm.service" || true
        fi
    done
    
    # Activer SDDM
    print_info "Activation de SDDM..."
    sudo systemctl enable sddm.service
    
    print_success "SDDM activé"
    
    echo ""
    read -p "Voulez-vous tester le thème maintenant ? [O/n] : " test_theme
    if [[ ! "$test_theme" =~ ^[Nn]$ ]]; then
        print_info "Test du thème SDDM..."
        print_warning "Appuyez sur Ctrl+C pour quitter le mode test"
        sleep 2
        sddm-greeter --test-mode --theme "$THEME_DIR"
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
    echo -e "${BLUE}Système détecté :${NC} $DETECTED_DISTRO"
    echo -e "${BLUE}Gestionnaire de paquets :${NC} $DETECTED_PM"
    echo -e "${BLUE}Répertoire du thème :${NC} $THEME_DIR"
    echo -e "${BLUE}Serveur d'affichage :${NC} $([ "$USE_WAYLAND" = true ] && echo "Wayland" || echo "X11")"
    echo ""
    
    if [[ -f "$THEME_DIR/background.mp4" ]]; then
        echo -e "${GREEN}✓${NC} Vidéo de fond : installée"
    fi
    
    if [[ -f "$THEME_DIR/loginterminalc.png" ]]; then
        echo -e "${GREEN}✓${NC} Image de login : installée"
    fi
    
    echo -e "${GREEN}✓${NC} Fichiers Qt6 : créés"
    echo ""
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  PROCHAINES ÉTAPES${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} Redémarrez votre système pour activer SDDM"
    echo -e "${YELLOW}2.${NC} Le thème Fallout sera appliqué automatiquement"
    echo -e "${YELLOW}3.${NC} Pour tester sans redémarrer :"
    echo -e "   ${CYAN}sddm-greeter --test-mode --theme $THEME_DIR${NC}"
    echo ""
    echo -e "${BLUE}Configuration sauvegardée :${NC} $SDDM_CONF"
    if [[ -f "${SDDM_CONF}.backup."* ]]; then
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
    echo -e "${CYAN}Version 2.0.0 - Qt6${NC}"
    echo -e "${CYAN}Auteur: PapaOursPolaire${NC}"
    echo ""
    
    # Vérifier les privilèges root
    if [[ $EUID -ne 0 ]] && ! sudo -v; then
        print_error "Ce script nécessite les privilèges sudo"
        exit 1
    fi
    
    # Détections
    detect_package_manager
    
    if ! check_sddm_compatibility; then
        echo ""
        read -p "SDDM n'est pas installé. Voulez-vous l'installer ? [O/n] : " install_sddm
        if [[ ! "$install_sddm" =~ ^[Nn]$ ]]; then
            install_dependencies
        else
            print_error "Installation annulée"
            exit 1
        fi
    fi
    
    # Installation
    install_dependencies
    
    # Sélection de la vidéo
    select_video_file
    
    # Création du thème
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
