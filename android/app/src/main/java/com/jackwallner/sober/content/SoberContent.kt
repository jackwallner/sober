package com.jackwallner.sober.content

import com.jackwallner.sober.model.BonsaiStage
import com.jackwallner.sober.model.CravingCoach
import com.jackwallner.sober.model.JournalKind
import java.time.LocalDate
import org.json.JSONArray
import org.json.JSONObject

data class HealthMilestone(
    val id: String,
    val hoursRequired: Double,
    val title: String,
    val summary: String,
    val detail: String,
    val sourceLabel: String,
    val sourceUrl: String?,
)

data class Achievement(
    val id: String,
    val title: String,
    val description: String,
    val kind: String,
    val dayThreshold: Int,
    val icon: String,
)

data class JournalPrompt(val id: String, val kind: JournalKind, val text: String)

data class Species(val id: String, val name: String, val description: String, val order: Int, val colors: List<String>)

data class HabitWords(
    val substance: String,
    val habitGerund: String,
    val habitInstance: String,
    val urge: String,
    val urges: String,
    val typicalUrgeSeconds: Int,
    val minUrgeSeconds: Int,
    val maxUrgeSeconds: Int,
    val triggers: List<String>,
    val reasonPlaceholder: String,
)

class SoberContent private constructor(json: JSONObject) {
    val health = json.getJSONArray("healthBenefits").objects().map {
        HealthMilestone(it.getString("id"), it.getDouble("hoursRequired"), it.getString("title"),
            it.getString("summary"), it.getString("detail"), it.getString("sourceLabel"),
            if (it.isNull("sourceURL")) null else it.getString("sourceURL"))
    }
    val achievements = json.getJSONArray("achievements").objects().map {
        Achievement(it.getString("id"), it.getString("title"), it.getString("description"),
            it.getString("kind"), it.getInt("dayThreshold"), it.getString("icon"))
    }
    val prompts = json.getJSONArray("journalPrompts").objects().map {
        JournalPrompt(it.getString("id"), JournalKind.entries.first { kind -> kind.key == it.getString("kind") }, it.getString("text"))
    }
    val species = json.getJSONArray("species").objects().map {
        Species(it.getString("id"), it.getString("displayName"), it.getString("description"),
            it.getInt("order"), it.getJSONArray("colors").strings())
    }.sortedBy { it.order }
    val stageMessages = json.getJSONArray("stages").objects().associate {
        BonsaiStage.entries[it.getInt("id")] to it.getString("growthMessage")
    }
    val coachLines = json.getJSONArray("coachLines").strings()
    val words = json.getJSONObject("vocabulary").let {
        HabitWords(it.getString("substance"), it.getString("habitGerund"), it.getString("habitInstance"),
            it.getString("urgeNoun"), it.getString("urgeNounPlural"), it.getInt("typicalUrgeSeconds"),
            it.getInt("minUrgeSeconds"), it.getInt("maxUrgeSeconds"), it.getJSONArray("triggers").strings(),
            it.getString("reasonPlaceholder"))
    }
    val speciesIds = species.map { it.id }.toSet()

    init {
        require(json.getInt("schemaVersion") == 1)
        require(health.map { it.id }.distinct().size == health.size)
        require(achievements.map { it.id }.distinct().size == achievements.size)
        require(prompts.map { it.id }.distinct().size == prompts.size)
        require(speciesIds.size == species.size)
        require(stageMessages.size == BonsaiStage.entries.size)
        require(coachLines.size == 5)
        require(words.minUrgeSeconds > 0 && words.maxUrgeSeconds >= words.typicalUrgeSeconds)
    }

    fun promptOfDay(date: LocalDate): JournalPrompt = prompts[date.dayOfYear % prompts.size]
    fun coach(elapsed: Int, target: Int): String = CravingCoach.line(elapsed, target, coachLines)
    fun species(id: String): Species = species.firstOrNull { it.id == id } ?: species.first()

    companion object {
        val shared: SoberContent by lazy {
            val stream = SoberContent::class.java.getResourceAsStream("/sober-content.json")
                ?: error("Run scripts/sync-android-content.sh before building Android.")
            stream.bufferedReader().use { SoberContent(JSONObject(it.readText())) }
        }
    }
}

private fun JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }
private fun JSONArray.strings(): List<String> = (0 until length()).map { getString(it) }
