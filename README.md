# 🎬 SDDM-video

Un thème moderne pour le gestionnaire de connexion **SDDM** permettant d'afficher une vidéo en arrière-plan de manière fluide.

---

## 🚀 Caractéristiques

* **Vidéo en boucle :** Support des formats standards (MP4, WebM) via QtMultimedia.
* **Design Épuré :** Interface minimaliste pour mettre en avant l'animation.
* **Performance :** Optimisé pour une faible consommation de ressources au démarrage.
* **Personnalisable :** Changez facilement la vidéo et les couleurs via le fichier de configuration.

## 📸 Aperçu

> [!TIP]
> Ajoutez ici une capture d'écran ou un GIF de votre thème en action !
> `![Aperçu du thème](screenshot.png)`

## 🛠️ Installation

### 1. Prérequis
Assurez-vous d'avoir les dépendances nécessaires pour Qt (souvent présentes par défaut sur KDE) :
* `sddm`
* `qt5-multimedia` (ou `qt6-multimedia` selon votre version)
* `gst-libav` (pour le support des codecs vidéo)

### 2. Clonage et déploiement
Déplacez le dossier du projet dans le répertoire des thèmes SDDM :

```bash
git clone git@github.com:PapaOursPolaire/SDDM-video.git
sudo cp -r SDDM-video /usr/share/sddm/themes/
