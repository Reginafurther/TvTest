# V0.8 自动测试报告

测试环境：Linux headless，Godot 4.6.3；项目目标是 Windows Godot 4.7。测试结果不能替代 Windows 图形实机验收。

已通过：

- `V08_CONTENT_TEST_PASS`：4世界、40关、36角色、76通用技能、10/20/30关解锁边界、4秘境。
- `V08_SKILLS_TEST_PASS`：16个新增专属主动逐一对真实单位触发；16被动均存在；两名新增治疗角色普攻类型正确；镜瞳无递归、药人有数量上限。
- `V08_SYSTEMS_TEST_PASS`：日志关闭重开保留；批量出售保护穿戴装备；V0.7载荷迁移；全灭倒计时和队伍重建。
- `V08_BALANCE_MATRIX_PASS`：6种队伍、Lv.20/30/40、160次配置采样，综合难度压力1.109，低配跨级被限制，Lv.40成型队伍仍有挑战窗口。
- `V07_UI_ACTORS_TEST_PASS`、`V07_ADVENTURE_TEST_PASS`、`V07_PERSISTENCE_TEST_PASS`：V0.7角色、背包、双秘境、奇遇、营地与迁移字段回归。
- `V061_AI_TEST_PASS`、`V061_SKILL_TEST_PASS`、`V061_CORE_TEST_PASS`、`V061_PLAYTEST_FIXES_TEST_PASS`。
- `V061_LONG_COMBAT_TEST_PASS`：加速模拟30分钟，真实伤害管线、护盾/减伤、换波索敌、Boss10/20和零伤害异常检查通过。
- Godot 全脚本解析、JSON解析通过。

Windows 执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\verify_v08.ps1 -Godot 'D:\Tools\Godot_v4.7-stable_win64_console.exe'
```

尚未完成：Windows 4.7 前台连续30—60分钟真实墙钟挂机、音画帧时间采样及两个分辨率的像素级目视检查。
