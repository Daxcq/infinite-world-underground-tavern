# Project Instructions

## The Four Principles in Detail

### 1. Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

LLMs often pick an interpretation silently and run with it. This principle forces explicit reasoning:

- State assumptions explicitly — If uncertain, ask rather than guess
- Present multiple interpretations — Don't pick silently when ambiguity exists
- Push back when warranted — If a simpler approach exists, say so
- Stop when confused — Name what's unclear and ask for clarification

### 2. Simplicity First

Minimum code that solves the problem. Nothing speculative.

Combat the tendency toward overengineering:

- No features beyond what was asked
- No abstractions for single-use code
- No "flexibility" or "configurability" that wasn't requested
- No error handling for impossible scenarios
- If 200 lines could be 50, rewrite it

The test: Would a senior engineer say this is overcomplicated? If yes, simplify.

### 3. Surgical Changes

Touch only what you must. Clean up only your own mess.

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting
- Don't refactor things that aren't broken
- Match existing style, even if you'd do it differently
- If you notice unrelated dead code, mention it — don't delete it

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused
- Don't remove pre-existing dead code unless asked

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

Define success criteria. Loop until verified.

Transform imperative tasks into verifiable goals:

| Instead of... | Transform to... |
| --- | --- |
| "Add validation" | "Write tests for invalid inputs, then make them pass" |
| "Fix the bug" | "Write a test that reproduces it, then make it pass" |
| "Refactor X" | "Ensure tests pass before and after" |

For multi-step tasks, state a brief plan:

1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]

Strong success criteria let the LLM loop independently. Weak criteria ("make it work") require constant clarification.

## 本项目已确认的方向

- 引擎方向为 Godot；具体版本、脚本语言和发布平台尚未确定，以后续真实工程配置为准。
- 玩法底稿为 [地下酒馆赌局_当前方案.md](地下酒馆赌局_当前方案.md)。
- 视角、器官代价与失败结算以较新的 [第一人称3D赌桌_调整方案.md](第一人称3D赌桌_调整方案.md) 为准：俯视 RPG 探索，落座切第一人称 3D，失败依次失去眼、手、心。
- 技能提供实现参考；用户指令、上述四项原则和已确认的项目设计优先。不要因技能示例改换引擎、升级版本、扩展玩法或反复询问已确认的决定。

## GodotPrompter

- 技能按任务加载，不预读整个技能库。
- Godot 系统实现前，先读取 [.agents/skills/using-godot-prompter/SKILL.md](.agents/skills/using-godot-prompter/SKILL.md)，再读取其路由表匹配的领域技能。
- 工具映射参考 [.agents/skills/using-godot-prompter/references/codex-tools.md](.agents/skills/using-godot-prompter/references/codex-tools.md)；仅使用当前环境实际提供的工具。安装技能不代表授权修改全局配置、安装其他插件或创建子代理。
- Godot 实现优先采用 GodotPrompter；通用玩法、美术和体验设计按需读取 [.agents/skills/router/SKILL.md](.agents/skills/router/SKILL.md) 及其推荐的通用技能。另一套技能的 Godot 专题可补充未覆盖的细节，API 兼容性以实际工程版本为准。
- 所有技能采用平铺安装：技能名 `<name>` 对应 `.agents/skills/<name>/SKILL.md`。上游文档中的 `skills/<category>/<name>/SKILL.md` 按技能名映射到此位置；`godot-prompter:<name>` 同样映射到本地 `<name>`，不要求另装插件。
- 安装范围、来源版本、许可证和使用入口见 [.agents/README.md](.agents/README.md)。
