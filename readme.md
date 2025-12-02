# Eye Notify Service

The system service sends a 20-minute reminder to take a break for eye exercises while you are working. (20-20-20 rule)

Works on Ubuntu-based systems.


## Install

Run this single command to install the service for the current user and start it immediately:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/cpiaseque/eyenotify/main/install.sh)
```

## Uninstall

To remove the user installation:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/cpiaseque/eyenotify/main/install.sh) --uninstall
```

To remove a system installation (run with sudo):

```bash
sudo bash <(curl -sSL https://raw.githubusercontent.com/cpiaseque/eyenotify/main/install.sh) --uninstall --system
```

## Notes

- The installer will attempt to install `python3`, `python3-venv`, and `libnotify-bin` via `apt` if they are missing (this requires sudo).
- Desktop notifications require a running graphical session; if notifications do not appear, check your `DISPLAY` and session bus settings. The user unit sets `DISPLAY=:0` by default — edit `~/.config/systemd/user/eyenotify.service` if necessary.
- Prefer the user-level installation for desktop notifications. System services usually cannot access a user's graphical session.
