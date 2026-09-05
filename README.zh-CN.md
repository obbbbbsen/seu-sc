# seu-sc

[English](README.md) | **简体中文**

一个可复用的 Codex skill，用于将本地项目同步到 SEU 科学计算集群，并根据任务类型选择：

- 通过已分配的 SSH 容器进行交互式 GPU 调试；或
- 通过稳定登录节点提交非交互式、长时间运行的 Slurm 作业。

## 环境要求

- Windows PowerShell
- OpenSSH 客户端（`ssh` 和 `scp`）
- `tar`
- 已具有目标集群的访问权限
- 支持本地 skills 的 Codex

## 安装

克隆仓库，然后将仓库目录放置或链接到：

```text
%USERPROFILE%\.codex\skills\seu-sc
```

例如，在 PowerShell 中执行：

```powershell
git clone https://github.com/YOUR_ACCOUNT/seu-sc.git "$env:USERPROFILE\.codex\skills\seu-sc"
```

如果 skill 没有立即出现，请重启 Codex。

## 初始化

不要提交真实配置文件。请使用自己集群账户对应的参数初始化 skill：

```powershell
& "$env:USERPROFILE\.codex\skills\seu-sc\scripts\initialize-seu-sc.ps1" `
  -MentorGroup YOUR_GROUP `
  -CardNumber YOUR_ACCOUNT `
  -CheckSsh
```

初始化程序会将本机私有配置写入：

```text
%LOCALAPPDATA%\seu-sc\config.json
```

该路径有意设置在 Git 仓库之外。

如果你的集群使用不同的存储目录、SSH 别名、模块名称或 Conda 路径，请传入相应的初始化参数。详见[项目与输出目录](references/project-layout.md)和 [SSH 初始化](references/ssh-setup.md)。

## 典型用法

让 Codex 使用 `$seu-sc`，并说明本地项目、期望的输出目录、Conda 环境，以及任务属于交互式调试还是长时间 Slurm 实验。该 skill 会保持本地项目为权威源，通过登录节点同步代码，只在已分配的 GPU 资源上运行计算，并直接监控远程日志。

这些脚本也可以直接调用。详细示例见：

- [交互式 GPU 模式](references/interactive-gpu.md)
- [Slurm 批处理模式](references/slurm-batch.md)
- [项目与输出目录](references/project-layout.md)

## 隐私与安全

- 切勿提交 `%LOCALAPPDATA%\seu-sc\config.json`。
- 切勿上传 SSH 私钥。
- 文档中的占位符只能在本机配置中替换为真实值。
- 每次公开发布前检查 `git status` 并扫描暂存内容。
- 交互式 GPU 容器的主机名和转发端口可能随每次资源分配而变化。

## 许可证

MIT
