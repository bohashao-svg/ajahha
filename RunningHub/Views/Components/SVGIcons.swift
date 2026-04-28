import SwiftUI

// MARK: - SVG Icon Shape Definitions
// All icons are drawn as SwiftUI Shape paths — no emoji, no SF Symbols dependency

struct RHIcon: View {
    let name: IconName
    var size: CGFloat = 24
    var color: Color = .rhPrimary

    var body: some View {
        iconShape
            .frame(width: size, height: size)
            .foregroundColor(color)
    }

    @ViewBuilder
    private var iconShape: some View {
        switch name {
        case .workflow:  WorkflowIcon()
        case .tasks:     TasksIcon()
        case .settings:  SettingsIcon()
        case .plus:      PlusIcon()
        case .check:     CheckIcon()
        case .close:     CloseIcon()
        case .refresh:   RefreshIcon()
        case .download:  DownloadIcon()
        case .duck:      DuckIcon()
        case .image:     ImageIcon()
        case .video:     VideoIcon()
        case .lock:      LockIcon()
        case .key:       KeyIcon()
        case .trash:     TrashIcon()
        case .chevron:   ChevronIcon()
        }
    }

    enum IconName {
        case workflow, tasks, settings, plus, check, close
        case refresh, download, duck, image, video
        case lock, key, trash, chevron
    }
}

// MARK: - Individual Icon Shapes

struct WorkflowIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            // Three connected nodes
            let r: CGFloat = s * 0.12
            let centers: [(CGFloat, CGFloat)] = [
                (s * 0.2, s * 0.5),
                (s * 0.6, s * 0.2),
                (s * 0.6, s * 0.8)
            ]
            // Lines
            for c in centers.dropFirst() {
                var p = Path()
                p.move(to: CGPoint(x: centers[0].0, y: centers[0].1))
                p.addLine(to: CGPoint(x: c.0, y: c.1))
                ctx.stroke(p, with: .foreground, lineWidth: 1.5)
            }
            // Nodes
            for c in centers {
                let rect = CGRect(x: c.0 - r, y: c.1 - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .foreground)
            }
            // Arrow head on right side
            var arrow = Path()
            arrow.move(to: CGPoint(x: s * 0.78, y: s * 0.5))
            arrow.addLine(to: CGPoint(x: s * 0.95, y: s * 0.5))
            arrow.move(to: CGPoint(x: s * 0.85, y: s * 0.38))
            arrow.addLine(to: CGPoint(x: s * 0.95, y: s * 0.5))
            arrow.addLine(to: CGPoint(x: s * 0.85, y: s * 0.62))
            ctx.stroke(arrow, with: .foreground, lineWidth: 1.5)
        }
    }
}

struct TasksIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            let rows: [CGFloat] = [0.22, 0.5, 0.78]
            for (i, y) in rows.enumerated() {
                // Checkbox square
                let box = CGRect(x: s * 0.06, y: y * s - s * 0.1, width: s * 0.2, height: s * 0.2)
                ctx.stroke(Path(roundedRect: box, cornerRadius: 3), with: .foreground, lineWidth: 1.6)
                // Checkmark inside first row to indicate "done"
                if i == 0 {
                    var tick = Path()
                    tick.move(to: CGPoint(x: s * 0.09, y: y * s))
                    tick.addLine(to: CGPoint(x: s * 0.14, y: y * s + s * 0.06))
                    tick.addLine(to: CGPoint(x: s * 0.23, y: y * s - s * 0.06))
                    ctx.stroke(tick, with: .foreground, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                }
                // Text line
                var line = Path()
                line.move(to: CGPoint(x: s * 0.34, y: y * s))
                line.addLine(to: CGPoint(x: s * 0.94, y: y * s))
                ctx.stroke(line, with: .foreground, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        }
    }
}

