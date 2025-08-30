# 🛡️ nosudopass

TUI tool to manage **sudo NOPASSWD** rules for users.
Allows enabling or disabling sudo without password via an interactive terminal menu.

## Support
- OS: `Linux` (only)
- Architecture: `x86_64`, `aarch64`, `arm64`

## Install

### Global

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/teplostanski/nosudopass/main/scripts/install.sh)" -- --global
```

> [!NOTE]
> If you get a `"Permission denied"` error, try running the command using `sudo`.

## 🚀 Run

```bash
sudo nosudopass
```

### Local (for current user)

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/teplostanski/nosudopass/main/scripts/install.sh)"
```

## 🚀 Run

```bash
sudo env PATH="$PATH" nosudopass
```
Or
```bash
sudo ~/.local/bin/nosudopass
```

## Uninstall

```bash
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/teplostanski/nosudopass/main/scripts/uninstall.sh)"
```
