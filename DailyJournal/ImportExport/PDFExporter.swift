import UIKit

/// Lays out entries as a paged PDF: date, title, place, text and photos.
enum PDFExporter {
    static func render(_ entries: [JournalEntry], to url: URL) throws -> URL {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let margin: CGFloat = 54
        let contentWidth = page.width - margin * 2

        let text = NSMutableAttributedString()
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .short

        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.systemOrange,
        ]
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor.black,
        ]
        let placeAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray,
        ]
        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = 3
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black,
            .paragraphStyle: bodyStyle,
        ]

        for (i, entry) in entries.enumerated() {
            autoreleasepool {
                if i > 0 { text.append(NSAttributedString(string: "\n\n", attributes: bodyAttrs)) }
                text.append(NSAttributedString(string: df.string(from: entry.date).uppercased() + "\n", attributes: dateAttrs))
                if !entry.title.isEmpty {
                    text.append(NSAttributedString(string: entry.title + "\n", attributes: titleAttrs))
                }
                if let place = entry.placeName {
                    text.append(NSAttributedString(string: "📍 " + place + "\n", attributes: placeAttrs))
                }
                if !entry.body.isEmpty {
                    text.append(NSAttributedString(string: "\n" + entry.body + "\n", attributes: bodyAttrs))
                }
                for item in entry.photos {
                    guard let data = item.data, let image = UIImage(data: data) else { continue }
                    let scale = min(contentWidth / image.size.width, 320 / image.size.height, 1)
                    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    let small = image.resized(maxSide: max(size.width, size.height) * 2)
                    let attachment = NSTextAttachment()
                    attachment.image = small
                    attachment.bounds = CGRect(origin: .zero, size: size)
                    text.append(NSAttributedString(string: "\n", attributes: bodyAttrs))
                    text.append(NSAttributedString(attachment: attachment))
                }
            }
        }

        // Paginate with TextKit: one text container per page.
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        var containers: [NSTextContainer] = []
        repeat {
            let container = NSTextContainer(size: CGSize(width: contentWidth, height: page.height - margin * 2))
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            containers.append(container)
            _ = layout.glyphRange(for: container)
        } while layout.glyphRange(for: containers.last!).length > 0
            && NSMaxRange(layout.glyphRange(for: containers.last!)) < layout.numberOfGlyphs

        let renderer = UIGraphicsPDFRenderer(bounds: page)
        try renderer.writePDF(to: url) { ctx in
            for (n, container) in containers.enumerated() {
                let range = layout.glyphRange(for: container)
                guard range.length > 0 || n == 0 else { continue }
                ctx.beginPage()
                let origin = CGPoint(x: margin, y: margin)
                layout.drawBackground(forGlyphRange: range, at: origin)
                layout.drawGlyphs(forGlyphRange: range, at: origin)
                let footer = NSAttributedString(string: "\(n + 1)", attributes: placeAttrs)
                footer.draw(at: CGPoint(x: page.width / 2 - 4, y: page.height - margin / 2 - 6))
            }
        }
        return url
    }
}
