package com.jackwallner.sober.data

import android.util.AtomicFile
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.sober.content.SoberContent
import com.jackwallner.sober.model.AppClock
import com.jackwallner.sober.model.CheckIn
import com.jackwallner.sober.model.CravingOutcome
import com.jackwallner.sober.model.GardenGrowth
import com.jackwallner.sober.model.GrowthEvent
import com.jackwallner.sober.model.JournalEntry
import com.jackwallner.sober.model.JourneyDays
import com.jackwallner.sober.model.SoberEngine
import com.jackwallner.sober.model.SoberState
import com.jackwallner.sober.model.UserSettings
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.time.Instant
import java.time.LocalDate

/** Persistence seam, so the store's rules run on the JVM without a device. */
interface StateFile {
    fun read(): String?
    fun write(text: String)
    fun keepUnreadable(text: String, stamp: Long)
}

class AtomicStateFile(private val directory: File) : StateFile {
    private val file = AtomicFile(File(directory, "sober-state.json"))

    override fun read(): String? = try {
        file.openRead().bufferedReader().use { it.readText() }
    } catch (_: FileNotFoundException) {
        null
    }

    override fun write(text: String) {
        val output = file.startWrite()
        try {
            output.write(text.toByteArray())
            file.finishWrite(output)
        } catch (error: IOException) {
            file.failWrite(output)
            throw error
        }
    }

    override fun keepUnreadable(text: String, stamp: Long) {
        File(directory, "sober-state-unreadable-$stamp.json").writeText(text)
    }
}

data class SlipOutcome(val previousStreakDays: Int, val carryoverDays: Int)

/**
 * The app's record: every SwiftData model in one JSON file, written
 * atomically. Each mutation mirrors an iOS service method so screens read like
 * their Swift counterparts.
 */
