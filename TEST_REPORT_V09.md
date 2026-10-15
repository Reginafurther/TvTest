# V0.9 自动测试报告

测试环境：Linux云环境，Godot 4.6.3 headless；目标运行环境为Windows Godot 4.7。

## 已通过

- `./verify_v09.sh`
  - 六世界、60关连续编号、52名可玩角色。
  - 魔兽职业比例1/1/1/3。
  - 新增16套专属主动均可真实释放，专属被动均有运行效果。
  - 魔兽6+6、金庸10+10通用技能数量正确。
  - 金庸10个通用主动均实际扣减敌方生命。
  - 40→41、50→51、60终点与禁止61关。
  - 20个新增普通池不含Boss身份；最终波只生成一个命名Boss。
  - 六世界秘境60/61层边界。
  - V0.8存档迁移、写入、重启读取一致。
  - 真Boss名称、普通怪及玩家角色标签身份隔离。
- `tests/v081_mainline_wave_validation.gd`
  - 全60关普通池/最终波检查。
  - 第23关Boss与召唤物三种死亡顺序。
  - 无第四波、普通/精英/Boss奖励分类正确。
- `tests/v081_combat_optimization_validation.gd`
  - 原36名角色伤害类型、独立最终增伤/减伤、治疗公式、装备词条迁移、治疗AI回归通过。
- `tests/v081_equipment_units_validation.gd`
  - 跨角色装备保护、双戒指优化、持久化、战斗贴图映射回归通过。
- `tests/v082_auto_equipment_scroll_validation.gd`
  - 自动出售/分解、背包满容量处理、持久化、技能滚动稳定回归通过。
- 全部JSON通过 `jq empty`；Godot项目无界面启动与脚本解析通过。

## 未在云环境执行

- 按任务约束未运行长时间挂机、全60关耗时通关或批量平衡压力模拟。
- 云环境只有headless dummy渲染驱动，无法取得真实Viewport截图。工程已提供 `--v09-preview-boss`，Windows运行后会生成 `user://v09_boss_name.png`。

