class_name CraftingRecipeData extends Resource

@export var id: int
@export var product: String
@export var region: String
@export var description: String
@export var role: String
@export var material: String
@export var quantity: int

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
	return r
