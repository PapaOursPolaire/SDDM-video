papaours@papaours:~$ ls -la /usr/share/sddm/themes/sddm-video/
cat /etc/sddm.conf.d/zzz-sddm-video.conf
ls /tmp/sddm-video-repo-* 2>/dev/null || echo "pas de tmp"
curl -I "https://raw.githubusercontent.com/PapaOursPolaire/SDDM-video/Projets/loginterminalc.png"
total 61676
drwxr-xr-x  2 root root     4096  1 avr 21:03 .
drwxr-xr-x 11 root root     4096  1 avr 21:03 ..
-rw-r--r--  1 root root      122  1 avr 21:03 angle-down.png
-rw-r--r--  1 root root 63110183  1 avr 21:03 background.mp4
-rw-r--r--  1 root root     1254  1 avr 21:03 loginterminalc.png
-rw-r--r--  1 root root    11086  1 avr 21:03 Main.qml
-rw-r--r--  1 root root      312  1 avr 21:03 metadata.desktop
-rw-r--r--  1 root root       36  1 avr 21:03 theme.conf
-rw-r--r--  1 root root      209  1 avr 21:03 theme.conf.user
# Configuration SDDM — sddm-video v2 — PapaOursPolaire
# Généré le 2026-04-01 21:03:10
#
# Pour changer la vidéo de fond :
#   sudo bash sddm-video.sh --change-video
# Pour diagnostiquer un problème :
#   bash sddm-video.sh --diagnose

[General]
Numlock=on
# DisplayServer=x11  ← décommentez si nécessaire
# InputMethod= vide : SDDM ne démarre aucune méthode d'entrée dans le greeter.
# Cela empêche IBus de s'initialiser hors contexte Wayland et évite l'alerte :
# "IBus should be called from the desktop session in Wayland".
InputMethod=

[Theme]
Current=sddm-video

[Users]
MinimumUid=1000
MaximumUid=60000
pas de tmp
HTTP/2 200 
cache-control: max-age=300
content-security-policy: default-src 'none'; style-src 'unsafe-inline'; sandbox
content-type: image/png
etag: "7f1b5a8064e76782bac443df66471caa3c7c448e49251d1c9c16b5e64651da3e"
strict-transport-security: max-age=31536000
x-content-type-options: nosniff
x-frame-options: deny
x-xss-protection: 1; mode=block
x-github-request-id: C16E:2B0974:81E1A0:88D5C1:69CD6E0C
accept-ranges: bytes
date: Wed, 01 Apr 2026 19:12:13 GMT
via: 1.1 varnish
x-served-by: cache-bru1480055-BRU
x-cache: MISS
x-cache-hits: 0
x-timer: S1775070733.544088,VS0,VE650
vary: Authorization,Accept-Encoding
access-control-allow-origin: *
cross-origin-resource-policy: cross-origin
x-fastly-request-id: 1d6e8d6701a1809f8853bb9b75b4e3ec5420561d
expires: Wed, 01 Apr 2026 19:17:13 GMT
source-age: 0
content-length: 138718

papaours@papaours:~$ 
