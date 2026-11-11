extends Button

@export var tooltip_title := ""
@export_multiline var tooltip_body := ""

func _ready() -> void:
	if tooltip_text.is_empty() and (not tooltip_title.is_empty() or not tooltip_body.is_empty()):tooltip_text = tooltip_title+"\n"+tooltip_body

func _make_custom_tooltip(for_text:String) -> Object:
	if not tooltip_title.is_empty() or not tooltip_body.is_empty():for_text = tooltip_title+"\n"+tooltip_body
	var text := Label.new();text.text = for_text;text.theme_type_variation = "TooltipLabel"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(420,get_theme_font("font").get_multiline_string_size(for_text,HORIZONTAL_ALIGNMENT_LEFT,420,18).y+8)
	text.add_theme_font_size_override("font_size",18)
	return text
