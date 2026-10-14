# 《万界冒险团》V0.6.1

Godot 4.7 Windows 单机 2D 挂机刷宝 RPG。本版本从已验收的 V0.6 基线提交 `01fa35b` 增量开发；稳定分支 `main` 未被直接修改。

## V0.6.1 核心循环

- 新档仅有 Lv.1 刘备、150 虎符与三个空编队位；须用材料招募输出/坦克角色后才能开战。
- 三国 1—10 关、宝可梦 11—20 关严格顺序解锁；每关末尾均有 Boss，第 10/20 关为吕布/超梦。
- 默认开启“自动挑战下一关”；关闭后重复当前关，第 20 关通关后循环挂机，不重复发首通奖励。
- 10 名角色使用坦克、近战、远程、治疗四类差异化 AI，而非统一追击逻辑。
- 角色专属主动/被动技能保留；另有 52 本通用技能书（32 主动、20 被动），每人可装备 3 主动与 4 被动。
- 角色页统一管理角色、九装备栏、技能、成长与背包；换装实时进入战斗属性。
- 商店支持 JSON 商品、批量购买、技能书、材料及装备买卖；出售列表只显示未穿戴且未锁定装备。
- 装备一键优化按职业实际收益评分，最多 3 件，不拿其他角色装备，锁定装备不参与。
- 角色等级上限随已通关主线难度动态开放，最高仍为 60；低级关卡经验有衰减。

V0.6.1 使用全新独立存档命名空间，不读取或覆盖 V0.6 进度文件。历史版本文档仍保留，仅用于追踪旧行为。

## 运行

Windows 安装 Godot 4.7 标准版，在项目管理器导入本目录的 `project.godot`，按 F6/F5 运行。命令行可执行：

```powershell
godot --path .
```

Windows 4.7 完整自动回归：

```powershell
powershell -ExecutionPolicy Bypass -File .\verify_v061_playtest.ps1 -GodotBin 'D:\Tools\Godot_v4.7-stable_win64_console.exe'
```

常用按键：`B` 打开统一角色页，空格暂停/继续，左键设置集结点。顶部功能入口可进入招募、商店、技能策略、目标与统计。

## 数据配置

- `data/actors.json`：10 名角色、职业 AI、专属技能引用。
- `data/skills.json` / `data/passives.json`：专属主动与被动。
- `data/general_skills.json`：52 个通用主动/被动技能。
- `data/worlds.json`：20 关、关底 Boss、首通奖励与地图解锁。
- `data/progression.json`：经验曲线、关卡衰减与动态等级上限。
- `data/shop.json`：商店商品、价格与技能书。
- `data/equipment.json` / `data/loot_tables.json`：装备、词条、品质与掉落。

## 验收资料

- [开发报告](DEVELOPMENT_REPORT_V061.md)
- [自动测试报告](TEST_REPORT_V061.md)
- [人工验收清单](ACCEPTANCE_CHECKLIST_V061.md)
- [技能清单](SKILL_CHECKLIST_V061.md)
- [Boss 清单](BOSS_CHECKLIST_V061.md)
- [数值模拟报告](BALANCE_REPORT_V061.md)
- [Windows Godot 4.7 检查表](WINDOWS_GODOT47_CHECKLIST_V061.md)
- [美术接入说明](ART_INTEGRATION_V061.md)
- [实机验收修复报告](PLAYTEST_FIX_REPORT_V061_1.md)
- [52技能校准表](SKILL_ALIGNMENT_V061_1.md)
- [20关Boss校准表](BOSS_ALIGNMENT_V061_1.md)
- [实机反馈后难度报告](BALANCE_REPORT_V061_1.md)

云端回归使用 Godot 4.6.3 headless；目标配置为 Godot 4.7。云机没有图形显示服务，因此 1440×768、1920×1080 已做布局边界断言，但最终像素级目视检查须按 Windows 4.7 清单执行。
