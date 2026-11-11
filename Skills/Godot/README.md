# Sect VFX / 门派技能

七派共21招共享特效。打开project.godot运行；[ / ]选招、方向键切方向、Space重播、G切光晕、B换底色、I演示来袭。Keep SectVFX and Examples/Hanyue together for the gallery.

接入项目时复制SectVFX/，读取[接入说明](Documentation/INTEGRATION_GUIDE_zh.md)、[分层用法](Documentation/GROUND_LAYERING.md)与[播放参数](Documentation/PLAYBACK_CONTRACTS.json)。保留帧时长、逻辑尺寸、锚点、轨迹与Shader；仅播放PNG不能复现全部程序运动。

ExportNativeFrames.py按招式导出阶段PNG与播放参数，不烘焙完整轨迹和光晕。四向显示使用贴图及变换，不等于八向独立绘图。支持macOS/Godot4.7.1 Compatibility；其他引擎需移植逻辑。
