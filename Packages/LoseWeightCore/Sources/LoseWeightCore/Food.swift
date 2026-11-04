import Foundation

/// Where the food came from. Deliberately broad so logging takes seconds.
public enum FoodCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case homeCooked
    case fastFood
    case restaurant
    case cafeteria
    case packaged
    case snack
    case drink

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .homeCooked: "Home cooked"
        case .fastFood: "Fast food"
        case .restaurant: "Restaurant"
        case .cafeteria: "Cafeteria / work"
        case .packaged: "Packaged / ready meal"
        case .snack: "Snack"
        case .drink: "Drink"
        }
    }

    /// SF Symbol name.
    public var systemImage: String {
        switch self {
        case .homeCooked: "frying.pan"
        case .fastFood: "takeoutbag.and.cup.and.straw"
        case .restaurant: "fork.knife"
        case .cafeteria: "tray"
        case .packaged: "shippingbox"
        case .snack: "carrot"
        case .drink: "cup.and.saucer"
        }
    }

    /// True for categories that make up a meal rather than an extra.
    public var isMeal: Bool {
        switch self {
        case .snack, .drink: false
        default: true
        }
    }

    /// Estimated energy for a *regular* portion, by healthiness level.
    /// These are rough ranges drawn from typical US/UK meal surveys; see docs/GUIDELINES.md.
    public func regularRange(for level: Healthiness) -> CalorieRange {
        switch (self, level) {
        case (.homeCooked, .lighter): CalorieRange(350, 500)
        case (.homeCooked, .balanced): CalorieRange(500, 700)
        case (.homeCooked, .indulgent): CalorieRange(700, 1000)

        case (.fastFood, .lighter): CalorieRange(400, 600)
        case (.fastFood, .balanced): CalorieRange(650, 900)
        case (.fastFood, .indulgent): CalorieRange(1000, 1400)

        case (.restaurant, .lighter): CalorieRange(450, 650)
        case (.restaurant, .balanced): CalorieRange(750, 1050)
        case (.restaurant, .indulgent): CalorieRange(1100, 1600)

        case (.cafeteria, .lighter): CalorieRange(350, 550)
        case (.cafeteria, .balanced): CalorieRange(550, 800)
        case (.cafeteria, .indulgent): CalorieRange(800, 1100)

        case (.packaged, .lighter): CalorieRange(250, 400)
        case (.packaged, .balanced): CalorieRange(400, 600)
        case (.packaged, .indulgent): CalorieRange(600, 900)

        case (.snack, .lighter): CalorieRange(80, 150)
        case (.snack, .balanced): CalorieRange(150, 300)
        case (.snack, .indulgent): CalorieRange(300, 500)

        case (.drink, .lighter): CalorieRange(0, 50)
        case (.drink, .balanced): CalorieRange(80, 180)
        case (.drink, .indulgent): CalorieRange(200, 450)
        }
    }

    /// Example foods that fit each level, so people can choose without thinking hard.
    public func examples(for level: Healthiness) -> String {
        switch (self, level) {
        case (.homeCooked, .lighter): "Half the plate veg, lean protein — stir-fry, salad with chicken, veggie soup"
        case (.homeCooked, .balanced): "A normal plate — pasta with sauce and veg, rice and curry, a sandwich"
        case (.homeCooked, .indulgent): "Rich or fried — creamy pasta, fried chicken, big second helpings"
        case (.fastFood, .lighter): "Grilled options, salads, small burger without fries, poke or burrito bowl"
        case (.fastFood, .balanced): "A burger or sub with a small side"
        case (.fastFood, .indulgent): "Combo meal with fries and soda, pizza, fried chicken bucket"
        case (.restaurant, .lighter): "Grilled fish or chicken with veg, broth soups, half portions"
        case (.restaurant, .balanced): "A typical entrée, no starter or dessert"
        case (.restaurant, .indulgent): "Starter + entrée + dessert, fried or creamy dishes, drinks"
        case (.cafeteria, .lighter): "Salad bar, grilled protein with veg, soup"
        case (.cafeteria, .balanced): "Hot meal with a side, a wrap or sandwich"
        case (.cafeteria, .indulgent): "Fried mains, pizza, pastries and dessert"
        case (.packaged, .lighter): "Light ready meal, yogurt and fruit, protein box"
        case (.packaged, .balanced): "Frozen dinner, instant noodles with egg, a deli sandwich"
        case (.packaged, .indulgent): "Frozen pizza, mac and cheese, big ready meal"
        case (.snack, .lighter): "Fruit, veg sticks, plain yogurt, a few nuts"
        case (.snack, .balanced): "Granola bar, cheese and crackers, handful of nuts"
        case (.snack, .indulgent): "Chips, chocolate bar, pastry, cookies"
        case (.drink, .lighter): "Water, black coffee or tea, diet soda"
        case (.drink, .balanced): "Milk, latte, small juice, a light beer"
        case (.drink, .indulgent): "Regular soda, sweet coffee drinks, smoothies, cocktails"
        }
    }
}

