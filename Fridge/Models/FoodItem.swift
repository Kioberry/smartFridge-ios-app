import Foundation
import SwiftData

@Model
final class FoodItem {
    var name: String
    var expirationDate: Date?
    var quantity: Int
    var shelf: Shelf?

    var daysUntilExpiration: Int? {
        guard let expirationDate = expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: expirationDate)).day
    }

    init(name: String, expirationDate: Date? = nil, quantity: Int = 1, shelf: Shelf? = nil) {
        self.name = name
        self.expirationDate = expirationDate
        self.quantity = quantity
        self.shelf = shelf
    }
}
