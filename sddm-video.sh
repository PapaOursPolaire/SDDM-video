#!/bin/bash
# =============================================================================
#  sddm-video.sh  v2  —  by PapaOursPolaire
#  Thème SDDM avec vidéo en arrière-plan — Qt5/Qt6 — Debian/Arch/Fedora/openSUSE
#
#  Fonctionnalités :
#    ✔ Vidéo configurable via theme.conf (sans réinstaller)
#    ✔ Interface SDDM complète : session, disposition clavier, login/reboot/shutdown
#    ✔ Panneau loginterminalc.png récupéré depuis le dépôt GitHub
#    ✔ Compatibilité Wayland ET X11 (auto-détection)
#    ✔ Qt5 et Qt6 (sélection automatique)
#    ✔ Installation des dépendances QtMultimedia
#    ✔ Mode --change-video pour changer la vidéo sans réinstaller
#
#  Usage :
#    sudo bash sddm-video.sh               # installation complète
#    sudo bash sddm-video.sh --change-video  # juste changer la vidéo
# =============================================================================

set -euo pipefail

# ─── Constantes ──────────────────────────────────────────────────────────────
readonly THEME_NAME="sddm-video"
readonly THEME_DIR="/usr/share/sddm/themes/$THEME_NAME"
readonly CONF_DIR="/etc/sddm.conf.d"
readonly CONF_FILE="$CONF_DIR/sddm-video.conf"
readonly REPO_RAW="https://raw.githubusercontent.com/PapaOursPolaire/SDDM-video/main"

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

# ─── Bannière ────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYN}╔═══════════════════════════════════════════════════════╗"
echo -e "║   SDDM Video Background  v2  —  PapaOursPolaire       ║"
echo -e "╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
#  FONCTIONS UTILITAIRES
# =============================================================================

# ─── Sélection de la vidéo ───────────────────────────────────────────────────
select_video() {
    VIDEO_PATH=""

    # Essai kdialog (KDE)
    if command -v kdialog &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        info "Ouverture du sélecteur de fichiers (kdialog)..."
        VIDEO_PATH=$(sudo -u "${SUDO_USER:-$USER}" kdialog \
            --getopenfilename "${HOME:-/home}" \
            "*.mp4 *.webm *.avi *.mkv *.mov *.gif" \
            --title "Sélectionnez votre vidéo de fond SDDM" 2>/dev/null) || VIDEO_PATH=""
    fi

    # Essai zenity (GTK/GNOME)
    if [[ -z "$VIDEO_PATH" ]] && command -v zenity &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        info "Ouverture du sélecteur de fichiers (zenity)..."
        VIDEO_PATH=$(sudo -u "${SUDO_USER:-$USER}" zenity \
            --file-selection \
            --title="Sélectionnez votre vidéo de fond SDDM" \
            --file-filter="Vidéos | *.mp4 *.webm *.avi *.mkv *.mov *.gif" \
            2>/dev/null) || VIDEO_PATH=""
    fi

    # Essai yad
    if [[ -z "$VIDEO_PATH" ]] && command -v yad &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        info "Ouverture du sélecteur de fichiers (yad)..."
        VIDEO_PATH=$(sudo -u "${SUDO_USER:-$USER}" yad \
            --file \
            --title="Sélectionnez votre vidéo de fond SDDM" \
            2>/dev/null) || VIDEO_PATH=""
    fi

    # Saisie manuelle en dernier recours
    if [[ -z "$VIDEO_PATH" ]]; then
        warn "Aucun sélecteur graphique disponible."
        read -rp "  Chemin complet vers votre vidéo : " VIDEO_PATH
    fi

    # Vérifications
    [[ -z "$VIDEO_PATH" ]] && die "Aucune vidéo sélectionnée."
    [[ ! -f "$VIDEO_PATH" ]] && die "Fichier introuvable : '$VIDEO_PATH'"

    local ext="${VIDEO_PATH##*.}"
    ext="${ext,,}"
    case "$ext" in
        mp4|webm|avi|mkv|mov|gif) ;;
        *) die "Format '$ext' non supporté. Formats acceptés : mp4, webm, avi, mkv, mov, gif" ;;
    esac

    ok "Vidéo sélectionnée : $(basename "$VIDEO_PATH") ($ext)"
}

# ─── Copie de la vidéo et mise à jour de theme.conf ─────────────────────────
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

    info "Copie de la vidéo vers $dest ..."
    cp "$VIDEO_PATH" "$dest"
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

# On supprime UNIQUEMENT notre propre fichier de config, pas les autres
if [[ -f "$CONF_FILE" ]]; then
    info "Suppression de $CONF_FILE"
    rm -f "$CONF_FILE"
fi

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
            apt-get install -y \
                qml6-module-qtmultimedia \
                qml6-module-qtquick-controls \
                qml6-module-qt5compat-graphicaleffects \
                qt6-multimedia-dev \
                2>/dev/null || \
            apt-get install -y \
                qml6-module-qtmultimedia \
                2>/dev/null || true
        else
            apt-get install -y \
                qml-module-qtmultimedia \
                qml-module-qtquick-controls2 \
                qml-module-qt-labs-folderlistmodel \
                2>/dev/null || true
        fi

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
            dnf install -y qt6-qtmultimedia qt6-qtmultimedia-devel 2>/dev/null || true
        else
            dnf install -y qt5-qtmultimedia qt5-qtmultimedia-devel 2>/dev/null || true
        fi

    elif command -v zypper &>/dev/null; then
        zypper install -y \
            libQt6Multimedia6 \
            qml6-module-qtmultimedia \
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

    if command -v curl &>/dev/null; then
        curl -fsSL --max-time 15 "$REPO_RAW/$asset" -o "$dest" 2>/dev/null && success=0
    elif command -v wget &>/dev/null; then
        wget -q --timeout=15 "$REPO_RAW/$asset" -O "$dest" 2>/dev/null && success=0
    fi

    if [[ $success -eq 0 ]]; then
        chmod 644 "$dest"
        ok "Téléchargé : $asset"
        return 0
    else
        warn "Impossible de télécharger $asset depuis $REPO_RAW"
        return 1
    fi
}

info "Téléchargement des assets graphiques..."
download_asset "loginterminalc.png" || warn "loginterminalc.png absent — le panneau affichera un fond transparent"
download_asset "angle-down.png"     || warn "angle-down.png absent — les flèches des menus ne s'afficheront pas"

# ── metadata.desktop ─────────────────────────────────────────────────────────
if [[ "$QT_VERSION" == "6" ]]; then
    cat > "$THEME_DIR/metadata.desktop" <<EOF
[Desktop Entry]
Name=SDDM Video Background
Comment=Fond vidéo configurable pour SDDM — by PapaOursPolaire
Type=Service
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
# ou éditez directement :
#   $THEME_DIR/theme.conf  →  background=nomdevideo.mp4

[General]
Numlock=on
$DISPLAY_SERVER_LINE

[Theme]
Current=$THEME_NAME

[Users]
MinimumUid=1000
MaximumUid=60000
EOF

ok "Config écrite : $CONF_FILE"

# Vérification : un seul fichier de config actif
echo ""
info "Fichiers de config SDDM actifs dans $CONF_DIR/ :"
ls -1 "$CONF_DIR/" | while read -r f; do echo "    $f"; done
if [[ -f /etc/sddm.conf ]]; then
    warn "/etc/sddm.conf présent — il peut entrer en conflit avec $CONF_FILE"
fi

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