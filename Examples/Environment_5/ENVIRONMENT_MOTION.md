# 像素环境动态 v1

Godot CanvasItem Shader，通过Shader驱动现有贴图。默认启用。

## 实际范围

- 7处水面：城镇石渠、荷塘、山林河流、雪溪、冰潭、沼泽、绿洲河流。水体内部1px采样偏移与2px块状水纹，以8fps变化；沼泽速度和高光更低，保留原压暗色调。荷塘仅让蓝绿色水像素产生明暗波纹，石沿、荷叶、花不移动。
- 657个植被对象：城镇阔叶/柳树、山林栎树/竹/柳/芦苇、雪松、沼泽植被、沙漠胡杨/灌木。顶部可见图像为基准，幅度3～4个源图像素，10fps整数像素偏移，下部14%固定；不变更节点位置、脚底锚点、Y排序或碰撞。枯树、裸枝、岩石、亭阁不摆动。
- 12个独立灯具：11个城镇灯、1个山林石灯。仅灯窗微暖色闪动，附低强度分级暖光；屋顶和灯杆保留。建筑合成图里画死的红灯笼/窗户不在这12个独立灯具中。

## 操作

独立五地图工程：1～5切地图、WASD移动、F9开关当前地图动态。普通地形自动拼接图集仍是静态PNG；若需要动态水面，应使用带动态组件的 `BuyerKit/terrain/*_water.tscn`，或在自建水面 Polygon2D 上配置 Water.gdshader。

## 复用与参数

每张地图附一个EnvironmentMotion子节点，扫描已标记的植被和灯具，以及明确的水面节点。动态物件预制件、独立水材质场景也附同一组件。

`metadata/environment_kind`用于明确物件种类，避免将亭子、岩石等非植被误识别为树木。自建水面使用`metadata/environment_water=true`。

- Water.gdshader：speed控制速度，marsh保持沼泽色调，composite只对合成荷塘中的水色变化。
- Wind.gdshader：amplitude、top_y、anchor_y控制可见冠部与固定根部；region_px/atlas_size防止采到相邻图集格，alpha_cutoff保留原有0.55硬透明规则。
- Lantern.gdshader：window_px框定灯窗；Glow.gdshader为程序生成的低强度分级光晕，没有新增光晕PNG。
- 四个Shader均有motion_time，-1使用TIME；非负数用于暂停在指定时间。
- EnvironmentMotion.set_enabled(false)恢复原材质并隐藏光晕；set_time(value)统一设置动画时间。

地图控制器遇到已经带控制器的预制件，会接管其材质和开关，避免重复套材质或响应两次F9。新内容放好后需重新扫描/重新进入场景，本版不每帧扫描树。

## 边界

这是视觉动态，不是流体、风力或物理光照模拟；没有新增昼夜、天气、游泳或火灾系统。Shader依赖Godot，跨引擎需移植。TIME不受SceneTree暂停控制，UI覆盖期间环境时间继续，返回后不会重载地图。
