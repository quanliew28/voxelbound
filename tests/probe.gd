extends SceneTree
func _initialize() -> void:
	print("A max_stack_for: ", ItemStack.max_stack_for(1))
	print("B direct is_tool: ", ToolRegistry.check_tool(1))
	print("C ternary probe: ", ProbeCaller.static_ternary(11))
	print("D plain probe: ", ProbeCaller.static_ctx(11))
	quit(0)
