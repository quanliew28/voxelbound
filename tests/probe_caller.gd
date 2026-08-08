extends RefCounted
class_name ProbeCaller
static func static_ctx(id: int) -> bool:
	return ProbeHelper.is_special(id)

static func static_ternary(id: int) -> int:
	return 1 if ProbeHelper.is_special(id) else 0
