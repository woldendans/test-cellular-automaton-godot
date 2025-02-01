extends Sprite2D

# Script built for the ReactionDiffusion compute shader

@export
var shader_file: RDShaderFile

@export 
var size: Vector2i
@export 
var GPS: int = 300
@export 
var FPS: int = 30
@export
var write_frames: bool = false
@export
var stop_at_gen: int = 300 * 70

var rd: RenderingDevice = null
var input_buffer: RID = RID()
var output_buffer: RID = RID()
var output_image: RID = RID()
var pipeline: RID = RID()
var uniform_set: RID = RID()

@onready var interval = (1.0 / GPS)
@onready var frame_interval = (1.0 / FPS)
var generation_time: float = 0.0
var frame_time: float = 0.0
var frames: Array[Image] = []
var gen: int = 0

func _ready():
	if (size.x < 8 || size.y < 8):
		printerr("Use an image of size at least 8x8 pixels.")
		return
		
	if (size.x % 8 != 0 or size.y % 8 != 0):
		printerr("Image width and heigth must be multiples of 8.")
		return
		
	DirAccess.make_dir_recursive_absolute("user://frames")
	
	texture = ImageTexture.create_from_image(Image.create_empty(size.x, size.y, false, Image.FORMAT_L8))

	var prev_world: PackedVector2Array = []
	var next_world: PackedVector2Array = []
	
	prev_world.resize(size.x * size.y)
	next_world.resize(size.x * size.y)
	
	# Init game of life
	var mw := size.x / 2.0
	var mh := size.y / 2.0
	for x in size.x:
		for y in size.y:
			var dist := sqrt(pow(x - mw, 2) + pow(y - mh, 2))
			if (dist < 20):
				prev_world.set(x * size.y + y, Vector2(1.0, 0.0))
			else:
				prev_world.set(x * size.y + y, Vector2(0.0, 1.0))

	rd = RenderingServer.create_local_rendering_device()
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)

	var params := PackedVector4Array([Vector4(size.x, size.y, 0.31, 0)])
	var params_bytes := params.to_byte_array()
	var params_buffer := rd.uniform_buffer_create(params_bytes.size(), params_bytes)

	var input_bytes := prev_world.to_byte_array()
	input_buffer = rd.storage_buffer_create(input_bytes.size(), input_bytes)

	var output_bytes := next_world.to_byte_array()
	output_buffer = rd.storage_buffer_create(output_bytes.size(), output_bytes)
	
	var format := RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	format.width = size.x
	format.height = size.y
	format.texture_type=RenderingDevice.TEXTURE_TYPE_2D
	format.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	output_image = rd.texture_create(format, RDTextureView.new())

	var param_uniform := RDUniform.new()
	param_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	param_uniform.binding = 0
	param_uniform.add_id(params_buffer)
	var input_uniform := RDUniform.new()
	input_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	input_uniform.binding = 1
	input_uniform.add_id(input_buffer)
	var output_uniform := RDUniform.new()
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	output_uniform.binding = 2
	output_uniform.add_id(output_buffer)
	var output_image_uniform := RDUniform.new()
	output_image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_image_uniform.binding = 3
	output_image_uniform.add_id(output_image)
	uniform_set = rd.uniform_set_create(
		[param_uniform, input_uniform, output_uniform, output_image_uniform],
		shader,
		0
	)

	pipeline = rd.compute_pipeline_create(shader)
	step()

func step():
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, ceili(size.x / 8.0), ceili(size.y / 8.0), 1)
	rd.compute_list_end()
	rd.submit()

func sync():
	rd.sync()
	
	var result_bytes := rd.buffer_get_data(output_buffer)
	rd.buffer_update(input_buffer, 0, result_bytes.size(), result_bytes)
	gen += 1

func draw():
	var result_img := rd.texture_get_data(output_image, 0)
	var image: Image = Image.create_from_data(size.x, size.y, false, Image.FORMAT_L8, result_img)
	(texture as ImageTexture).update(image)
	if write_frames:
		frames.push_back(image)

func _process(delta):
	if gen >= stop_at_gen:
		if frames.size() > 0:
			for frame_index in frames.size():
				frames[frame_index].save_jpg("user://frames/"+("%05d" % frame_index)+"_rd.jpg", 1.0)
			frames.clear()
	else:
		generation_time += delta
		frame_time += delta
		if generation_time > interval:
			sync()
			if frame_time >= frame_interval:
				draw()
				frame_time = 0.0
			step()
			generation_time = 0.0
