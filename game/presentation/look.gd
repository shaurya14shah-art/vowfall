class_name Look
extends RefCounted
## The palette and a few materials, in one place (docs/08_art_direction.md).
## Greybox uses these so that even stand-in geometry sits in the right world:
## vellum stone, ink shadow, gold for what carries law, vermilion for an act.

const VELLUM := Color(0.86, 0.83, 0.76)
const VELLUM_DARK := Color(0.70, 0.67, 0.60)
const STONE := Color(0.70, 0.67, 0.60)        # lit world surfaces; darker than the HUD's vellum
const STONE_SHADE := Color(0.30, 0.31, 0.37)  # trim, bases, the yard wall: ink-leaning
const INK := Color(0.10, 0.12, 0.19)
const GOLD := Color(0.83, 0.66, 0.28)
const VERMILION := Color(0.80, 0.22, 0.13)
const VERDIGRIS := Color(0.36, 0.55, 0.50)
const STRUCK := Color(0.03, 0.03, 0.04)


static func stone(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.92
	m.metallic = 0.0
	return m


## Dressed stone for a real place: coursed and jointed by a shader, no textures.
static func masonry(colour: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://presentation/shaders/stone_wall.gdshader")
	m.set_shader_parameter("stone", colour)
	m.set_shader_parameter("ink", INK)
	return m


static func flat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func metal(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.45
	m.metallic = 0.8
	return m
