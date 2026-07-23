import UIKit

// MARK: - NF-9: Full Diagnostic PDF Export

enum DiagnosticPDFExporter {
    // US Letter page dimensions
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 48

    // PDF is a static document — adaptive UIColors must be resolved against a
    // concrete trait collection before being converted to CGColor, otherwise UIKit
    // logs "Requesting visual style in an implementation that has disabled it."
    private static let pdfTraits = UITraitCollection(userInterfaceStyle: .light)

    static func generate(health: NetworkHealthScore, devices: [ThreadDevice]) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let fileName = "ThreadMapper-\(isoDate()).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try renderer.writePDF(to: url) { ctx in
                // Page 1 — Health Summary
                ctx.beginPage()
                drawSummaryPage(ctx: ctx.cgContext, health: health, devices: devices)

                // Page 2 — Device Inventory
                ctx.beginPage()
                drawDevicePage(ctx: ctx.cgContext, devices: devices)

                // Page 3 — Issues & Recommendations
                ctx.beginPage()
                drawRecommendationsPage(ctx: ctx.cgContext, health: health)
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Page 1: Health Summary

    private static func drawSummaryPage(ctx: CGContext, health: NetworkHealthScore, devices: [ThreadDevice]) {
        let x = margin
        var y: CGFloat = margin

        // Header bar
        ctx.setFillColor(UIColor.systemBlue.resolvedColor(with: pdfTraits).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pageWidth, height: 8))

        // Title
        drawText("ThreadMapper Diagnostic Report", x: x, y: &y,
                 attrs: titleAttrs(), width: pageWidth - margin * 2)
        y += 4
        drawText(longDate(), x: x, y: &y, attrs: captionAttrs(), width: pageWidth - margin * 2)
        y += 24

