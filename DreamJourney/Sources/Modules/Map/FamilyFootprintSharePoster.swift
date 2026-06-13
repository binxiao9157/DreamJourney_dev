import CoreImage
import CoreLocation
import UIKit

struct FamilyFootprintPosterMetric: Equatable {
    let value: String
    let label: String
}

struct FamilyFootprintSharePosterDescriptor {
    let familyTitle: String
    let subtitle: String
    let dateRangeText: String
    let scopeTitle: String
    let generationTitle: String
    let metrics: [FamilyFootprintPosterMetric]
    let qrPayload: String
    let qrCaption: String
    let generatedDateText: String
    let journeySummary: FamilyFootprintJourneySummary
    let points: [FamilyFootprintPoint]
    let regions: [FootprintIlluminationRegion]

    static func make(
        ownerName: String?,
        scope: FootprintIlluminationScope,
        generation: FamilyFootprintGeneration,
        allPoints: [FamilyFootprintPoint],
        generatedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> FamilyFootprintSharePosterDescriptor {
        let visiblePoints = FamilyFootprintTimeline.filtered(allPoints, by: generation)
        let posterPoints = visiblePoints.isEmpty ? allPoints : visiblePoints
        let regions = FootprintIlluminationCatalog.regions(
            scope: scope,
            points: posterPoints,
            generation: generation
        )
        let minYear = posterPoints.map(\.year).min() ?? calendar.component(.year, from: generatedAt)
        let maxYear = posterPoints.map(\.year).max() ?? minYear
        let familyTitle = Self.familyTitle(ownerName: ownerName)
        let subtitle = FamilyFootprintTimeline.narrativeText(for: allPoints, generation: generation)
        let journeySummary = FamilyFootprintTimeline.journeySummary(for: allPoints, generation: generation)
        let generatedDateText = Self.dateFormatter.string(from: generatedAt)

        return FamilyFootprintSharePosterDescriptor(
            familyTitle: familyTitle,
            subtitle: subtitle,
            dateRangeText: minYear == maxYear ? "\(minYear)" : "\(minYear)-\(maxYear)",
            scopeTitle: scope.title,
            generationTitle: generation.title,
            metrics: Self.metrics(scope: scope, generation: generation, points: posterPoints, regions: regions),
            qrPayload: "dreamjourney://family-footprint?scope=\(scope.title)&generation=\(generation.rawValue)",
            qrCaption: "扫码查看家族足迹",
            generatedDateText: generatedDateText,
            journeySummary: journeySummary,
            points: posterPoints.sorted { $0.year == $1.year ? $0.month < $1.month : $0.year < $1.year },
            regions: regions
        )
    }

    private static func familyTitle(ownerName: String?) -> String {
        let trimmed = ownerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name = trimmed, !name.isEmpty, name != "家人" else {
            return "一家人的家族足迹"
        }
        if name.hasSuffix("家") || name.hasSuffix("家庭") {
            return "\(name)的家族足迹"
        }
        return "\(name)的家族足迹"
    }

    private static func metrics(
        scope: FootprintIlluminationScope,
        generation: FamilyFootprintGeneration,
        points: [FamilyFootprintPoint],
        regions: [FootprintIlluminationRegion]
    ) -> [FamilyFootprintPosterMetric] {
        guard !points.isEmpty else {
            return [FamilyFootprintPosterMetric(value: "0", label: generation == .all ? "暂无足迹" : "\(generation.title)足迹")]
        }

        let minYear = points.map(\.year).min() ?? 0
        let maxYear = points.map(\.year).max() ?? minYear
        let days = max(1, (maxYear - minYear + 1) * 365)
        let cityCount = Set(points.map { FootprintIlluminationCatalog.normalizedCityName($0.location) }).count

        switch scope {
        case .city:
            let percent = min(99, max(1, regions.count * 4 + points.count))
            let corners = max(points.count * 7, regions.count * 12)
            return [
                FamilyFootprintPosterMetric(value: "\(percent)", label: "走过杭州(%)"),
                FamilyFootprintPosterMetric(value: "\(corners)", label: "探索角落")
            ]
        case .nation:
            let area = max(points.count * 3842, regions.reduce(0) { $0 + $1.approximateAreaKm2 })
            return [
                FamilyFootprintPosterMetric(value: "\(max(cityCount, regions.count))", label: "全国城市"),
                FamilyFootprintPosterMetric(value: "\(days)", label: "历时(天)"),
                FamilyFootprintPosterMetric(value: "\(area)", label: "点亮(km²)")
            ]
        case .world:
            let countryCount = Set(points.map {
                FootprintIlluminationCatalog.countryName(latitude: $0.latitude, longitude: $0.longitude, location: $0.location)
            }).count
            return [
                FamilyFootprintPosterMetric(value: "\(max(countryCount, regions.count))", label: "全球国家"),
                FamilyFootprintPosterMetric(value: "\(days)", label: "历时(天)")
            ]
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}

enum FamilyFootprintSharePosterRenderer {
    static func render(
        descriptor: FamilyFootprintSharePosterDescriptor,
        mapSnapshot: UIImage? = nil,
        size: CGSize = CGSize(width: 1080, height: 1920)
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            drawBackground(in: cg, size: size)

            let contentInset: CGFloat = 76
            let mapRect = CGRect(x: contentInset, y: 118, width: size.width - contentInset * 2, height: 1070)
            drawMapPanel(in: cg, rect: mapRect, descriptor: descriptor, mapSnapshot: mapSnapshot)

            drawHeader(in: cg, size: size, descriptor: descriptor)
            drawLegend(in: cg, size: size)
            drawStats(in: cg, size: size, descriptor: descriptor)
            drawFooter(in: cg, size: size, descriptor: descriptor)
        }
    }

    private static func drawBackground(in cg: CGContext, size: CGSize) {
        let colors = [
            UIColor(hex: "#071518").cgColor,
            UIColor(hex: "#0A2227").cgColor,
            UIColor(hex: "#04090D").cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, 0.52, 1]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations)!
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: size.width * 0.5, y: 0),
            end: CGPoint(x: size.width * 0.5, y: size.height),
            options: []
        )
    }

    private static func drawMapPanel(
        in cg: CGContext,
        rect: CGRect,
        descriptor: FamilyFootprintSharePosterDescriptor,
        mapSnapshot: UIImage?
    ) {
        cg.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: 38).addClip()

        if let mapSnapshot {
            drawSnapshot(mapSnapshot, in: rect)
            drawMapScrim(in: cg, rect: rect)
        } else {
            drawMapTexture(in: cg, rect: rect)
            let mapBounds = coordinateBounds(points: descriptor.points, regions: descriptor.regions)
            drawRegions(in: cg, rect: rect, descriptor: descriptor, bounds: mapBounds)
            drawPoints(in: cg, rect: rect, points: descriptor.points, bounds: mapBounds)
        }

        let fadeColors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.72).cgColor
        ] as CFArray
        let fade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: fadeColors, locations: [0, 1])!
        cg.drawLinearGradient(
            fade,
            start: CGPoint(x: rect.midX, y: rect.maxY - 250),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
        cg.restoreGState()

        UIColor.white.withAlphaComponent(0.08).setStroke()
        UIBezierPath(roundedRect: rect, cornerRadius: 38).stroke()
    }

    private static func drawSnapshot(_ image: UIImage, in rect: CGRect) {
        let imageRatio = image.size.width / max(1, image.size.height)
        let rectRatio = rect.width / max(1, rect.height)
        let drawRect: CGRect
        if imageRatio > rectRatio {
            let width = rect.height * imageRatio
            drawRect = CGRect(x: rect.midX - width * 0.5, y: rect.minY, width: width, height: rect.height)
        } else {
            let height = rect.width / max(0.01, imageRatio)
            drawRect = CGRect(x: rect.minX, y: rect.midY - height * 0.5, width: rect.width, height: height)
        }
        image.draw(in: drawRect)
    }

    private static func drawMapScrim(in cg: CGContext, rect: CGRect) {
        UIColor(hex: "#031015").withAlphaComponent(0.26).setFill()
        cg.fill(rect)
    }

    private static func drawMapTexture(in cg: CGContext, rect: CGRect) {
        cg.saveGState()
        let colors = [
            UIColor(hex: "#0B2B30").cgColor,
            UIColor(hex: "#0A242B").cgColor,
            UIColor(hex: "#06131A").cgColor
        ] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.56, 1])!
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY),
            options: []
        )

        UIColor(hex: "#16454B").withAlphaComponent(0.20).setStroke()
        for offset in stride(from: -rect.height * 0.3, through: rect.height * 0.9, by: rect.height * 0.18) {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.minX - 40, y: rect.minY + offset))
            path.addCurve(
                to: CGPoint(x: rect.maxX + 40, y: rect.minY + offset + 88),
                controlPoint1: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + offset - 58),
                controlPoint2: CGPoint(x: rect.minX + rect.width * 0.66, y: rect.minY + offset + 132)
            )
            path.lineWidth = 2
            path.stroke()
        }
        cg.restoreGState()
    }

    private static func drawRegions(
        in cg: CGContext,
        rect: CGRect,
        descriptor: FamilyFootprintSharePosterDescriptor,
        bounds: CoordinateBounds
    ) {
        for region in descriptor.regions {
            for overlaySpec in region.overlaySpecs {
                let path = polygonPath(for: overlaySpec.coordinates, in: rect, bounds: bounds)
                path.lineJoinStyle = .round
                path.lineCapStyle = .round
                overlaySpec.style.fillColor.setFill()
                path.fill()
                overlaySpec.style.strokeColor.setStroke()
                path.lineWidth = overlaySpec.style.lineWidth * 2
                path.stroke()
            }

            let center = point(for: region.center, in: rect, bounds: bounds)
            drawText(
                region.name,
                in: CGRect(x: center.x - 76, y: center.y - 17, width: 152, height: 34),
                font: .systemFont(ofSize: 24, weight: .heavy),
                color: UIColor.white.withAlphaComponent(0.92),
                alignment: .center
            )
        }
    }

    private static func drawPoints(
        in cg: CGContext,
        rect: CGRect,
        points: [FamilyFootprintPoint],
        bounds: CoordinateBounds
    ) {
        let centers = points.map {
            self.point(
                for: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                in: rect,
                bounds: bounds
            )
        }

        if centers.count > 1 {
            let path = UIBezierPath()
            path.move(to: centers[0])
            for center in centers.dropFirst() {
                path.addLine(to: center)
            }
            UIColor(hex: "#55F3FF").withAlphaComponent(0.36).setStroke()
            path.lineWidth = 4
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }

        for point in points {
            let center = self.point(
                for: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                in: rect,
                bounds: bounds
            )
            UIColor.white.withAlphaComponent(0.88).setFill()
            UIBezierPath(ovalIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)).fill()
            UIColor(hex: "#55F3FF").withAlphaComponent(0.46).setStroke()
            let ring = UIBezierPath(ovalIn: CGRect(x: center.x - 13, y: center.y - 13, width: 26, height: 26))
            ring.lineWidth = 2
            ring.stroke()
        }
    }

    private static func drawHeader(
        in cg: CGContext,
        size: CGSize,
        descriptor: FamilyFootprintSharePosterDescriptor
    ) {
        drawText(
            descriptor.familyTitle,
            in: CGRect(x: 76, y: 74, width: size.width - 152, height: 58),
            font: .systemFont(ofSize: 42, weight: .heavy),
            color: .white
        )
        drawText(
            "\(descriptor.scopeTitle) · \(descriptor.generationTitle) · \(descriptor.dateRangeText)",
            in: CGRect(x: 76, y: 134, width: size.width - 152, height: 36),
            font: .systemFont(ofSize: 24, weight: .semibold),
            color: UIColor.white.withAlphaComponent(0.68)
        )
        drawText(
            "家族足迹点亮图",
            in: CGRect(x: 76, y: 176, width: 320, height: 34),
            font: .systemFont(ofSize: 22, weight: .bold),
            color: UIColor(hex: "#7AFAFF").withAlphaComponent(0.86)
        )
    }

    private static func drawLegend(in cg: CGContext, size: CGSize) {
        let panel = CGRect(x: 76, y: 1206, width: size.width - 152, height: 38)
        let items: [(title: String, kind: Int)] = [
            ("点亮区域", 0),
            ("到过的城市", 1),
            ("迁徙路线", 2)
        ]
        let itemWidth = panel.width / CGFloat(items.count)

        for (index, item) in items.enumerated() {
            let originX = panel.minX + CGFloat(index) * itemWidth
            let symbolX = originX + 10
            let symbolY = panel.midY

            switch item.kind {
            case 0:
                UIColor(hex: "#22C7D4").withAlphaComponent(0.42).setFill()
                let regionPath = UIBezierPath()
                regionPath.move(to: CGPoint(x: symbolX + 3, y: symbolY - 9))
                regionPath.addLine(to: CGPoint(x: symbolX + 30, y: symbolY - 7))
                regionPath.addLine(to: CGPoint(x: symbolX + 26, y: symbolY + 10))
                regionPath.addLine(to: CGPoint(x: symbolX + 7, y: symbolY + 8))
                regionPath.close()
                regionPath.fill()
                UIColor(hex: "#7AFAFF").withAlphaComponent(0.74).setStroke()
                regionPath.lineWidth = 2
                regionPath.stroke()
            case 1:
                UIColor.white.withAlphaComponent(0.92).setFill()
                UIBezierPath(ovalIn: CGRect(x: symbolX + 10, y: symbolY - 5, width: 10, height: 10)).fill()
                UIColor(hex: "#55F3FF").withAlphaComponent(0.62).setStroke()
                let ring = UIBezierPath(ovalIn: CGRect(x: symbolX + 2, y: symbolY - 13, width: 26, height: 26))
                ring.lineWidth = 2
                ring.stroke()
            default:
                UIColor(hex: "#55F3FF").withAlphaComponent(0.68).setStroke()
                let line = UIBezierPath()
                line.move(to: CGPoint(x: symbolX, y: symbolY))
                line.addLine(to: CGPoint(x: symbolX + 32, y: symbolY))
                line.lineWidth = 4
                line.lineCapStyle = .round
                line.stroke()
            }

            drawText(
                item.title,
                in: CGRect(x: symbolX + 42, y: panel.minY + 3, width: itemWidth - 52, height: 32),
                font: .systemFont(ofSize: 20, weight: .semibold),
                color: UIColor.white.withAlphaComponent(0.72)
            )
        }
    }

    private static func drawStats(
        in cg: CGContext,
        size: CGSize,
        descriptor: FamilyFootprintSharePosterDescriptor
    ) {
        let panel = CGRect(x: 76, y: 1260, width: size.width - 152, height: 360)
        UIColor.black.withAlphaComponent(0.46).setFill()
        UIBezierPath(roundedRect: panel, cornerRadius: 34).fill()

        drawText(
            descriptor.subtitle,
            in: CGRect(x: panel.minX + 36, y: panel.minY + 30, width: panel.width - 72, height: 78),
            font: .systemFont(ofSize: 30, weight: .bold),
            color: .white
        )
        drawText(
            "\(descriptor.journeySummary.routeText) · \(descriptor.journeySummary.scaleText)",
            in: CGRect(x: panel.minX + 36, y: panel.minY + 110, width: panel.width - 72, height: 36),
            font: .systemFont(ofSize: 22, weight: .semibold),
            color: UIColor(hex: "#7AFAFF").withAlphaComponent(0.78)
        )

        let metricCount = max(1, descriptor.metrics.count)
        let metricWidth = (panel.width - 72) / CGFloat(metricCount)
        for (index, metric) in descriptor.metrics.enumerated() {
            let metricRect = CGRect(
                x: panel.minX + 36 + CGFloat(index) * metricWidth,
                y: panel.minY + 174,
                width: metricWidth,
                height: 126
            )
            drawText(
                metric.value,
                in: CGRect(x: metricRect.minX, y: metricRect.minY, width: metricRect.width, height: 56),
                font: .monospacedDigitSystemFont(ofSize: 46, weight: .heavy),
                color: .white,
                alignment: .center
            )
            drawText(
                metric.label,
                in: CGRect(x: metricRect.minX, y: metricRect.minY + 62, width: metricRect.width, height: 42),
                font: .systemFont(ofSize: 22, weight: .semibold),
                color: UIColor.white.withAlphaComponent(0.62),
                alignment: .center
            )
        }

        cg.setStrokeColor(UIColor(hex: "#55F3FF").withAlphaComponent(0.28).cgColor)
        cg.setLineWidth(2)
        cg.move(to: CGPoint(x: panel.minX + 36, y: panel.maxY - 50))
        cg.addLine(to: CGPoint(x: panel.maxX - 36, y: panel.maxY - 50))
        cg.strokePath()
        drawText(
            "寻梦环游 · 家族记忆地图",
            in: CGRect(x: panel.minX + 36, y: panel.maxY - 42, width: panel.width - 72, height: 30),
            font: .systemFont(ofSize: 20, weight: .semibold),
            color: UIColor.white.withAlphaComponent(0.46),
            alignment: .center
        )
    }

    private static func drawFooter(
        in cg: CGContext,
        size: CGSize,
        descriptor: FamilyFootprintSharePosterDescriptor
    ) {
        let qrRect = CGRect(x: size.width - 250, y: size.height - 250, width: 154, height: 154)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: qrRect.insetBy(dx: -14, dy: -14), cornerRadius: 18).fill()
        if let qr = qrImage(payload: descriptor.qrPayload) {
            qr.draw(in: qrRect)
        }

        drawText(
            descriptor.qrCaption,
            in: CGRect(x: qrRect.minX - 32, y: qrRect.maxY + 22, width: qrRect.width + 64, height: 30),
            font: .systemFont(ofSize: 20, weight: .medium),
            color: UIColor.white.withAlphaComponent(0.64),
            alignment: .center
        )
        drawText(
            "生成于 \(descriptor.generatedDateText)",
            in: CGRect(x: 76, y: size.height - 160, width: 520, height: 34),
            font: .systemFont(ofSize: 22, weight: .medium),
            color: UIColor.white.withAlphaComponent(0.54)
        )
    }

    private static func coordinateBounds(
        points: [FamilyFootprintPoint],
        regions: [FootprintIlluminationRegion]
    ) -> CoordinateBounds {
        let regionCoordinates = regions.flatMap { region in
            [region.center] + region.overlaySpecs.flatMap(\.coordinates)
        }
        var latitudes = points.map(\.latitude) + regionCoordinates.map(\.latitude)
        var longitudes = points.map(\.longitude) + regionCoordinates.map(\.longitude)
        if latitudes.isEmpty {
            latitudes = [18, 54]
            longitudes = [73, 135]
        }
        let minLat = latitudes.min() ?? 18
        let maxLat = latitudes.max() ?? 54
        let minLon = longitudes.min() ?? 73
        let maxLon = longitudes.max() ?? 135
        let latPadding = max(0.4, (maxLat - minLat) * 0.18)
        let lonPadding = max(0.4, (maxLon - minLon) * 0.18)
        return CoordinateBounds(
            minLatitude: minLat - latPadding,
            maxLatitude: maxLat + latPadding,
            minLongitude: minLon - lonPadding,
            maxLongitude: maxLon + lonPadding
        )
    }

    private static func point(
        for coordinate: CLLocationCoordinate2D,
        in rect: CGRect,
        bounds: CoordinateBounds
    ) -> CGPoint {
        let lonRange = max(0.001, bounds.maxLongitude - bounds.minLongitude)
        let latRange = max(0.001, bounds.maxLatitude - bounds.minLatitude)
        let xRatio = (coordinate.longitude - bounds.minLongitude) / lonRange
        let yRatio = 1 - (coordinate.latitude - bounds.minLatitude) / latRange
        return CGPoint(
            x: rect.minX + CGFloat(xRatio) * rect.width,
            y: rect.minY + CGFloat(yRatio) * rect.height
        )
    }

    private static func polygonPath(
        for coordinates: [CLLocationCoordinate2D],
        in rect: CGRect,
        bounds: CoordinateBounds
    ) -> UIBezierPath {
        let path = UIBezierPath()
        guard let first = coordinates.first else { return path }
        path.move(to: point(for: first, in: rect, bounds: bounds))
        for coordinate in coordinates.dropFirst() {
            path.addLine(to: point(for: coordinate, in: rect, bounds: bounds))
        }
        path.close()
        return path
    }

    private static func qrImage(payload: String) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator"),
              let data = payload.data(using: .utf8) else {
            return nil
        }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        return UIImage(ciImage: transformed)
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        minimumScaleFactor: CGFloat = 0.72
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let minSize = max(8, font.pointSize * minimumScaleFactor)
        var fittingFont = font
        while fittingFont.pointSize > minSize {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: fittingFont,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
            let measured = (text as NSString).boundingRect(
                with: CGSize(width: rect.width, height: CGFloat.greatestFiniteMagnitude),
                options: options,
                attributes: attributes,
                context: nil
            )
            if measured.height <= rect.height + 1 && measured.width <= rect.width + 1 {
                break
            }
            fittingFont = fittingFont.withSize(fittingFont.pointSize - 1)
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: fittingFont,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        (text as NSString).draw(with: rect, options: options, attributes: attributes, context: nil)
    }
}

