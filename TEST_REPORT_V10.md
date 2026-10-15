# 《万界冒险团》V1.0 自动测试报告

测试环境：云端 Godot 4.6.3 headless；目标运行环境为 Windows Godot 4.7。界面截图使用 X11 + OpenGL llvmpipe 实际渲染。

## 定向回归

| 测试 | 结果 | 覆盖 |
|---|---|---|
| `v10_unobstructed_ranged_ai_validation.gd` | PASS | 固定障碍为0、直接路径、范围内攻击、超距追击、集结中断 |
| `v10_skill_damage_stats_validation.gd` | PASS | 最终生命伤害、多段汇总、DOT来源、召唤归属、重置 |
| `v10_eight_worlds_validation.gd` | PASS | 8世界、80关、72英雄、40通用技能、20专属主动/被动、8秘境、80级、V0.9迁移 |
| JSON解析 | PASS | 新内容、商店、成长、冒险配置合法 |
| 项目启动 | PASS | 无新增GDScript解析错误或资源加载错误 |

关键输出：

```text
V10_UNOBSTRUCTED_RANGED_AI_VALIDATION_PASS obstacles=0 direct_path=true ranged_attack=true pursuit=true rally_interrupt=true
V10_SKILL_DAMAGE_STATS_VALIDATION_PASS actual_hp=true multihit=true dot=true summon_owner=true reset=true
V10_EIGHT_WORLDS_VALIDATION_PASS worlds=8 stages=80 playable=72 new_exclusive=20 new_general=40 rifts=8 level_cap=80 migration=true
```

## 已验证边界

- 60关完成前不能进入61关；60关完成后只能进入61关。
- 70关完成前不能进入71关；70关完成后开放火影忍者。
- 61—80可严格顺序记录通关；80关后 `can_enter_stage(81)` 为 false。
- 所有80张地图的普通怪池均不含Boss身份；61—80关均有唯一中文名关底Boss。
- 新20名英雄专属主动均能实际释放，专属被动ID唯一且有运行时效果。
- 两世界各10主动、10被动；20个新增通用主动均能产生伤害、治疗、防护、控制、循环或有限召唤效果。
- 影分身上限和防递归有效；自来也仙人模式触发条件、7秒持续和18秒冷却有效。
- 旧V0.9角色、等级、材料、60关进度及金庸秘境进度在写盘和重载后保持一致。

## 未自动验证

- Windows Godot 4.7 的最终字体、像素级布局、音频设备和GPU驱动表现需人工验收。
- 未运行长时间80关数值平衡、挂机压力或全Boss通关率模拟；本轮测试聚焦功能正确性。
- 秦时明月与火影忍者正式人物立绘和战斗PNG不在本轮范围。
