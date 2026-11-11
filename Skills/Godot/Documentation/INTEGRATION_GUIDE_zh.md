# 技能接入接口

## 接入Godot

把**整个 `SectVFX/`**复制到项目根目录，路径保持 `res://SectVFX/`。角色、城镇、UI、原工程缓存和这套预览场景均不是运行依赖。

```gdscript
var fx = preload("res://SectVFX/SectVFX.gd").new()
add_child(fx)
fx.global_position = caster_ground_world_position
var error = fx.play_skill("02_beam", "east", Vector2(216,0), {
    "contact_offsets": [Vector2(390,0), Vector2(216,0)],
})
assert(error == OK)
fx.finished.connect(func(_id): fx.queue_free())
```

组件节点放在施法者**脚底/地面位置**。`target_offset` 与 `contact_offsets` 都是相对**本次施法初始脚点**的地面偏移，不是角色头顶，不是绝对世界坐标。方向为 east / west / north / south。世界坐标回调见下表。

组件使用世界地面坐标，内部保留一个原点为零的私有视觉容器；因此节点可以摆在任意地面位置，父节点平移不会让脚锚错位。技能开始后，区域特效保留施法时的世界位置；移动外部角色不会拖着剑阵跑。1×比例在原坐标下验证，不建议缩放/旋转组件节点来改变画面尺寸；用摄像机管理显示。

### 常用选项

|选项|内容|默认|
|---|---|---|
|`contact_offsets`|内部视觉接触标记的地面偏移数组|`[target_offset]`；传`[]`不生成命中事件|
|`ally_offsets`|治疗光效的两处友方位置偏移|`[[-82,12],[86,18]]`，须恰好两处|
|`caster_texture` / `caster_anchor`|你自己的角色纹理与脚锚，用于残影|有现成母图时复用，不生成新人物|
|`show_caster`|是否显示静态参考人物|false；即使隐藏人物，残影仍可取其纹理|
|`demo_incoming`|自动演示来袭弹，不是敌人AI|false，正式接入应保持关闭|
|`endpoint_resolver(from,to)`|返回被墙截断后的世界地面终点|直接返回to，不查地图/物理|
|`path_blocker(from,to)`|你的遮挡判断，返回bool|使用endpoint_resolver结果，未提供则不遮挡|
|`movement_resolver(from,wanted)`|为内部视觉运动锚点返回允许位置|允许移动到wanted；不会直接移动买家的角色|

回调的 from/to/wanted 都是**世界地面坐标**，不是相对偏移。组件自身不做物理查询，也不会触碰你的玩家、NPC、血量或装备。

`contact(skill, ground_world)`、`support(skill)`、`caster_motion(skill, from_world, to_world)` 是视觉提示，按延迟信号发送，避免回调中重播导致旧效果中断崩溃；`finished(skill)` 发送结束事件。它们**不是伤害/治疗/位移权限**，示例数值不能直接作为正式伤害。敌我、距离、墙壁、命中和状态由你的游戏确认。

现有视觉仍用几何条件选择接触光的位置，目标标记只存在组件内部；旧兼容字段如training/test_hp不会修改游戏对象。治疗仅播放光效，不增加真实HP；束缚仅更新内部标记，不冻结真实敌人。

### 防御/反击与剑阵事件

正式播放时关闭自动来袭，在你的游戏确认防御接触后调用：

```gdscript
if fx.incoming_contact():
    pass # 已接受视觉反击事件；无需生成训练木桩或攻击者
```

适用于回风归鞘、花影移香、虚竹卸劲、金钟震岳、不动明王身。返回false表示当前模式、时段或状态不接受事件；不适用的技能（包括剑阵）也安全返回false。每次只触发一轮。

为让反击在原固定寿命内完整播完，独立入口接受窗口如下（从本次施法开始计秒）：回风归鞘0.25～4.20，花影移香0.30～2.00，虚竹卸劲0.45～2.30，金钟0.78～2.60，明王0.78～2.50。过晚事件返回false，不截断一段未完成的反击。请在上述窗口内发送接触事件。

天枢剑阵：先 `play_skill("01_array", facing, target_offset)`。敌人尝试靠近边界时，用 `boundary_attempt(step)` 传入本次地面位移，返回内部允许的相对位置；你的游戏自行决定是否采纳约束。它会触发一把0.6倍的小剑落击，保留1.35秒冷却。阵心固定、七剑缓慢环转，半径[138,78]不收缩。`update_target(offset)`用于同步你已经决定的目标位置；别把整个组件节点跟随目标移动。

### 时间、锚点与方向

调用 `play_skill()` 重播；`stop()`取消并清理；`set_glow(bool)`控制局部淡光。自动播放用固定60Hz视觉时钟。调试时设 `playing=false`，再调用 `advance(seconds)` 或 `seek(seconds)`。倒回seek会重建这次效果，不重新生成素材；seek静音视觉信号，避免拖动时间线重复触发游戏逻辑。

不能假定所有源帧都顺序播完一次：例如一线开天16帧瞬闪源长1008ms，原效果只使用650ms；部分技能只有静态母图，运动/揭示/碎裂在脚本中实现。源帧总长不是整招技能时长。

原始PNG的锚点以**文件画布像素**为单位。普通阶段使用原尺寸；有 `logical_canvas` 时，按 `logical_canvas.x / canvas.x` 缩放，并在此基础上应用技能本身的倍率、扁平投影与旋转。不要把1774px母图直接按1774游戏单位摆放，也不要把它的文件画布尺寸误称为最终像素显示尺寸。硬边核心nearest，局部光晕按原Shader连续采样。

方向变体按已有 right / up / down 元数据选择；西向按原逻辑处理。不宣称每招都重新绘制了四向或八向图片。部分技能共用纹理，仅轨迹或投影变化，这是现有资源的真实能力。

## 不用Godot时

PNG与元数据可独立取得，不依赖Python图像库。想要清楚的阶段文件名：

`python3 ExportNativeFrames.py 03_orbit /你的导出目录`

会在新目录下导出 `03_orbit/default/<phase>/frame_000.png`、`sheet.png`与本地 `phase.json`；有原生方向组的也一并导出。它只复制文件，不编辑像素；目标目录已经存在时拒绝覆盖。`SOURCE_SKILL.json`保留完整原清单，里面的SectVFX路径仍指向原素材库，不冒充已移植的引擎工程。

**完整外观还需要移植轨迹、分层混合与Shader**。只顺播PNG不会自动得到剑阵环转、返回剑、局部白光或花瓣路径。参考实现为Godot；其他引擎需要移植代码，简单透明序列不能复现全部ADD/alpha混合效果。
