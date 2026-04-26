#!/usr/bin/env python3
"""
Migrate old single-material crafting recipe .tres files to the new multi-ingredient format.

Old format: One .tres per material, multiple files per product (treated as variants)
New format: One .tres per product, with recipes_json containing all recipe alternatives

Migration strategy:
- Group old recipes by product name
- Each old variant becomes a separate recipe with one slot and one option
- User can later manually restructure (e.g., combine Sapwood Blade's 3 materials into 1 recipe with 3 slots)

Usage: python3 tools/migrate_recipes.py
"""

import os
import re
import json
from collections import defaultdict

RECIPE_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "resources", "crafting_recipes")
BACKUP_DIR = os.path.join(RECIPE_DIR, "_old_backup")
SCRIPT_PATH = "res://Scripts/resources/crafting_recipe_data.gd"

def parse_tres(filepath):
    """Parse a .tres file and extract key=value fields from [resource] section."""
    data = {}
    in_resource = False
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line == "[resource]":
                in_resource = True
                continue
            if in_resource and "=" in line:
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip()
                # Parse value
                if val.startswith('"') and val.endswith('"'):
                    val = val[1:-1]
                elif val.isdigit() or (val.startswith("-") and val[1:].isdigit()):
                    val = int(val)
                data[key] = val
    return data


def escape_tres_string(s):
    """Escape a string for use in .tres file double-quoted values."""
    return s.replace("\\", "\\\\").replace('"', '\\"')


def write_tres(filepath, data, recipe_lines):
    """Write a new-format .tres file with recipe_lines."""
    escaped_desc = escape_tres_string(str(data['description']))
    escaped_product = escape_tres_string(str(data['product']))

    # Format PackedStringArray for .tres
    lines_str = ", ".join(f'"{escape_tres_string(line)}"' for line in recipe_lines)
    packed_array = f"PackedStringArray({lines_str})"

    content = f'''[gd_resource type="Resource" script_class="CraftingRecipeData" load_steps=2 format=3]

[ext_resource type="Script" path="{SCRIPT_PATH}" id="1_script"]

[resource]
script = ExtResource("1_script")
id = {data['id']}
product = "{escaped_product}"
region = "{escape_tres_string(str(data['region']))}"
description = "{escaped_desc}"
role = "{escape_tres_string(str(data['role']))}"
output_quantity = {data['output_quantity']}
recipe_lines = {packed_array}
'''
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")


def main():
    # Collect all old recipe files
    old_recipes = []
    for fname in sorted(os.listdir(RECIPE_DIR)):
        if not fname.endswith(".tres"):
            continue
        fpath = os.path.join(RECIPE_DIR, fname)
        data = parse_tres(fpath)
        if data.get("product"):
            old_recipes.append({"file": fname, "path": fpath, "data": data})

    print(f"Found {len(old_recipes)} recipe files")

    # Group by product
    products = defaultdict(list)
    for rec in old_recipes:
        products[rec["data"]["product"]].append(rec)

    print(f"Found {len(products)} unique products")

    # Backup old files
    os.makedirs(BACKUP_DIR, exist_ok=True)
    for rec in old_recipes:
        src = rec["path"]
        dst = os.path.join(BACKUP_DIR, rec["file"])
        os.rename(src, dst)

    print(f"Backed up {len(old_recipes)} files to {BACKUP_DIR}")

    # Create new files
    next_id = 1
    for product_name, recs in sorted(products.items()):
        # Take metadata from first recipe
        first = recs[0]["data"]

        # All old variants for the same product become slots in ONE recipe
        # (they were separate ingredients, all required)
        slots = []
        for rec in recs:
            d = rec["data"]
            mat = d.get("material", "")
            qty = d.get("quantity", 1)
            if isinstance(qty, str):
                qty = int(qty) if qty.isdigit() else 1
            if mat:
                slots.append({"options": [{"material": mat, "quantity": qty}]})
        recipes = [{"slots": slots}] if slots else []

        output_qty = first.get("output_quantity", 1)
        if isinstance(output_qty, str):
            output_qty = int(output_qty) if output_qty.isdigit() else 1
        if output_qty < 1:
            output_qty = 1

        new_data = {
            "id": next_id,
            "product": product_name,
            "region": first.get("region", ""),
            "description": first.get("description", ""),
            "role": first.get("role", ""),
            "output_quantity": output_qty,
        }

        # Build recipe_lines: one line with all ingredients joined by " + "
        ingredient_parts = []
        for rec in recs:
            d = rec["data"]
            mat = d.get("material", "")
            qty = d.get("quantity", 1)
            if isinstance(qty, str):
                qty = int(qty) if qty.isdigit() else 1
            if mat:
                ingredient_parts.append(f"{qty}x {mat}")
        recipe_lines = [" + ".join(ingredient_parts)] if ingredient_parts else []

        # Generate filename from product name
        safe_name = product_name.lower().replace(" ", "_").replace("-", "_").replace("'", "")
        safe_name = re.sub(r'[^a-z0-9_]', '', safe_name)
        filename = f"{safe_name}.tres"

        write_tres(os.path.join(RECIPE_DIR, filename), new_data, recipe_lines)
        next_id += 1

    print(f"Created {next_id - 1} new recipe files")
    print("Migration complete! Old files backed up to _old_backup/")
    print("All old variants combined as ingredients in one recipe line.")
    print("Gem upgrade/downgrade recipes may need manual fix — split into separate lines.")


if __name__ == "__main__":
    main()
