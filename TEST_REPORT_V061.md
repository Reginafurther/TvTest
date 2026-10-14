# V0.6.1 自动测试报告

测试日期：2026-10-14。环境：Linux、Godot 4.6.3 headless。所有测试使用隔离的 `XDG_DATA_HOME`，不接触玩家存档。

| 测试 | 结果 | 覆盖 |
|---|---|---|
| `--v061-start-test` | PASS | 刘备单人、150虎符、材料招募3人、编队替换、纯治疗阻断、V0.6隔离 |
| `--v061-ai-test` | PASS | 3波实战、坦克拦截、近战接敌、远程撤退、治疗站位与治疗普攻 |
| `--v061-exclusive-skill-test` | PASS | 10专属主动、10专属被动、升级、UI与存档 |
| `--v061-skill-test` | PASS | 32通用主动、20通用被动真实触发，槽位、书本升级与重载 |
| `--v061-progression-test` | PASS | 20关Boss、顺序解锁、自动推进/重复/终局循环、动态等级上限、首通去重 |
| `--v061-economy-test` | PASS | 全品质职业评分、一次9件、不偷装/锁定、出售过滤、技能书来源 |
| `--v061-core-test` | PASS | 掉落→角色页穿戴→替换→卸下、战斗属性刷新、装备重载、离线收益一次性领取、双分辨率边界 |
| `--v061-playtest-fixes-test` | PASS | 伤害轨迹、限时盾、减伤、单击招募、20关滚动、金币升级、书本回收、数值说明、统计清空、技能/Boss校准 |
| `--v061-long-combat-test` | PASS | 30分钟真实结算管线、6次目标替换、状态叠加、第10/20关Boss、异常零伤害=0 |
| `tests/balance_simulation.gd` | PASS | 8阵容×20关×120次；Lv7第18关阻断、Lv20成型第20关可通、多治疗不无限生存 |

命令模板：

```bash
XDG_CONFIG_HOME=/tmp/wanjie-godot-config XDG_DATA_HOME=/tmp/wanjie-v061-test XDG_CACHE_HOME=/tmp/wanjie-font-cache godot --headless --path . -- --v061-core-test
```

布局断言已覆盖 1440×768、1920×1080，结果为 PASS。截图导出在云端失败，原因是 headless 驱动只提供 Dummy Renderer、无法取得 viewport texture；这不是游戏脚本异常。Windows 4.7 目视验收见独立检查表。
