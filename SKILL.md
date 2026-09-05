---
name: seu-sc
description: Synchronize a local project to the SEU cluster and run or monitor it through either an interactive seu-gpu terminal or a non-interactive seu-login plus Slurm job. Use for SEU remote GPU development, smoke tests, training jobs, log monitoring, and result retrieval; do not run training directly on login nodes.
---

# SEU Scientific Computing

Keep the local project as the source of truth. Code and project data belong below one of the user-configured project roots, commonly `/seu_share2/home/<mentor-group>/<card-number>/` and `/seu_share/home/<mentor-group>/<card-number>/`. Logs, checkpoints, and other generated outputs belong below the separately configured output root, normally `/seu_nvme/home/<mentor-group>/<card-number>/`.

## Initialize once

Before the first use, collect the mentor-group directory and card number, then run [scripts/initialize-seu-sc.ps1](scripts/initialize-seu-sc.ps1). This writes `%LOCALAPPDATA%\seu-sc\config.json` with allowed project roots, the default project root, output root, Conda root, optional default Conda environment, and SSH aliases. The file contains local user settings, not keys, tokens, or cookies. Do not guess identity values from another user. Read [references/project-layout.md](references/project-layout.md) when initializing identity or choosing per-project sync/data/output directories.

If stable SSH aliases are absent or authentication fails, read [references/ssh-setup.md](references/ssh-setup.md) and guide the user through key creation, public-key installation, and SSH config. Never regenerate or overwrite working keys merely because the skill is being initialized. The `seu-gpu` hostname and port remain allocation-specific.

## Choose the execution mode

- Choose **Slurm batch mode** for training, long or unattended runs, sweeps, reproducible experiments, or any task that must survive local disconnects. Read [references/slurm-batch.md](references/slurm-batch.md).
- Choose **interactive GPU mode** for short smoke tests, dependency and CUDA diagnosis, `pdb`, repeated edit-test cycles, or commands that need immediate terminal feedback. Read [references/interactive-gpu.md](references/interactive-gpu.md).
- If the intent is unclear, prefer Slurm for a real experiment and `seu-gpu` only for bounded debugging.

## Shared workflow

1. Load the initialized configuration. Identify the authoritative local project, remote sync directory, output directory, Conda environment, and intended command. Ask only for values that cannot be inferred safely.
2. Modify code locally. Do not make the remote copy a second source of truth.
3. Synchronize through `seu-login` with [scripts/sync-project.ps1](scripts/sync-project.ps1). Let the user set a project name or a specific remote sync directory below any configured project root. It overlays uploaded files and deliberately excludes Git metadata, caches, logs, and checkpoints; it does not delete stale remote files. Do not exclude project data unless the user requests it.
4. Before a long run, verify the selected execution node, GPU visibility, Python executable, imports, output path, and a minimal smoke test.
5. Execute through the selected mode. Never run training, GPU work, or sustained computation directly on `login01` or `login02`.
6. Let the user set a specific run-output root below the configured NVMe root. Monitor remote logs in place and download only final artifacts or files that need local analysis.

Use SSH alias `seu-login` for synchronization, Slurm submission, job status, and log access. Use `seu-gpu` only for the currently allocated interactive GPU container. If `seu-gpu` fails after a new allocation, report that its dynamic hostname or port must be refreshed; do not silently fall back to running compute on `seu-login`.

The scripts are standalone and must not call the SEU web console or scripts outside this skill. Treat submission and remote execution as external mutations: show the resolved project, command, queue, GPU count, and output paths before the first substantial run when they were not already explicitly supplied.

