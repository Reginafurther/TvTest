# V0.6 测试报告

测试日期：2026-10-14（UTC云环境）  
云端引擎：Godot 4.6.3 stable，headless；项目目标仍为 Godot 4.7。

## V0.6专项

- `V06_WORLD_TEST_PASS`：20关编号、顺序解锁、新档世界锁、旧入口防绕过、Boss门槛、通关持久化、V0.5保守迁移。
- `V06_PROGRESSION_TEST_PASS`：等级/类型经验、精英与Boss加成、低级关衰减、四人共享且单次结算、升级属性、刘备治疗AI、远程后撤、存档。
- `V06_CHARACTER_TEST_PASS`：10人、9栏、4标签、经验同步、一键优化最多3件/紫色+/不抢装备、锁定、通用技能实战、存档及两个目标分辨率。

## 旧版回归

以下套件全部通过：

- `SMOKE_TEST_PASS`
- `EQUIPMENT_TEST_PASS`
- `PERSISTENCE_WRITE_PASS` / `PERSISTENCE_READ_PASS`
- `V03_TEST_PASS` / `V03_PERSIST_WRITE_PASS` / `V03_PERSIST_READ_PASS`
- `V031_TEST_PASS` / `V035_TEST_PASS`
- `V05_CORE_TEST_PASS`
- `V05_SHOP_TEST_PASS`
- `V05_SKILL_TEST_PASS`（10/10专属主动、10/10专属被动）
- `V05_SYSTEM_TEST_PASS`（更新为20关正式规则）

## 覆盖结论

- 打怪、装备掉落、穿戴与战斗属性：通过。
- 招募令、材料招募、编队和持久化：通过。
- 商店批量购买、金币不足、背包满、出售、交易记录：通过。
- 专属与通用技能的数值、升级、施放和持久化：通过。
- 20关、双Boss、离线收益防重复、V0.35/V0.5迁移：通过。
- 1440×768、1920×1080：控件几何边界通过；云端无窗口系统，像素级视觉待Windows 4.7人工验收。
