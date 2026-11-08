# MagicTowerCJK 字体子集

`MagicTowerCJK.otf` 是 **Noto Sans CJK SC Regular 2.004** 的简体中文界面派生子集，用于本游戏的中文／英文显示。字形来自系统已安装的 Noto 字库，不是本项目原创字形，也未下载额外字体。

## 许可和来源

- 原字体版权：© 2014–2021 Adobe；系统发行包另记载 Copyright 2010–2012 Google Corporation。原字体作者信息保留在 OTF 的 `name` 表及 `manifest.json` 中。
- 上游：https://github.com/notofonts/noto-cjk
- 构建来源：`/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc`，简中 face（脚本按 PostScript 名查找，当前索引为 2）。
- 许可文字来源：`/usr/share/doc/fonts-noto-cjk/copyright` 的完整 SIL-1.1 部分，并合并字体内嵌版权声明。
- **字体及其派生版本采用 SIL Open Font License 1.1**，完整文本见 [`LICENSE-OFL.txt`](LICENSE-OFL.txt)。该字体许可独立于游戏源码／美术许可；游戏未指定开源许可证不影响字体本身的 OFL 权利。
- 派生字体的 family／full／PostScript 名（含 CFF）已改为 `MagicTowerCJK`，不将 Noto 或 Adobe 名称用于声称背书。保留原作者归属不等于他们认可本游戏。
- 发行游戏时必须同时保留字体版权及 OFL，例如将本目录的 `LICENSE-OFL.txt` 放进导出包。**不能仅销售字体本身。**

## 可重复构建与校验

需要 Python 和 fontTools。默认读取上述本地 TTC；没有联网下载步骤：

```sh
python tools/build_font.py
python tools/build_font.py --check
# 也可明确提供本地字库与许可位置：
python tools/build_font.py --source /path/to/NotoSansCJK-Regular.ttc --copyright /path/to/copyright
```

脚本扫描 `scripts/**/*.gd` 和 `project.godot` 中所有可打印字符，另保留 ASCII、源字体支持的常用标点、箭头和数学符号。生成后核对 cmap、主字体名及 CFF 名，缺字时失败而不是默默遗漏。`manifest.json` 记录输入和输出 SHA-256、face、源作者信息、扫描文件、字符覆盖和文件大小；`characters.txt` 记录强制覆盖字符。

新增中文界面文案后必须重新执行构建及 `--check`。该子集不是通用中文输入字体，不保证显示未出现在源码中的任意用户文本；若以后增加自由输入，须扩大字符范围或提供完整字体。

临时排版可使用 `python tools/build_font.py --full` 输出完整 SC face，**发布前应执行默认命令恢复精简子集**。`manifest.json` 的 mode 会区分两者。完整版权／许可在两种模式下都保留。
