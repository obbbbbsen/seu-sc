# User and project layout

Initialize once with identity values supplied by the user:

```powershell
& <skill-dir>\scripts\initialize-seu-sc.ps1 `
  -MentorGroup MENTOR_GROUP `
  -CardNumber CARD_NUMBER `
  -ProjectRoots @(
    '/seu_share2/home/MENTOR_GROUP/CARD_NUMBER',
    '/seu_share/home/MENTOR_GROUP/CARD_NUMBER'
  ) `
  -DefaultProjectRoot '/seu_share2/home/MENTOR_GROUP/CARD_NUMBER' `
  -CondaRoot '/seu_share2/home/MENTOR_GROUP/CARD_NUMBER/.conda/envs' `
  -CheckSsh
```

This derives:

```text
project root 1: /seu_share2/home/MENTOR_GROUP/CARD_NUMBER
project root 2: /seu_share/home/MENTOR_GROUP/CARD_NUMBER
default project: /seu_share2/home/MENTOR_GROUP/CARD_NUMBER/projects
Conda root:     /seu_share2/home/MENTOR_GROUP/CARD_NUMBER/.conda/envs
NVMe outputs:   /seu_nvme/home/MENTOR_GROUP/CARD_NUMBER
```

The default configuration file is `%LOCALAPPDATA%\seu-sc\config.json`, separate from the reusable skill package so skill updates do not overwrite user settings. Use `-ConfigPath` only when a different location is explicitly desired.

The card number is normally also the SSH user, but SSH aliases remain independently configurable because a school may use a different gateway or login hostname. `ProjectRoots`, `DefaultProjectRoot`, `OutputRoot`, and `CondaRoot` can all be overridden during initialization.

`DefaultCondaEnv` is optional. Leave it empty to require an explicit environment for each run, or initialize it with an environment name such as `my-env`. Runtime `-CondaEnv` accepts either a name below `CondaRoot` or a full path below that root.

## Select a synchronization directory

Derive the remote directory from the local folder name:

```powershell
& <skill-dir>\scripts\sync-project.ps1 -LocalProject D:\work\my-project
```

Choose a logical project name:

```powershell
& <skill-dir>\scripts\sync-project.ps1 `
  -LocalProject D:\work\source `
  -ProjectName my-project
```

Or explicitly choose any destination below the configured share root, including a project data directory:

```powershell
& <skill-dir>\scripts\sync-project.ps1 `
  -LocalProject D:\datasets\my-data `
  -RemoteProject /seu_share2/home/MENTOR_GROUP/CARD_NUMBER/data/my-data
```

Project code and input data must stay below one of the configured project roots. The default exclusions remove development caches, logs, and model checkpoints; use `-AdditionalExclude` for project-specific exclusions.

## Select an output directory

Pass `-RunRoot` and, when needed, `-LogRoot` to `submit-slurm.ps1`. Both must remain below the configured NVMe root:

```powershell
-LogRoot /seu_nvme/home/MENTOR_GROUP/CARD_NUMBER/my-project/logs
-RunRoot /seu_nvme/home/MENTOR_GROUP/CARD_NUMBER/my-project/runs
```

The actual run directory adds `<job-name>-<job-id>` below `RunRoot`. Keep generated logs, checkpoints, evaluation outputs, and other experiment artifacts on NVMe rather than in the synchronized project tree.
