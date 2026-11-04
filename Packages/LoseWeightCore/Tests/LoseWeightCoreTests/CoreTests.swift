import XCTest
@testable import LoseWeightCore

private var utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

private func day(_ offset: Int, hour: Int = 12) -> Date {
    // 2026-01-05 is a Monday.
    let base = utc.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: hour))!
    return utc.date(byAdding: .day, value: offset, to: base)!
}

final class TargetTests: XCTestCase {
    func testMifflinStJeor() {
        // Female, 40 y, 165 cm, 80 kg: 800 + 1031.25 - 200 - 161 = 1470.25
        XCTAssertEqual(TargetCalculator.restingEnergy(sex: .female, ageYears: 40, heightCm: 165, weightKg: 80), 1470.25, accuracy: 0.01)
        // Male, 35 y, 180 cm, 95 kg: 950 + 1125 - 175 + 5 = 1905
        XCTAssertEqual(TargetCalculator.restingEnergy(sex: .male, ageYears: 35, heightCm: 180, weightKg: 95), 1905, accuracy: 0.01)
    }

    func testDailyTargetSteadyPace() {
        let p = Profile(sex: .male, ageYears: 35, heightCm: 180, weightKg: 95, goalWeightKg: 85, activity: .sedentary, pace: .steady)
        let t = TargetCalculator.dailyTarget(for: p)
        XCTAssertEqual(t.maintenanceKcal, 2286, accuracy: 0.5)          // 1905 × 1.2
        XCTAssertEqual(t.targetKcal, (2286 - 550).rounded(), accuracy: 1) // 0.5 kg/wk ≈ 550 kcal/day
        XCTAssertFalse(t.limitedByFloor)
        XCTAssertEqual(t.expectedKgPerWeek, 0.5, accuracy: 0.01)
    }

    func testCalorieFloorApplies() {
        // Small, older, sedentary woman: maintenance is low, so the 1200 floor should hold.
        let p = Profile(sex: .female, ageYears: 70, heightCm: 152, weightKg: 60, goalWeightKg: 55, activity: .sedentary, pace: .brisk)
        let t = TargetCalculator.dailyTarget(for: p)
        XCTAssertEqual(t.targetKcal, 1200)
        XCTAssertTrue(t.limitedByFloor)
        XCTAssertLessThan(t.plannedDeficit, LossPace.brisk.dailyDeficit)
    }

    func testMaintenanceOnlyHasNoDeficit() {
        let p = Profile(sex: .female, ageYears: 30, heightCm: 168, weightKg: 75, goalWeightKg: 65, activity: .light, maintenanceOnly: true)
        let t = TargetCalculator.dailyTarget(for: p)
        XCTAssertEqual(t.plannedDeficit, 0)
        XCTAssertEqual(t.targetKcal, t.maintenanceKcal.rounded())
    }

    func testSuggestedGoalsRespectHealthyBMI() {
        XCTAssertEqual(TargetCalculator.suggestedGoals(currentKg: 100, heightCm: 175).map { $0.rounded() }, [95, 90])
        // 58 kg at 175 cm is BMI ~18.9: a 5% loss would go below 18.5, so nothing is suggested.
        XCTAssertTrue(TargetCalculator.suggestedGoals(currentKg: 58, heightCm: 175).isEmpty)
        XCTAssertEqual(TargetCalculator.bmi(weightKg: 81, heightCm: 180), 25, accuracy: 0.01)
    }
}

final class EnergyTests: XCTestCase {
    func testPortionScaling() {
        let r = EnergyEstimator.calories(category: .fastFood, healthiness: .indulgent, portion: .large)
        XCTAssertEqual(r.low, 1500)
        XCTAssertEqual(r.high, 2100)
        XCTAssertEqual(EnergyEstimator.calories(category: .homeCooked, healthiness: .balanced, portion: .small).mid, 360, accuracy: 0.01)
    }

    func testRangesIncreaseWithIndulgence() {
        for c in FoodCategory.allCases {
            XCTAssertLessThan(c.regularRange(for: .lighter).mid, c.regularRange(for: .balanced).mid, c.rawValue)
            XCTAssertLessThan(c.regularRange(for: .balanced).mid, c.regularRange(for: .indulgent).mid, c.rawValue)
        }
    }

