shader_type canvas_item;
// Desaturates a CanvasItem to luminance. Used for deceased companions' portraits
// in the companions screen. COLOR already carries texture * modulate, so tinting
// or fading the node still composes correctly on top of this.

void fragment() {
	float lum = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR.rgb = vec3(lum);
}
