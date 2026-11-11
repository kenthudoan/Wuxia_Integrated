# 墨影断江 / Ink Slash

在本套件Godot工程中打开Demo.tscn并按F6运行。WASD/方向键移动与转向，H重置。按住Space蓄力、松开释放，蓄力1–3秒。

Source.gd为技能入口；保留本目录、../../Shared/、catalog.json和项目入口，并保持res://资源路径完整。PNG/目录在提供贴图的技能中存在；缩地成寸直接使用角色纹理形成残影。

运动轨迹、混合、旋转和淡出由代码/Shader实现，跨引擎需移植。参考人物、目标与伤害数值用于演示，不提供完整角色战斗系统。

Run Demo.tscn with F6 inside the kit project. Keep this skill folder and Shared together. Other engines require code/shader integration. The reference actor and targets are demonstration dependencies.
