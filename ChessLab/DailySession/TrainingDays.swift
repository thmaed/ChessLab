import Foundation

/// La série de jours d'entraînement (A5) : combien de jours de suite on a
/// travaillé, aujourd'hui compris — ou jusqu'à hier si la journée n'a pas
/// encore commencé, car une série ne meurt qu'à la fin d'un jour manqué.
///
/// Un jour compte quand une position d'ouverture est révisée, un puzzle tenté
/// ou une finale ouverte depuis la séance. Les révisions que l'app planifie
/// elle-même après une partie (A3) n'y comptent pas : ce serait une série
/// gagnée sans rien faire. Local à l'appareil, jamais synchronisé.
enum TrainingStreak {

    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Jours consécutifs jusqu'à aujourd'hui (ou hier, si aujourd'hui est vide).
    static func current(days: Set<String>, now: Date = Date(), calendar: Calendar = .current) -> Int {
        var cursor = now
        if !days.contains(key(for: cursor, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(key(for: cursor, calendar: calendar)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}

@MainActor
enum TrainingDays {
    private static let storageKey = "trainingDays.v1"
    private static let endgameKey = "dailySession.endgameDay"
    /// Au-delà, les jours les plus anciens ne changent plus rien à une série.
    private static let retained = 400

    static func all(defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    static func markToday(now: Date = Date(), defaults: UserDefaults = .standard) {
        let today = TrainingStreak.key(for: now)
        var days = defaults.stringArray(forKey: storageKey) ?? []
        guard !days.contains(today) else { return }
        days.append(today)
        defaults.set(Array(days.sorted().suffix(retained)), forKey: storageKey)
    }

    static func streak(now: Date = Date(), defaults: UserDefaults = .standard) -> Int {
        TrainingStreak.current(days: all(defaults: defaults), now: now)
    }

    static func didTrainToday(now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        all(defaults: defaults).contains(TrainingStreak.key(for: now))
    }

    private static let openingsDoneKey = "dailySession.openingsDone"

    /// Combien de positions d'ouverture DUES ont été révisées aujourd'hui dans
    /// la séance. C'est ce compteur — et non le nombre de positions encore dues —
    /// qui dit que l'objectif du jour est atteint : avec un plafond, il reste
    /// presque toujours des positions dues après les avoir faites.
    static func openingsReviewedToday(now: Date = Date(), defaults: UserDefaults = .standard) -> Int {
        let parts = (defaults.string(forKey: openingsDoneKey) ?? "").split(separator: ":")
        guard parts.count == 2, parts[0] == TrainingStreak.key(for: now), let count = Int(parts[1]) else { return 0 }
        return count
    }

    static func addOpeningsReviewed(_ n: Int = 1, now: Date = Date(), defaults: UserDefaults = .standard) {
        let total = openingsReviewedToday(now: now, defaults: defaults) + n
        defaults.set("\(TrainingStreak.key(for: now)):\(total)", forKey: openingsDoneKey)
    }

    /// La finale de la séance a-t-elle été ouverte aujourd'hui ?
    static func endgameOpenedToday(now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: endgameKey) == TrainingStreak.key(for: now)
    }

    static func markEndgameOpened(now: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(TrainingStreak.key(for: now), forKey: endgameKey)
        markToday(now: now, defaults: defaults)
    }
}
