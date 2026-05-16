import Foundation
import MapKit
import UIKit

/// MKAnnotation for one participant's live position.
///
/// `coordinate` is `@objc dynamic` so KVO fires when we mutate it — MapKit
/// uses that to animate the marker smoothly to its new location instead of
/// remove-and-re-add (which flickers).
final class ParticipantAnnotation: NSObject, MKAnnotation {
    let participantId: UUID
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var color: UIColor
    var isStale: Bool

    init(participantId: UUID,
         coordinate: CLLocationCoordinate2D,
         color: UIColor,
         isStale: Bool) {
        self.participantId = participantId
        self.coordinate = coordinate
        self.color = color
        self.isStale = isStale
    }
}

enum MarkerImage {
    static func circle(color: UIColor, stale: Bool) -> UIImage {
        let size: CGFloat = 18
        let inset: CGFloat = 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let rect = CGRect(x: inset, y: inset,
                              width: size - 2 * inset, height: size - 2 * inset)
            let cg = ctx.cgContext
            cg.setFillColor(color.withAlphaComponent(stale ? 0.4 : 1.0).cgColor)
            cg.fillEllipse(in: rect)
            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineWidth(2)
            cg.strokeEllipse(in: rect)
        }
    }
}

extension UIColor {
    /// Parses `#rrggbb` or `#rrggbbaa`. Falls back to gray on bad input.
    convenience init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8,
              let value = UInt64(s, radix: 16) else {
            self.init(white: 0.5, alpha: 1.0); return
        }
        let r, g, b, a: CGFloat
        if s.count == 6 {
            r = CGFloat((value >> 16) & 0xFF) / 255
            g = CGFloat((value >> 8)  & 0xFF) / 255
            b = CGFloat( value        & 0xFF) / 255
            a = 1
        } else {
            r = CGFloat((value >> 24) & 0xFF) / 255
            g = CGFloat((value >> 16) & 0xFF) / 255
            b = CGFloat((value >> 8)  & 0xFF) / 255
            a = CGFloat( value        & 0xFF) / 255
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
