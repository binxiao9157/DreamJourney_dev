import UIKit

// MARK: - KBLitePDFExporter

/// 知识库导出为家谱 PDF
/// 使用 UIGraphicsPDFRenderer 生成 A4 尺寸文档
final class KBLitePDFExporter {

    // MARK: - Constants

    /// A4 纸张尺寸 (pt)
    private static let pageWidth: CGFloat = 595.28
    private static let pageHeight: CGFloat = 841.89
    private static let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

    /// 页边距
    private static let margin: CGFloat = 50

    /// 内容区域
    private static var contentRect: CGRect {
        CGRect(x: margin, y: margin, width: pageWidth - margin * 2, height: pageHeight - margin * 2)
    }

    /// 颜色
    private static let titleColor = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
    private static let bodyColor = UIColor.black
    private static let subtitleColor = UIColor.gray

    // MARK: - Public API

    /// 生成家谱 PDF 文档
    /// - Parameter completion: 完成回调，返回 PDF 文件 URL（主线程）
    static func generateFamilyBook(completion: @escaping (URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let graph = KBLiteManager.shared.sanitizedGraph(for: .export)
            let memoirs = MemoirRepository.shared.getAll()

            let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
            var currentPageNumber = 0

            let data = renderer.pdfData { context in

                // --- 封面页 ---
                currentPageNumber += 1
                context.beginPage()
                drawCoverPage(graph: graph, memoirCount: memoirs.count, pageNumber: currentPageNumber)

                // --- 人物关系树页 ---
                currentPageNumber += 1
                context.beginPage()
                drawFamilyTreePage(people: graph.people, pageNumber: currentPageNumber)

                // --- 人物档案页（最多前 10 人）---
                let profilePeople = Array(graph.people.prefix(10))
                for person in profilePeople {
                    currentPageNumber += 1
                    context.beginPage()
                    drawPersonProfilePage(person: person, graph: graph, pageNumber: currentPageNumber)
                }

                // --- 时间线页 ---
                currentPageNumber += 1
                context.beginPage()
                drawTimelinePage(events: graph.events, pageNumber: currentPageNumber)

                // --- 回忆录集锦页（最多前 5 篇）---
                let selectedMemoirs = Array(memoirs.prefix(5))
                if !selectedMemoirs.isEmpty {
                    currentPageNumber += 1
                    context.beginPage()
                    drawMemoirCollectionPage(memoirs: selectedMemoirs, pageNumber: currentPageNumber)
                }
            }

            // 写入临时目录
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "family_book_\(timestamp).pdf"
            let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

            do {
                try data.write(to: fileURL)
                DispatchQueue.main.async { completion(fileURL) }
            } catch {
                print("[KBLitePDFExporter] 写入 PDF 失败: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    // MARK: - 封面页

    private static func drawCoverPage(graph: KBLiteGraph, memoirCount: Int, pageNumber: Int) {
        let centerX = pageWidth / 2

        // 大标题"家族记忆"
        let titleFont = UIFont.systemFont(ofSize: 32, weight: .bold)
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: titleColor
        ]
        let titleStr = "家族记忆"
        let titleSize = titleStr.size(withAttributes: titleAttr)
        let titlePoint = CGPoint(x: centerX - titleSize.width / 2, y: pageHeight * 0.35)
        titleStr.draw(at: titlePoint, withAttributes: titleAttr)

        // 副标题
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年M月d日"
        let dateStr = dateFormatter.string(from: Date())
        let subtitleStr = "寻梦环游 · 生成于 \(dateStr)"
        let subtitleFont = UIFont.systemFont(ofSize: 16, weight: .regular)
        let subtitleAttr: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: subtitleColor
        ]
        let subtitleSize = subtitleStr.size(withAttributes: subtitleAttr)
        let subtitlePoint = CGPoint(x: centerX - subtitleSize.width / 2, y: titlePoint.y + titleSize.height + 20)
        subtitleStr.draw(at: subtitlePoint, withAttributes: subtitleAttr)

        // 统计信息
        let statsStr = "共 \(graph.people.count) 位家人 · \(memoirCount) 段回忆 · \(graph.events.count) 件往事"
        let statsFont = UIFont.systemFont(ofSize: 14, weight: .medium)
        let statsAttr: [NSAttributedString.Key: Any] = [
            .font: statsFont,
            .foregroundColor: subtitleColor
        ]
        let statsSize = statsStr.size(withAttributes: statsAttr)
        let statsPoint = CGPoint(x: centerX - statsSize.width / 2, y: subtitlePoint.y + subtitleSize.height + 40)
        statsStr.draw(at: statsPoint, withAttributes: statsAttr)

        drawPageNumber(pageNumber)
    }

    // MARK: - 人物关系树页

    private static func drawFamilyTreePage(people: [KBPerson], pageNumber: Int) {
        var yOffset = margin

        // 标题
        yOffset = drawSectionTitle("家族成员", at: yOffset)
        yOffset += 10

        // 按关系分组
        let groups = groupPeopleByGeneration(people)
        let groupOrder: [(String, [KBPerson])] = [
            ("祖辈", groups["祖辈"] ?? []),
            ("父辈", groups["父辈"] ?? []),
            ("平辈", groups["平辈"] ?? []),
            ("子辈", groups["子辈"] ?? []),
            ("其他", groups["其他"] ?? [])
        ]

        let groupTitleFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let groupTitleAttr: [NSAttributedString.Key: Any] = [
            .font: groupTitleFont,
            .foregroundColor: titleColor
        ]

        let itemFont = UIFont.systemFont(ofSize: 13, weight: .regular)
        let itemAttr: [NSAttributedString.Key: Any] = [
            .font: itemFont,
            .foregroundColor: bodyColor
        ]

        for (groupName, members) in groupOrder where !members.isEmpty {
            // 分组标题
            if yOffset > pageHeight - margin - 40 { break }
            groupName.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: groupTitleAttr)
            yOffset += 22

            // 每人一行
            for person in members {
                if yOffset > pageHeight - margin - 20 { break }
                let relation = person.relation ?? ""
                let traits = person.traits.isEmpty ? "" : " [\(person.traits.joined(separator: "·"))]"
                let line = "\(person.name)  \(relation)\(traits)"
                line.draw(at: CGPoint(x: margin + 16, y: yOffset), withAttributes: itemAttr)
                yOffset += 20
            }

            yOffset += 10
        }

        drawPageNumber(pageNumber)
    }

    // MARK: - 人物档案页

    private static func drawPersonProfilePage(person: KBPerson, graph: KBLiteGraph, pageNumber: Int) {
        var yOffset = margin

        // 姓名大标题
        let nameFont = UIFont.systemFont(ofSize: 24, weight: .bold)
        let nameAttr: [NSAttributedString.Key: Any] = [
            .font: nameFont,
            .foregroundColor: titleColor
        ]
        person.name.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: nameAttr)
        yOffset += 36

        let labelFont = UIFont.systemFont(ofSize: 13, weight: .medium)
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: subtitleColor
        ]
        let contentFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let contentAttr: [NSAttributedString.Key: Any] = [
            .font: contentFont,
            .foregroundColor: bodyColor
        ]

