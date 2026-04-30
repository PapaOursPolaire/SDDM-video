sudo tee /etc/sddm.conf > /dev/null <<EOF
[Theme]
Current=SDDM-Fallout-Qt6

[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
EOF
