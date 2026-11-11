# 通用技能使用 / Common VFX

打开project.godot运行；选择技能，或打开某个Skills/*/Demo.tscn按F6运行。WASD/方向键移动，Space施放，H重置。墨影断江按住Space蓄力、松开释放（1–3秒）；基础剑弧用J/K/L切换近战、剑气和组合。

六招通用技能加一组基础剑弧：

- [缩地成寸](Skills/01_Suodi/README.md)
- [万剑归宗](Skills/02_Wanjian/README.md)
- [葬花吟](Skills/03_Zanghua/README.md)
- [如来神掌](Skills/04_Rulai/README.md)
- [斗转星移](Skills/05_Taiji/README.md)
- [墨影断江](Skills/06_Moying/README.md)
- [基础剑弧](Skills/07_Sword_Arc/README.md)

每招的Source.gd为入口，Demo.tscn为示例，PNG/保存对应贴图。Shared/含运行必需的参考角色、目标、音效与共享逻辑。提取单招时保留Shared、该技能目录、catalog.json及项目入口；也可在项目内直接运行该招Demo.tscn。

缩地成寸的残影取自角色当前纹理，无独立特效PNG。完整轨迹、旋转、残影和淡出依赖代码与Shader。木桩、伤害、击退和速度倍率为示例规则，游戏逻辑需自行接入。

[许可](LICENSE.txt) · [第三方声明](THIRD_PARTY_NOTICES.md)。斗笠侠客独立PNG及动作配置位于../Characters/Original_Hero_Limited/；与示例里的参考角色为同一设计，缺独立Hurt动作。

Open project.godot, select a skill and cast with Space. Keep Shared and the skill folder together. PNGs do not bake procedural trajectories or shaders; examples do not provide a complete combat framework. See README_EN.md for English controls.
