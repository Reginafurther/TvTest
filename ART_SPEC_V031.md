# V0.31 美术资源接入规范

正式 PNG 尚未提供，当前画面保留原有代码绘制的 Q 版占位形象。不要将 `tests/fixtures/replaceable_texture.svg` 视为正式美术；它仅用于验证加载接口。

在 `data/art_resources.json` 填写 `res://` 路径。路径必须指向项目内文件；未填写、文件不存在或不是纹理时自动回退占位内容。更换文件后重新打开 Godot 项目并运行，让导入器处理 PNG。

| 类别 | 建议目录 | JSON 分组 | 键 | 建议 PNG 尺寸 |
|---|---|---|---|---|
| 角色头像 | `assets/portraits/` | `portraits` | 角色 ID，如 `zhao_yun` | 128×128，透明背景 |
| 战斗角色 | `assets/units/` | `units` | 角色或怪物 ID | 128×144，透明背景；游戏显示约 64×72 |
| 装备图标 | `assets/equipment/` | `equipment_icons` | 模板 ID，如 `wanderer_blade` | 64×64，透明背景 |
| 功能图标 | `assets/ui/` | `function_icons` | `party`、`recruit`、`world`、`boss`、`craft`、`strategy`、`stats` | 32×32，透明背景；始终保留文字 |
| 地面 | `assets/maps/ground/` | `maps_ground` | 地图 ID：`hulao_pass`、`viridian_forest` | 1060×520 整张，或无缝平铺纹理 |
| 地图装饰 | `assets/maps/decor/` | `maps_decor` | 地图 ID | 1060×520，透明背景 |

示例：

```json
{
  "portraits": {"zhao_yun": "res://assets/portraits/zhao_yun.png"},
  "units": {"zhao_yun": "res://assets/units/zhao_yun.png"},
  "equipment_icons": {"wanderer_blade": "res://assets/equipment/wanderer_blade.png"},
  "function_icons": {"recruit": "res://assets/ui/recruit.png"},
  "maps_ground": {"hulao_pass": "res://assets/maps/ground/hulao_pass.png"},
  "maps_decor": {"hulao_pass": "res://assets/maps/decor/hulao_pass.png"}
}
```

完整配置可只填写已完成的条目。战斗角色图片以脚下为基准放在 128×144 画布中，画布底部预留少量透明边；地面与装饰应对齐同一 1060×520 坐标，障碍和寻路仍由 Godot 地图数据决定，换贴图不会改变碰撞。头像目前显示在队伍卡片中；装备图标显示在背包清单中。
