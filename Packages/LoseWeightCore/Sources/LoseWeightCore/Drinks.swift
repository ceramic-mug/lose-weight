import Foundation

/// The first choice when logging a drink.
public enum DrinkKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case water, coffee, tea, soda, juice, alcohol, other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .water: "Water"
        case .coffee: "Coffee"
        case .tea: "Tea"
        case .soda: "Soda & energy"
        case .juice: "Juice & smoothie"
        case .alcohol: "Alcohol"
        case .other: "Milk & other"
        }
    }

    public var systemImage: String {
        switch self {
        case .water: "drop.fill"
        case .coffee: "cup.and.saucer.fill"
        case .tea: "mug.fill"
        case .soda: "bubbles.and.sparkles.fill"
        case .juice: "carrot.fill"
        case .alcohol: "wineglass.fill"
        case .other: "takeoutbag.and.cup.and.straw.fill"
        }
    }

    public var styles: [DrinkStyle] { DrinkStyle.allCases.filter { $0.kind == self } }
}

/// The specific drink. Kinds with one style (water, juice, milk) skip the "Which?" step.
public enum DrinkStyle: String, CaseIterable, Codable, Sendable, Identifiable {
    case water
    // Coffee
    case blackCoffee, coffeeMilkSugar, espresso, latte, flavoredLatte, coldBrew, frappe, decaf
    // Tea
    case blackTea, greenTea, herbalTea, chai
    // Soda & energy
    case regularSoda, dietSoda, energyDrink, sugarFreeEnergy
    case juice
    // Alcohol
    case beer, wine, cocktail
    case milk

    public var id: String { rawValue }

    public var kind: DrinkKind {
        switch self {
        case .water: .water
        case .blackCoffee, .coffeeMilkSugar, .espresso, .latte, .flavoredLatte, .coldBrew, .frappe, .decaf: .coffee
        case .blackTea, .greenTea, .herbalTea, .chai: .tea
        case .regularSoda, .dietSoda, .energyDrink, .sugarFreeEnergy: .soda
        case .juice: .juice
        case .beer, .wine, .cocktail: .alcohol
        case .milk: .other
        }
    }

    public var displayName: String {
        switch self {
        case .water: "Water"
        case .blackCoffee: "Black coffee"
        case .coffeeMilkSugar: "With milk & sugar"
        case .espresso: "Espresso"
        case .latte: "Latte / cappuccino"
        case .flavoredLatte: "Flavored latte / mocha"
        case .coldBrew: "Cold brew"
        case .frappe: "Frappé / blended"
        case .decaf: "Decaf"
        case .blackTea: "Black tea"
        case .greenTea: "Green tea"
        case .herbalTea: "Herbal tea"
        case .chai: "Chai latte"
        case .regularSoda: "Soda"
        case .dietSoda: "Diet soda"
        case .energyDrink: "Energy drink"
        case .sugarFreeEnergy: "Sugar-free energy"
        case .juice: "Juice / smoothie"
        case .beer: "Beer"
        case .wine: "Wine"
        case .cocktail: "Cocktail"
        case .milk: "Milk"
        }
    }

    /// Short name for chips and list rows.
    public var shortName: String {
        switch self {
        case .coffeeMilkSugar: "Coffee w/ milk"
        case .latte: "Latte"
        case .flavoredLatte: "Flavored latte"
        case .frappe: "Frappé"
        case .sugarFreeEnergy: "SF energy"
        case .juice: "Juice"
        default: displayName
        }
    }

