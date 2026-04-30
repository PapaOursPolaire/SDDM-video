papaours@papaours:~$ # Config que SDDM lit réellement au démarrage
sudo sddm --example-config 2>/dev/null | grep -i "^Current\|^Theme"

# Ce que contient notre config
cat /etc/sddm.conf

# Nom exact du dossier thème (casse importante)
ls /usr/share/sddm/themes/

# Permissions
ls -la /usr/share/sddm/themes/SDDM-Fallout-Qt6/

# Logs du dernier vrai démarrage SDDM
journalctl -u sddm -b 0 | grep -i "theme\|fallout\|error\|warning\|load" | tail -40
[sudo] Mot de passe de papaours : 
Current=debian-theme
ThemeDir=/usr/share/sddm/themes
[Theme]
Current=SDDM-Fallout-Qt6
CursorTheme=breeze_cursors

[General]
DisplayServer=wayland
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
debian-theme  SDDM-Fallout-Qt6
total 61800
drwxr-xr-x 2 root root     4096 30 avr 11:46 .
drwxr-xr-x 3 root root     4096 30 avr 11:46 ..
-rw-r--r-- 1 root root 63110183 30 avr 11:46 background.mp4
-rw-r--r-- 1 root root   138718 30 avr 11:46 loginterminalc.png
-rw-r--r-- 1 root root    11963 30 avr 11:46 Main.qml
-rw-r--r-- 1 root root      271 30 avr 11:46 metadata.desktop
-rw-r--r-- 1 root root       89 30 avr 11:46 theme.conf
avr 30 11:49:33 papaours sddm[1273]: Loaded empty theme configuration
avr 30 11:49:33 papaours sddm[1273]: Loading theme configuration from "/usr/share/sddm/themes/SDDM-Fallout-Qt6/theme.conf"
avr 30 11:49:33 papaours sddm[1273]: The theme at "/usr/share/sddm/themes/SDDM-Fallout-Qt6" requires missing "/usr/bin/sddm-greeter" . Using fallback theme.
avr 30 11:49:33 papaours sddm[1273]: Loaded empty theme configuration
avr 30 11:49:34 papaours sddm[1273]: Greeter stopped. SDDM::Auth::HELPER_DISPLAYSERVER_ERROR
avr 30 11:49:34 papaours sddm[1273]: Loaded empty theme configuration
avr 30 11:49:34 papaours sddm[1273]: Loading theme configuration from "/usr/share/sddm/themes/SDDM-Fallout-Qt6/theme.conf"
avr 30 11:49:34 papaours sddm[1273]: The theme at "/usr/share/sddm/themes/SDDM-Fallout-Qt6" requires missing "/usr/bin/sddm-greeter" . Using fallback theme.
avr 30 11:49:34 papaours sddm[1273]: Loaded empty theme configuration
papaours@papaours:~$ 


