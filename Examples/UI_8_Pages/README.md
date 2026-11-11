# 武侠UI组件使用

打开project.godot运行。Esc返回/关闭弹窗。八页包括组件、背包、门派武学、对话任务、音效设置、小地图、装备、商店；背包与交易等为展示数据，音量控制实际总线。

复制UI/及assets/fonts/，使用UI/wuxia_theme.tres或实例化UI/prefabs/。35个预制场景包括27个组件场景与8个页面；按用途为25类组件。Page.gd和Widget.gd在运行时建立子控件，可通过data/configure配置内容。

UI/icons/items/含100个物品图标；UI/atlases/items_64px.png为640×640、10列64px图集，配套JSON列出rect、source_size、source_offset与export_png。individual_64/为统一64×64版本，icons/items/保留各自尺寸。UI/icons/skills/为33张技能缩略图。复制图集时保留对应索引。

## 组件配置接口


预制件继承统一主题。生成前设置data，运行中调用configure字典重建内容；重建会清除该组件的临时选中/输入状态。数据由游戏端传入，不读取外部文件或联网。

```gdscript
var quantity = preload("res://UI/prefabs/QuantitySelector.tscn").instantiate()
quantity.data = {"min": 1, "max": 20, "value": 2}
quantity.changed.connect(func(value): print(value))
add_child(quantity)
```

|预制件|data字段 / 方法|信号|
|---|---|---|
|Slider|min/max/value/step/disabled|changed(float)|
|Dropdown|options、disabled_options（索引）、disabled|changed(index)|
|Tooltip|title/body/width；悬停按钮另用TooltipButton的tooltip_title/body|无|
|TabNavigation|tabs/selected/disabled_tabs；select_tab(index)|changed(index)，由调用者切页面|
|Pagination|pages/page（从0开始）；set_page(index)|changed(index)|
|InventoryGrid|items（name/icon/count）/columns/capacity/selected|changed(index)|
|ItemDetails|name/description/attributes字典|无|
|DialogueBox|speaker/body/portrait（res://路径或空）/options|activated(选项文字)|
|TaskEntry|title/progress/total/complete|changed(bool)|
|MiniMapDisplay|position（[x,y]）/markers（id/position）|无；仅简图|
|WindowHeader|title|activated(back/close)，调用者决定导航或关闭|
|ScrollingList|items（字符串数组）/empty_text|changed(index)|
|SearchField|query/placeholder/disabled|changed(text)，调用者过滤；带清除|
|QuantitySelector|min/max/value/disabled；set_quantity(value)|changed(int)，允许手动输入|
|EquipmentSlots|slots（name/icon）/selected；select_slot(index)|changed(index)|
|ShopItemRow|name/icon/price/stock/owned；primary为数量选择器|activated(buy/sell)，调用者交易校验|
|ConfirmationModal|title/body/button；open_confirmation()|activated(confirm/cancel)，默认聚焦取消|
|StatusEffectBar|effects数组（name/icon/remaining秒/layers）；configure更新|本地倒计时，到期移除；空数组显示空态|
|ToastMessage|message/severity/seconds；show_message(text,severity,seconds)|activated(expired)；info/success/error；后一次消息重启定时|
|Hotbar|slots数组（name/icon/key/cooldown秒/disabled）/selected；activate_hotbar(index)|changed(index)/activated(索引字符串)；只演示选中/冷却，不施放真实技能|

数量选择器支持整数和SpinBox的数值表达式输入，不接受自由文本。价格/库存需游戏端提供非负整数；示例页面在提交确认时再次校验余额与数量，但无持久化、折扣或网络交易。

组件状态条只显示本地计时，不附加属性或伤害；Hotbar以1/2/3为默认键，输入框聚焦、组件隐藏、禁用或冷却时不触发。应用需自行连接activated到技能逻辑并同步真实冷却。不要把Esc等系统导航键作为快捷栏按键。短消息不含消息队列或历史日志，后一次消息直接覆盖前一次。
