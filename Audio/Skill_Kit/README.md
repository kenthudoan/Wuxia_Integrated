# 技能音效使用

33招、105段WAV，44.1kHz双声道PCM16。打开project.godot试听，选择技能后按Space播放整招、Esc停止，也可选择施法/释放/命中/循环阶段；音量与静音控制实际音频总线。

Audio/catalog.json包含技能、阶段音效、时长、循环和试听时间；SFX_Mapping.csv为对应表。复制Audio/和所需Scripts/，通过SectSkillAudio.gd的begin(id)、advance(seconds)、impact(damage)、finish()、stop_all()与set_gain(db)调用。停止或离开场景时结束循环。

preview_impact_times仅供试听演示，正式游戏应按真实接触触发命中音。保留WAV导入设置以使用无损PCM，不开启normalize/trim等转换。版权及录音署名见SOURCE_LICENSES.md，字体许可见fonts/。试听器不提供Boss战斗、伤害或完整角色技能逻辑。
