---
name: architecture-diagram
description: Create professional architecture diagrams using drawio MCP tools. Use when Claude needs to create software architecture diagrams, system diagrams, flowcharts, sequence diagrams, or data flow diagrams. Triggers on requests like "draw architecture", "create diagram", "visualize system", "flowchart", "sequence diagram".
---

# Architecture Diagram Skill

Create clear, professional architecture diagrams using drawio tools.

## Workflow

**Creating a new diagram:**
1. Call `start_session` to open browser preview
2. Analyze requirements → identify diagram type and components
3. Plan layout → sketch component placement mentally
4. Call `create_new_diagram` with complete mxGraphModel XML

**Modifying existing diagram:**
1. Call `get_diagram` to fetch current state
2. Call `edit_diagram` with add/update/delete operations

**Exporting:**
- Call `export_diagram` with path to save .drawio file

## Design Principles

### Layout Rules
- **Flow direction**: Left→Right (data/process flow) or Top→Bottom (hierarchy)
- **Viewport**: Keep within x=40-760, y=40-560 (800x600 canvas with margins)
- **Spacing**: 150-200px between components for clear edge routing
- **Grouping**: Related components should be visually clustered
- **Alignment**: Align components on grid (multiples of 20px)

### Visual Hierarchy
- **Entry points** (users, external triggers): Left or top edge
- **Core services**: Center area
- **Data stores**: Bottom or right edge
- **External services**: Right edge or separate zone

## Color Palette (Light Theme)

| Component Type | Fill | Stroke | Usage |
|---------------|------|--------|-------|
| Primary/Core | `#E8F4FD` | `#5B9BD5` | Main services, core modules |
| Secondary | `#F0F9FF` | `#7FB3E0` | Supporting services |
| Entry/User | `#FFF4E6` | `#FF8C42` | Users, API gateway, triggers |
| Database/Storage | `#E8F5E9` | `#66BB6A` | DB, cache, file storage |
| External Service | `#F3E5F5` | `#AB47BC` | 3rd party APIs, cloud services |
| Queue/Message | `#FFF8E1` | `#FFB300` | MQ, event bus, streams |
| Container/Group | `#FAFAFA` | `#BDBDBD` | Grouping boxes, swimlanes |

Text color: `#333333` (dark gray for readability)

## Shape Styles

```
# Core shapes
rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;

# Database (cylinder)
shape=cylinder3;whiteSpace=wrap;boundedLbl=1;fillColor=#E8F5E9;strokeColor=#66BB6A;

# User/Actor
shape=umlActor;fillColor=#FFF4E6;strokeColor=#FF8C42;

# Cloud/External
ellipse;shape=cloud;whiteSpace=wrap;fillColor=#F3E5F5;strokeColor=#AB47BC;

# Queue
shape=parallelogram;whiteSpace=wrap;fillColor=#FFF8E1;strokeColor=#FFB300;

# Group container
rounded=1;whiteSpace=wrap;fillColor=#FAFAFA;strokeColor=#BDBDBD;dashed=1;
```

## Edge Styles

```
# Standard arrow
edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;endArrow=classic;strokeColor=#5B9BD5;

# Dashed (optional/async)
edgeStyle=orthogonalEdgeStyle;rounded=1;dashed=1;endArrow=classic;strokeColor=#999999;

# Bidirectional
edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;startArrow=classic;strokeColor=#5B9BD5;
```

### Edge Routing Rules
- Specify `exitX`, `exitY`, `entryX`, `entryY` explicitly
- Use different Y values for multiple edges between same nodes
- Bidirectional: use opposite sides (exitX=1 → entryX=0)
- Add 20-30px clearance around obstacles

## Diagram Types

### 1. System Architecture
- Show major components and their relationships
- Group by layer: Presentation → Application → Data
- See: [references/patterns.md#system-architecture](references/patterns.md)

### 2. Flowchart
- Linear process with decision points
- Diamond shapes for decisions, rounded rectangles for actions
- See: [references/patterns.md#flowchart](references/patterns.md)

### 3. Sequence Diagram
- Vertical lifelines with horizontal messages
- Time flows top to bottom
- See: [references/patterns.md#sequence-diagram](references/patterns.md)

### 4. Data Flow Diagram
- Show how data moves through system
- Emphasize transformations and storage
- See: [references/patterns.md#data-flow](references/patterns.md)

## XML Structure

```xml
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <!-- Components start from id="2" -->
    <mxCell id="2" value="Label" style="..." vertex="1" parent="1">
      <mxGeometry x="100" y="100" width="120" height="60" as="geometry"/>
    </mxCell>
    <!-- Edges reference source/target by id -->
    <mxCell id="edge-1" style="..." edge="1" parent="1" source="2" target="3">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>
```

## Quick Reference

**Standard component size**: 120x60 (services), 80x80 (databases), 40x80 (actors)

**Common mistakes to avoid**:
- Edges overlapping → use different exitY/entryY
- Cramped layout → increase spacing to 200px
- Missing labels → always set `value` attribute
- Wrong parent → top-level shapes use `parent="1"`

For complete patterns and examples, see [references/patterns.md](references/patterns.md).