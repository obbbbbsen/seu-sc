# Interactive GPU mode

Use this mode for short, iterative debugging that needs immediate GPU feedback. It requires a currently allocated container reachable through SSH alias `seu-gpu`; its hostname and forwarded port are allocation-specific.

Synchronize through `seu-login` before testing, then either open an activated terminal:

```powershell
& <skill-dir>\scripts\invoke-gpu-debug.ps1 `
  -WorkDir /seu_share2/home/MENTOR_GROUP/CARD_NUMBER/projects/project-name
```

or run one bounded command:

```powershell
& <skill-dir>\scripts\invoke-gpu-debug.ps1 `
  -WorkDir /seu_share2/home/MENTOR_GROUP/CARD_NUMBER/projects/project-name `
  -Command 'python -u train.py --steps 1'
```

Before debugging, the helper prints `hostname`, Python location and version, and `nvidia-smi`. It clears inherited Python path overrides and activates the configured Conda environment.

Do not use the interactive container for unattended production training. Stopping or expiring the container terminates its processes. Move a validated command to Slurm batch mode for the real experiment.

