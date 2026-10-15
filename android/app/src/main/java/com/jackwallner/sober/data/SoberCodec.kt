package com.jackwallner.sober.data

import com.jackwallner.sober.model.CheckIn
import com.jackwallner.sober.model.CravingEpisode
import com.jackwallner.sober.model.CravingOutcome
import com.jackwallner.sober.model.GardenState
import com.jackwallner.sober.model.JournalEntry
import com.jackwallner.sober.model.JournalKind
import com.jackwallner.sober.model.Journey
import com.jackwallner.sober.model.SoberState
import com.jackwallner.sober.model.UserSettings
import java.time.Instant
import java.time.LocalDate
import org.json.JSONArray
import org.json.JSONObject

object SoberCodec {
    fun encode(state: SoberState): String = JSONObject().apply {
        put("schemaVersion", state.schemaVersion)
        put("settings", JSONObject().apply {
            put("costPerDayCents", state.settings.costPerDayCents)
            put("currencyCode", state.settings.currencyCode)
            put("caloriesPerDay", state.settings.caloriesPerDay)
            put("dailyReminderEnabled", state.settings.dailyReminderEnabled)
            put("dailyReminderHour", state.settings.dailyReminderHour)
            put("hasCompletedOnboarding", state.settings.hasCompletedOnboarding)
            put("madeCommitment", state.settings.madeCommitment)
        })
        put("journeys", JSONArray(state.journeys.map { journey ->
            JSONObject().apply {
                put("id", journey.id)
                put("startDate", journey.start.toString())
                putNullable("endDate", journey.end?.toString())
                putNullable("resetReason", journey.resetReason)
            }
        }))
        put("checkIns", JSONArray(state.checkIns.map { entry ->
            JSONObject().apply {
                put("day", entry.day.toString())
                put("wasSober", entry.wasSober)
                putNullable("mood", entry.mood)
                putNullable("note", entry.note)
                put("wasLogged", entry.wasLogged)
            }
        }))
        put("journal", JSONArray(state.journal.map { entry ->
            JSONObject().apply {
                put("id", entry.id)
                put("createdAt", entry.createdAt.toString())
                putNullable("promptID", entry.promptId)
                put("kindRaw", entry.kind.key)
                put("text", entry.text)
                putNullable("feeling", entry.feeling)
            }
        }))
        put("cravings", JSONArray(state.cravings.map { entry ->
            JSONObject().apply {
                put("id", entry.id)
                put("startedAt", entry.startedAt.toString())
                put("endedAt", entry.endedAt.toString())
                put("intensity", entry.intensity)
                put("outcomeRaw", entry.outcome.key)
                putNullable("trigger", entry.trigger)
                put("secondsElapsed", entry.secondsElapsed)
            }
        }))
        put("garden", JSONObject().apply {
            put("vitality", state.garden.vitality)
            putNullable("lastWateredAt", state.garden.lastWateredAt?.toString())
            put("activeBonsaiStyleID", state.garden.speciesId)
            put("gardenThemeID", state.garden.themeId)
            put("lastUnlockNotifiedAtDays", state.garden.watermark)
            put("completedTreeStyles", JSONArray(state.garden.completedTreeStyles))
            put("groveCountAtJourneyStart", state.garden.groveCountAtJourneyStart)
            put("carryoverDays", state.garden.carryoverDays)
            put("carryoverBeforeSlip", state.garden.carryoverBeforeSlip)
        })
        put("earnedAchievementIds", JSONArray(state.earnedAchievementIds.sorted()))
    }.toString()

    fun decode(text: String): SoberState {
        val json = JSONObject(text)
        require(json.getInt("schemaVersion") == 1) { "Unsupported saved-data version" }
        val settings = json.getJSONObject("settings")
        val garden = json.getJSONObject("garden")
        val state = SoberState(
            settings = UserSettings(
                costPerDayCents = settings.getInt("costPerDayCents").coerceAtLeast(0),
                currencyCode = settings.getString("currencyCode"),
                caloriesPerDay = settings.getInt("caloriesPerDay").coerceAtLeast(0),
                dailyReminderEnabled = settings.getBoolean("dailyReminderEnabled"),
                dailyReminderHour = settings.getInt("dailyReminderHour").coerceIn(0, 23),
                hasCompletedOnboarding = settings.getBoolean("hasCompletedOnboarding"),
                madeCommitment = settings.optBoolean("madeCommitment", true),
            ),
            journeys = json.getJSONArray("journeys").objects().map {
                Journey(it.getString("id"), Instant.parse(it.getString("startDate")),
                    it.nullableString("endDate")?.let(Instant::parse), it.nullableString("resetReason"))
            },
            checkIns = json.getJSONArray("checkIns").objects().map {
                CheckIn(LocalDate.parse(it.getString("day")), it.getBoolean("wasSober"),
                    if (it.isNull("mood")) null else it.getInt("mood").coerceIn(1, 5), it.nullableString("note"),
                    it.optBoolean("wasLogged", true))
            },
            journal = json.getJSONArray("journal").objects().map {
                JournalEntry(it.getString("id"), Instant.parse(it.getString("createdAt")), it.nullableString("promptID"),
                    JournalKind.entries.first { kind -> kind.key == it.getString("kindRaw") },
                    it.getString("text"), it.nullableString("feeling"))
            },
            cravings = json.getJSONArray("cravings").objects().map {
                CravingEpisode(it.getString("id"), Instant.parse(it.getString("startedAt")),
                    Instant.parse(it.getString("endedAt")), it.getInt("intensity").coerceIn(0, 5),
                    CravingOutcome.entries.first { outcome -> outcome.key == it.getString("outcomeRaw") },
                    it.nullableString("trigger"), it.getInt("secondsElapsed").coerceAtLeast(0))
            },
            garden = GardenState(
                vitality = garden.getDouble("vitality").coerceIn(0.3, 1.0),
                lastWateredAt = garden.nullableString("lastWateredAt")?.let(Instant::parse),
                speciesId = garden.getString("activeBonsaiStyleID"),
                themeId = garden.getString("gardenThemeID"),
                watermark = garden.getInt("lastUnlockNotifiedAtDays").coerceAtLeast(0),
                completedTreeStyles = garden.getJSONArray("completedTreeStyles").strings(),
                groveCountAtJourneyStart = garden.getInt("groveCountAtJourneyStart").coerceAtLeast(0),
                carryoverDays = garden.optInt("carryoverDays", 0).coerceIn(0, 364),
                carryoverBeforeSlip = garden.optInt("carryoverBeforeSlip", 0).coerceIn(0, 364),
            ),
            earnedAchievementIds = json.getJSONArray("earnedAchievementIds").strings().toSet(),
        )
        require(state.journeys.map { it.id }.distinct().size == state.journeys.size)
        require(state.journeys.count { it.end == null } <= 1)
        require(state.checkIns.map { it.day }.distinct().size == state.checkIns.size)
        require(state.journal.map { it.id }.distinct().size == state.journal.size)
        require(state.cravings.map { it.id }.distinct().size == state.cravings.size)
        return state
    }
}

private fun JSONObject.putNullable(key: String, value: Any?) { put(key, value ?: JSONObject.NULL) }
private fun JSONObject.nullableString(key: String): String? = if (isNull(key)) null else getString(key)
private fun JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }
private fun JSONArray.strings(): List<String> = (0 until length()).map { getString(it) }
