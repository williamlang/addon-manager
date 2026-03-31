# AddonManager

A World of Warcraft addon (Retail 12.0.1) that lets you save named sets of enabled addons and switch between them.

## Features

- **Addon sets** — Save any combination of installed addons as a named set and switch between them with a single click
- **Default set** — A built-in set that enables all installed addons
- **Zone auto-switch** — Assign a set to a zone type (Raid, Dungeon, Delve, Battleground, Arena); when you enter that zone you'll be prompted to switch
- **Minimap button** — Always-visible dropdown picker on the minimap; drag to reposition
- **Interface Options panel** — Manage sets and toggle auto-switch under Game Menu → Interface → AddOns → AddonManager

## Installation

1. Clone or download this repository
2. Copy the `AddonManager` folder into your WoW addons directory:
   ```
   World of Warcraft/_retail_/Interface/AddOns/AddonManager/
   ```
   The folder name must be exactly `AddonManager`
3. Launch WoW and enable the addon on the character select screen

## Usage

### Minimap button

Click the minimap button to open a dropdown list of your saved sets. Click any set to switch to it. Drag the button to reposition it around the minimap.

### `/am` commands

| Command | Description |
|---|---|
| `/am` | Toggle the main window |
| `/am save <name>` | Save current addon state as a named set |
| `/am load <name>` | Apply a set and reload the UI |
| `/am delete <name>` | Delete a set |
| `/am rename <old> <new>` | Rename a set |
| `/am list` | List all saved sets |
| `/am options` | Open the Interface Options panel |

### Main window (`/am`)

- **Left panel** — Your saved sets. Select one to preview its addons, then click **Load** to apply it or **Delete** to remove it. Use the **Zone** dropdown to assign a zone type to the selected set.
- **Right panel** — All installed addons as checkboxes. Check or uncheck addons, enter a name, and click **Save Current** to create a new set from that selection. If the name already exists you'll be prompted to overwrite.

### Zone auto-switch

Assign a zone type to a set via the **Zone** dropdown in the main window. When you enter a matching instance, a prompt will appear asking if you want to switch. Each zone type can only be assigned to one set at a time.

Supported zone types: **Raid**, **Dungeon**, **Delve**, **Battleground**, **Arena**

The prompt is skipped if the assigned set is already active.

Enable or disable auto-switch under Interface Options → AddonManager.

## Notes

- Switching addon sets requires a UI reload — this is a WoW engine limitation
- The `Default` set is built-in and cannot be deleted or renamed
- If an addon in a set is uninstalled, it is automatically removed from the set when the set is next loaded
- Addon sets are account-wide and shared across all characters
