# 起步示例

打开project.godot，运行BuyerStart.tscn。WASD/方向键移动；关闭窗口或在编辑器按F8结束。建筑不提供室内，按钮未连接游戏业务。

场景中World包含House、Planter、Chest和Basket；HUD包含HealthBar、Quantity和Button。可在Inspector修改HealthBar.value、Button.text以及Quantity.data的min/max/value。Quantity子控件由Widget.gd在运行时建立。

复制工程时保留BuyerKit、UI、assets/fonts和DoorStates。字体许可见assets/fonts/LICENSE.txt，素材许可见LICENSE.txt，第三方署名见THIRD_PARTY_NOTICES.md。

建筑开门外观位于DoorStates/B02_open.png。选择World/House，启用Editable Children，替换其Sprite.Texture，保持position=(-256,-486)、centered=false、House.scale=(2,2)。恢复Texture为BuyerKit/expansion/textures/B02_512px.png即可切回。切图不会解除Body/Shape碰撞，不包含开门动画或室内触发。
