# Sourced by the container's test runners: starts a D-Bus session and an unlocked gnome-keyring, which rayvn's secrets
# test needs to store secrets in the Linux keyring.

if command -v dbus-launch &> /dev/null && command -v gnome-keyring-daemon &> /dev/null; then
    eval "$(dbus-launch --sh-syntax)"
    echo "" | gnome-keyring-daemon --unlock --components=secrets &> /dev/null || true
fi
