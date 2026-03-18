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

- The script now asks the Marketplace for recent versions first, skips versions already marked as preview/pre-release, and also skips versions whose Marketplace `Microsoft.VisualStudio.Code.Engine` requirement is already incompatible with the local code-server build.
- It still verifies preview status and VS Code engine compatibility from the VSIX itself as a safety net after download.
