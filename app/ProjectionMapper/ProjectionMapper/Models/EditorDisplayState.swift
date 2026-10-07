import Foundation

/// Session-only editor decorations. No field belongs to ProjectDocument or RenderScene.
struct EditorDisplayState: Equatable, Sendable {
    var cornerHandles = true
    var maskHandles = true
    var outlines = true
    var faceLabels = false
    var edgeLabels = false
    static let defaults = Self()
    var hasHandles: Bool { cornerHandles || maskHandles }
}

enum EditorEdgeStatus: String, Sendable { case unlinked, joined, seam, warning }
struct EditorEdgeLabel: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let position: SIMD2<Float>
    let status: EditorEdgeStatus
}
struct EditorFaceLabel: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let position: SIMD2<Float>
    let edges: [EditorEdgeLabel]
}

enum EditorDecorations {
    /// Arrow follows the edge's endpoint order in output coordinates, including reversed faces.
    static func directionArrow(from a: SIMD2<Float>,to b: SIMD2<Float>) -> String {
        let d = b-a
        if abs(d.x) > abs(d.y)*2.414 { return d.x >= 0 ? "→" : "←" }
        if abs(d.y) > abs(d.x)*2.414 { return d.y >= 0 ? "↓" : "↑" }
        if d.x >= 0 { return d.y >= 0 ? "↘" : "↗" }
        return d.y >= 0 ? "↙" : "↖"
    }
    static func labels(project: MappingProject, selectedFace: UUID?, selectedObject: UUID?) -> [EditorFaceLabel] {
        project.surfaces.reversed().compactMap { face in
            guard face.layout.isVisible, project.object(for: face)?.isVisible != false else { return nil }
            let transform = PerspectiveTransform(face.corners)
            func position(_ uv: SIMD2<Float>) -> SIMD2<Float> {
                if let transform { let p = transform.project(SIMD2(Double(uv.x),Double(uv.y))); return SIMD2(Float(p.x),Float(p.y)) }
                // Invalid output geometry still has a reachable identifying label.
                let top = face.corners.topLeft*(1-uv.x)+face.corners.topRight*uv.x
                let bottom = face.corners.bottomLeft*(1-uv.x)+face.corners.bottomRight*uv.x
                return top*(1-uv.y)+bottom*uv.y
            }
            let center = position(SIMD2(0.5,0.5))
            guard center.x.isFinite, center.y.isFinite else { return nil }
            let object = project.object(for: face)
            let title = object.map { $0.name+" · "+face.name } ?? face.name
            let selected = face.id == selectedFace || (selectedObject != nil && face.layout.objectID == selectedObject)
            let edges = selected ? FaceEdge.allCases.map { edge -> EditorEdgeLabel in
                let links = object?.links.filter { ($0.firstFace == face.id && $0.firstEdge == edge) || ($0.secondFace == face.id && $0.secondEdge == edge) } ?? []
                let status: EditorEdgeStatus
                if links.contains(where: { !$0.isSeam && project.joinMessage($0,objectID: object!.id) != nil }) { status = .warning }
                else if links.contains(where: \.isSeam) { status = .seam }
                else { status = links.isEmpty ? .unlinked : .joined }
                let (a,b) = edge.endpoints
                let arrow = directionArrow(from: position(a),to: position(b))
                let suffix = status == .unlinked ? "" : " · "+status.rawValue.capitalized
                return EditorEdgeLabel(id: face.id.uuidString+edge.rawValue,title: edge.title+" "+arrow+suffix,position: position((a+b)/2),status: status)
            } : []
            return EditorFaceLabel(id: face.id,title: title,position: center,edges: edges)
        }
    }
}
