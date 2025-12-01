#!/bin/sh
# Setup script for pmo - configures permissions for non-root access

UDEV_RULE="/etc/udev/rules.d/90-pmo.rules"

echo "Creating udev rule for video group access..."
doas tee "$UDEV_RULE" > /dev/null << 'EOF'
SUBSYSTEM=="graphics", KERNEL=="fb0", RUN+="/bin/chmod g+w /sys%p/blank"
SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys%p/brightness"
EOF
doas udevadm control --reload-rules
doas udevadm trigger
echo "Done. Reboot or run: doas chmod g+w /sys/class/graphics/fb0/blank"
