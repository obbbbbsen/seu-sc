# Slurm batch mode

Use this mode for long, unattended, or reproducible GPU work. The control path is local Codex → SSH alias `seu-login` → `/usr/bin/sbatch_wrapper` → allocated compute node. Closing the local app or SSH connection does not stop the job.

## Submit

Synchronize first, then call:

```powershell
& <skill-dir>\scripts\submit-slurm.ps1 `
  -JobName experiment-name `
  -Partition gpu_v100 `
  -GpuCount 1 `
  -CpuCount 1 `
  -WorkDir /seu_share2/home/MENTOR_GROUP/CARD_NUMBER/projects/project-name `
  -RunRoot /seu_nvme/home/MENTOR_GROUP/CARD_NUMBER/project-name-runs `
  -Command 'python -u train.py --output-dir "$RUN_DIR"'
```

The initialized user configuration supplies these defaults:

- Conda root: normally `/seu_share2/home/<mentor-group>/<card-number>/.conda/envs`
- Conda environment: selected per run by name or full path, unless initialization configured a default
- Anaconda module: `anaconda3-2024.10-1`
- Log root: `<nvme-root>/slurm_logs`
- Run root: `<nvme-root>/runs`, unless the user selects another directory below the NVMe root

The script prints the Job ID and resolved paths. It exposes `RUN_DIR=<run-root>/<job-name>-<job-id>` to the command. The submitted Slurm file is archived under `<log-root>/submitted/`, and copied to `<RUN_DIR>/job.slurm` when the job starts.

Add `-Preview` to inspect the generated Slurm script without connecting or submitting.

Queue names and limits are controlled by the cluster. `normal_test` is appropriate only for a minimal test and may be killed at the platform test limit. A lack of fully idle nodes does not prevent submission; the job may run on a partially occupied node or remain pending.

## Monitor

```powershell
& <skill-dir>\scripts\monitor-slurm.ps1 -JobId 1234567 -JobName experiment-name
```

Add `-Follow` for a continuous `tail -F`. Read `.out` and `.err` remotely instead of repeatedly downloading them. Use SCP only for final checkpoints, metrics needed by local tools, or requested archival.

If an import resolves into `/seu_share/apps/anaconda3/lib/python3.6`, treat it as environment contamination. The supplied submitter clears `PYTHONPATH` and `PYTHONHOME`, activates the selected environment, and uses `bash -c` rather than a second login shell.