class SoberStore(
    private val file: StateFile,
    val clock: AppClock,
    private val content: SoberContent,
    private val onChange: () -> Unit = {},
) {
    private var readBlocked = false

    /** The "Not saved" alert, like `SaveFailureReporter.message`. */
    var message by mutableStateOf<String?>(null)
        private set
    var state by mutableStateOf(load())
        private set

    private fun load(): SoberState {
        val text = try {
            file.read() ?: return SoberState()
        } catch (_: IOException) {
            readBlocked = true
            message = "Your saved record couldn't be opened. Close the app and try again."
            return SoberState()
        }
        return try {
            com.jackwallner.sober.data.SoberCodec.decode(text)
        } catch (_: Exception) {
            readBlocked = true
            message = try {
                file.keepUnreadable(text, clock.now().toEpochMilli())
                "Your saved record couldn't be read. A recovery copy is kept on this device; contact support before deleting the app."
            } catch (_: IOException) {
                "Your saved record couldn't be read. Close the app and contact support before making more changes."
            }
            SoberState()
        }
    }

    /** Applies and saves a change. False (and the alert) when it couldn't be written. */
    fun update(change: (SoberState) -> SoberState): Boolean {
        if (readBlocked) return false
        val next = change(state)
        if (next == state) return true
        return try {
            file.write(SoberCodec.encode(next))
            state = next
            onChange()
            true
        } catch (_: Exception) {
            message = SAVE_FAILED
            false
        }
    }

    fun clearMessage() {
        if (!readBlocked) message = null
    }

    // MARK: - Reads

    val settings: UserSettings get() = state.settings
    val hasCompletedOnboarding: Boolean get() = state.settings.hasCompletedOnboarding
    val days: Int get() = JourneyDays.current(state, clock)
    val treeDays: Int get() = GardenGrowth.treeDays(days, state.garden.carryoverDays)
    val activeStart: Instant? get() = JourneyDays.active(state)?.start
    val longestStreakDays: Int get() = JourneyDays.longest(state, clock)
    val lifetimeSoberDays: Int get() = SoberEngine.lifetimeSoberDays(state)
    val today: LocalDate get() = clock.today()
    fun checkIn(day: LocalDate): CheckIn? = state.checkIns.firstOrNull { it.day == day }
    fun hasCheckedIn(day: LocalDate = today): Boolean = SoberEngine.hasCheckedIn(state, day)
    fun loggedSlip(day: LocalDate = today): Boolean = SoberEngine.loggedSlip(state, day)
    fun daysSinceLastCheckIn(): Int = SoberEngine.daysSinceLastCheckIn(state, clock)
    fun streakDays(endingOn: LocalDate): Int = maxOf(0, JourneyDays.at(state, endingOn, clock.zone()))
    fun canUndoSlip(day: LocalDate): Boolean = SoberEngine.canUndoSlip(state, day, clock)
    fun rodeOutCount(): Int = state.cravings.count { it.outcome == CravingOutcome.RODE_IT_OUT }

    /** What the tree inherits if a slip on `day` is logged (the SlipSheet preview). */
    fun previewCarryover(day: LocalDate): Int {
        val had = GardenGrowth.treeDays(streakDays(day), state.garden.carryoverDays)
        return minOf(364, (had * SLIP_CARRYOVER_FRACTION).toInt())
    }

    // MARK: - Onboarding

    /** `persistSetup`: idempotent, so every step can call it. */
    fun persistSetup(start: Instant, costPerDayCents: Int, caloriesPerDay: Int, remindersOptIn: Boolean) = update { old ->
        val clamped = minOf(start, clock.now())
        val withJourney = if (JourneyDays.active(old) == null) SoberEngine.startJourney(old, clamped, clock)
        else SoberEngine.changeStart(old, clamped, clock)
        withJourney.copy(settings = withJourney.settings.copy(
            costPerDayCents = costPerDayCents,
            caloriesPerDay = caloriesPerDay,
            dailyReminderEnabled = remindersOptIn,
            madeCommitment = false,
        ))
    }

    fun completeOnboarding() = update { it.copy(settings = it.settings.copy(hasCompletedOnboarding = true)) }

    // MARK: - Home

    /** Home's onAppear: decay, backfill through yesterday, grove and badges. */
    fun refresh(): Boolean = update { old ->
        var next = SoberEngine.decayVitality(old, clock)
        next = SoberEngine.fillJourney(next, clock.today().minusDays(1), clock)
        val current = JourneyDays.current(next, clock)
        next = SoberEngine.completeCycles(next, current)
        val longest = SoberEngine.longestSoberStreak(next)
        val earned = content.achievements.filter {
            if (it.kind == "timeMilestone") current >= it.dayThreshold else longest >= it.dayThreshold
        }.map { it.id }
        next.copy(earnedAchievementIds = next.earnedAchievementIds + earned)
    }

    /** `processGrowthEvents`: advances the watermark and returns what to celebrate. */
    fun processGrowth(): GrowthEvent? {
        val drawn = treeDays
        val event = SoberEngine.growthEvent(state, drawn)
        update { SoberEngine.markGrowthSeen(it, drawn) }
        return if (event is GrowthEvent.TreeCompleted) GrowthEvent.TreeCompleted(state.garden.completedTreeStyles.size) else event
    }

    fun checkInToday() = update { SoberEngine.water(SoberEngine.checkIn(it, today), clock) }

    fun addTodayDetail(mood: Int?, note: String?) = update { SoberEngine.checkIn(it, today, mood = mood, note = note) }

    /** "Still sober" after an absence. */
    fun backfillAndWater() = update { SoberEngine.water(SoberEngine.backfillSoberDays(it, today), clock) }

    fun resetCounter() = update { SoberEngine.resetCounter(it, clock) }

    // MARK: - Slips (`SlipRecorder`)

    fun recordSlip(day: LocalDate, mood: Int? = null, note: String? = null): SlipOutcome {
        if (loggedSlip(day)) {
            update { SoberEngine.checkIn(it, day, wasSober = false, mood = mood, note = note) }
            return SlipOutcome(streakDays(day), state.garden.carryoverDays)
        }
        val previous = streakDays(day)
        update { SoberEngine.recordSlip(it, day, clock, mood, note) }
        return SlipOutcome(previous, state.garden.carryoverDays)
    }

    fun undoSlip(day: LocalDate, mood: Int? = null, note: String? = null): Boolean {
        if (!canUndoSlip(day)) return false
        return update { old ->
            val undone = SoberEngine.undoSlip(old, day, clock)
            if (mood == null && note == null) undone else SoberEngine.checkIn(undone, day, wasSober = true, mood = mood, note = note)
        }
    }

    // MARK: - Timeline

    fun logCheckIn(day: LocalDate, wasSober: Boolean, mood: Int?, note: String?) =
        update { SoberEngine.checkIn(it, day, wasSober = wasSober, mood = mood, note = note) }

    /** Editing mood or note on an existing row marks it tended, as iOS does. */
    fun editCheckIn(day: LocalDate, mood: Int?, note: String?) = update { old ->
        val existing = old.checkIns.firstOrNull { it.day == day } ?: return@update old
        val edited = existing.copy(mood = mood, note = note, wasLogged = true)
        old.copy(checkIns = old.checkIns.map { if (it.day == day) edited else it })
    }

    fun deleteCheckIn(day: LocalDate) = update { old -> old.copy(checkIns = old.checkIns.filterNot { it.day == day }) }

    // MARK: - Settings

    fun updateSettings(change: (UserSettings) -> UserSettings) = update { it.copy(settings = change(it.settings)) }

    /** Moves the start and keeps the calendar in lockstep, as the iOS binding does. */
    fun changeStart(start: Instant) = update { old ->
        SoberEngine.fillJourney(SoberEngine.changeStart(old, start, clock), clock.today().minusDays(1), clock)
    }

    // MARK: - Garden, cravings, journal

    fun selectSpecies(id: String, isPro: Boolean) =
        update { SoberEngine.selectSpecies(it, id, content.speciesIds, isPro) }

    /** Returns false when the craving row could not be written. */
    fun recordCraving(startedAt: Instant, seconds: Int, outcome: CravingOutcome, intensity: Int?, trigger: String?): Boolean =
        update { SoberEngine.addCraving(it, startedAt, seconds, outcome, intensity, trigger, clock) }

    fun putJournalEntry(entry: JournalEntry, isPro: Boolean) = update { SoberEngine.putJournalEntry(it, entry, isPro) }

    fun deleteJournalEntry(id: String) = update { SoberEngine.deleteJournalEntry(it, id) }

    companion object {
        const val SLIP_CARRYOVER_FRACTION = 0.5
        const val SAVE_FAILED = "Your last change could not be saved on this device, so it may be missing after you close the app. This is usually because storage is full. Free up some space, then check it and try again."
    }
}
