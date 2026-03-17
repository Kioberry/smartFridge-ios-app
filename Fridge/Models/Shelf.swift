import Foundation
import SwiftData

@Model
final class Shelf {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \FoodItem.shelf)
    var items: [FoodItem]

    init(name: String, items: [FoodItem] = []) {
        self.name = name
        self.items = items
    }
}
