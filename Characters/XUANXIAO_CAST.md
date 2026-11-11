# 玄霄掌门四向通用Cast

南、北、东、西各8帧，共32张128×144透明PNG，单次1200ms，逐帧120/140/180/180/100/160/140/180ms；不循环，结束回同向Idle。供玄霄技能共用，保留两套攻击。

读取Characters/ANIMATION_LIBRARY.json中的clips.cast。南向锚点[64,126]、北向[64,129]、东西[64,133]。切换到不同画布的Idle时同时更新纹理偏移，保持世界脚点；按nearest原生尺寸播放。

suggested_release为接入建议：北f002起始260ms，其他方向f005起始720ms（帧从0计）。具体特效/伤害触发由游戏决定。本组不内置战斗逻辑。

Examples/XuanxiaoCast/project.godot为播放示例：Space施法，A自动播放。示例里的Idle/Cast副本用于独立运行，不计为新人物。门派包与整合包提供本组Cast。
