#!/usr/bin/env bash
set -euo pipefail

#!/usr/bin/env bash
set -euo pipefail

# Simple installer for eyenotify
# Usage:
#  - Single-command remote install (recommended):
#      bash <(curl -sSL https://raw.githubusercontent.com/cpiaseque/eyenotify/main/install.sh)
#+ optional: pass --system to perform a system-wide install
#  - To uninstall: run the same script with --uninstall

DEFAULT_REPO="https://github.com/cpiaseque/eyenotify"
REPO_ARG="${1:-}"
MODE="user"
UNINSTALL=0

if [ "${REPO_ARG}" = "--system" ]; then
  MODE="system"
  REPO_ARG=""
elif [ "${REPO_ARG}" = "--uninstall" ]; then
  UNINSTALL=1
  REPO_ARG=""
fi

if [ "${2:-}" = "--system" ]; then
  MODE="system"
fi

SUDO=""
if [ "$EUID" -ne 0 ]; then
  SUDO="sudo"
fi

# If no repo provided, default to the project's GitHub URL (enables single-command install)
if [ -z "$REPO_ARG" ]; then
  REPO_ARG="$DEFAULT_REPO"
fi

SCRIPT_DIR="$(pwd)"
TMPDIR=""

if [ -n "$REPO_ARG" ]; then
  TMPDIR="$(mktemp -d)"
  echo "Cloning repository ${REPO_ARG} to ${TMPDIR}..."
  git clone --depth 1 "$REPO_ARG" "$TMPDIR"
  SCRIPT_DIR="$TMPDIR"
fi

# Where to install for user/system
if [ "$MODE" = "system" ]; then
  INSTALL_DIR="/opt/eyenotify"
  SERVICE_PATH="/etc/systemd/system/eyenotify.service"
else
  INSTALL_DIR="$HOME/.local/share/eyenotify"
  SERVICE_DIR="$HOME/.config/systemd/user"
  SERVICE_PATH="$SERVICE_DIR/eyenotify.service"
fi

function cleanup_tmp() {
  if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
  fi
}

trap cleanup_tmp EXIT

if [ $UNINSTALL -eq 1 ]; then
  echo "Uninstalling eyenotify (mode=$MODE)"
  if [ "$MODE" = "system" ]; then
    $SUDO systemctl stop eyenotify.service || true
    $SUDO systemctl disable eyenotify.service || true
    $SUDO rm -f /etc/systemd/system/eyenotify.service || true
    $SUDO systemctl daemon-reload || true
    $SUDO rm -rf /opt/eyenotify || true
    echo "System uninstall complete. System packages (libnotify, python3) are not removed.";
  else
    systemctl --user stop eyenotify.service || true
    systemctl --user disable eyenotify.service || true
    rm -f "$SERVICE_PATH" || true
    systemctl --user daemon-reload || true
    rm -rf "$INSTALL_DIR" || true
    echo "User uninstall complete.";
  fi
  exit 0
fi

echo "Installing eyenotify (mode=$MODE) from: $SCRIPT_DIR"

if [ "$MODE" = "system" ]; then
  echo "Note: system install may not display desktop notifications in user sessions."
fi

# Ensure python3 exists
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found. Installing required packages (requires sudo)..."
  $SUDO apt-get update
  $SUDO apt-get install -y python3 python3-venv git libnotify-bin
fi

# Ensure notify-send is available
if ! command -v notify-send >/dev/null 2>&1; then
  echo "Installing libnotify-bin (notify-send)..."
  $SUDO apt-get update
  $SUDO apt-get install -y libnotify-bin
fi

if [ "$MODE" = "system" ]; then
  echo "Preparing system install at $INSTALL_DIR"
  $SUDO mkdir -p "$INSTALL_DIR"
  $SUDO rm -rf "$INSTALL_DIR"/* || true
  $SUDO cp -a "$SCRIPT_DIR"/* "$INSTALL_DIR"/

  echo "Creating python venv..."
  $SUDO python3 -m venv "$INSTALL_DIR/venv"
  $SUDO "$INSTALL_DIR/venv/bin/pip" install --upgrade pip >/dev/null
  if [ -f "$INSTALL_DIR/requirements.txt" ]; then
    $SUDO "$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt" || true
  fi

  # create system user if not exists
  if ! id -u eyenotify >/dev/null 2>&1; then
    $SUDO useradd --system --no-create-home --shell /usr/sbin/nologin eyenotify || true
  fi

  $SUDO chown -R eyenotify:eyenotify "$INSTALL_DIR"

  echo "Creating systemd service file at $SERVICE_PATH"
  $SUDO bash -c "cat > $SERVICE_PATH <<'SERVICE'
[Unit]
Description=EyeNotify (Health Notification Service)
After=network.target

[Service]
Type=simple
User=eyenotify
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/eyenotify.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
SERVICE"

  $SUDO systemctl daemon-reload
  $SUDO systemctl enable --now eyenotify.service
  echo "System service enabled and started (may not display desktop notifications)."
else
  echo "Preparing user install at $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALL_DIR"/* || true
  cp -a "$SCRIPT_DIR"/* "$INSTALL_DIR"/

  echo "Creating python venv..."
  python3 -m venv "$INSTALL_DIR/venv"
  "$INSTALL_DIR/venv/bin/pip" install --upgrade pip >/dev/null
  if [ -f "$INSTALL_DIR/requirements.txt" ]; then
    "$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt" || true
  fi

  mkdir -p "$SERVICE_DIR"
  echo "Creating systemd user service at $SERVICE_PATH"
  cat > "$SERVICE_PATH" <<'SERVICE'
[Unit]
Description=EyeNotify (Health Notification Service)
After=graphical-session.target

[Service]
Type=simple
Environment=DISPLAY=:0
Environment=PYTHONUNBUFFERED=1
ExecStart=%h/.local/share/eyenotify/venv/bin/python %h/.local/share/eyenotify/eyenotify.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
SERVICE

  # Reload user units and enable service
  systemctl --user daemon-reload
  systemctl --user enable --now eyenotify.service
  echo "User service enabled and started."
  echo "If notifications don't appear, ensure you are running a graphical session and adjust DISPLAY in the unit if needed."
fi

echo "Installation finished."