struct SettingsIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            let cx = s / 2, cy = s / 2
            let outerR = s * 0.44, innerR = s * 0.18
            let toothCount = 8
            // Gear: alternate between outer (tooth tip) and mid (tooth base) radii
            let midR = s * 0.33
            var gear = Path()
            for i in 0..<(toothCount * 2) {
                let angle = Double(i) * .pi / Double(toothCount)
                let r = i % 2 == 0 ? outerR : midR
                let pt = CGPoint(x: cx + r * cos(angle - .pi / 2),
                                 y: cy + r * sin(angle - .pi / 2))
                if i == 0 { gear.move(to: pt) } else { gear.addLine(to: pt) }
            }
            gear.closeSubpath()
            ctx.fill(gear, with: .foreground)
            // Punch out center hole
            let hole = Path(ellipseIn: CGRect(x: cx - innerR, y: cy - innerR,
                                              width: innerR * 2, height: innerR * 2))
            ctx.blendMode = .clear
            ctx.fill(hole, with: .foreground)
        }
        .compositingGroup()
    }
}

struct PlusIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            var p = Path()
            p.move(to: CGPoint(x: s / 2, y: s * 0.1))
            p.addLine(to: CGPoint(x: s / 2, y: s * 0.9))
            p.move(to: CGPoint(x: s * 0.1, y: s / 2))
            p.addLine(to: CGPoint(x: s * 0.9, y: s / 2))
            ctx.stroke(p, with: .foreground, lineWidth: 2)
        }
    }
}

struct CheckIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            var p = Path()
            p.move(to: CGPoint(x: s * 0.1, y: s * 0.5))
            p.addLine(to: CGPoint(x: s * 0.4, y: s * 0.8))
            p.addLine(to: CGPoint(x: s * 0.9, y: s * 0.2))
            ctx.stroke(p, with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

struct CloseIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            var p = Path()
            p.move(to: CGPoint(x: s * 0.15, y: s * 0.15))
            p.addLine(to: CGPoint(x: s * 0.85, y: s * 0.85))
            p.move(to: CGPoint(x: s * 0.85, y: s * 0.15))
            p.addLine(to: CGPoint(x: s * 0.15, y: s * 0.85))
            ctx.stroke(p, with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}

struct RefreshIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            let c = CGPoint(x: s / 2, y: s / 2)
            let r = s * 0.38
            var arc = Path()
            arc.addArc(center: c, radius: r, startAngle: .degrees(-30), endAngle: .degrees(240), clockwise: false)
            ctx.stroke(arc, with: .foreground, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            // Arrow head
            var arrow = Path()
            let tip = CGPoint(x: c.x + r * cos(.pi * 4 / 3), y: c.y + r * sin(.pi * 4 / 3))
            arrow.move(to: CGPoint(x: tip.x - s * 0.12, y: tip.y - s * 0.04))
            arrow.addLine(to: tip)
            arrow.addLine(to: CGPoint(x: tip.x + s * 0.04, y: tip.y - s * 0.12))
            ctx.stroke(arrow, with: .foreground, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }
}

struct DownloadIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            var p = Path()
            p.move(to: CGPoint(x: s / 2, y: s * 0.1))
            p.addLine(to: CGPoint(x: s / 2, y: s * 0.7))
            p.move(to: CGPoint(x: s * 0.25, y: s * 0.5))
            p.addLine(to: CGPoint(x: s / 2, y: s * 0.72))
            p.addLine(to: CGPoint(x: s * 0.75, y: s * 0.5))
            p.move(to: CGPoint(x: s * 0.1, y: s * 0.85))
            p.addLine(to: CGPoint(x: s * 0.9, y: s * 0.85))
            ctx.stroke(p, with: .foreground, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }
}

struct DuckIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            // Body
            ctx.fill(Path(ellipseIn: CGRect(x: s*0.15, y: s*0.45, width: s*0.7, height: s*0.45)), with: .foreground)
            // Head
            ctx.fill(Path(ellipseIn: CGRect(x: s*0.5, y: s*0.1, width: s*0.35, height: s*0.35)), with: .foreground)
            // Beak
            var beak = Path()
            beak.move(to: CGPoint(x: s*0.82, y: s*0.25))
            beak.addLine(to: CGPoint(x: s*0.98, y: s*0.22))
            beak.addLine(to: CGPoint(x: s*0.98, y: s*0.32))
            beak.closeSubpath()
            ctx.fill(beak, with: .foreground)
        }
    }
}

