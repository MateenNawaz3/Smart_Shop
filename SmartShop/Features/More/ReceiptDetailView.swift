//
//  ReceiptDetailView.swift
//  SmartShop
//

import SwiftUI
import CoreImage.CIFilterBuiltins

/// Port of `routes/_authenticated/mere_.kvitteringer.$id.tsx`.
struct ReceiptDetailView: View {
    @Binding var path: [MoreRoute]
    let id: String

    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment
    @Environment(LanguageStore.self) private var languages

    @State private var receipt: Receipt?
    @State private var loaded = false

    var body: some View {
        AppPageLayout(title: t("receipts.receipt")) {
            GuestBackLink(title: t("receipts.back")) { path.removeLast() }
        } content: {
            if let receipt {
                ReceiptPaper(receipt: receipt)
                    .frame(maxWidth: 400)
                    .frame(maxWidth: .infinity)
            } else if !loaded {
                ProgressView()
                    .tint(Theme.Colors.green)
                    .frame(maxWidth: .infinity)
            } else {
                Text(t("receipts.loadFailed"))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.green.opacity(0.7))
            }
        }
        .task {
            guard !loaded else { return }
            // Lines exist only on the detail call, which is why the list could
            // not simply pass the receipt it already had.
            if let detail = try? await environment.purchaseService.purchase(id: id) {
                receipt = Receipt(detail, locale: languages.language.locale)
            }
            loaded = true
        }
    }
}

private extension Receipt {
    /// Maps the API's receipt onto the paper-slip model `ReceiptPaper` draws.
    ///
    /// `barcode` carries the till's own `reference`, which is what a shop
    /// assistant can actually look up — the bundled data used a made-up code.
    ///
    /// **Amounts are copied, never divided.** Receipt fields are kroner; only a
    /// `…Minor` field would need converting, and none here is.
    init(_ detail: PurchaseDetail, locale: Locale) {
        self.init(
            id: detail.id,
            store: detail.storeName,
            address: detail.storeAddress,
            date: detail.occurredAt.formatted(
                Date.FormatStyle(date: .abbreviated).locale(locale)
            ),
            time: detail.occurredAt.formatted(
                Date.FormatStyle(time: .shortened).locale(locale)
            ),
            payment: detail.paymentMethod,
            barcode: detail.reference,
            lines: detail.lines.map {
                Receipt.Line(
                    group: "",
                    name: $0.quantity > 1 ? "\(Int($0.quantity))× \($0.name)" : $0.name,
                    price: $0.lineGross
                )
            }
        )
    }
}

/// A receipt drawn like a paper till slip with serrated edges.
/// Port of `components/app/ReceiptPaper.tsx`.
struct ReceiptPaper: View {
    let receipt: Receipt

    @Environment(\.strings) private var t
    @Environment(LanguageStore.self) private var languages

    private var dateLabel: String {
        receipt.purchasedAt?.formatted(
            Date.FormatStyle(date: .long).locale(languages.language.locale)
        ) ?? receipt.date
    }

    var body: some View {
        VStack(spacing: 0) {
            ScallopedEdge(isTop: true).fill(.white).frame(height: 6)

            VStack(spacing: 0) {
                Text(receipt.store)
                    .font(Theme.display(.title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                Text(receipt.address)
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.ink.opacity(0.7))
                    .padding(.top, 12)
                Text("\(dateLabel) · \(receipt.time)")
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.ink.opacity(0.7))

                dashed

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(receipt.lines.enumerated()), id: \.offset) { _, line in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(line.group)
                                .font(.system(.caption, design: .monospaced, weight: .semibold))
                                .foregroundStyle(Theme.Colors.ink.opacity(0.6))
                            HStack(alignment: .firstTextBaseline) {
                                Text(line.name).lineLimit(1)
                                Spacer()
                                Text(Receipt.kr(line.price)).monospacedDigit()
                            }
                            .font(.system(.subheadline, design: .monospaced))
                            .padding(.leading, 12)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                dashed

                HStack(alignment: .firstTextBaseline) {
                    Text(t("receipts.total"))
                    Spacer()
                    Text(Receipt.kr(receipt.total)).monospacedDigit()
                }
                .font(Theme.display(.title2))

                Text("\(t("receipts.payment")): \(receipt.payment)")
                    .font(.system(.caption, design: .monospaced))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                BarcodeView(value: receipt.barcode)
                    .padding(.top, 20)

                Text(t("receipts.thanks"))
                    .font(.system(.caption, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(2.5)
                    .foregroundStyle(Theme.Colors.ink.opacity(0.6))
                    .padding(.top, Theme.Spacing.md)
            }
            .foregroundStyle(Theme.Colors.ink)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 20)
            .background(.white)

            ScallopedEdge(isTop: false).fill(.white).frame(height: 6)
        }
        .shadow(color: .black.opacity(0.25), radius: 18, y: 12)
    }

    private var dashed: some View {
        Rectangle()
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundStyle(Theme.Colors.ink.opacity(0.2))
            .frame(height: 1)
            .padding(.vertical, 20)
    }
}

/// The torn top and bottom of the receipt paper.
///
/// The web draws this with a repeating radial-gradient — small semicircular
/// bites out of a 10px strip, subtle enough to read as paper rather than as a
/// saw blade. Shallow round bumps are the closest equivalent here; sharp
/// triangles read as a zigzag and are much louder than the design.
private nonisolated struct ScallopedEdge: Shape {
    /// `true` for the strip above the receipt, `false` for the one below.
    var isTop: Bool

    func path(in rect: CGRect) -> Path {
        let pitch: CGFloat = 12
        var path = Path()

        if isTop {
            // Flat where it meets the body, bumps along the outer (upper) edge.
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - 0.5))
            var x = rect.minX
            while x < rect.maxX {
                path.addQuadCurve(
                    to: CGPoint(x: min(x + pitch, rect.maxX), y: rect.maxY - 0.5),
                    control: CGPoint(x: x + pitch / 2, y: rect.minY - rect.height * 0.35)
                )
                x += pitch
            }
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 0.5))
            var x = rect.minX
            while x < rect.maxX {
                path.addQuadCurve(
                    to: CGPoint(x: min(x + pitch, rect.maxX), y: rect.minY + 0.5),
                    control: CGPoint(x: x + pitch / 2, y: rect.maxY + rect.height * 0.35)
                )
                x += pitch
            }
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }

        path.closeSubpath()
        return path
    }
}

/// Code 128 barcode with the value printed under it. Port of `Barcode.tsx`.
struct BarcodeView: View {
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            if let image = Self.render(value) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .frame(height: 70)
            }
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Theme.Colors.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.white, in: .rect(cornerRadius: Theme.Radius.field))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
        .accessibilityLabel(value)
    }

    private static func render(_ value: String) -> UIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(value.utf8)
        filter.quietSpace = 4
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 3, y: 3))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
