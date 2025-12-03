#!/usr/bin/env sh
# Setup script for pmo - configures permissions for non-root access

UDEV_RULE="/etc/udev/rules.d/90-pmo.rules"
TH_CONF="$HOME/.config/triggerhappy"

# Install dependencies
for pkg in buffyboard libcap musl-locales git make gcc musl-dev linux-headers; do
    if ! apk info -e "$pkg" >/dev/null 2>&1; then
        echo "Installing $pkg..."
        if ! doas apk add --no-interactive "$pkg"; then
            echo "Error: Failed to install $pkg" >&2
            exit 1
        fi
    fi
done

# Build and install triggerhappy
if ! command -v thd >/dev/null 2>&1; then
    echo "Building triggerhappy..."
    cd /tmp
    rm -rf triggerhappy
    git clone --depth 1 https://github.com/wertarbyte/triggerhappy.git
    cd triggerhappy
    make
    doas cp thd th-cmd /usr/local/bin/
    rm -rf /tmp/triggerhappy
    echo "Installed thd to /usr/local/bin/"
fi

# Create triggerhappy config
mkdir -p "$TH_CONF"
[ -f "$TH_CONF/buttons.conf" ] || cat > "$TH_CONF/buttons.conf" << 'EOF'
# Volume buttons
KEY_VOLUMEUP    1    pactl set-sink-volume @DEFAULT_SINK@ +5%
KEY_VOLUMEDOWN  1    pactl set-sink-volume @DEFAULT_SINK@ -5%
EOF

# Add user to video group for display control
doas adduser "$USER" video 2>/dev/null

# Set UTF-8 locale
grep -q 'LANG=C.UTF-8' ~/.profile 2>/dev/null || echo 'export LANG=C.UTF-8' >> ~/.profile

# Allow setfont without root
doas setcap cap_sys_tty_config+ep /usr/sbin/setfont

# Udev rules for device access
echo "Creating udev rules..."
doas tee "$UDEV_RULE" > /dev/null << 'EOF'
# Display control
SUBSYSTEM=="graphics", KERNEL=="fb0", RUN+="/bin/chgrp video /sys%p/blank", RUN+="/bin/chmod g+w /sys%p/blank"
SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys%p/brightness", RUN+="/bin/chmod g+w /sys%p/brightness"
# Buffyboard - input devices
KERNEL=="uinput", TAG+="uaccess"
KERNEL=="tty0", TAG+="uaccess"
# Triggerhappy - input event access
SUBSYSTEM=="input", TAG+="uaccess"
EOF
doas udevadm control --reload-rules
doas udevadm trigger

echo "Done. Reboot for group changes to take effect."
