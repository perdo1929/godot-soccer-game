extends Node3D

const FIELD_LENGTH := 108.0
const FIELD_WIDTH := 70.0
const PLAYER_SPEED := 8.0
const SPRINT_SPEED := 11.5
const BALL_RADIUS := 0.34

var player: CharacterBody3D
var ball: RigidBody3D
var camera: Camera3D
var hud: Label
var opponents: Array[CharacterBody3D] = []
var teammates: Array[CharacterBody3D] = []
var possession := true
var shot_cooldown := 0.0
var match_time := 300.0
var score_home := 0
var score_away := 0
var last_touch := "home"

func _ready() -> void:
	_build_environment()
	_build_pitch()
	_build_goals()
	_build_players()
	_build_ball()
	_build_camera()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.76, 0.85)
	env.ambient_light_energy = 0.65
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

func _mat(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _build_pitch() -> void:
	var grass := _mat(Color(0.08, 0.37, 0.16))
	_box(self, Vector3(FIELD_LENGTH, 0.3, FIELD_WIDTH), Vector3(0, -0.18, 0), grass)
	# Alternating mowing bands
	for i in range(9):
		var band_mat := _mat(Color(0.10, 0.41, 0.18) if i % 2 == 0 else Color(0.07, 0.34, 0.14))
		_box(self, Vector3(FIELD_LENGTH / 9.0, 0.012, FIELD_WIDTH - 0.8),
			Vector3(-FIELD_LENGTH / 2 + FIELD_LENGTH / 18.0 + i * FIELD_LENGTH / 9.0, -0.015, 0), band_mat)
	var white := _mat(Color(0.94, 0.96, 0.91))
	_line(Vector3(-FIELD_LENGTH/2+1, 0.025, -FIELD_WIDTH/2+1), Vector3(FIELD_LENGTH/2-1, 0.025, -FIELD_WIDTH/2+1), 0.12, white)
	_line(Vector3(-FIELD_LENGTH/2+1, 0.025, FIELD_WIDTH/2-1), Vector3(FIELD_LENGTH/2-1, 0.025, FIELD_WIDTH/2-1), 0.12, white)
	_line(Vector3(-FIELD_LENGTH/2+1, 0.025, -FIELD_WIDTH/2+1), Vector3(-FIELD_LENGTH/2+1, 0.025, FIELD_WIDTH/2-1), 0.12, white)
	_line(Vector3(FIELD_LENGTH/2-1, 0.025, -FIELD_WIDTH/2+1), Vector3(FIELD_LENGTH/2-1, 0.025, FIELD_WIDTH/2-1), 0.12, white)
	_line(Vector3(0, 0.03, -FIELD_WIDTH/2+1), Vector3(0, 0.03, FIELD_WIDTH/2-1), 0.1, white)
	_circle(Vector3.ZERO, 9.15, white)
	# Penalty boxes and six-yard boxes
	for side in [-1, 1]:
		var x := side * (FIELD_LENGTH/2 - 16.5)
		_rect_box(Vector3(x, 0.03, 0), Vector2(16.5, 40.3), white)
		var six_x := side * (FIELD_LENGTH/2 - 5.5)
		_rect_box(Vector3(six_x, 0.035, 0), Vector2(5.5, 18.3), white)
		_dot(Vector3(side * (FIELD_LENGTH/2 - 11.0), 0.05, 0), 0.16, white)
	_dot(Vector3.ZERO, 0.16, white)
	# Surroundings and basic stands
	var dark := _mat(Color(0.08, 0.10, 0.12))
	_box(self, Vector3(FIELD_LENGTH + 16, 0.5, FIELD_WIDTH + 16), Vector3(0, -0.42, 0), dark)
	var stand_mat := _mat(Color(0.18, 0.23, 0.28))
	_box(self, Vector3(FIELD_LENGTH + 22, 8, 8), Vector3(0, 3.5, -FIELD_WIDTH/2-9), stand_mat)
	_box(self, Vector3(FIELD_LENGTH + 22, 8, 8), Vector3(0, 3.5, FIELD_WIDTH/2+9), stand_mat)
	_box(self, Vector3(8, 8, FIELD_WIDTH + 24), Vector3(-FIELD_LENGTH/2-9, 3.5, 0), stand_mat)
	_box(self, Vector3(8, 8, FIELD_WIDTH + 24), Vector3(FIELD_LENGTH/2+9, 3.5, 0), stand_mat)

func _line(a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(a.distance_to(b), 0.025, width)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.position = (a+b)/2
	inst.rotation.y = atan2(b.x-a.x, b.z-a.z)
	add_child(inst)

func _rect_box(center: Vector3, size: Vector2, material: Material) -> void:
	var x1 := center.x - size.x/2
	var x2 := center.x + size.x/2
	var z1 := center.z - size.y/2
	var z2 := center.z + size.y/2
	_line(Vector3(x1, center.y, z1), Vector3(x2, center.y, z1), 0.1, material)
	_line(Vector3(x2, center.y, z1), Vector3(x2, center.y, z2), 0.1, material)
	_line(Vector3(x2, center.y, z2), Vector3(x1, center.y, z2), 0.1, material)
	_line(Vector3(x1, center.y, z2), Vector3(x1, center.y, z1), 0.1, material)

func _circle(center: Vector3, radius: float, material: Material) -> void:
	var points := 64
	for i in range(points):
		var a1 := TAU * i / points
		var a2 := TAU * (i+1) / points
		_line(center + Vector3(cos(a1)*radius, 0, sin(a1)*radius),
			center + Vector3(cos(a2)*radius, 0, sin(a2)*radius), 0.08, material)

func _dot(pos: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.025
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.material_override = material
	add_child(inst)

func _build_goals() -> void:
	var white := _mat(Color(0.92, 0.94, 0.92))
	for side in [-1, 1]:
		var x := side * (FIELD_LENGTH/2 + 1.8)
		_box(self, Vector3(0.18, 2.44, 7.32), Vector3(x, 1.22, 0), white)
		_box(self, Vector3(3.6, 0.18, 0.18), Vector3(x - side*1.8, 2.44, -3.66), white)
		_box(self, Vector3(3.6, 0.18, 0.18), Vector3(x - side*1.8, 2.44, 3.66), white)
		_box(self, Vector3(0.12, 2.44, 7.32), Vector3(x - side*3.6, 1.22, 0), white)

func _make_player(team: String, number: int, pos: Vector3, is_user := false) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "%s_%d" % [team, number]
	body.position = pos
	var body_mat := _mat(Color(0.05, 0.22, 0.88) if team == "home" else Color(0.86, 0.08, 0.06))
	var skin := _mat(Color(0.72, 0.48, 0.32))
	var shorts_mat := _mat(Color(0.06, 0.07, 0.10) if team == "home" else Color(0.94, 0.94, 0.91))
	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = 1.05
	torso.mesh = capsule
	torso.position.y = 1.12
	torso.material_override = body_mat
	body.add_child(torso)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	head.mesh = sphere
	head.position = Vector3(0, 1.88, 0)
	head.material_override = skin
	body.add_child(head)
	var shorts := MeshInstance3D.new()
	var short_mesh := BoxMesh.new()
	short_mesh.size = Vector3(0.65, 0.32, 0.43)
	shorts.mesh = short_mesh
	shorts.position.y = 0.57
	shorts.material_override = shorts_mat
	body.add_child(shorts)
	for side in [-1, 1]:
		var leg := MeshInstance3D.new()
		var legmesh := CapsuleMesh.new()
		legmesh.radius = 0.13
		legmesh.height = 0.72
		leg.mesh = legmesh
		leg.position = Vector3(side*0.19, 0.23, 0)
		leg.material_override = skin
		body.add_child(leg)
	var marker := MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.18
	marker_mesh.bottom_radius = 0.18
	marker_mesh.height = 0.04
	marker.mesh = marker_mesh
	marker.position.y = 2.3
	marker.material_override = _mat(Color(1, 0.85, 0.05)) if is_user else body_mat
	body.add_child(marker)
	add_child(body)
	return body

func _build_players() -> void:
	player = _make_player("home", 10, Vector3(-8, 0, 0), true)
	teammates.append(_make_player("home", 7, Vector3(-24, 0, -15)))
	teammates.append(_make_player("home", 9, Vector3(-26, 0, 15)))
	teammates.append(_make_player("home", 8, Vector3(-5, 0, -22)))
	teammates.append(_make_player("home", 6, Vector3(-5, 0, 22)))
	for i in range(6):
		var p := Vector3(12 + float(i%2)*14, 0, float(i-2)*9)
		opponents.append(_make_player("away", i+1, p))

func _build_ball() -> void:
	ball = RigidBody3D.new()
	ball.name = "Ball"
	ball.mass = 0.43
	ball.position = Vector3(-7, BALL_RADIUS, 0)
	ball.linear_damp = 0.35
	ball.angular_damp = 0.25
	ball.continuous_cd = true
	var mesh := SphereMesh.new()
	mesh.radius = BALL_RADIUS
	mesh.height = BALL_RADIUS*2
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _mat(Color(0.96, 0.96, 0.90), 0.42)
	ball.add_child(visual)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = BALL_RADIUS
	shape.shape = sphere
	ball.add_child(shape)
	add_child(ball)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(-15, 27, 28)
	camera.current = true
	camera.fov = 52
	add_child(camera)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(24, 18)
	hud.add_theme_font_size_override("font_size", 24)
	hud.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(hud)
	var controls := Label.new()
	controls.position = Vector2(24, 650)
	controls.text = "WASD: mover  |  SHIFT: correr  |  X: pase  |  ESPACIO: tiro  |  Q: cambiar jugador  |  ESC: liberar mouse"
	controls.add_theme_font_size_override("font_size", 15)
	controls.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(controls)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_Q:
			_switch_player()
		elif event.keycode == KEY_X:
			_pass_ball()
		elif event.keycode == KEY_SPACE:
			_shoot_ball()

func _physics_process(delta: float) -> void:
	shot_cooldown = maxf(0.0, shot_cooldown-delta)
	match_time = maxf(0.0, match_time-delta)
	_move_user(delta)
	_move_ai(delta)
	_handle_ball_control(delta)
	_check_goals()
	_update_camera(delta)
	hud.text = "%02d:%02d     LOCAL %d  -  %d VISITANTE     %s" % [
		int(match_time)/60, int(match_time)%60, score_home, score_away,
		"POSESIÓN LOCAL" if possession else "PELOTA LIBRE / RIVAL"
	]

func _move_user(delta: float) -> void:
	var input_vec := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	var dir := Vector3(input_vec.x, 0, input_vec.y).normalized()
	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else PLAYER_SPEED
	player.velocity.x = dir.x * speed
	player.velocity.z = dir.z * speed
	player.velocity.y = 0
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -FIELD_LENGTH/2+1, FIELD_LENGTH/2-1)
	player.position.z = clampf(player.position.z, -FIELD_WIDTH/2+1, FIELD_WIDTH/2-1)
	if dir.length() > 0.1:
		player.rotation.y = atan2(dir.x, dir.z)

func _move_ai(delta: float) -> void:
	for i in range(opponents.size()):
		var p := opponents[i]
		var target := ball.global_position
		var to_ball := target - p.global_position
		to_ball.y = 0
		var speed := 5.2 if i != 0 else 6.1
		if to_ball.length() > 1.5:
			var dir := to_ball.normalized()
			p.velocity.x = dir.x * speed
			p.velocity.z = dir.z * speed
			p.move_and_slide()
			p.rotation.y = atan2(dir.x, dir.z)
		else:
			p.velocity = Vector3.ZERO
	for i in range(teammates.size()):
		var tm := teammates[i]
		var base := [Vector3(-24,0,-15), Vector3(-26,0,15), Vector3(-5,0,-22), Vector3(-5,0,22)][i]
		var target_pos := base
		if possession:
			target_pos.x += 5.0
			target_pos.z += sin(Time.get_ticks_msec()/900.0 + i) * 3.0
		else:
			target_pos.x -= 3.0
		var offset := target_pos - tm.position
		offset.y = 0
		if offset.length() > 0.8:
			var dir := offset.normalized()
			tm.velocity.x = dir.x * 4.3
			tm.velocity.z = dir.z * 4.3
			tm.move_and_slide()

func _handle_ball_control(_delta: float) -> void:
	if possession:
		var forward := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
		var target := player.global_position + forward * 1.0 + Vector3(0, 0.34, 0)
		if player.global_position.distance_to(ball.global_position) < 2.6:
			ball.linear_velocity = ball.linear_velocity.lerp((target-ball.global_position)*5.0, 0.16)
		else:
			possession = false
	else:
		var nearest := _nearest_player_to_ball()
		if nearest != null and nearest[1] < 1.15 and ball.linear_velocity.length() < 8.0:
			if nearest[0] == player:
				possession = true
				last_touch = "home"
			elif nearest[0] in opponents:
				last_touch = "away"
				ball.linear_velocity += (nearest[0].global_position.direction_to(ball.global_position) + Vector3(0,0.12,0))*2.0
	# Opponent can win it by getting close to the user while the user has possession.
	if possession:
		for op in opponents:
			if op.global_position.distance_to(player.global_position) < 1.25:
				possession = false
				var steal_dir := (player.global_position - op.global_position).normalized()
				ball.linear_velocity = steal_dir * 3.8 + Vector3(0, 0.7, 0)
				last_touch = "away"
				break

func _nearest_player_to_ball():
	var best = null
	var best_dist := INF
	var all_players: Array = [player]
	all_players.append_array(teammates)
	all_players.append_array(opponents)
	for p in all_players:
		var d: float = p.global_position.distance_to(ball.global_position)
		if d < best_dist:
			best_dist = d
			best = p
	return [best, best_dist]

func _pass_ball() -> void:
	if not possession:
		return
	var nearest_tm: CharacterBody3D = null
	var best := INF
	for tm in teammates:
		var d := player.global_position.distance_to(tm.global_position)
		if d < best:
			best = d
			nearest_tm = tm
	if nearest_tm != null:
		var dir := (nearest_tm.global_position - player.global_position).normalized()
		ball.global_position = player.global_position + dir*1.0 + Vector3(0, 0.4, 0)
		ball.linear_velocity = dir*13.0 + Vector3(0, 1.2, 0)
		possession = false
		last_touch = "home"

func _shoot_ball() -> void:
	if not possession or shot_cooldown > 0:
		return
	shot_cooldown = 0.4
	var target := Vector3(FIELD_LENGTH/2 + 1.0, 1.3, 0)
	var dir := (target - ball.global_position).normalized()
	var power := 23.0 if Input.is_key_pressed(KEY_SHIFT) else 18.0
	ball.global_position = player.global_position + dir*1.15 + Vector3(0, 0.4, 0)
	ball.linear_velocity = dir*power + Vector3(0, 2.3, 0)
	possession = false
	last_touch = "home"

func _switch_player() -> void:
	var nearest = _nearest_player_to_ball()
	if nearest[0] in teammates:
		var old := player
		player = nearest[0]
		teammates.erase(player)
		teammates.append(old)

func _check_goals() -> void:
	if absf(ball.global_position.x) > FIELD_LENGTH/2 + 2.5 and absf(ball.global_position.z) < 3.8 and ball.global_position.y < 2.7:
		if ball.global_position.x > 0:
			score_home += 1
		else:
			score_away += 1
		ball.global_position = Vector3.ZERO
		ball.linear_velocity = Vector3.ZERO
		player.position = Vector3(-8,0,0)
		possession = true

func _update_camera(delta: float) -> void:
	var focus := player.global_position.lerp(ball.global_position, 0.35)
	var desired := focus + Vector3(-16, 25, 30)
	camera.global_position = camera.global_position.lerp(desired, 3.0*delta)
	camera.look_at(focus + Vector3(7,0,0), Vector3.UP)
