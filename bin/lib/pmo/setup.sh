#!/bin/sh
# Setup script for pmo - configures permissions for non-root access

UDEV_RULE="/etc/udev/rules.d/90-pmo.rules"

# Install dependencies
for pkg in buffyboard libcap; do
    if ! apk info -e "$pkg" >/dev/null 2>&1; then
        echo "Installing $pkg..."
        if ! doas apk add "$pkg"; then
            echo "Error: Failed to install $pkg" >&2
            exit 1
        fi
    fi
done

# Add user to video group for display control
doas adduser "$USER" video 2>/dev/null

# Allow setfont without root
doas setcap cap_sys_tty_config+ep /usr/bin/setfont

# Udev rules for device access
echo "Creating udev rules..."
doas tee "$UDEV_RULE" > /dev/null << 'EOF'
# Display control
SUBSYSTEM=="graphics", KERNEL=="fb0", RUN+="/bin/chgrp video /sys%p/blank", RUN+="/bin/chmod g+w /sys%p/blank"
SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys%p/brightness", RUN+="/bin/chmod g+w /sys%p/brightness"
# Buffyboard - input devices
KERNEL=="uinput", TAG+="uaccess"
KERNEL=="tty0", TAG+="uaccess"
EOF
doas udevadm control --reload-rules
doas udevadm trigger

echo "Done. Reboot for group changes to take effect."
