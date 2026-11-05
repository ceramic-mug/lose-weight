# How the numbers work

Every target, estimate and tip in Sensible comes from a published guideline. The constants live in
`Packages/LoseWeightCore`, and the tests in `Tests/LoseWeightCoreTests` check them against worked examples.

> Sensible is a general wellness tool, not a medical device. It doesn't diagnose or treat anything.

## 1. Daily food budget

| Step | Rule | Source |
|---|---|---|
| Resting energy | Mifflin-St Jeor: `10·kg + 6.25·cm − 5·age + 5` (men) / `− 161` (women). "Prefer not to say" uses the midpoint, `− 78`. | Mifflin et al., *Am J Clin Nutr* 1990; the Academy of Nutrition and Dietetics' preferred equation (Frankenfield et al., *JADA* 2005) |
| Everyday activity | × 1.2 mostly sitting, × 1.375 on feet some of the day, × 1.55 on feet most of the day. Logged workouts are **not** part of this factor; they're added separately. | Standard activity factors (FAO/WHO/UNU) |
| Deficit | Gentle 0.25, Steady 0.5, Brisk 0.75 kg/week, at ≈ 7,700 kcal per kg (≈ 275 / 550 / 825 kcal a day) | NIH/NHLBI *Aim for a Healthy Weight*; CDC *Losing Weight* (1–2 lb/week) |
| Floor | The budget never goes below 1,200 kcal (women / unspecified) or 1,500 kcal (men) | NHLBI *Clinical Guidelines* (1998); 2013 AHA/ACC/TOS Obesity Guideline |
| Maintain only | Optional setting ("Just maintain my weight"): no deficit, budget = maintenance | — |

The target is recalculated from the **trend** weight (not the latest scale reading) as weight changes.

## 2. Food estimates

Users choose **category × healthiness × portion**. Each category/healthiness pair maps to a calorie range for a
regular portion, which is then scaled (small × 0.6, regular × 1.0, large × 1.5).

| Category | Lighter | Balanced | Indulgent |
|---|---|---|---|
| Home cooked | 350–500 | 500–700 | 700–1000 |
| Fast food | 400–600 | 650–900 | 1000–1400 |
| Restaurant | 450–650 | 750–1050 | 1100–1600 |
| Cafeteria / work | 350–550 | 550–800 | 800–1100 |
| Packaged / ready meal | 250–400 | 400–600 | 600–900 |
| Snack | 80–150 | 150–300 | 300–500 |
| Drink | 0–50 | 80–180 | 200–450 |

These are deliberately rough. They're anchored to: restaurant meals averaging ~1,200 kcal
(Urban et al., *J Acad Nutr Diet* 2016); fast-food entrées and the menu-labeling data
(Bleich et al., *Am J Prev Med* 2017); and USDA FoodData Central reference servings for snacks and drinks.
The app stores the low–high range, never a single "exact" number, and hides numbers by default.

**Healthiness levels** follow USDA **MyPlate** and the Harvard **Healthy Eating Plate**:
- *Lighter*: half the plate vegetables or fruit, lean protein, whole grains, little fried food or added sugar.
- *Balanced*: a normal mixed plate.
- *Indulgent*: fried, creamy, sugary, or a large treat.

The *Dietary Guidelines for Americans 2020–2025* note that sugary drinks are the largest single source of
added sugar, which is why drinks are their own category and sweet drinks get their own tip.

## 3. Exercise

- **Calories:** `kcal = MET × kg × hours`, using the **Adult Compendium of Physical Activities**
  (Ainsworth et al. 2011; Herrmann et al. 2024). Only **net** calories, `(MET − 1)`, are added to the food
  budget, because resting burn is already counted.
- **Weekly target:** 150 min moderate or 75 min vigorous aerobic activity, plus muscle-strengthening on
  2+ days (*Physical Activity Guidelines for Americans*, 2nd ed., HHS 2018). To keep it simple, the app counts
  every logged minute once toward 150 and shows exactly what you logged; effort only changes calories.
  A week shows its real total so far (never projected); longer periods show the weekly average.
- **Effort** uses the CDC "talk test": easy = can chat, moderate = can talk but not sing, hard = only a few words.
- **Apple Health workouts** get an intensity by matching their active energy per kg-hour to the closest MET
  level for that activity.

## 4. Weight trend

- **Smoothing:** exponentially weighted moving average, α = 0.1 per day (as in Walker, *The Hacker's Diet*).
  After a gap of *n* days the smoothing factor is `1 − 0.9ⁿ`. More than one reading in a day is averaged.
- **Rate:** least-squares slope of the trend over the last 21 days, which needs at least about a week of readings.
- **Projection:** the goal date at the current rate. It's shown only when the trend is heading toward the goal.
- **First goal:** 5–10% of starting weight, which brings meaningful health benefits (2013 AHA/ACC/TOS
  guideline; NIDDK). Goals below BMI 18.5 aren't accepted. BMI is always shown with a note on its limits.

## 5. Report card and tips

The score is out of 100:

| Part | Points | Measure |
|---|---|---|
| Food quality | 40 | Average healthiness: lighter 1.0, balanced 0.6, indulgent 0. Water and black coffee are excluded. |
| Near target | 20 | Full marks on target, falling to 0 at 30% over or under |
| Movement | 30 | Guideline minutes per week ÷ 150, capped at 1 |
| Consistency | 10 | Share of days with any entry |

Grades: A ≥ 85, B ≥ 70, C ≥ 55, D ≥ 40.

Tips are rule-based. They always appear in this order: **cautions** first, then **suggestions**, then
**celebrations**.

- **Caution:** the trend is falling faster than 1% of body weight a week, or estimated intake is under 75% of the target.
- **Suggestion:**
  - 25% or more of meals are takeout → swap two a week, with the calorie saving shown.
  - 3 or more sweet drinks a week.
  - More than 35% of entries are indulgent.
  - Under 150 active minutes.
  - Fewer than 2 strength days.
  - Logged on fewer than 60% of days. Regular self-monitoring predicts success (Burke et al., *JADA* 2011).
  - The trend is creeping up.
- **Celebration:** met 150 minutes, 75% or more healthy choices, the trend is going down, best weekday.

## 6. Design choices for "normal people"

- Three taps to log a meal, with no Save button: the portion tap saves. Repeat meals take one tap.
- Two taps to log exercise. Apple Health / Watch is optional; manual entry is the main path.
- Screens show data, not prose. Every explanation lives on the in-app **Explanations** page (`ExplainView`).
- Calorie numbers are **off** by default: users see percentages and plain-language feedback.
- Tips and alerts never shame. A single gentle reminder a day, at most.
