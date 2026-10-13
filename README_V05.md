# 万界冒险团 V0.5

V0.5 以仓库中的 V0.35 为基线增量开发，不替换既有地图、美术、自动战斗、装备实例或双世界架构。`project.godot` 继续保留原应用标识，以便 Godot 能找到旧版用户目录；界面和窗口标题显示 V0.5。

## 完整循环

1. 自动战斗获得金币、世界材料、经验和随机装备。
2. 点击“背包”，选择角色与装备；单击查看比较，双击或点击按钮穿戴。装备实时改变战斗属性并自动保存。
3. 点击“招募”，使用招募令随机获得未拥有的普通角色，或双击角色使用世界材料定向招募。
4. 点击右侧“商店”，按数量购买过渡装备、材料或招募令；非穿戴装备可出售换取金币。
5. 点击“技能”，查看角色主动/被动技能、当前与下一级数值，消耗金币和重铸材料升级。
6. 角色随击杀获得经验并升级。队伍平均等级达到要求后，可进入双世界共六关并挑战吕布、超梦。
7. 再次启动后，在“收益”页面领取最多八小时的离线收益；领取后立即清零并存档。

## 存档兼容

- V0.5 进度：`user://wanjie_v05_progress.json`
- V0.5 装备：`user://wanjie_v05_inventory.json`
- 旧进度 `wanjie_v03_progress.json` 和旧装备 `wanjie_v02_save.json` 只读迁移，原文件不会被覆盖。
- 新字段缺失时使用安全默认值：角色/技能等级从 1 级开始，旧编队、材料、金币和装备关系保留。
- 自动测试使用独立测试文件，不接触玩家存档。

## 运行与验证

推荐使用 Windows Godot 4.7 标准版，导入 `project.godot` 后按 F5。工程不需要 .NET 或第三方插件。

```powershell
$env:GODOT_BIN = 'D:\Tools\Godot_v4.7-stable_win64_console.exe'
powershell -ExecutionPolicy Bypass -File .\verify_project.ps1
```

云端回归使用 Godot 4.6.3 完成；工程的 Godot 4.7 feature 标记未降低。Windows 4.7 的最终鼠标与画面检查请按 `ACCEPTANCE_CHECKLIST_V05.md` 执行。