/// Three simple levels, based on the USDA MyPlate and Harvard Healthy Eating Plate ideas.
public enum Healthiness: String, CaseIterable, Codable, Sendable, Identifiable, Comparable {
    case lighter
    case balanced
    case indulgent

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .lighter: "Lighter"
        case .balanced: "Balanced"
        case .indulgent: "Indulgent"
        }
    }

    public var shortHint: String {
        switch self {
        case .lighter: "Mostly veg, lean protein, whole grains"
        case .balanced: "A normal, mixed plate"
        case .indulgent: "Fried, sugary, creamy, or a treat"
        }
    }

    /// 0...1 quality score used in audits (higher is better).
    public var qualityScore: Double {
        switch self {
        case .lighter: 1.0
        case .balanced: 0.6
        case .indulgent: 0.0
        }
    }

    private var order: Int {
        switch self {
        case .lighter: 0
        case .balanced: 1
        case .indulgent: 2
        }
    }

    public static func < (lhs: Healthiness, rhs: Healthiness) -> Bool { lhs.order < rhs.order }
}

public enum Portion: String, CaseIterable, Codable, Sendable, Identifiable {
    case small
    case regular
    case large

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .small: "Small"
        case .regular: "Regular"
        case .large: "Large"
        }
    }

    public var hint: String {
        switch self {
        case .small: "Kid-sized, half plate, left some"
        case .regular: "One normal plate or serving"
        case .large: "Big plate, seconds, or super-size"
        }
    }

    public var multiplier: Double {
        switch self {
        case .small: 0.6
        case .regular: 1.0
        case .large: 1.5
        }
    }
}

public enum MealSlot: String, CaseIterable, Codable, Sendable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }

    /// A sensible default based on the time of day.
    public static func suggested(for date: Date, category: FoodCategory? = nil, calendar: Calendar = .current) -> MealSlot {
        if let category, !category.isMeal { return .snack }
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 4..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<22: return .dinner
        default: return .snack
        }
    }
}

/// A low–high calorie estimate. Ranges are honest: we never pretend to know the exact number.
public struct CalorieRange: Equatable, Hashable, Codable, Sendable {
    public var low: Double
    public var high: Double

    public init(_ low: Double, _ high: Double) {
        self.low = min(low, high)
        self.high = max(low, high)
    }

    public static let zero = CalorieRange(0, 0)

    public var mid: Double { (low + high) / 2 }

    public func scaled(by factor: Double) -> CalorieRange {
        CalorieRange(low * factor, high * factor)
    }

    public static func + (lhs: CalorieRange, rhs: CalorieRange) -> CalorieRange {
        CalorieRange(lhs.low + rhs.low, lhs.high + rhs.high)
    }
}
