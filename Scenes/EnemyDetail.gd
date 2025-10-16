extends Window
class_name EnemyDetail

@onready var EnemyIcon: TextureRect = $PanelContainer/VBox/HeaderRow/EnemyIcon
@onready var EnemyName: Label = $PanelContainer/VBox/HeaderRow/HeaderInfo/EnemyName
@onready var HpCurrentSpin: SpinBox = $PanelContainer/VBox/HeaderRow/HeaderInfo/HpRow/HpCurrentSpin
@onready var HpMaxSpin: SpinBox = $PanelContainer/VBox/HeaderRow/HeaderInfo/HpRow/HpMaxSpin
@onready var PhaseSpin: SpinBox = $PanelContainer/VBox/HeaderRow/HeaderInfo/PhaseRow/PhaseSpin
@onready var KilledCheck: CheckBox = $PanelContainer/VBox/HeaderRow/KilledCheck

@onready var ResistancesText: RichTextLabel = $PanelContainer/VBox/MidRow/ResBox/ResistancesText
@onready var NotesField: TextEdit = $PanelContainer/VBox/MidRow/NotesBox/NotesField

@onready var AttackList: ItemList = $PanelContainer/VBox/AttackRow/AttackList
@onready var AttackDetails: RichTextLabel = $PanelContainer/VBox/AttackRow/AttackDetails

@onready var SaveButton: Button = $PanelContainer/VBox/FooterRow/SaveButton
@onready var CloseButton: Button = $PanelContainer/VBox/FooterRow/CloseButton

var enemy_id: int = -1
var enemy_data: Dictionary = {}
var baseline_resists: Dictionary = {"Fire": 0, "Ice": 0, "Electric": 0, "Water": 0, "Earth": 0, "Wind": 0}

func _ready() -> void:
    CloseButton.pressed.connect(hide)
    SaveButton.pressed.connect(_on_save_pressed)
    AttackList.item_selected.connect(_on_attack_selected)

func open_for_enemy(id_value: int, data: Dictionary) -> void:
    enemy_id = id_value
    enemy_data = data.duplicate(true)

    EnemyName.text = str(enemy_data.get("Name", "Unknown"))
    HpCurrentSpin.value = int(enemy_data.get("HP_Current", enemy_data.get("CurrentHP", 0)))
    HpMaxSpin.value = int(enemy_data.get("HP_Max", enemy_data.get("MaxHP", 1)))
    PhaseSpin.value = int(enemy_data.get("Phase", 1))
    KilledCheck.button_pressed = bool(enemy_data.get("Killed", false))
    NotesField.text = str(enemy_data.get("Notes", ""))

    var res_dict: Dictionary = enemy_data.get("Resistances", {})
    var diff_lines: Array = []
    for k in baseline_resists.keys():
        var base_v = int(baseline_resists[k])
        var v = int(res_dict.get(k, base_v))
        if v != base_v:
            diff_lines.append("- " + k + ": " + str(v) + "%")
    if diff_lines.size() > 0:
        ResistancesText.text = "\n".join(diff_lines)
    else:
        ResistancesText.text = "None (all normal)"

    AttackList.clear()
    var attack_map: Dictionary = {}
    for rid in Global.ATTACKS.keys():
        var a: Dictionary = Global.ATTACKS[rid]
        var match_by_id = a.get("EnemyID", null) == enemy_id
        var match_by_name = a.get("EnemyName", "") == enemy_data.get("Name", "")
        if match_by_id or match_by_name:
            var idx = AttackList.add_item(str(a.get("Name", "Attack")))
            attack_map[idx] = a
    AttackList.set_meta("attack_map", attack_map)
    AttackDetails.text = "Select an attack to view details."

    popup_centered()

func _on_attack_selected(index: int) -> void:
    var attack_map: Dictionary = AttackList.get_meta("attack_map", {})
    var a: Dictionary = attack_map.get(index, {})
    if a.is_empty():
        AttackDetails.text = "No details."
        return
    var lines: Array = []
    lines.append("[" + str(a.get("Name", "Attack")) + "]")
    lines.append("Type: " + str(a.get("Type", "—")) + " | Range: " + str(a.get("Range", "—")) + " | Target: " + str(a.get("Target", "—")))
    lines.append("Bypass Defense: " + str(a.get("Bypass", false)))
    if a.has("OnHit"):
        lines.append("On Hit: " + str(a["OnHit"]))
    if a.has("Cooldown"):
        lines.append("Cooldown: " + str(a["Cooldown"]))
    if a.has("Notes"):
        var n = str(a["Notes"]).strip_edges()
        if n != "":
            lines.append("Notes: " + n)
    AttackDetails.text = "\n".join(lines)

func _on_save_pressed() -> void:
    var id_key = enemy_id
    if not Global.ENEMIES.has(id_key):
        hide()
        return
    Global.ENEMIES[id_key]["HP_Current"] = int(HpCurrentSpin.value)
    Global.ENEMIES[id_key]["HP_Max"] = max(1, int(HpMaxSpin.value))
    Global.ENEMIES[id_key]["Phase"] = int(PhaseSpin.value)
    Global.ENEMIES[id_key]["Killed"] = KilledCheck.button_pressed
    Global.ENEMIES[id_key]["Notes"] = NotesField.text
    # Required by your rule: log at end of confirm
    Global.Log("EnemyDetail.Save", {
        "enemy_id": id_key,
        "hp_current": Global.ENEMIES[id_key]["HP_Current"],
        "hp_max": Global.ENEMIES[id_key]["HP_Max"],
        "phase": Global.ENEMIES[id_key]["Phase"],
        "killed": Global.ENEMIES[id_key]["Killed"]
    })
    hide()
