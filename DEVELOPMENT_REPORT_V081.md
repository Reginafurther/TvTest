# 《万界冒险团》V0.8.1 开发报告

开发分支：`codex/v081-ui-stats-difficulty-reset`  
基线：V0.8 `8d65054`

## 交付结果

- 右侧商店、奇遇、成就、收益、目标、日志、战斗统计改为独立 `ScrollContainer + VBoxContainer`，高度随窗口缩放，不占用中央战场。
- “战斗统计”打开时不暂停战斗，每0.75秒只更新现有数值控件。当前上阵角色即使数据为0也显示，退场角色保留本次历史；支持DPS/HPS排序、伤害占比条、完整数值提示和安全清空。
- 统计覆盖普攻、技能、特效、有效治疗、承伤、技能次数、击杀、装备与材料。召唤物伤害归属召唤者；秘境、奇遇、主线首通和世界Boss收益进入同一统计。
- 赵云正式立绘与战斗贴图已实际加入 `assets`。角色页改为复用单一 `TextureRect`，切换时直接替换纹理，杜绝排队删除造成的串图；缺图角色显示自己的姓名、定位和占位UI，并只记录一次缺图警告。
- `art_resources.json` 新增 `portraits_layouts`、`units_layouts`，支持缩放、偏移和战斗图锚点，无需修改角色页核心代码即可继续接入36名角色美术。
- 设置页难度范围为0.5×—5.0×并提供五档快捷预设。新版1.0×严格等价旧版2.5×；当前敌人不改变，确认后从下一只新敌人/下一波/Boss/秘境/奇遇生效。
- 难度先换算为`旧版等价系数=2.5×新版系数`，再沿用生命=`旧版等价系数^0.55`、攻击=`旧版等价系数^0.35`、防御=`旧版等价系数^0.18`。敌人实例带单次应用标记；玩家属性和奖励不变。
- “重新开始游戏”先备份所有 `wanjie_*.json` 到 `user://backups/reset_时间/`，逐字节校验并生成清单。备份失败立即中止；成功后写迁移阻断标记、初始化进度与背包、校验新存档并重载场景。
- 新开局为刘备Lv.1、第一格上阵、虎符150、金币0、空背包、主线第1关、新版难度1.0×和完整新手引导。仅刘备时不会启动无法获胜的战斗。

## 主要修改文件

- `scripts/v03_ui.gd`：侧栏、实时统计、难度与重开设置页。
- `scripts/combat_stats.gd`：HPS、队伍汇总、零数据角色与收益率。
- `scripts/battle_controller.gd`：召唤归属、统一难度和安全重开入口。
- `scripts/reset_manager.gd`：备份、校验、回滚和迁移阻断。
- `scripts/progression_manager.gd` / `inventory_manager.gd`：难度持久化、新档初始化及旧档迁移保护。
- `scripts/art_catalog.gd` / `character_ui.gd` / `unit.gd`：数据驱动美术布局及可靠切图。
- `data/art_resources.json`、`assets/portraits/zhao_yun_portrait_v1.png`、`assets/units/zhao_yun_battle_v1.png`。

## 已知限制

- 云端只有Godot 4.6.3 headless Dummy renderer，不能进行Windows Godot 4.7像素级截图验收；布局边界、资源实际加载和交互逻辑已自动验证，最终目视检查见人工清单。
- 目前正式角色半身立绘只有赵云和刘备；其他角色按设计显示自己的占位UI，不会借用刘备图片。
