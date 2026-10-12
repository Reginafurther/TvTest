# 《万界冒险团》V0.2A 自动测试报告

验证日期：2026-10-12（Asia/Shanghai）  
引擎：Godot Engine 4.3.stable.official，Windows 64 位便携版  
方式：真实主场景、无窗口运行、4 倍时间加速

## 原系统回归

```text
SMOKE_TEST_PASS elapsed=20.0 kills=7 heroes=4 wave=2
EXIT=0
```

结论：AStarGrid2D 寻路、四人自动索敌、移动、攻击、技能、治疗和波次刷新没有因装备系统而中断。

## V0.2A 自动验收

正式验收运行使用隔离的测试存档：

```text
EQUIPMENT_TEST_PASS elapsed=20.0 kills=6 drops=8 unique_ids=true slots=36 save_reload=true
```

自动断言覆盖：

- 战斗击杀后产生随机掉落并进入背包；
- 4 名角色各有 9 个栏位；
- 攻击、生命、防御、暴击率、攻速、冷却缩减进入角色实时属性；
- 装备防御后，同一笔原始伤害的实际承伤下降；
- 卸下装备后角色属性恢复到穿戴前数值；
- 穿戴、替换、卸下不会改变背包物品总数；
- 保存后由全新管理器重载，装备数量、实例 ID 和穿戴关系一致；
- 背包内所有实例 ID 唯一；
- 测试可重复运行，不读取或覆盖正式存档。

另以两个独立 Godot 进程执行写入与读取，确认真实重启后的持久化：

```text
PERSISTENCE_WRITE_PASS id=6acc910e-1-af433a affixes=5
PERSISTENCE_READ_PASS id=6acc910e-1-af433a items=1 affixes=5
```

## 配置与静态检查

- 5 档品质、9 个栏位、9 个基础模板：通过
- 10 种首批词条及数值配置：通过
- 角色、技能、掉落表 JSON：通过
- Git 工作区与历史：通过

## Windows 可执行文件

本机没有安装 Godot 4.3 Windows 导出模板，故未生成 `.exe`。工程已包含 Windows Desktop x86_64 导出预设；安装匹配版本模板后可按 README 的步骤导出。