    func testMETCalories() {
        // Brisk walk (5.0 MET), 80 kg, 30 min: gross 200, net 160.
        XCTAssertEqual(ExerciseMath.grossCalories(met: 5, weightKg: 80, minutes: 30), 200, accuracy: 0.01)
        XCTAssertEqual(ExerciseMath.netCalories(type: .walk, intensity: .vigorous, weightKg: 80, minutes: 30), 160, accuracy: 0.01)
    }

    func testGuidelineMinutes() {
        XCTAssertEqual(ExerciseMath.guidelineMinutes(type: .walk, intensity: .light, minutes: 30), 0)
        XCTAssertEqual(ExerciseMath.guidelineMinutes(type: .walk, intensity: .moderate, minutes: 30), 30)
        XCTAssertEqual(ExerciseMath.guidelineMinutes(type: .run, intensity: .moderate, minutes: 30), 60)
    }

    func testMealSlotSuggestion() {
        XCTAssertEqual(MealSlot.suggested(for: day(0, hour: 8), calendar: utc), .breakfast)
        XCTAssertEqual(MealSlot.suggested(for: day(0, hour: 13), calendar: utc), .lunch)
        XCTAssertEqual(MealSlot.suggested(for: day(0, hour: 19), calendar: utc), .dinner)
        XCTAssertEqual(MealSlot.suggested(for: day(0, hour: 13), category: .snack, calendar: utc), .snack)
    }

    func testDayBudget() {
        let b = DayBudget(targetKcal: 1800, eaten: CalorieRange(1600, 2000), exerciseKcal: 200)
        XCTAssertEqual(b.budgetKcal, 2000)
        XCTAssertEqual(b.remainingKcal, 200)
        XCTAssertEqual(b.status, .onTrack)
    }
}

final class TrendTests: XCTestCase {
    func testTrendSmoothsAndHandlesGaps() {
        let samples = [WeightSample(date: day(0), kg: 90), WeightSample(date: day(1), kg: 89)]
        let pts = WeightTrend.compute(samples, calendar: utc)
        XCTAssertEqual(pts.count, 2)
        XCTAssertEqual(pts[1].trendKg, 89.9, accuracy: 1e-9)

        // A 3-day gap applies three smoothing steps: 1 - 0.9^3 = 0.271
        let gap = WeightTrend.compute([WeightSample(date: day(0), kg: 90), WeightSample(date: day(3), kg: 89)], calendar: utc)
        XCTAssertEqual(gap[1].trendKg, 90 - 0.271, accuracy: 1e-9)
    }

    func testDuplicatesAveraged() {
        let pts = WeightTrend.compute([
            WeightSample(date: day(0, hour: 7), kg: 90),
            WeightSample(date: day(0, hour: 21), kg: 91),
        ], calendar: utc)
        XCTAssertEqual(pts.count, 1)
        XCTAssertEqual(pts[0].scaleKg, 90.5)
    }

    func testRateFromSteadyLoss() {
        // Losing 0.1 kg/day exactly; trend lags but its slope converges toward −0.7 kg/week.
        let samples = (0..<60).map { WeightSample(date: day($0), kg: 100 - 0.1 * Double($0)) }
        let pts = WeightTrend.compute(samples, calendar: utc)
        let rate = WeightTrend.kgPerWeek(pts, calendar: utc)!
        XCTAssertEqual(rate, -0.7, accuracy: 0.05)
    }

    func testRateNeedsAWeekOfData() {
        let pts = WeightTrend.compute((0..<4).map { WeightSample(date: day($0), kg: 90) }, calendar: utc)
        XCTAssertNil(WeightTrend.kgPerWeek(pts, calendar: utc))
    }

    func testProjection() {
        let now = day(0)
        let date = GoalProjection.projectedDate(currentKg: 90, goalKg: 85, kgPerWeek: -0.5, from: now)!
        XCTAssertEqual(date.timeIntervalSince(now) / 86_400, 70, accuracy: 0.01)
        XCTAssertNil(GoalProjection.projectedDate(currentKg: 90, goalKg: 85, kgPerWeek: 0.2, from: now))
        XCTAssertEqual(GoalProjection.progress(startKg: 100, currentKg: 95, goalKg: 90), 0.5)
    }
}

