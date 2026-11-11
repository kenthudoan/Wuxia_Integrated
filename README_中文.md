# 整合包 · v1.1.3

34位完整五动作角色，23位附第二套攻击。Idle/Walk八向，Attack/Hurt/Death四向。另附一位斗笠侠客：32组、240张PNG，缺少独立Hurt；按附赠有限动作角色使用。

角色目录见[ANIMATION_LIBRARY.json](Characters/ANIMATION_LIBRARY.json)。使用每组的canvas、anchor、durations_ms、loop与end_behavior，保持nearest采样；切换动作时同时切换偏移，让世界脚点保持不变。

包含免费、门派、反派档的素材，以及建筑、环境、地形、UI、音效和Godot使用示例。34位完整角色，另附一位有限动作斗笠侠客。玄霄剑宗独立地图扩展包不包含。

## 示例入口

- [Audio/Skill_Kit/project.godot](Audio/Skill_Kit/project.godot)
- [Common_VFX/project.godot](Common_VFX/project.godot)
- [Examples/Environment_5/project.godot](Examples/Environment_5/project.godot)
- [Examples/Starter/project.godot](Examples/Starter/project.godot)
- [Examples/UI_8_Pages/project.godot](Examples/UI_8_Pages/project.godot)
- [Examples/XuanxiaoCast/project.godot](Examples/XuanxiaoCast/project.godot)
- [Skills/Godot/project.godot](Skills/Godot/project.godot)

用Godot打开相应project.godot，等待导入后运行。复制技能或场景时保留配套资源目录。PNG/WAV可用于其他引擎；Godot轨迹、Shader和控件需自行移植。特效PNG不包含全部程序运动，示例不是完整游戏框架。

[使用范围](Documentation/KNOWN_LIMITATIONS.md) · [许可证](Documentation/LICENSE.txt) · [第三方署名](Documentation/THIRD_PARTY_NOTICES.md)。素材含AI辅助内容。支持环境：macOS/Godot4.7.1 Compatibility，其他平台未验证。
