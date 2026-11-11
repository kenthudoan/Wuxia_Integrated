# 用交付资源重新搭一小块地图

以下操作只使用本包。建议先复制工程，再在Godot中创建一个Node2D场景，保存为 `BuyerKit/MyMap.tscn`。

若希望用方格自动铺设道路和水岸，优先阅读 `TERRAIN_GUIDE.md`，从connected中的14个示例另存新场景。以下为自由多边形搭建方法，两种方式均可使用。

1. 根节点启用Y Sort，纹理过滤设为Nearest；子节点建立Ground和Objects，Objects同样启用Y Sort。
2. 从 `BuyerKit/terrain/Desert_sand.tscn` 拖入Ground。选择Polygon2D，用编辑器多边形工具修改四个顶点，扩展到1024×768；同时调整UV或保持原512px纹理比例。z_index保留负值。
3. 拖入 `Desert_gravel.tscn`，将其多边形改为一段L形道路，z_index调至比沙地高，例如-8。若需手工方格铺设，可创建TileMapLayer并加载 `Desert_Tiles.tres`；它是基础图集画刷，没有自动连接道路规则。
4. 拖入 `Desert_water.tscn`，编辑水面多边形。在周围放一圈 `Desert_rock.tscn`，使岩岸略大于水面。添加StaticBody2D及CollisionPolygon2D，沿水域内部描边。地形材质片本身默认不带水域碰撞，完整地图中的水域有。
5. 在Objects中拖入 `Desert_poplar.tscn`、`Desert_boulder.tscn` 和 `Desert_inn.tscn`。移动根节点即移动落地点；不要单独移动Sprite2D后又忘记同步碰撞。推荐比例见catalog，例如小树可用0.72倍，驿站用1倍。
6. 若使用独立PNG，Sprite2D取消Centered，position设为catalog对应anchor的负值。图片尺寸是画布尺寸，不是人物/建筑的世界大小，需同时参考recommended_scale。
7. 雪地使用 `Snow_snow.tscn` 才有蓬松shader。需要脚印时，给地图根节点附加 `SnowArea.gd`，设置snow_size，添加道路/水域/桥面等exclusions多边形，并在角色就绪后调用 `snow_map.bind_actor(character_body)`。脚印坐标会转换到地图局部，地图可平移。
8. 加入CharacterBody2D测试标记与半径7px的碰撞，或复用查看器Walker.gd。围绕物件走一圈，确认脚底前后遮挡和碰撞位置，再扩展地图。

材质使用shader时，单独导出的PNG只保留基础像素。跨引擎需要自行移植shader和脚印；不要将普通贴图与Godot材质场景的显示效果混为一谈。

修改 `maps/*.tscn` 可以直接保存并运行，无需原Demo或生成器。若以后重新导出地图，先备份买家改过的场景，避免覆盖自己的编辑。