struct ImageIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            let rect = CGRect(x: s*0.05, y: s*0.15, width: s*0.9, height: s*0.7)
            ctx.stroke(Path(roundedRect: rect, cornerRadius: s*0.08), with: .foreground, lineWidth: 1.5)
            ctx.fill(Path(ellipseIn: CGRect(x: s*0.2, y: s*0.28, width: s*0.18, height: s*0.18)), with: .foreground)
            var mountain = Path()
            mountain.move(to: CGPoint(x: s*0.1, y: s*0.78))
            mountain.addLine(to: CGPoint(x: s*0.42, y: s*0.42))
            mountain.addLine(to: CGPoint(x: s*0.62, y: s*0.62))
            mountain.addLine(to: CGPoint(x: s*0.75, y: s*0.5))
            mountain.addLine(to: CGPoint(x: s*0.9, y: s*0.78))
            ctx.stroke(mountain, with: .foreground, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

struct VideoIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            let rect = CGRect(x: s*0.05, y: s*0.2, width: s*0.65, height: s*0.6)
            ctx.stroke(Path(roundedRect: rect, cornerRadius: s*0.08), with: .foreground, lineWidth: 1.5)
            var play = Path()
            play.move(to: CGPoint(x: s*0.75, y: s*0.28))
            play.addLine(to: CGPoint(x: s*0.95, y: s*0.38))
            play.addLine(to: CGPoint(x: s*0.95, y: s*0.62))
            play.addLine(to: CGPoint(x: s*0.75, y: s*0.72))
            play.closeSubpath()
            ctx.fill(play, with: .foreground)
        }
    }
}

struct LockIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            let body = CGRect(x: s*0.15, y: s*0.45, width: s*0.7, height: s*0.5)
            ctx.fill(Path(roundedRect: body, cornerRadius: s*0.08), with: .foreground)
            var shackle = Path()
            shackle.addArc(center: CGPoint(x: s/2, y: s*0.42),
                           radius: s*0.22, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
            ctx.stroke(shackle, with: .foreground, lineWidth: 2)
        }
    }
}

struct KeyIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            ctx.stroke(Path(ellipseIn: CGRect(x: s*0.05, y: s*0.15, width: s*0.45, height: s*0.45)), with: .foreground, lineWidth: 1.8)
            var shaft = Path()
            shaft.move(to: CGPoint(x: s*0.45, y: s*0.55))
            shaft.addLine(to: CGPoint(x: s*0.95, y: s*0.85))
            shaft.move(to: CGPoint(x: s*0.68, y: s*0.68))
            shaft.addLine(to: CGPoint(x: s*0.68, y: s*0.82))
            shaft.move(to: CGPoint(x: s*0.8, y: s*0.75))
            shaft.addLine(to: CGPoint(x: s*0.8, y: s*0.9))
            ctx.stroke(shaft, with: .foreground, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
    }
}

struct TrashIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            var p = Path()
            p.move(to: CGPoint(x: s*0.1, y: s*0.28))
            p.addLine(to: CGPoint(x: s*0.9, y: s*0.28))
            p.move(to: CGPoint(x: s*0.35, y: s*0.12))
            p.addLine(to: CGPoint(x: s*0.65, y: s*0.12))
            let body = CGRect(x: s*0.18, y: s*0.3, width: s*0.64, height: s*0.6)
            p.addRoundedRect(in: body, cornerSize: CGSize(width: s*0.06, height: s*0.06))
            p.move(to: CGPoint(x: s*0.38, y: s*0.44))
            p.addLine(to: CGPoint(x: s*0.38, y: s*0.78))
            p.move(to: CGPoint(x: s*0.62, y: s*0.44))
            p.addLine(to: CGPoint(x: s*0.62, y: s*0.78))
            ctx.stroke(p, with: .foreground, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }
}

struct ChevronIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            var p = Path()
            p.move(to: CGPoint(x: s*0.3, y: s*0.2))
            p.addLine(to: CGPoint(x: s*0.7, y: s*0.5))
            p.addLine(to: CGPoint(x: s*0.3, y: s*0.8))
            ctx.stroke(p, with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}
