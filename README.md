# FarmerRoutes — Graph-Based Routing for WoW TBC

![FarmerRoutes Banner](C:\Users\Giaken\.gemini\antigravity\brain\75e1ea27-e4eb-4bf0-8396-8f0ece798f3d\farmer_routes_banner_1777905753977.png)

**FarmerRoutes** is a reimagined routing system for World of Warcraft: The Burning Crusade. Unlike traditional routing addons that use linear arrays of waypoints, FarmerRoutes uses a **graph-based data model**. This allows for natural branching, intersections, and loops, making it the perfect tool for complex farming routes (Gas Clouds, Herbs, and Ore) in Outland.

---

## 🚀 Key Features

*   **🌐 Graph-Based Architecture**: Build complex, non-linear routes with interconnected nodes and edges.
*   **🛠️ World Map Editor**: Edit your routes directly on the World Map with intuitive mouse controls.
*   **🎯 Smart Navigation HUD**: A draggable directional arrow and distance readout with predictive "look-ahead" logic to guide you seamlessly through your route.
*   **📍 High-Fidelity Minimap**: Zoom-aware, interpolated dot-lines that provide a smooth visual path without cluttering your minimap.
*   **🎨 Advanced Styling & Inheritance**: Granular control over node and edge visuals with a 3-tier inheritance model (Global → Route → Item).
*   **🔄 Sync & Sharing**: Import/Export routes via strings. Fully compatible with legacy RoutePlanner strings.
*   **👥 Multi-Character Support**: Manage routes across all your characters with bulk import capabilities.

---

## 🎮 How to Use

### Map Editor Controls
Enter **Edit Mode** by clicking the wrench icon on the World Map toolbar.

*   **Ctrl + Left-Click (Empty Space)**: Add a new node and connect it to the selected node.
*   **Left-Click (Node)**: Select a node or drag to reposition it.
*   **Ctrl + Left-Click (Existing Node)**: Create or remove an edge between the selected node and the clicked node.
*   **Shift + Left-Click (Edge)**: Split an edge by inserting a new node in the middle.
*   **Right-Click (Node/Edge)**: Delete the targeted element.
*   **Right-Click (Empty Space)**: Clear selection or zoom out map.

### Navigation HUD
Toggle the HUD to get directional guidance to your next farm node.
*   **Shift + Left-Click (Minimap Button)**: Quickly toggle the HUD on/off.
*   **Draggable Interface**: Click and drag the HUD to reposition it anywhere on your screen.
*   **Smart Logic & Look-Ahead**: The HUD automatically detects your direction of travel and targets the most logical next node. When within 20 yards of a target, it automatically "looks ahead" to the next node in the sequence for seamless navigation.

### Slash Commands
*   `/fr` — Open main settings.
*   `/fr import <string>` — Import a route from a string.
*   `/fr export <route name>` — Generate an export string for a route.

---

## 🔧 Styling System

FarmerRoutes uses a powerful inheritance model for visuals:
1.  **Global Default**: Set the default look for all routes in the main settings.
2.  **Route Default**: Override style for a specific route via the Style Drawer.
3.  **Item Override**: Set a unique color or size for a specific node or edge for high-priority waypoints.

Access the **Style Drawer** by clicking the gear icon on the World Map toolbar while a route is selected.

---

## 📦 Installation

1.  Download the latest release.
2.  Extract the `FarmerRoutes` folder into your `Interface/AddOns` directory.
3.  Restart WoW or `/reload`.

---

*Crafted with ❤️ for the TBC farming community.*
