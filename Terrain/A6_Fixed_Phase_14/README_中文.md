# 草地 ↔ 石板 · 固定相位14模块

每格64×64像素、1×、nearest。tiles内G为grass_base_64，S为flagstone_base_64；其余是4直边、4内角、4外角。这里的top等名称以组合图中石板庭院的位置为准，不代表图像可任意旋转。

请直接照LAYOUTS.json的grid摆放，key映射modules里的path；Module_Placement_Guide.png给出编号。4×4庭院、4种内凹角、11×8庭院与道路均用实际交付PNG原样拼接，。庭院上沿为outer_tl / top / top / outer_tr，中心铺S，外围续G；内凹形照对应示例，避免仅按名称猜测内外角。