final class FamilyFootprintSharePosterPreviewViewController: UIViewController {
    private let image: UIImage
    private let descriptor: FamilyFootprintSharePosterDescriptor
    private let imageView = UIImageView()
    private let shareButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)

    init(image: UIImage, descriptor: FamilyFootprintSharePosterDescriptor) {
        self.image = image
        self.descriptor = descriptor
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "#071518")
        setupUI()
    }

    private func setupUI() {
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 18
        imageView.layer.masksToBounds = true

        configure(button: saveButton, title: "保存图片", systemImage: "square.and.arrow.down")
        configure(button: shareButton, title: "分享给家人", systemImage: "square.and.arrow.up")
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [saveButton, shareButton])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually

        view.addSubview(imageView)
        view.addSubview(stack)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            imageView.bottomAnchor.constraint(equalTo: stack.topAnchor, constant: -18),

            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            stack.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func configure(button: UIButton, title: String, systemImage: String) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: systemImage)
        config.imagePadding = 8
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor(hex: "#1FAEBB")
        config.cornerStyle = .medium
        button.configuration = config
    }

    @objc private func shareTapped() {
        let activityVC = UIActivityViewController(activityItems: [image, descriptor.familyTitle], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(activityVC, animated: true)
    }

    @objc private func saveTapped() {
        guard let url = writePosterToTemporaryFile() else {
            showToast("海报导出失败", type: .error)
            return
        }
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        present(picker, animated: true)
    }

    private func writePosterToTemporaryFile() -> URL? {
        guard let data = image.pngData() else { return nil }
        let sanitizedTitle = descriptor.familyTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "")
        let fileName = "\(sanitizedTitle)-足迹海报.png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private struct CoordinateBounds {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double
}
