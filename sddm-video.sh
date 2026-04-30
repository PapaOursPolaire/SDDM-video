# Config que SDDM lit réellement au démarrage
sudo sddm --example-config 2>/dev/null | grep -i "^Current\|^Theme"

# Ce que contient notre config
cat /etc/sddm.conf

# Nom exact du dossier thème (casse importante)
ls /usr/share/sddm/themes/

# Permissions
ls -la /usr/share/sddm/themes/SDDM-Fallout-Qt6/

# Logs du dernier vrai démarrage SDDM
journalctl -u sddm -b 0 | grep -i "theme\|fallout\|error\|warning\|load" | tail -40
