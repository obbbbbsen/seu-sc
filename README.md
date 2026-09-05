# seu-sc

A reusable Codex skill for synchronizing local projects to an SEU scientific-computing cluster and choosing between:

- interactive GPU debugging through an allocated SSH container; and
- non-interactive, long-running Slurm jobs through a stable login node.

The repository contains no user account, mentor-group name, SSH key, access token, cookie, or live cluster configuration. User-specific settings are created outside the skill directory.

## Requirements

- Windows PowerShell
- OpenSSH client (`ssh` and `scp`)
- `tar`
- Existing access to the target cluster
- Codex with local skills support

## Install

Clone the repository, then place or link the repository folder at:

```text
%USERPROFILE%\.codex\skills\seu-sc
```

For example, from PowerShell:

```powershell
git clone https://github.com/YOUR_ACCOUNT/seu-sc.git "$env:USERPROFILE\.codex\skills\seu-sc"
```

Restart Codex after installation if the skill does not appear immediately.

## Initialize

Do not commit a real configuration file. Initialize the skill with values supplied by your own cluster account:

```powershell
& "$env:USERPROFILE\.codex\skills\seu-sc\scripts\initialize-seu-sc.ps1" `
  -MentorGroup YOUR_GROUP `
  -CardNumber YOUR_ACCOUNT `
  -CheckSsh
```

The initializer writes the private, machine-local configuration to:

```text
%LOCALAPPDATA%\seu-sc\config.json
```

That location is deliberately outside the repository.

If your cluster uses different storage layouts, SSH aliases, module names, or Conda locations, pass the corresponding initializer parameters. See [references/project-layout.md](references/project-layout.md) and [references/ssh-setup.md](references/ssh-setup.md).

## Typical use

Ask Codex to use `$seu-sc` and describe the local project, desired output location, Conda environment, and whether the task is an interactive debug run or a long Slurm experiment. The skill keeps the local project authoritative, synchronizes through the login alias, runs compute only on allocated GPU resources, and monitors logs remotely.

The scripts can also be invoked directly. Detailed examples are in:

- [Interactive GPU mode](references/interactive-gpu.md)
- [Slurm batch mode](references/slurm-batch.md)
- [Project and output layout](references/project-layout.md)

## Privacy and security

- Never commit `%LOCALAPPDATA%\seu-sc\config.json`.
- Never upload private SSH keys.
- Replace all documentation placeholders with local values only in machine-local configuration.
- Review `git status` and scan staged content before every public release.
- The interactive GPU hostname and forwarded port may change with each allocation.

## License

MIT
