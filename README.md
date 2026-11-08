# Magic Tower · 苍穹之钥

一个使用 **Godot 4.6 + Blender 4.3** 制作的原创魔塔玩法原型。三层探索、可预判的战斗、钥匙门、属性成长与最终 Boss。不是随机战斗：每一步都可以先算清楚再决定。

## 启动

1. 安装 Godot 4.6.x（标准版，无需 .NET）。
2. 在 Godot 项目管理器导入本目录的 `project.godot`，按 F6/F5 运行。
3. 或命令行：`godot --path .`

游戏界面暂为英文；中文本地化、音效和完整章节属于后续规划，不冒充已完成。

## 操作

| 操作 | 按键 |
| --- | --- |
| 移动 / 战斗 / 拾取 / 上下楼 | WASD / 方向键，或点击相邻格 |
| 看怪物预计损血 | 鼠标悬停 |
| 怪物手册与规则 | H，关闭用 H / Esc / 点击 |
| 撤销一步 | U，最多本次会话最近 100 步 |
| 保存 | 点击 SAVE 按钮，每步也自动保存 |
| 读取 | L / LOAD |
| 新游戏 | 连按两次 R，覆盖当前自动存档 |

红宝石 +5 攻击，蓝宝石 +4 防御，药水 +100 生命。金钥匙开金门。金币目前是评分，不存在商店或付费机制。击败三层的 Hollow King 通关。

- 玩家先手：`损血 = (ceil(怪物生命 / (玩家攻击 - 怪物防御)) - 1) × max(0, 怪物攻击 - 玩家防御)`。
- 无法破防或会致死的战斗直接阻止，不消耗生命。
- 各楼层双向联通，拾取/开门状态保留；门是捷径，并非所有门都必须打开。
- 存档位于 Godot `user://journey.json`，只在本机，不联网上传。启动新进程后按 L 继续。

## 工程与资产

- `scripts/world.gd`：独立规则模型、地图、存档校验。
- `scripts/main.gd`：绘制、输入、撤销、保存及 UI。
- `assets/tower.blend`：原创可编辑 Blender 魔塔场景。
- `assets/tower.glb`：导出 3D 模型，供后续 3D 展示使用；当前战棋棋盘是 2D。
- `assets/tower.png`：Blender 实际渲染并在游戏左侧使用。
- `tools/build_assets.py`：可复现生成器，运行 `blender -b -P tools/build_assets.py`。
- `docs/PLAN.md`：设计、范围、后续路线和验收标准。

Godot 已关闭 `.blend` 自动导入，避免运行项目必须安装 Blender。保留源文件，实际用 PNG；GLB 可直接在 Godot 中查看。

## 测试

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_world.gd
godot --headless --path . --script tests/test_main.gd
godot --headless --path . --quit-after 30
```

自动测试覆盖墙、锁门、钥匙消耗、确定性损血、无法破防、致死保护、JSON 往返、坏存档拒绝，以及由真实规则执行的三层完整通关路径。最新验证见 `docs/VERIFICATION.md`。

原型不依赖网络服务、第三方素材、密钥或付费 API。尚未包含各平台独立可执行程序；源码在 Godot 中运行。

## 版权与许可

代码和美术为本项目原创。仓库按作者要求公开，但当前未指定开源许可证；不因公开自动授予复制、修改或再分发许可。Godot 和 Blender 是开发工具，未打包其程序或第三方素材。正式开源许可证由作者后续选择。
