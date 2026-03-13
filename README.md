# GitHub Copilot Code Server Installer

This repository installs GitHub Copilot and Copilot Chat in code-server.

## Maintenance Status

This project is now maintained in this repository.

It started as a fork of the original sunpix repository, but that upstream is no longer being updated. Ongoing fixes and compatibility updates will be published here instead.

## Run

```bash
curl -fsSL https://raw.githubusercontent.com/hsyhhssyy/howto-install-copilot-in-code-server/refs/heads/main/install-copilot.sh | bash
```

or download it manually and then run:

```bash
chmod +x install-copilot.sh && ./install-copilot.sh
```

## Requirements

- code-server
- curl
- jq
- gzip or gunzip

## Notes

- The script now tries recent Marketplace versions in order and lets code-server decide compatibility during installation.
- This avoids brittle version matching logic when Copilot extension metadata changes upstream.
