# 原创机关与装备道具

- `winch.png`：铜框、青绿线缆与手柄的卷扬机。
- `maul.png`：宽横锤头、细握柄的重击锤。
- `props.blend`：可编辑 Blender 场景，含独立 `winch`／`maul` 集合与共享透明渲染灯光。

两张 PNG 均为 256×256 RGBA 透明图，使用本项目原创低多边形几何与程序材质生成；没有下载或复制第三方模型、纹理、照片。实际检查过 256px 原图与 50px 地图缩略图。

## 重建

在仓库根目录，使用 Blender 4.3.x：

```sh
blender -b -t 4 -P tools/build_props.py
# 只重绘指定图片；仍保存含全部模型的可编辑场景：
blender -b -t 4 -P tools/build_props.py -- --only winch
blender -b -t 4 -P tools/build_props.py -- --only maul
```

脚本使用 Cycles CPU、96 样本、透明背景。当前机器 Blender 没有 OpenImageDenoise 支持，因此不启用降噪。没有安装额外软件。

实际构建及场景重开核验摘要见 `VERIFICATION.txt`。这些是道具资产，不包含游戏规则；字体的 OFL 许可另见 `assets/fonts/LICENSE-OFL.txt`。本目录未另行选择全项目开源许可证。
