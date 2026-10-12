# V0.3 自动测试报告

测试环境：Godot 4.3.stable.official，Windows 64 位，无窗口真实主场景。

完整验收覆盖：

- V0.1 寻路、四人自动战斗、治疗和波次回归。
- V0.2A 掉落、装备属性、36 个出战栏位、唯一 ID 与跨进程装备存档回归。
- 四种特殊词条真实触发与反伤/雷击/中毒扩散/破盾的防递归限制。
- 分解收益、穿戴保护、重铸扣费、接受候选与实例 ID 保持。
- 招募令仅消费一次、角色不重复、编队变化和离队角色装备归属。
- 虎牢关/常青森林敌人池隔离与战斗状态重建。
- 吕布/超梦首胜唯一解锁与重复材料奖励。
- 策略敌人数阈值进入实际技能门控。
- 统计数据来自真实战斗事件。
- V0.3 进度跨两个独立 Godot 进程写入/读取。

最终运行结果记录在 `TEST_RUN_V03.log`。

```text
SMOKE_TEST_PASS elapsed=20.0 kills=6 heroes=4 wave=2
EQUIPMENT_TEST_PASS elapsed=20.0 kills=5 drops=7 unique_ids=true slots=36 save_reload=true
PERSISTENCE_READ_PASS items=1 affixes=5
V03_TEST_PASS worlds=2 roster=7 party=4 specials=4 bosses=2 stats=true crafting=true save=true
V03_PERSIST_READ_PASS roster=5 party0=gengar material=77
PASS: V0.1, V0.2A, V0.3 integration, and both cross-process save suites are valid.
```
