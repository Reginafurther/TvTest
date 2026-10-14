# 《万界冒险团》V0.8

Godot 4.7 Windows 单机 2D 挂机刷宝 RPG。本版本以 V0.7 提交 `fa6aa44` 为基线，在独立分支 `codex/v08-dragon-nsh-worlds` 开发；稳定分支 `main` 未被直接修改。

## V0.8 核心循环

- 新档仅有 Lv.1 刘备、150 虎符与三个空编队位；须用材料招募输出/坦克角色后才能开战。
- 三国 1—10、宝可梦 11—20、龙族 21—30、逆水寒 31—40 严格顺序解锁；第 10/20/30 关永久开放下一世界。
- 默认开启“自动挑战下一关”；关闭后重复当前关，第 20 关通关后循环挂机，不重复发首通奖励。
- 36 名角色使用坦克、近战、远程、治疗、辅助、急救和召唤差异化 AI；路明非、素问普攻为治疗。
- 每名角色有专属主动/被动；76 个通用技能按四世界与功能类别筛选，每人可装备 3 主动与 4 被动并跨世界构筑。
- 角色页与背包彻底分离；角色装备位可携带角色和部位筛选跳转独立背包，两页共享同一装备实例。
- 商店支持 JSON 商品、批量购买、技能书、材料及装备买卖；出售列表只显示未穿戴且未锁定装备。
- 四世界动态大秘境的最高开放层等于主线最高已通关地图等级；进度、首通、Boss与词缀池独立。
- “挑战”统一承载世界 Boss、主线 Boss 重战和大秘境；全灭默认自动重试，连续失败回退安全关卡。
- 战斗日志由固定长度中央队列维护；角色页隐藏时不再因每次击杀重建 76 技能控件。
- 商店支持按世界筛选及“一键出售未穿戴装备”，提交时再次保护全部角色的穿戴与锁定装备。
- 挂机中可遇到异界精英、宝箱怪、流浪商人和隐藏Boss；战斗事件真实生成敌人并统一结算。
- 可进入12×8网格营地摆放、移动和收回家具，展示角色、收藏品并领取一次性成就奖励。
- 装备一键优化按职业实际收益评分，覆盖全部9栏，不拿其他角色装备，锁定装备不参与。
- 角色等级上限随已通关主线难度动态开放，最高仍为 60；低级关卡经验有衰减。

V0.8 写入独立的 `wanjie_v08_*` 存档；首次启动只读迁移 V0.7，并先生成 `*.pre_v08_backup.json`，原文件不会被覆盖。`project.godot` 的应用名刻意保持旧值，以便仍能定位同一 Godot 用户数据目录。

## 运行

Windows 安装 Godot 4.7 标准版，在项目管理器导入本目录的 `project.godot`，按 F6/F5 运行。命令行可执行：

```powershell
godot --path .
```

Windows 4.7 完整自动回归：

```powershell
powershell -ExecutionPolicy Bypass -File .\verify_v08.ps1 -Godot 'D:\Tools\Godot_v4.7-stable_win64_console.exe'
```

常用按键：`B` 打开独立背包，空格暂停/继续，左键设置集结点。主导航可直接进入角色、背包、世界、大秘境、招募、商店、营地和设置。

## 数据配置

- `data/v08_content.json`：新增世界、16名角色、24通用技能、20关和四世界秘境扩展。
- `data/actors.json`：V0.7 原20名角色与敌人配置。
- `data/skills.json` / `data/passives.json`：专属主动与被动。
- `data/general_skills.json`：52 个通用主动/被动技能。
- `data/worlds.json`：V0.7 原20关；运行时与 V0.8 扩展合并为40关。
- `data/progression.json`：经验曲线、关卡衰减与动态等级上限。
- `data/shop.json`：商店商品、价格与技能书。
- `data/equipment.json` / `data/loot_tables.json`：装备、词条、品质与掉落。
- `data/adventure.json`：秘境成长/词缀、四类奇遇、家具与成就。

## 验收资料

- [V0.8开发报告](DEVELOPMENT_REPORT_V08.md)
- [V0.8自动测试报告](TEST_REPORT_V08.md)
- [V0.8完整内容清单](CONTENT_CATALOG_V08.md)
- [V0.7→V0.8存档迁移报告](SAVE_MIGRATION_V08.md)
- [Windows Godot 4.7人工验收清单](WINDOWS_GODOT47_CHECKLIST_V08.md)
- [美术占位与已知风险](ART_AND_KNOWN_ISSUES_V08.md)

- [V0.7开发报告](DEVELOPMENT_REPORT_V07.md)
- [V0.7自动测试报告](TEST_REPORT_V07.md)
- [20名角色实战对照表](CHARACTER_ROSTER_V07.md)
- [秘境系统说明](RIFT_SYSTEM_V07.md)
- [奇遇系统说明](ENCOUNTER_SYSTEM_V07.md)
- [营地、收藏与成就说明](CAMP_SYSTEM_V07.md)
- [UI导航说明](UI_NAVIGATION_V07.md)
- [存档迁移报告](SAVE_MIGRATION_V07.md)
- [V0.7数值报告](BALANCE_REPORT_V07.md)
- [V0.7验收清单](ACCEPTANCE_CHECKLIST_V07.md)
- [Windows Godot 4.7检查表](WINDOWS_GODOT47_CHECKLIST_V07.md)
- [待替换美术资源](ART_ASSET_GAPS_V07.md)

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
