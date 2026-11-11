extends Control

var peaks:Array = []
var progress := 0.0

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("122327"))
	if peaks.is_empty():return
	var step := size.x/peaks.size()
	for i in range(peaks.size()):
		var height:float = float(peaks[i])*size.y*.46/.63
		var color := Color("e2c184") if float(i)/peaks.size()<progress else Color("5b9390")
		draw_line(Vector2((i+.5)*step,size.y/2-height),Vector2((i+.5)*step,size.y/2+height),color,maxf(1,step-1))
	draw_line(Vector2(size.x*progress,8),Vector2(size.x*progress,size.y-8),Color("f4dec0"),1)
