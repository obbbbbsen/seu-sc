# SSH initialization

Read this reference when `seu-login`, `seu-jump`, or `seu-gpu` is missing or cannot authenticate. Do not overwrite a working SSH configuration. Back up `%USERPROFILE%\.ssh\config` before changing it.

## Identity and public-key bootstrap

Create one dedicated key pair locally if it does not already exist:

```powershell
ssh-keygen -t rsa -b 2048 -f "$env:USERPROFILE\.ssh\id_rsa_seu_gpu" -C "seu-gpu"
```

The passphrase is intentionally not echoed while typing. Upload only `id_rsa_seu_gpu.pub` through the school platform's existing terminal or file transfer, then append it to the user's persistent home:

```bash
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"
grep -qxF "$(cat id_rsa_seu_gpu.pub)" "$HOME/.ssh/authorized_keys" || cat id_rsa_seu_gpu.pub >> "$HOME/.ssh/authorized_keys"
```

Never upload or disclose the private key.

## Stable aliases

Use the card number as `User`. Substitute the real gateway address, port, and login hostname supplied by the school:

```sshconfig
Host seu-jump
    HostName GATEWAY_HOST
    User CARD_NUMBER
    Port 22222
    IdentityFile C:/Users/WINDOWS_USER/.ssh/id_rsa_seu_gpu
    IdentitiesOnly yes

Host seu-login
    HostName login01
    User CARD_NUMBER
    ProxyJump seu-jump
    IdentityFile C:/Users/WINDOWS_USER/.ssh/id_rsa_seu_gpu
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

Verify without running compute:

```powershell
ssh -o BatchMode=yes seu-login "hostname; echo `$HOME"
```

## Dynamic GPU alias

`seu-gpu` is allocation-specific. After the platform allocates an SSH GPU container, set its reported GPU hostname and forwarded port while keeping the same user, key, and `ProxyJump seu-jump`. Recheck with:

```powershell
ssh -o BatchMode=yes seu-gpu "hostname; nvidia-smi --query-gpu=name,index --format=csv,noheader"
```

Failure of `seu-gpu` must not cause GPU code to run on `seu-login`. Refresh the allocation-specific hostname/port or choose Slurm batch mode.