        // 关系
        if let relation = person.relation {
            "关系".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: labelAttr)
            yOffset += 18
            relation.draw(at: CGPoint(x: margin + 8, y: yOffset), withAttributes: contentAttr)
            yOffset += 22
        }

        // 特征
        if !person.traits.isEmpty {
            "特征".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: labelAttr)
            yOffset += 18
            let traitsStr = person.traits.joined(separator: " · ")
            traitsStr.draw(at: CGPoint(x: margin + 8, y: yOffset), withAttributes: contentAttr)
            yOffset += 22
        }

        // 简介
        if let bio = person.briefBio {
            "简介".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: labelAttr)
            yOffset += 18
            yOffset = drawWrappedText(bio, at: yOffset, attributes: contentAttr)
            yOffset += 10
        }

        // 关联事实
        let relatedFacts = graph.facts.filter { $0.relatedPersonIds.contains(person.id) }
        if !relatedFacts.isEmpty {
            yOffset += 6
            "相关事实".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: labelAttr)
            yOffset += 18
            for fact in relatedFacts {
                if yOffset > pageHeight - margin - 20 { break }
                let factLine = "· \(fact.statement)"
                yOffset = drawWrappedText(factLine, at: yOffset, attributes: contentAttr)
                yOffset += 4
            }
        }

        // 关联事件
        let relatedEvents = graph.events.filter { $0.participantIds.contains(person.id) }
        if !relatedEvents.isEmpty {
            yOffset += 6
            "相关事件".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: labelAttr)
            yOffset += 18
            for event in relatedEvents {
                if yOffset > pageHeight - margin - 20 { break }
                let date = event.formattedDate.isEmpty ? "" : "\(event.formattedDate) · "
                let eventLine = "· \(date)\(event.title)"
                eventLine.draw(at: CGPoint(x: margin + 8, y: yOffset), withAttributes: contentAttr)
                yOffset += 20
            }
        }

        drawPageNumber(pageNumber)
    }

    // MARK: - 时间线页

    private static func drawTimelinePage(events: [KBEvent], pageNumber: Int) {
        var yOffset = margin

        // 标题
        yOffset = drawSectionTitle("家族时间线", at: yOffset)
        yOffset += 10

        // 按年份排列
        let sorted = events.sorted { ($0.year ?? 9999, $0.month ?? 13) < ($1.year ?? 9999, $1.month ?? 13) }

        let itemFont = UIFont.systemFont(ofSize: 13, weight: .regular)
        let itemAttr: [NSAttributedString.Key: Any] = [
            .font: itemFont,
            .foregroundColor: bodyColor
        ]

        for event in sorted {
            if yOffset > pageHeight - margin - 20 { break }

            let date = event.formattedDate.isEmpty ? "未知时间" : event.formattedDate
            let desc = event.description ?? ""
            let descSuffix = desc.isEmpty ? "" : " · \(desc)"
            let line = "\(date) · \(event.title)\(descSuffix)"
            yOffset = drawWrappedText(line, at: yOffset, attributes: itemAttr)
            yOffset += 8
        }

        drawPageNumber(pageNumber)
    }

    // MARK: - 回忆录集锦页

    private static func drawMemoirCollectionPage(memoirs: [MemoirModel], pageNumber: Int) {
        var yOffset = margin

        // 标题
        yOffset = drawSectionTitle("回忆录集锦", at: yOffset)
        yOffset += 10

        let memoirTitleFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let memoirTitleAttr: [NSAttributedString.Key: Any] = [
            .font: memoirTitleFont,
            .foregroundColor: titleColor
        ]

        let metaFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let metaAttr: [NSAttributedString.Key: Any] = [
            .font: metaFont,
            .foregroundColor: subtitleColor
        ]

        let proseFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let proseAttr: [NSAttributedString.Key: Any] = [
            .font: proseFont,
            .foregroundColor: bodyColor
        ]

        for memoir in memoirs {
            if yOffset > pageHeight - margin - 60 { break }

            // 标题
            memoir.title.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: memoirTitleAttr)
            yOffset += 22

            // 时间地点
            let meta = "\(memoir.year)年\(memoir.month)月 · \(memoir.location)"
            meta.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: metaAttr)
            yOffset += 18

            // 正文（限前 300 字）
            let proseText = String(memoir.prose.prefix(300))
            let displayText = proseText + (memoir.prose.count > 300 ? "……" : "")
            yOffset = drawWrappedText(displayText, at: yOffset, attributes: proseAttr)
            yOffset += 20
        }

        drawPageNumber(pageNumber)
    }

    // MARK: - Helpers

    /// 绘制章节标题，返回标题底部 y 坐标
    private static func drawSectionTitle(_ title: String, at yOffset: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 20, weight: .bold)
        let attr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: titleColor
        ]
        title.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: attr)
        return yOffset + 30
    }

    /// 绘制自动换行文本，返回文本底部 y 坐标
    private static func drawWrappedText(_ text: String, at yOffset: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let maxWidth = pageWidth - margin * 2 - 8
        let constraintRect = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let drawRect = CGRect(x: margin + 8, y: yOffset, width: maxWidth, height: boundingBox.height)
        text.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        return yOffset + boundingBox.height
    }

    /// 绘制页码（底部居中）
    private static func drawPageNumber(_ number: Int) {
        let font = UIFont.systemFont(ofSize: 10, weight: .regular)
        let attr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: subtitleColor
        ]
        let text = "- \(number) -"
        let size = text.size(withAttributes: attr)
        let point = CGPoint(x: (pageWidth - size.width) / 2, y: pageHeight - margin + 10)
        text.draw(at: point, withAttributes: attr)
    }

    /// 按代际分组人物
    private static func groupPeopleByGeneration(_ people: [KBPerson]) -> [String: [KBPerson]] {
        var groups: [String: [KBPerson]] = [
            "祖辈": [],
            "父辈": [],
            "平辈": [],
            "子辈": [],
            "其他": []
        ]

        let grandparentKeywords = ["祖父", "祖母", "爷爷", "奶奶", "外公", "外婆", "姥姥", "姥爷", "太爷", "太奶"]
        let parentKeywords = ["父亲", "母亲", "爸爸", "妈妈", "叔叔", "伯伯", "阿姨", "姑姑", "舅舅", "姨妈", "婶婶", "伯母", "舅母"]
        let peerKeywords = ["哥哥", "姐姐", "弟弟", "妹妹", "表哥", "表姐", "表弟", "表妹", "堂兄", "堂姐", "堂弟", "堂妹", "老伴", "老公", "老婆", "丈夫", "妻子", "同学", "战友", "师傅", "老师"]
        let childKeywords = ["儿子", "女儿", "孙子", "孙女", "外孙", "外孙女", "侄子", "侄女"]

        for person in people {
            let nameAndRelation = [person.name, person.relation ?? ""].joined(separator: " ")
            if grandparentKeywords.contains(where: { nameAndRelation.contains($0) }) {
                groups["祖辈"]?.append(person)
            } else if parentKeywords.contains(where: { nameAndRelation.contains($0) }) {
                groups["父辈"]?.append(person)
            } else if peerKeywords.contains(where: { nameAndRelation.contains($0) }) {
                groups["平辈"]?.append(person)
            } else if childKeywords.contains(where: { nameAndRelation.contains($0) }) {
                groups["子辈"]?.append(person)
            } else {
                groups["其他"]?.append(person)
            }
        }

        return groups
    }
}