final class AuditTests: XCTestCase {
    func testWeeklyReport() {
        var food: [FoodLog] = []
        for d in 0..<7 {
            food.append(FoodLog(date: day(d, hour: 8), category: .homeCooked, healthiness: .lighter, portion: .regular))
            food.append(FoodLog(date: day(d, hour: 13), category: .fastFood, healthiness: .indulgent, portion: .regular))
            food.append(FoodLog(date: day(d, hour: 19), category: .homeCooked, healthiness: .balanced, portion: .regular))
        }
        food.append(FoodLog(date: day(10), category: .snack, healthiness: .indulgent, portion: .large)) // outside range
        let exercise = [
            ExerciseLog(date: day(0), type: .walk, intensity: .moderate, minutes: 30),
            ExerciseLog(date: day(2), type: .run, intensity: .moderate, minutes: 20),
            ExerciseLog(date: day(4), type: .strength, intensity: .moderate, minutes: 30),
        ]
        let weights = (-14..<7).map { WeightSample(date: day($0), kg: 90 - 0.05 * Double($0 + 14)) }

        let r = Auditor.report(start: day(0), end: day(6), food: food, exercise: exercise, weights: weights,
                               targetKcal: 2000, currentWeightKg: 89, wantsLoss: true, calendar: utc)
        XCTAssertEqual(r.days, 7)
        XCTAssertEqual(r.mealsLogged, 21)
        XCTAssertEqual(r.tierCounts[.indulgent], 7)
        XCTAssertEqual(r.healthyShare!, 14.0 / 21.0, accuracy: 1e-9)
        // Daily mid: 425 + 1200 + 600 = 2225
        XCTAssertEqual(r.averageDailyKcal!, 2225, accuracy: 0.01)
        XCTAssertEqual(r.guidelineMinutes, 30 + 40 + 30)
        XCTAssertEqual(r.strengthDays, 1)
        XCTAssertEqual(r.daysWithAnyLog, 7)
        XCTAssertLessThan(r.trendChangeKg!, 0)
        XCTAssertNotNil(r.kgPerWeek)

        let titles = r.insights.map(\.title)
        XCTAssertTrue(titles.contains("Swap two takeout meals a week"), "\(titles)")
        XCTAssertTrue(titles.contains("Add strength twice a week"))
        XCTAssertTrue(titles.contains { $0.contains("more active minutes") })
        XCTAssertFalse(r.insights.contains { $0.kind == .caution })
        XCTAssertTrue((0...100).contains(r.overallScore))
    }

    func testFastLossCaution() {
        // 1.5 kg/week at 80 kg is ~1.9% a week.
        let weights = (0..<30).map { WeightSample(date: day($0), kg: 80 - 0.215 * Double($0)) }
        let r = Auditor.report(start: day(23), end: day(29), food: [], exercise: [], weights: weights,
                               targetKcal: 1800, currentWeightKg: 74, wantsLoss: true, calendar: utc)
        XCTAssertEqual(r.insights.first?.kind, .caution)
    }

    func testStreak() {
        let days: Set<Date> = [day(0), day(1), day(2), day(4), day(5)]
        XCTAssertEqual(Auditor.streak(loggedDays: days, today: day(5), calendar: utc), 2)
        XCTAssertEqual(Auditor.streak(loggedDays: days, today: day(6), calendar: utc), 2) // today not logged yet
        XCTAssertEqual(Auditor.streak(loggedDays: days, today: day(8), calendar: utc), 0)
        XCTAssertEqual(Auditor.streak(loggedDays: days, today: day(2), calendar: utc), 3)
    }

    func testUnits() {
        XCTAssertEqual(Units.kgToLb(100), 220.46, accuracy: 0.01)
        XCTAssertEqual(Units.cmToFeetInches(175).feet, 5)
        XCTAssertEqual(Units.cmToFeetInches(175).inches, 9)
        XCTAssertEqual(UnitSystem.imperial.formatWeightChange(-1), "−2.2 lb")
    }
}