    /// Volume (mL), caffeine (mg) and energy (kcal) for small / medium / large.
    /// Typical values from USDA FoodData Central and common coffee-shop sizes.
    public var spec: DrinkSpec {
        switch self {
        case .water:           DrinkSpec(ml: [240, 500, 750], mg: [0, 0, 0], kcal: [0, 0, 0])
        case .blackCoffee:     DrinkSpec(ml: [240, 355, 470], mg: [95, 140, 190], kcal: [5, 5, 10])
        case .coffeeMilkSugar: DrinkSpec(ml: [240, 355, 470], mg: [95, 140, 190], kcal: [50, 75, 100])
        case .espresso:        DrinkSpec(ml: [30, 60, 90], mg: [63, 126, 189], kcal: [3, 5, 8])
        case .latte:           DrinkSpec(ml: [240, 355, 470], mg: [75, 150, 150], kcal: [150, 190, 250])
        case .flavoredLatte:   DrinkSpec(ml: [240, 355, 470], mg: [75, 150, 175], kcal: [200, 290, 380], sweet: true)
        case .coldBrew:        DrinkSpec(ml: [355, 470, 710], mg: [155, 205, 310], kcal: [5, 5, 10])
        case .frappe:          DrinkSpec(ml: [355, 470, 710], mg: [70, 95, 130], kcal: [230, 380, 470], sweet: true)
        case .decaf:           DrinkSpec(ml: [240, 355, 470], mg: [3, 5, 7], kcal: [5, 5, 10])
        case .blackTea:        DrinkSpec(ml: [240, 355, 470], mg: [47, 70, 94], kcal: [2, 3, 4])
        case .greenTea:        DrinkSpec(ml: [240, 355, 470], mg: [28, 42, 56], kcal: [2, 3, 4])
        case .herbalTea:       DrinkSpec(ml: [240, 355, 470], mg: [0, 0, 0], kcal: [2, 3, 4])
        case .chai:            DrinkSpec(ml: [240, 355, 470], mg: [50, 95, 120], kcal: [140, 240, 310], sweet: true)
        case .regularSoda:     DrinkSpec(ml: [240, 355, 590], mg: [23, 34, 56], kcal: [100, 150, 250], sweet: true)
        case .dietSoda:        DrinkSpec(ml: [240, 355, 590], mg: [31, 46, 76], kcal: [0, 0, 0])
        case .energyDrink:     DrinkSpec(ml: [250, 355, 470], mg: [80, 120, 160], kcal: [110, 160, 210], sweet: true)
        case .sugarFreeEnergy: DrinkSpec(ml: [250, 355, 470], mg: [80, 120, 160], kcal: [10, 10, 15])
        case .juice:           DrinkSpec(ml: [240, 355, 470], mg: [0, 0, 0], kcal: [110, 165, 220], sweet: true)
        case .beer:            DrinkSpec(ml: [355, 470, 710], mg: [0, 0, 0], kcal: [150, 200, 300])
        case .wine:            DrinkSpec(ml: [150, 180, 250], mg: [0, 0, 0], kcal: [120, 145, 200])
        case .cocktail:        DrinkSpec(ml: [120, 180, 240], mg: [0, 0, 0], kcal: [150, 250, 350], sweet: true)
        case .milk:            DrinkSpec(ml: [240, 355, 470], mg: [0, 0, 0], kcal: [120, 180, 240])
        }
    }

    /// Espresso is counted in shots rather than cup sizes.
    public func sizeName(_ size: DrinkSize) -> String {
        guard self == .espresso else { return size.displayName }
        switch size {
        case .small: return "Single"
        case .medium: return "Double"
        case .large: return "Triple"
        }
    }
}

public enum DrinkSize: String, CaseIterable, Codable, Sendable, Identifiable {
    case small, medium, large

    public var id: String { rawValue }
    var index: Int {
        switch self {
        case .small: 0
        case .medium: 1
        case .large: 2
        }
    }

    public var displayName: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    public var letter: String {
        switch self {
        case .small: "S"
        case .medium: "M"
        case .large: "L"
        }
    }
}

public struct DrinkSpec: Equatable, Sendable {
    public var ml: [Double]
    public var mg: [Double]
    public var kcal: [Double]
    /// Counts toward the "sweet drinks" tip.
    public var sweet: Bool = false

    public func ml(_ s: DrinkSize) -> Double { ml[s.index] }
    public func caffeine(_ s: DrinkSize) -> Double { mg[s.index] }
    public func kcal(_ s: DrinkSize) -> Double { kcal[s.index] }
}

public struct DrinkLog: Equatable, Sendable {
    public var date: Date
    public var style: DrinkStyle
    public var size: DrinkSize

    public init(date: Date, style: DrinkStyle, size: DrinkSize) {
        self.date = date
        self.style = style
        self.size = size
    }

    public var caffeineMg: Double { style.spec.caffeine(size) }
    public var kcal: Double { style.spec.kcal(size) }
    public var ml: Double { style.spec.ml(size) }
    public var isSweet: Bool { style.spec.sweet }
}

public enum DrinkMath {
    /// FDA: up to 400 mg a day is generally safe for healthy adults.
    public static let caffeineDailyLimitMg: Double = 400
    /// Caffeine later than this hour can affect sleep.
    public static let lateCaffeineHour = 14
    /// One "glass" of water for display.
    public static let glassMl: Double = 240

    public static func caffeineByDay(_ drinks: [DrinkLog], calendar: Calendar = .current) -> [Date: Double] {
        var out: [Date: Double] = [:]
        for d in drinks { out[calendar.startOfDay(for: d.date), default: 0] += d.caffeineMg }
        return out
    }

    public static func formatVolume(_ ml: Double, units: UnitSystem) -> String {
        switch units {
        case .metric: return "\(Int(ml.rounded())) mL"
        case .imperial: return "\(Int((ml / 29.5735).rounded())) oz"
        }
    }
}
