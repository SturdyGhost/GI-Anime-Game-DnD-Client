class_name CraftingRecipeData extends Resource

@export var id: int
@export var product: String
@export var region: String
@export var description: String
@export var role: String
@export var material: String
@export var quantity: int
@export var output_quantity: int = 1  # How many of the product are created per craft

static func _i(v) -> int:    return int(v) if v != null else 0
static func _s(v) -> String: return str(v) if v != null else ""

static func from_dict(d: Dictionary) -> CraftingRecipeData:
	var r = CraftingRecipeData.new()
	r.id = _i(d.get("id"))
	r.product = _s(d.get("Product"))
	r.region = _s(d.get("Region"))
	r.description = _s(d.get("Description"))
	r.role = _s(d.get("Role"))
	r.material = _s(d.get("Material"))
	r.quantity = _i(d.get("Quantity"))
	r.output_quantity = _i(d.get("Output_Quantity", 1))
	if r.output_quantity < 1:
		r.output_quantity = 1
	return r
