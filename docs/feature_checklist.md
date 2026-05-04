# FarmerRoutes — Graph-Based Routing Feature List

> A reimagined routing system optimized for WoW TBC farming (gas clouds, herbs, ore). Instead of linear, 1D arrays of waypoints, routes are built as graphs consisting of interconnected nodes and edges. This allows for branching paths, intersections, and loops naturally.

---

## 1. Core Concepts & Data Model

### 1.1 Graph-Based Routes
Instead of an array of points, a route consists of two main collections:
- [x] **`nodes`**: A table of points on the map `{x, y}` with a unique ID.
- [x] **`edges`**: A table of connections between nodes `{node_A_id, node_B_id}`.

### 1.2 Database Structure
Each route in `FarmerRoutesDB["TBC Classic"].routes[routeName]` contains:
- [x] `name` (string)
- [x] `mapID` (number)
- [x] `color` (RGBA table `{r, g, b, a}`)
- [x] `visible` (bool)
- [x] `style` (Optional: route-level visual overrides)
- [x] `nodes` (table mapping `nodeID -> {x, y, style}`)
- [x] `edges` (table of `{nodeID1, nodeID2, style}`)
- [x] `globalStyle` (Stored in `db.settings` for system-wide defaults)

---

## 2. World Map Editor (UX)

All route planning and editing is done directly on the World Map.

### 2.1 Node Placement & Selection
- [x] **Select Node**: Left-click an existing node to select it. It highlights (e.g., thicker border, pulsing glow).
- [x] **Create Initial Node**: Left-click empty space on the map to create a node. It becomes the `selectedNodeID`.
- [x] **Branching / Continuing**: 
  - [x] With a `selectedNodeID` active, left-clicking empty space creates a *new node* AND an *edge* connecting the two. The selection moves to the new node.
  - [x] With a `selectedNodeID` active, left-clicking another *existing node* creates an *edge* connecting them. The selection moves to the clicked node.

### 2.2 Edge Selection
- [x] **Select Edge**: Left-click a line connecting two nodes. It highlights.
- [/] **Deselect**: Left-click empty space (without holding any modifiers) clears the current node or edge selection. (Implemented via Right-Click currently).

### 2.3 Deletion
- [x] **Delete Node**: Shift-Right-Click a node to delete it. Deleting a node automatically deletes any edges attached to it. (Implemented via Right-Click currently).
- [x] **Delete Edge**: Shift-Right-Click an edge to delete it. (Implemented via Right-Click currently).

### 2.4 Drag & Drop
- [x] **Move Node**: Left-click and drag a node to reposition it. Connected edges update dynamically.

---

## 3. User Interface

### 3.1 Map Interaction Buttons
- [x] **Settings Button**: A button embedded directly on the World Map frame to open the settings window.
- [x] **Minimap Button (Fallback)**: A minimap icon provided via LibDBIcon to open the settings window (useful if a map addon conflicts with the World Map button).

### 3.2 Compact Settings Window
The settings window provides global control and route management:
- [x] **Global Toggles**: Enable/disable World Map rendering, Minimap rendering.
- [x] **Global Styling Tab**: System-wide defaults for node size/color and edge thickness/color.
- [x] **Route Manager List**:
  - [x] Toggle visibility per route.
  - [x] Change color (color picker swatch).
  - [x] **Style Button**: Opens map, selects route, and expands styling drawer.
  - [x] Rename route.
  - [x] Delete route.
  - [x] Export route to string.

---

## 4. Visual Rendering

### 4.1 World Map
- [x] Nodes rendered as interactive points.
- [x] Edges rendered as lines connecting nodes.
- [x] **Hierarchical Rendering**: Elements respect the Style Inheritance model (Item > Route > Global).

### 4.2 Minimap
- [x] Interpolated dots drawn along the path of every `edge` for active routes.
- [x] Supports rotating minimap and coordinate mapping via HereBeDragons.
- [x] **Inherited Visuals**: Dots inherit color and size from the edge/route/global style chain.

---

## 5. Import / Export
- [x] **Format**: Updates to `FR!` prefix. Serializes both nodes and edges.
- [x] `/fr import` opens a popup to paste the string.
- [x] Export string generation accessible from the Route Manager List.

---

## 7. Styling & Inheritance Model

A robust visual system that balances granular control with easy bulk editing.

### 7.1 Inheritance Chain
1.  **Individual Item**: Style override on a specific Node or Edge.
2.  **Route Default**: Fallback style for all elements within a specific route.
3.  **Global Default**: System-wide fallback for all routes (set in main Settings).

### 7.2 Styling Drawer (Map Toolbar)
- [x] **Dynamic Context**: Toolbar automatically samples the style of the selected node/edge.
- [x] **Bulk Actions**: 
    - [x] "Set Route Def": Apply current toolbar settings to the entire route.
    - [x] "Clear Override": Revert selected item to inherited style.
- [x] **Creation Buffering**: Toolbar settings are used for the *next* node/edge created when nothing is selected.

---

## 8. Future Ideas & AGI Goals
*Concepts to explore post-launch:*
- [x] **Smart Navigation HUD (Arrow Tracking)**: 
  - **Description**: An arrow icon rendered near/above the character model (center screen HUD) pointing to the likely next destination on the route.
  - **Toggle**: Can be quickly toggled on/off via the Minimap button (e.g., Shift-Click or context menu).
  - **Smart Target Selection Logic**:
    - Calculates the player's distance to nearby edges to identify the "closest edge".
    - Uses the player's recent movement (velocity vector) projected onto the closest edge to determine the direction of travel.
    - Prioritizes the *next node* along that edge in the direction of travel. (e.g., if passing a node while heading north, it targets the next node to the north).
  - **Distance Readout**: Displays the yardage to the targeted node next to the arrow.
  - **Implementation & Enhancement Ideas**:
    - [x] *Intersection Handling*: At a node with multiple branches, point to the node itself until the player passes it, then use their new heading to snap to the chosen outgoing edge.
    - [x] *Off-Route Recovery*: If the player wanders far from the graph, default to pointing at the absolute closest node to guide them back.
    - [x] *Visual Polish*: Arrow color could shift (e.g., red to green) based on proximity, or become transparent when stationary.
- [ ] **Dynamic Line Coloring**: Change color based on distance/progress.
- [ ] **Node Timers**: Respawn windows for gathered elements.
