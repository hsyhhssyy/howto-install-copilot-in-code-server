# code-server Marketplace Extension Installer

This repository installs Visual Studio Code Marketplace extensions into code-server.

By default, it still installs GitHub Copilot and Copilot Chat, but it can now install arbitrary Marketplace extensions passed as parameters.

It also provides dedicated wrapper scripts for Copilot, Claude, and Codex.

## Maintenance Status

This project is now maintained in this repository.

It started as a fork of the original sunpix repository, but that upstream is no longer being updated. Ongoing fixes and compatibility updates will be published here instead.

## Dedicated Installers

Install GitHub Copilot and Copilot Chat:

```bash
./install-copilot.sh
```

Or run directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/hsyhhssyy/howto-install-copilot-in-code-server/refs/heads/main/install-copilot.sh | bash
```

Install Claude Code:

```bash
./install-claude.sh
```

Or run directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/hsyhhssyy/howto-install-copilot-in-code-server/refs/heads/main/install-claude.sh | bash
```

Install Codex:

```bash
./install-codex.sh
```

Or run directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/hsyhhssyy/howto-install-copilot-in-code-server/refs/heads/main/install-codex.sh | bash
```

Wrapper mapping:

- `install-copilot.sh` -> `GitHub.copilot` + `GitHub.copilot-chat`
- `install-claude.sh` -> `anthropic.claude-code`
- `install-codex.sh` -> `openai.chatgpt`

## Generic Installer

```bash
curl -fsSL https://raw.githubusercontent.com/hsyhhssyy/howto-install-copilot-in-code-server/refs/heads/main/install-code-server-extension.sh | bash
```

Install specific extensions:

```bash
curl -fsSL https://raw.githubusercontent.com/hsyhhssyy/howto-install-copilot-in-code-server/refs/heads/main/install-code-server-extension.sh | bash -s -- GitHub.copilot GitHub.copilot-chat ms-python.python
```

Or use the explicit flag form:

```bash
./install-code-server-extension.sh --extension GitHub.copilot --extension ms-python.python
```

Install an exact version:

```bash
./install-code-server-extension.sh ms-python.python@2026.4.1
```

or download it manually and then run:

```bash
chmod +x install-code-server-extension.sh && ./install-code-server-extension.sh
```

Run help:

```bash
./install-code-server-extension.sh --help
```

The dedicated wrappers first try the local generic installer, and if it is not present they fetch the generic installer from GitHub and execute it.

## Search Extension IDs

Search by text and print extension IDs:

```bash
./search-code-server-extension.sh python
```

Limit the number of results:

```bash
./search-code-server-extension.sh --limit 15 git graph
```

## Requirements

- code-server
- curl
- jq
- unzip
- gzip or gunzip

## Notes

- Extension IDs use the Marketplace format `publisher.extension`, for example `GitHub.copilot` or `ms-python.python`.
- If no parameters are provided, the generic installer installs `GitHub.copilot` and `GitHub.copilot-chat` for backward compatibility.
- The installer asks the Marketplace for recent versions first, skips versions already marked as preview/pre-release, and also skips versions whose Marketplace `Microsoft.VisualStudio.Code.Engine` requirement is already incompatible with the local code-server build.
- It still verifies preview status and VS Code engine compatibility from the VSIX itself as a safety net after download.
- For extension specs without `@version`, the script tries recent Marketplace versions in order and lets code-server decide compatibility during installation.
- This avoids brittle version matching logic when upstream Marketplace metadata changes.
- `search-code-server-extension.sh` uses Marketplace keyword search and prints IDs you can pass directly to the installer.
- The dedicated installer scripts support both local execution and `curl | bash` execution. Set `RAW_BASE_URL` if you need to point them at a fork or another branch.
