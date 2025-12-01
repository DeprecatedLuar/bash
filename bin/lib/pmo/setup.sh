#!/bin/sh
# Setup script for pmo - configures permissions for non-root access

UDEV_RULE="/etc/udev/rules.d/90-pmo.rules"
DOAS_RULE="/etc/doas.d/pmo.conf"

# Install buffyboard if missing
if ! command -v buffyboard >/dev/null 2>&1; then
    echo "Installing buffyboard..."
    doas apk add buffyboard
fi

# Udev rules for display control
echo "Creating udev rules..."
doas tee "$UDEV_RULE" > /dev/null << 'EOF'
SUBSYSTEM=="graphics", KERNEL=="fb0", RUN+="/bin/chgrp video /sys%p/blank", RUN+="/bin/chmod g+w /sys%p/blank"
SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys%p/brightness", RUN+="/bin/chmod g+w /sys%p/brightness"
EOF
doas udevadm control --reload-rules
doas udevadm trigger

# Doas rules for passwordless access
echo "Creating doas rules..."
doas tee "$DOAS_RULE" > /dev/null << 'EOF'
permit nopass :wheel cmd buffyboard
EOF
doas chmod 600 "$DOAS_RULE"

echo "Done. Reboot or run: doas chmod g+w /sys/class/graphics/fb0/blank"
