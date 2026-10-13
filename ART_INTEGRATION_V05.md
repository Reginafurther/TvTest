# V0.5 美术资源接入说明

V0.5 没有替换或删除 V0.35 美术。角色、地图和装备仍通过 `data/art_resources.json` 查找资源，缺失时安全使用代码占位表现。

- 角色头像：`assets/portraits/`，在 `portraits` 中按角色 ID 配置。
- 战斗单位：`assets/units/`，在 `units` 中按角色 ID 配置。
- 地面和障碍：`assets/maps/ground/`、`assets/maps/decor/`，按关卡 ID 配置。
- 装备图标：`assets/equipment/`，在 `equipment_icons` 中按模板 ID 配置。
- 功能图标：在 `function_icons` 中使用 `shop`、`strategy`、`recruit` 等入口 ID。

商店当前会在正式图标缺失时生成按品质/类别着色的 24×24 占位图标。接入正式图标时只需补充资源和 `art_resources.json` 映射，不应修改交易逻辑。六个关卡中未配置专属地面的关卡会继续使用现有安全回退背景，避免伪装成正式美术完成。
