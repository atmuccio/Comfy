# Comfy

A personal quality-of-life World of Warcraft addon. Built for my own use but shared publicly as a convenience for others.

## Features

### Crafting Orders
- **Replacement UI** for the Blizzard crafting orders browser with a unified view across all order types (Public, Guild, Personal, Npc)
- **Recipe status indicators** - Green names for first-craft skill point recipes, gray for unlearned
- **Quality icons** and reagent display per order
- **Per-type caching** with automatic refresh to reduce API churn
- **Sortable columns** - Sort by recipe name, commission, or time remaining
- **Type filters** - Toggle which order types are visible
- **First-craft-only filter** - Show only recipes that grant a skill point

### Tooltips
- **Tooltip at mouse cursor** - Repositions the game tooltip to follow your cursor
- **Hide tooltips in combat** - Suppress tooltips during combat with a modifier key override (Alt/Ctrl/Shift)

### Player Frame
- **Hide player frame in combat** - Removes the player unit frame during combat for a cleaner view

### Minimap Button
- **Draggable minimap button** with left-click (settings) and right-click (quick toggles)
- Hideable via right-click menu or `/comfy minimap`

## Installation

1. Download the latest release
2. Extract to `World of Warcraft/_retail_/Interface/AddOns/`
3. Restart WoW or `/reload`

## Slash Commands

| Command | Description |
|---------|-------------|
| `/comfy` | List available commands |
| `/comfy minimap` | Toggle minimap button |
| `/comfy settings` | Open settings panel |

## Requirements

- World of Warcraft Retail 12.0+

## License

MIT License - See [LICENSE](LICENSE) for details.
