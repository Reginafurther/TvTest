# V0.6 美术资源接入说明

V0.6继续使用 `data/art_resources.json` 与 `ArtCatalog`，没有把贴图路径硬编码进角色页或战斗逻辑。

- 角色页立绘/头像：在 `portraits` 下以角色ID配置；推荐透明PNG，角色页按保持宽高比居中缩放。
- 战斗形象：在 `units` 下以角色ID配置。
- 20关地图：可在 `maps_ground`、`maps_obstacles`、`maps_decor` 中按 `data/worlds.json` 的 map ID逐步补齐。未配置关卡沿用安全回退，不影响锁定与数值。
- 装备图标：在 `equipment_icons` 下按模板ID配置；品质边框颜色仍由 `data/equipment.json` 驱动。
- 功能图标：`function_icons` 可增加 `party`、`strategy`、`shop`、`world` 等键。

替换PNG后重新导入Godot即可，不要修改物品实例ID、装备槽ID、角色ID或关卡 `global_stage`。正式资源应在1440×768和1920×1080各检查一次裁切、留白和字体对比度。
