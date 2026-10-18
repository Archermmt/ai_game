class_name EditorFeedback
extends RefCounted

const REASONS: Dictionary = {
	"invalid_support": "不能提交：支撑面不适用，请改放长凳或木箱",
	"support_outside_surface": "不能提交：上层物件超出支撑面，请先移开上层",
	"missing_support": "不能提交：支撑面仍被使用，请先移开上层物件",
	"support_stack_limit": "不能提交：叠放层数过多，请减少叠放",
	"hedge_clearance": "绿篱不能放下：请避开建筑、池岸和入口",
	"invalid_hedge_width": "绿篱不能放下：宽度须在 0.5–1.6 米",
	"hedge_segment_limit": "绿篱不能放下：每段长度须在 0.25–16 米",
	"hedge_length_limit": "绿篱不能放下：总长不能超过 40 米",
	"invalid_hedge_points": "绿篱不能放下：请拖出至少两个有效控制点",
	"opening_margin_0_15m": "不能放门窗：距墙角和屋檐至少留出 0.15 米",
	"opening_clearance_0_15m": "不能放门窗：与已有开口至少留出 0.15 米",
	"bridge_adjust_heads": "短桥需要调整：请将两端放到池塘两岸",
	"bridge_missing_pond": "短桥需要浅池，请先画池塘",
	"bridge_length_1_5_to_6": "短桥长度须在 1.5–6 米",
	"bridge_height_0_5": "短桥两端高差不能超过 0.5 米",
	"stair_height_0_15_to_0_9": "短阶高差须在 0.15–0.9 米，请调整地形或入口",
	"stair_length": "短阶长度须在 0.6–3 米",
	"structure_building_collision": "不能放结构：请移到建筑外侧",
	"instance_outside_bounds": "物件不能放到可编辑地块以外",
	"prototype_instance_limit": "已达到 800 项上限，请先擦除或删除部分内容",
	"invalid_palette": "色板不可用，请重新选择",
	"invalid_hedge": "绿篱数据不可用，请重新拖绘"
}


static func humanize(message: String) -> String:
	for key: String in REASONS:
		if key in message:
			return REASONS[key]
	return message
