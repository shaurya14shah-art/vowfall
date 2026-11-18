class_name LawGeom
extends RefCounted
## Integer geometry for the Law Engine. Points are [x, y] in centimetres on
## the ground plane. No floats: results must be identical on every machine.


static func orient(p: Array, q: Array, r: Array) -> int:
	var v: int = (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
	if v > 0:
		return 1
	if v < 0:
		return -1
	return 0


## True when path a->b meets segment c->d. Touching counts as crossing.
## Collinear overlap and zero-length paths do not.
static func segments_cross(a: Array, b: Array, c: Array, d: Array) -> bool:
	var o1 := orient(a, b, c)
	var o2 := orient(a, b, d)
	var o3 := orient(c, d, a)
	var o4 := orient(c, d, b)
	return o1 != o2 and o3 != o4


static func inside_circle(p: Array, centre: Array, radius: int) -> bool:
	var dx: int = p[0] - centre[0]
	var dy: int = p[1] - centre[1]
	return dx * dx + dy * dy <= radius * radius


static func dist_sq(a: Array, b: Array) -> int:
	var dx: int = a[0] - b[0]
	var dy: int = a[1] - b[1]
	return dx * dx + dy * dy