        // Grade circle
        let circleSize: CGFloat = 80
        let gradeColor = uiColor(for: health.grade)
        ctx.setFillColor(gradeColor.withAlphaComponent(0.15).cgColor)
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: circleSize, height: circleSize))
        ctx.setStrokeColor(gradeColor.cgColor)
        ctx.setLineWidth(3)
        ctx.strokeEllipse(in: CGRect(x: x + 1.5, y: y + 1.5, width: circleSize - 3, height: circleSize - 3))
        let gradeAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 40, weight: .bold),
            .foregroundColor: gradeColor
        ]
        let gradeStr = health.grade as NSString
        let gradeSize = gradeStr.size(withAttributes: gradeAttr)
        gradeStr.draw(at: CGPoint(x: x + (circleSize - gradeSize.width) / 2,
                                  y: y + (circleSize - gradeSize.height) / 2),
                      withAttributes: gradeAttr)

        // Score label alongside
        let labelX = x + circleSize + 20
        var labelY = y + 10
        drawText("Score: \(health.score)/100", x: labelX, y: &labelY,
                 attrs: headingAttrs(), width: pageWidth - margin - circleSize - 24)
        drawText(String(localized: health.summary), x: labelX, y: &labelY,
                 attrs: bodyAttrs(), width: pageWidth - margin - circleSize - 24)
        labelY += 8
        let statusLine = "\(devices.count) devices · \(devices.filter(\.isOffline).count) offline · \(devices.filter(\.isBorderRouter).count) border routers"
        drawText(statusLine, x: labelX, y: &labelY, attrs: captionAttrs(),
                 width: pageWidth - margin - circleSize - 24)
        y = max(y + circleSize, labelY) + 24

        // Divider
        drawDivider(ctx: ctx, y: y)
        y += 16

        // Issues
        if health.issues.isEmpty {
            drawText("No issues detected. Your network is healthy.", x: x, y: &y,
                     attrs: bodyAttrs(), width: pageWidth - margin * 2)
        } else {
            drawText("Issues", x: x, y: &y, attrs: headingAttrs(), width: pageWidth - margin * 2)
            y += 8
            for issue in health.issues {
                let bullet = issue.isCritical ? "⚠️ " : "• "
                let affected = issue.affectedDevices.isEmpty ? "" : " (\(issue.affectedDevices.count) device\(issue.affectedDevices.count == 1 ? "" : "s"))"
                drawText("\(bullet)\(String(localized: issue.message))\(affected)", x: x, y: &y,
                         attrs: bodyAttrs(), width: pageWidth - margin * 2)
                y += 4
            }
        }

        drawFooter(ctx: ctx, pageNumber: 1)
    }

    // MARK: - Page 2: Device Inventory

    private static func drawDevicePage(ctx: CGContext, devices: [ThreadDevice]) {
        let x = margin
        var y: CGFloat = margin

        drawText("Device Inventory", x: x, y: &y, attrs: titleAttrs(), width: pageWidth - margin * 2)
        y += 4
        drawText("\(devices.count) devices found", x: x, y: &y, attrs: captionAttrs(), width: pageWidth - margin * 2)
        y += 20
        drawDivider(ctx: ctx, y: y)
        y += 12

        // Column headers
        let cols: [(label: String, x: CGFloat, w: CGFloat)] = [
            ("Device", x, 200),
            ("Room", x+204, 120),
            ("Role", x+328, 80),
            ("Status", x+412, 70),
            ("RSSI", x+486, 60),
        ]
        for col in cols {
            var cy = y
            drawText(col.label, x: col.x, y: &cy, attrs: colHeaderAttrs(), width: col.w)
        }
        y += 18
        drawDivider(ctx: ctx, y: y)
        y += 8

        // Rows
        let sorted = devices.sorted { $0.name < $1.name }
        for (i, device) in sorted.enumerated() {
            if y > pageHeight - margin - 30 { break }

            // Alternate row shading
            if i % 2 == 0 {
                ctx.setFillColor(UIColor.systemGray6.resolvedColor(with: pdfTraits).cgColor)
                ctx.fill(CGRect(x: x - 4, y: y - 2, width: pageWidth - margin * 2 + 8, height: 18))
            }

            var rowY = y
            drawText(device.name, x: cols[0].x, y: &rowY, attrs: cellAttrs(), width: cols[0].w)
            rowY = y
            drawText(device.room ?? "—", x: cols[1].x, y: &rowY, attrs: cellAttrs(), width: cols[1].w)
            rowY = y
            let role = device.isBorderRouter ? "Border Router" : (device.isSleepyEndDevice ? "End Device" : "Router")
            drawText(role, x: cols[2].x, y: &rowY, attrs: cellAttrs(), width: cols[2].w)
            rowY = y
            let status = device.isOffline ? "Offline" : "Online"
            let statusColor: UIColor = device.isOffline ? .systemRed : .systemGreen
            drawText(status, x: cols[3].x, y: &rowY,
                     attrs: cellAttrsColored(statusColor), width: cols[3].w)
            rowY = y
            let rssiStr = device.rssi.map { "\($0)" } ?? "—"
            drawText(rssiStr, x: cols[4].x, y: &rowY, attrs: cellAttrs(), width: cols[4].w)

            y += 18
        }

        drawFooter(ctx: ctx, pageNumber: 2)
    }

    // MARK: - Page 3: Recommendations

    private static func drawRecommendationsPage(ctx: CGContext, health: NetworkHealthScore) {
        let x = margin
        var y: CGFloat = margin

        drawText("Recommendations", x: x, y: &y, attrs: titleAttrs(), width: pageWidth - margin * 2)
        y += 4
        drawText("Based on the current network assessment", x: x, y: &y,
                 attrs: captionAttrs(), width: pageWidth - margin * 2)
        y += 20
        drawDivider(ctx: ctx, y: y)
        y += 16

        if health.tips.isEmpty {
            drawText("No additional recommendations — your network is performing well.", x: x, y: &y,
                     attrs: bodyAttrs(), width: pageWidth - margin * 2)
        } else {
            drawText("Action Items", x: x, y: &y, attrs: headingAttrs(), width: pageWidth - margin * 2)
            y += 8
            for (i, tip) in health.tips.enumerated() {
                let num = "\(i + 1). "
                drawText("\(num)\(String(localized: tip))", x: x, y: &y,
                         attrs: bodyAttrs(), width: pageWidth - margin * 2)
                y += 8
            }
        }

        y += 24
        drawDivider(ctx: ctx, y: y)
        y += 16

        drawText("About ThreadMapper", x: x, y: &y, attrs: headingAttrs(), width: pageWidth - margin * 2)
        y += 8
        drawText("""
            This report was generated by ThreadMapper, an iOS app for monitoring Thread mesh networks. \
            Thread is a low-power, IP-based mesh networking protocol used by smart home devices. \
            For support, visit the ThreadMapper page on the App Store.
            """, x: x, y: &y, attrs: bodyAttrs(), width: pageWidth - margin * 2)

        drawFooter(ctx: ctx, pageNumber: 3)
    }

    // MARK: - Drawing helpers

    private static func drawText(_ text: String, x: CGFloat, y: inout CGFloat,
                                  attrs: [NSAttributedString.Key: Any], width: CGFloat) {
        let str = text as NSString
        let rect = CGRect(x: x, y: y, width: width, height: 9999)
        let bounds = str.boundingRect(with: rect.size,
                                       options: [.usesLineFragmentOrigin, .usesFontLeading],
                                       attributes: attrs, context: nil)
        str.draw(in: CGRect(x: x, y: y, width: width, height: bounds.height), withAttributes: attrs)
        y += bounds.height
    }

    private static func drawDivider(ctx: CGContext, y: CGFloat) {
        ctx.setStrokeColor(UIColor.separator.resolvedColor(with: pdfTraits).cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: y))
        ctx.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        ctx.strokePath()
    }

    private static func drawFooter(ctx: CGContext, pageNumber: Int) {
        var y = pageHeight - margin + 8
        let footer = "ThreadMapper — Generated \(isoDate()) — Page \(pageNumber)"
        drawText(footer, x: margin, y: &y, attrs: captionAttrs(), width: pageWidth - margin * 2)
    }

    // MARK: - Text attributes

    private static func titleAttrs() -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: 20, weight: .bold),
         .foregroundColor: UIColor.label.resolvedColor(with: pdfTraits)]
    }
    private static func headingAttrs() -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: 14, weight: .semibold),
         .foregroundColor: UIColor.label.resolvedColor(with: pdfTraits)]
    }
    private static func bodyAttrs() -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: 11),
         .foregroundColor: UIColor.label.resolvedColor(with: pdfTraits)]
    }
    private static func captionAttrs() -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: 9),
         .foregroundColor: UIColor.secondaryLabel.resolvedColor(with: pdfTraits)]
    }
    private static func colHeaderAttrs() -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: 10, weight: .semibold),
         .foregroundColor: UIColor.secondaryLabel.resolvedColor(with: pdfTraits)]
    }
    private static func cellAttrs() -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: 10),
         .foregroundColor: UIColor.label.resolvedColor(with: pdfTraits)]
    }
    private static func cellAttrsColored(_ color: UIColor) -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: 10, weight: .semibold),
         .foregroundColor: color.resolvedColor(with: pdfTraits)]
    }

    // MARK: - Utilities

    private static func isoDate() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private static func longDate() -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .short
        return fmt.string(from: Date())
    }

    private static func uiColor(for grade: String) -> UIColor {
        switch grade {
        case "A": return .systemGreen
        case "B": return .systemMint
        case "C": return .systemYellow
        case "D": return .systemOrange
        default:  return .systemRed
        }
    }
}
