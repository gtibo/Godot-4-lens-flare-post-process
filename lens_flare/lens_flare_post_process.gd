class_name LensFlarePostProcess
extends CompositorEffect

var rd : RenderingDevice
var shader : RID
var pipeline : RID
var linear_sampler : RID
const template_shader : String = "#version 450"

const LENS_FLARE_SUN_FLARE : Texture2D = preload("./lens_flare_sun_flare.png")
const GLSL_FILE : RDShaderFile = preload("./lens_flare.glsl")
var lens_flare_tex: RID

func _init() -> void:
	RenderingServer.call_on_render_thread(_init_compute_shader)

func _notification(what: int) -> void:
	# If script instance about to be destroyed
	# Free resources from memory
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid(): rd.free_rid(shader)
		if linear_sampler.is_valid(): rd.free_rid(linear_sampler)
		if lens_flare_tex.is_valid(): rd.free_rid(lens_flare_tex)

func _render_callback(_effect_callback_type: int, render_data: RenderData):
	if rd == null: return
	
	var scene_buffers : RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	var scene_data : RenderSceneDataRD = render_data.get_render_scene_data()
	if scene_buffers == null || scene_data == null: return
	
	var size : Vector2i = scene_buffers.get_internal_size()
	if size.x == 0 || size.y == 0: return
	
	@warning_ignore("integer_division")
	var x_groups : int = (size.x - 1) / 8 + 1
	@warning_ignore("integer_division")
	var y_groups : int = (size.y - 1) / 8 + 1
	var z_groups = 1
	
	var push_constants : PackedFloat32Array = PackedFloat32Array()
	push_constants.append(size.x)
	push_constants.append(size.y)
	push_constants.append(SunFlare.sun_screen_position.x)
	push_constants.append(SunFlare.sun_screen_position.y)
	push_constants.append(SunFlare.sun_dot)
	push_constants.append(0.0)
	push_constants.append(0.0)
	push_constants.append(0.0)

	for view in scene_buffers.get_view_count():
		var screen_tex : RID = scene_buffers.get_color_layer(view)
		
		var uniform : RDUniform = RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.binding = 0
		uniform.add_id(screen_tex)
	
		var image_uniform_set : RID = UniformSetCacheRD.get_cache(shader, 0, [uniform])
		
		uniform = RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		uniform.binding = 0
		uniform.add_id(linear_sampler)
		uniform.add_id(lens_flare_tex)
	
		var lens_flare_texture_set : RID = UniformSetCacheRD.get_cache(shader, 1, [uniform])

		# Run our compute shader
		var compute_list : int = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, image_uniform_set, 0)
		rd.compute_list_bind_uniform_set(compute_list, lens_flare_texture_set, 1)
		rd.compute_list_set_push_constant(compute_list, push_constants.to_byte_array(), push_constants.size() * 4)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
		rd.compute_list_end()

func _init_compute_shader() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null: return

	shader = rd.shader_create_from_spirv(GLSL_FILE.get_spirv())
	pipeline = rd.compute_pipeline_create(shader)

	var sampler_state : RDSamplerState = RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_BORDER
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_BORDER
	linear_sampler = rd.sampler_create(sampler_state)

	# Load flare image...
	var flare_image : Image = LENS_FLARE_SUN_FLARE.get_image()
	flare_image.convert(Image.FORMAT_RGF)
	
	var texture_format : RDTextureFormat = RDTextureFormat.new()
	texture_format.width = flare_image.get_width()
	texture_format.height = flare_image.get_height()
	texture_format.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT;
	texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT;
	lens_flare_tex = rd.texture_create(texture_format, RDTextureView.new(), [flare_image.get_data()])
