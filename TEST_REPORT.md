# 第一阶段验证报告

验证日期：2026-10-12（Asia/Shanghai）

## 环境

- Godot Engine 4.3.stable.official（Windows 64 位便携版）
- 无窗口运行模式
- 项目渲染器：Compatibility（GL Compatibility）

## 自动验证

执行了工程自带的 `--smoke-test` 自动战斗冒烟测试。测试会将时间倍率设为 4 倍，实际运行完整游戏场景，并检查：

- 主场景及全部脚本可解析、加载和运行；
- 角色与技能 JSON 可读取；
- 四人小队完成自动寻路、接敌与攻击；
- 伤害/治疗/死亡逻辑可持续运行；
- 至少产生一次有效击杀；
- 测试结束时至少一名英雄存活。

实测结果：

```text
SMOKE_TEST_PASS elapsed=20.0 kills=7 heroes=4 wave=2
EXIT=0
```

## 静态验证

- 必需工程文件检查：通过
- 两份 JSON 语法检查：通过
- 6 个角色配置及其技能引用检查：通过
- Git 工作区检查：通过

## 未执行项目

本机原本未安装 Godot，也未安装 Windows 导出模板。验证使用的是工作区临时便携版编辑器，因此没有生成 Windows `.exe`；项目已提供可直接导入运行的 `project.godot` 和预配置的 Windows x86_64 导出预设。
