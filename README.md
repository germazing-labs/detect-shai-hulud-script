# Mini Shai-Hulud Scanner

Small Bash scanner for looking for known Mini Shai-Hulud / TanStack compromise indicators in a local project or repository.

## What It Does

The script performs a read-only scan for:

- suspicious package and lockfile entries
- risky lifecycle hooks in `package.json`
- known payload and persistence file names or strings
- exposed `.env` files
- git branch or ref names containing `shai-hulud`

It prints findings to the terminal and exits with:

- `0` when no obvious indicators are found
- `1` when potential indicators are detected
- `2` when the target path does not exist

## Who Should Run It

This script is intended for developers, repository maintainers, security engineers, or incident responders who need a quick local triage check on code they own or are explicitly authorized to inspect.

Do not run it against systems, repositories, or files you are not permitted to access.

## How To Run It

Run it from this directory with Bash:

```bash
bash ./detect-mini-shai-hulud.sh
```

Scan a specific directory:

```bash
bash ./detect-mini-shai-hulud.sh /path/to/project
```

Scan a specific file:

```bash
bash ./detect-mini-shai-hulud.sh /path/to/file
```

If you prefer, make it executable first:

```bash
chmod +x ./detect-mini-shai-hulud.sh
./detect-mini-shai-hulud.sh /path/to/project
```

## Disclaimer

Use this script at your own risk.

It is only a lightweight indicator scan, not a full forensic or malware-analysis tool. A clean result does not prove a project is safe, and a positive result should be manually reviewed before acting on it.
