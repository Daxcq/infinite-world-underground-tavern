# 项目级游戏开发技能

本目录包含两套技能的固定版本副本，安装日期为 2026-11-08，范围仅为当前项目。技能逐项放置在 `skills/<name>/SKILL.md`，随附的 references、scripts、assets 等文件完整保留。

## 来源与版本

- [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills)：77 项领域技能＋1 项 `router`，共 78 项；提交 `19d93f97c9c1ea0f8b306e77aa81e0d3e352d3e9`。许可证为 [Apache-2.0](skill-sources/awesome-gamedev-agent-skills/LICENSE)，附 [NOTICE](skill-sources/awesome-gamedev-agent-skills/NOTICE)。
- [GodotPrompter](https://github.com/jame581/GodotPrompter)：59 项技能；提交 `d7b26cdb5fae14d4ef7b713c5bf259395e75c3c6`。许可证为 [MIT](skill-sources/GodotPrompter/LICENSE)。

共 137 项技能，没有重名。机器可读的来源、提交号和逐技能路径保存在 [skills.lock.json](skills.lock.json)。通过 skill-installer 的 `install-skill-from-github.py` 按各自提交号安装，并显式指定项目内的 `skills/` 为目标目录；未使用全局默认安装目录。

## 使用入口

- 项目约定见 [AGENTS.md](../AGENTS.md)，其中完整保留用户提供的四项开发原则。
- Godot 实现从 [using-godot-prompter](skills/using-godot-prompter/SKILL.md) 开始，再加载当前任务对应的领域技能。
- 通用玩法、美术和体验设计从 [router](skills/router/SKILL.md) 按需选择；不一次加载全部技能。
- 可以显式使用 `$using-godot-prompter`、`$router` 或具体技能名，例如 `$camera-system`。
- 上游的 `skills/<category>/<name>/SKILL.md` 与 `godot-prompter:<name>` 均按技能名解析为本项目的 `skills/<name>/SKILL.md`。
- 上游示例所用的 Godot 版本不构成本项目的版本决定。实际开发应先核对工程配置与 API 兼容性。

这些文件是 AI 开发技能，不会自动安装 Godot 引擎、游戏运行时插件、全局配置或可选子代理。下一轮会话可检查技能是否已被发现；若技能列表尚未刷新，重新打开当前项目会话后再检查。
