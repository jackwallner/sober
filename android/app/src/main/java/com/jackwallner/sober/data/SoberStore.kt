package com.jackwallner.sober.data

import android.content.Context
import android.util.AtomicFile
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.sober.content.SoberContent
import com.jackwallner.sober.model.AppClock
import com.jackwallner.sober.model.JourneyDays
import com.jackwallner.sober.model.SoberEngine
import com.jackwallner.sober.model.SoberState
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException

class SoberStore(context: Context, val clock: AppClock, private val content: SoberContent) {
    private val directory = context.filesDir
    private val file = AtomicFile(File(directory, "sober-state.json"))
    private var readBlocked = false
    val hasRecoveryIssue: Boolean get() = readBlocked
    var message by mutableStateOf<String?>(null)
        private set
    var state by mutableStateOf(load())
        private set

    private fun load(): SoberState {
        val text = try {
            file.openRead().bufferedReader().use { it.readText() }
        } catch (_: FileNotFoundException) {
            return SoberState()
        } catch (_: IOException) {
            message = "Your saved record couldn't be opened. Close the app and try again."
            return SoberState()
        }
        return try {
            SoberCodec.decode(text)
        } catch (_: Exception) {
            val backup = File(directory, "sober-state-unreadable-${clock.now().toEpochMilli()}.json")
            try {
                backup.writeText(text)
                message = "Your saved record couldn't be read. A recovery copy is kept on this device; contact support before deleting the app."
            } catch (_: IOException) {
                message = "Your saved record couldn't be read. Close the app and contact support before making more changes."
            }
            SoberState()
        }
    }

    fun update(change: (SoberState) -> SoberState): Boolean {
        if (message?.contains("saved record") == true) return false
        val next = change(state)
        var output: java.io.FileOutputStream? = null
        return try {
            output = file.startWrite()
            output.write(SoberCodec.encode(next).toByteArray())
            file.finishWrite(output)
            state = next
            message = null
            true
        } catch (_: Exception) {
            output?.let(file::failWrite)
            message = "Your last change could not be saved on this device. Free some storage, then try again."
            false
        }
    }

    fun refresh(): Boolean = update { old ->
        var next = SoberEngine.fillJourney(old, clock.today().minusDays(1), clock)
        val days = JourneyDays.current(next, clock)
        next = SoberEngine.completeCycles(next, days)
        val longest = SoberEngine.longestSoberStreak(next)
        val earned = content.achievements.filter {
            if (it.kind == "timeMilestone") days >= it.dayThreshold else longest >= it.dayThreshold
        }.map { it.id }
        next.copy(earnedAchievementIds = next.earnedAchievementIds + earned)
    }

    fun clearMessage() { if (message?.contains("saved record") != true) message = null }
}
