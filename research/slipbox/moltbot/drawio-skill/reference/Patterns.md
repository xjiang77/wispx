# Architecture Diagram Patterns

Complete patterns and XML templates for common diagram types.

## Table of Contents
- [System Architecture](#system-architecture)
- [Flowchart](#flowchart)
- [Sequence Diagram](#sequence-diagram)
- [Data Flow](#data-flow)
- [Microservices](#microservices)
- [Gateway Pattern](#gateway-pattern)

---

## System Architecture

3-tier layered architecture with clear separation.

**Layout**: Top-to-bottom layers, left-to-right data flow within layers.

```
┌─────────────────────────────────────────┐ y=40
│  Presentation Layer (Users, Clients)    │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐ y=180
│  Application Layer (Services, Logic)    │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐ y=320
│  Data Layer (Databases, Storage)        │
└─────────────────────────────────────────┘
```

**Example XML** (3-tier web app):
```xml
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <!-- User -->
    <mxCell id="user" value="User" style="shape=umlActor;fillColor=#FFF4E6;strokeColor=#FF8C42;" vertex="1" parent="1">
      <mxGeometry x="60" y="60" width="40" height="80" as="geometry"/>
    </mxCell>
    <!-- Web Client -->
    <mxCell id="web" value="Web App" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="160" y="60" width="120" height="60" as="geometry"/>
    </mxCell>
    <!-- API Gateway -->
    <mxCell id="gateway" value="API Gateway" style="rounded=1;whiteSpace=wrap;fillColor=#FFF4E6;strokeColor=#FF8C42;" vertex="1" parent="1">
      <mxGeometry x="340" y="60" width="120" height="60" as="geometry"/>
    </mxCell>
    <!-- Services -->
    <mxCell id="svc-user" value="User Service" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="200" y="200" width="120" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="svc-order" value="Order Service" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="380" y="200" width="120" height="60" as="geometry"/>
    </mxCell>
    <!-- Database -->
    <mxCell id="db" value="PostgreSQL" style="shape=cylinder3;whiteSpace=wrap;boundedLbl=1;fillColor=#E8F5E9;strokeColor=#66BB6A;size=15;" vertex="1" parent="1">
      <mxGeometry x="290" y="340" width="100" height="80" as="geometry"/>
    </mxCell>
    <!-- Edges -->
    <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="user" target="web">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="web" target="gateway">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#5B9BD5;exitX=0.25;exitY=1;entryX=0.5;entryY=0;" edge="1" parent="1" source="gateway" target="svc-user">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e4" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#5B9BD5;exitX=0.75;exitY=1;entryX=0.5;entryY=0;" edge="1" parent="1" source="gateway" target="svc-order">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e5" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="svc-user" target="db">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e6" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="svc-order" target="db">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>
```

---

## Flowchart

Process flow with decision points.

**Shapes**:
- Start/End: Rounded rectangle or stadium
- Process: Rectangle
- Decision: Diamond
- Input/Output: Parallelogram

**Layout**: Top-to-bottom, branches go left/right.

```xml
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <!-- Start -->
    <mxCell id="start" value="Start" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;arcSize=50;" vertex="1" parent="1">
      <mxGeometry x="300" y="40" width="100" height="40" as="geometry"/>
    </mxCell>
    <!-- Process -->
    <mxCell id="p1" value="Process Input" style="rounded=0;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="280" y="120" width="140" height="50" as="geometry"/>
    </mxCell>
    <!-- Decision -->
    <mxCell id="d1" value="Valid?" style="rhombus;whiteSpace=wrap;fillColor=#FFF8E1;strokeColor=#FFB300;" vertex="1" parent="1">
      <mxGeometry x="300" y="210" width="100" height="80" as="geometry"/>
    </mxCell>
    <!-- Yes branch -->
    <mxCell id="p2" value="Execute" style="rounded=0;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="280" y="340" width="140" height="50" as="geometry"/>
    </mxCell>
    <!-- No branch -->
    <mxCell id="p3" value="Show Error" style="rounded=0;whiteSpace=wrap;fillColor=#FFEBEE;strokeColor=#E57373;" vertex="1" parent="1">
      <mxGeometry x="500" y="220" width="120" height="50" as="geometry"/>
    </mxCell>
    <!-- End -->
    <mxCell id="end" value="End" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;arcSize=50;" vertex="1" parent="1">
      <mxGeometry x="300" y="440" width="100" height="40" as="geometry"/>
    </mxCell>
    <!-- Edges -->
    <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="start" target="p1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="p1" target="d1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e3" value="Yes" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#66BB6A;exitX=0.5;exitY=1;entryX=0.5;entryY=0;" edge="1" parent="1" source="d1" target="p2">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e4" value="No" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#E57373;exitX=1;exitY=0.5;entryX=0;entryY=0.5;" edge="1" parent="1" source="d1" target="p3">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e5" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="p2" target="end">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e6" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#999999;dashed=1;exitX=0.5;exitY=1;" edge="1" parent="1" source="p3" target="end">
      <mxGeometry relative="1" as="geometry">
        <Array as="points">
          <mxPoint x="560" y="460"/>
        </Array>
      </mxGeometry>
    </mxCell>
  </root>
</mxGraphModel>
```

---

## Sequence Diagram

Message exchange between participants over time.

**Layout**:
- Participants as boxes at top (x spacing: 150-180px)
- Vertical lifelines (dashed) below each participant
- Messages as horizontal arrows (y spacing: 50-60px per message)

```xml
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <!-- Participants -->
    <mxCell id="client" value="Client" style="rounded=0;whiteSpace=wrap;fillColor=#FFF4E6;strokeColor=#FF8C42;" vertex="1" parent="1">
      <mxGeometry x="60" y="40" width="100" height="40" as="geometry"/>
    </mxCell>
    <mxCell id="server" value="Server" style="rounded=0;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="240" y="40" width="100" height="40" as="geometry"/>
    </mxCell>
    <mxCell id="db" value="Database" style="rounded=0;whiteSpace=wrap;fillColor=#E8F5E9;strokeColor=#66BB6A;" vertex="1" parent="1">
      <mxGeometry x="420" y="40" width="100" height="40" as="geometry"/>
    </mxCell>
    <!-- Lifelines -->
    <mxCell id="ll1" style="endArrow=none;dashed=1;strokeColor=#BDBDBD;" edge="1" parent="1">
      <mxGeometry relative="1" as="geometry">
        <mxPoint x="110" y="80" as="sourcePoint"/>
        <mxPoint x="110" y="360" as="targetPoint"/>
      </mxGeometry>
    </mxCell>
    <mxCell id="ll2" style="endArrow=none;dashed=1;strokeColor=#BDBDBD;" edge="1" parent="1">
      <mxGeometry relative="1" as="geometry">
        <mxPoint x="290" y="80" as="sourcePoint"/>
        <mxPoint x="290" y="360" as="targetPoint"/>
      </mxGeometry>
    </mxCell>
    <mxCell id="ll3" style="endArrow=none;dashed=1;strokeColor=#BDBDBD;" edge="1" parent="1">
      <mxGeometry relative="1" as="geometry">
        <mxPoint x="470" y="80" as="sourcePoint"/>
        <mxPoint x="470" y="360" as="targetPoint"/>
      </mxGeometry>
    </mxCell>
    <!-- Messages -->
    <mxCell id="m1" value="1. Request" style="endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1">
      <mxGeometry relative="1" as="geometry">
        <mxPoint x="110" y="120" as="sourcePoint"/>
        <mxPoint x="290" y="120" as="targetPoint"/>
      </mxGeometry>
    </mxCell>
    <mxCell id="m2" value="2. Query" style="endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1">
      <mxGeometry relative="1" as="geometry">
        <mxPoint x="290" y="180" as="sourcePoint"/>
        <mxPoint x="470" y="180" as="targetPoint"/>
      </mxGeometry>
    </mxCell>
    <mxCell id="m3" value="3. Results" style="endArrow=classic;dashed=1;strokeColor=#66BB6A;" edge="1" parent="1">
      <mxGeometry relative="1" as="geometry">
        <mxPoint x="470" y="240" as="sourcePoint"/>
        <mxPoint x="290" y="240" as="targetPoint"/>
      </mxGeometry>
    </mxCell>
    <mxCell id="m4" value="4. Response" style="endArrow=classic;dashed=1;strokeColor=#66BB6A;" edge="1" parent="1">
      <mxGeometry relative="1" as="geometry">
        <mxPoint x="290" y="300" as="sourcePoint"/>
        <mxPoint x="110" y="300" as="targetPoint"/>
      </mxGeometry>
    </mxCell>
  </root>
</mxGraphModel>
```

---

## Data Flow

Show how data moves and transforms through a system.

**Shapes**:
- Process: Rounded rectangle
- Data store: Open rectangle (two parallel lines)
- External entity: Rectangle
- Data flow: Labeled arrows

```xml
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <!-- External Entity -->
    <mxCell id="user" value="User" style="rounded=0;whiteSpace=wrap;fillColor=#FFF4E6;strokeColor=#FF8C42;" vertex="1" parent="1">
      <mxGeometry x="60" y="160" width="100" height="60" as="geometry"/>
    </mxCell>
    <!-- Processes -->
    <mxCell id="p1" value="1.0&#xa;Validate&#xa;Input" style="ellipse;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="240" y="150" width="100" height="80" as="geometry"/>
    </mxCell>
    <mxCell id="p2" value="2.0&#xa;Process&#xa;Order" style="ellipse;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="440" y="150" width="100" height="80" as="geometry"/>
    </mxCell>
    <!-- Data Store -->
    <mxCell id="ds1" value="D1 | Orders" style="shape=partialRectangle;whiteSpace=wrap;fillColor=#E8F5E9;strokeColor=#66BB6A;top=0;left=0;bottom=0;right=0;direction=south;" vertex="1" parent="1">
      <mxGeometry x="420" y="320" width="140" height="40" as="geometry"/>
    </mxCell>
    <!-- Data Flows -->
    <mxCell id="f1" value="Order Data" style="endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="user" target="p1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="f2" value="Valid Order" style="endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="p1" target="p2">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="f3" value="Store" style="endArrow=classic;strokeColor=#66BB6A;" edge="1" parent="1" source="p2" target="ds1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="f4" value="Confirmation" style="endArrow=classic;dashed=1;strokeColor=#66BB6A;" edge="1" parent="1" source="p2" target="user">
      <mxGeometry relative="1" as="geometry">
        <Array as="points">
          <mxPoint x="490" y="60"/>
          <mxPoint x="110" y="60"/>
        </Array>
      </mxGeometry>
    </mxCell>
  </root>
</mxGraphModel>
```

---

## Microservices

Event-driven microservices with message queue.

**Layout**: Services in horizontal row, shared infrastructure below.

```xml
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <!-- API Gateway -->
    <mxCell id="gw" value="API Gateway" style="rounded=1;whiteSpace=wrap;fillColor=#FFF4E6;strokeColor=#FF8C42;" vertex="1" parent="1">
      <mxGeometry x="300" y="40" width="120" height="50" as="geometry"/>
    </mxCell>
    <!-- Services -->
    <mxCell id="svc1" value="Auth&#xa;Service" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="80" y="160" width="100" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="svc2" value="User&#xa;Service" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="230" y="160" width="100" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="svc3" value="Order&#xa;Service" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="380" y="160" width="100" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="svc4" value="Notification&#xa;Service" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="530" y="160" width="100" height="60" as="geometry"/>
    </mxCell>
    <!-- Message Queue -->
    <mxCell id="mq" value="Message Queue&#xa;(RabbitMQ)" style="rounded=1;whiteSpace=wrap;fillColor=#FFF8E1;strokeColor=#FFB300;" vertex="1" parent="1">
      <mxGeometry x="255" y="300" width="200" height="50" as="geometry"/>
    </mxCell>
    <!-- Databases -->
    <mxCell id="db1" value="Auth DB" style="shape=cylinder3;whiteSpace=wrap;boundedLbl=1;fillColor=#E8F5E9;strokeColor=#66BB6A;size=10;" vertex="1" parent="1">
      <mxGeometry x="90" y="400" width="80" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="db2" value="User DB" style="shape=cylinder3;whiteSpace=wrap;boundedLbl=1;fillColor=#E8F5E9;strokeColor=#66BB6A;size=10;" vertex="1" parent="1">
      <mxGeometry x="240" y="400" width="80" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="db3" value="Order DB" style="shape=cylinder3;whiteSpace=wrap;boundedLbl=1;fillColor=#E8F5E9;strokeColor=#66BB6A;size=10;" vertex="1" parent="1">
      <mxGeometry x="390" y="400" width="80" height="60" as="geometry"/>
    </mxCell>
    <!-- Edges from Gateway -->
    <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="gw" target="svc1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="gw" target="svc2">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="gw" target="svc3">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <!-- Service to MQ -->
    <mxCell id="e4" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#FFB300;dashed=1;" edge="1" parent="1" source="svc3" target="mq">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e5" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#FFB300;dashed=1;" edge="1" parent="1" source="mq" target="svc4">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <!-- Service to DB -->
    <mxCell id="e6" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#66BB6A;" edge="1" parent="1" source="svc1" target="db1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e7" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#66BB6A;" edge="1" parent="1" source="svc2" target="db2">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e8" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#66BB6A;" edge="1" parent="1" source="svc3" target="db3">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>
```

---

## Gateway Pattern

Central gateway routing to multiple channels/services (like Clawdbot architecture).

**Layout**: Channels on left, gateway center, services/agents on right.

```xml
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <!-- Channel Group -->
    <mxCell id="grp-ch" value="Channels" style="rounded=1;whiteSpace=wrap;fillColor=#FAFAFA;strokeColor=#BDBDBD;dashed=1;verticalAlign=top;fontStyle=1;" vertex="1" parent="1">
      <mxGeometry x="40" y="40" width="140" height="340" as="geometry"/>
    </mxCell>
    <!-- Channels -->
    <mxCell id="ch1" value="WhatsApp" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="60" y="80" width="100" height="40" as="geometry"/>
    </mxCell>
    <mxCell id="ch2" value="Telegram" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="60" y="140" width="100" height="40" as="geometry"/>
    </mxCell>
    <mxCell id="ch3" value="Discord" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="60" y="200" width="100" height="40" as="geometry"/>
    </mxCell>
    <mxCell id="ch4" value="iMessage" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="60" y="260" width="100" height="40" as="geometry"/>
    </mxCell>
    <mxCell id="ch5" value="WebChat" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="60" y="320" width="100" height="40" as="geometry"/>
    </mxCell>
    <!-- Gateway -->
    <mxCell id="gw" value="Gateway&#xa;(WebSocket)" style="rounded=1;whiteSpace=wrap;fillColor=#FFF4E6;strokeColor=#FF8C42;fontStyle=1;" vertex="1" parent="1">
      <mxGeometry x="260" y="160" width="120" height="80" as="geometry"/>
    </mxCell>
    <!-- Agent/Services -->
    <mxCell id="agent" value="AI Agent&#xa;(RPC)" style="rounded=1;whiteSpace=wrap;fillColor=#F3E5F5;strokeColor=#AB47BC;" vertex="1" parent="1">
      <mxGeometry x="460" y="100" width="100" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="cli" value="CLI" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="460" y="180" width="100" height="40" as="geometry"/>
    </mxCell>
    <mxCell id="app" value="Desktop App" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="460" y="240" width="100" height="40" as="geometry"/>
    </mxCell>
    <mxCell id="mobile" value="Mobile Nodes" style="rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;" vertex="1" parent="1">
      <mxGeometry x="460" y="300" width="100" height="40" as="geometry"/>
    </mxCell>
    <!-- Edges: Channels to Gateway -->
    <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;startArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="ch1" target="gw">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;startArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="ch2" target="gw">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;startArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="ch3" target="gw">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e4" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;startArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="ch4" target="gw">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e5" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;startArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="ch5" target="gw">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <!-- Edges: Gateway to Services -->
    <mxCell id="e6" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;startArrow=classic;strokeColor=#AB47BC;" edge="1" parent="1" source="gw" target="agent">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e7" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;startArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="gw" target="cli">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e8" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;startArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="gw" target="app">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e9" style="edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;startArrow=classic;strokeColor=#5B9BD5;" edge="1" parent="1" source="gw" target="mobile">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>
```

---

## Style Reference Summary

| Element | Style String |
|---------|-------------|
| Core Service | `rounded=1;whiteSpace=wrap;fillColor=#E8F4FD;strokeColor=#5B9BD5;` |
| Entry Point | `rounded=1;whiteSpace=wrap;fillColor=#FFF4E6;strokeColor=#FF8C42;` |
| Database | `shape=cylinder3;whiteSpace=wrap;boundedLbl=1;fillColor=#E8F5E9;strokeColor=#66BB6A;size=15;` |
| External API | `ellipse;shape=cloud;whiteSpace=wrap;fillColor=#F3E5F5;strokeColor=#AB47BC;` |
| Queue | `rounded=1;whiteSpace=wrap;fillColor=#FFF8E1;strokeColor=#FFB300;` |
| Decision | `rhombus;whiteSpace=wrap;fillColor=#FFF8E1;strokeColor=#FFB300;` |
| Group Box | `rounded=1;whiteSpace=wrap;fillColor=#FAFAFA;strokeColor=#BDBDBD;dashed=1;` |
| Arrow | `edgeStyle=orthogonalEdgeStyle;rounded=1;endArrow=classic;strokeColor=#5B9BD5;` |
| Dashed Arrow | `edgeStyle=orthogonalEdgeStyle;rounded=1;dashed=1;endArrow=classic;strokeColor=#999999;` |