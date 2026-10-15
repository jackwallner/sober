package com.jackwallner.sober

import com.jackwallner.sober.ui.bonsai.BRect
import com.jackwallner.sober.ui.bonsai.BonsaiCap
import com.jackwallner.sober.ui.bonsai.BonsaiColor
import com.jackwallner.sober.ui.bonsai.BonsaiGraphics
import com.jackwallner.sober.ui.bonsai.BonsaiPaint
import com.jackwallner.sober.ui.bonsai.BonsaiPath
import com.jackwallner.sober.ui.bonsai.BonsaiRecorder
import com.jackwallner.sober.ui.bonsai.BonsaiStyle
import com.jackwallner.sober.ui.bonsai.Pt
import com.jackwallner.sober.ui.bonsai.bonsaiContentRect
import com.jackwallner.sober.ui.bonsai.drawBonsai
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.BufferedReader
import java.io.File
import java.io.InputStream
import java.io.InputStreamReader
import java.security.MessageDigest
import java.util.zip.GZIPInputStream

/**
 * The Kotlin bonsai renderer must emit the same drawing commands as the Swift original
 * (recorded by scripts/sync-android-bonsai.py): paths, colors, gradients, transforms,
 * opacity, stroke widths and caps, within [TOLERANCE].
 *
 * - sampledFixture: committed fixture (src/test/resources/bonsai/sampled.jsonl.gz).
 * - fullSweep: every day 0...365 of every style, from an uncommitted export. Skipped when
 *   absent. Location: $BONSAI_FULL_DIR or android/app/build/bonsai-full (script default).
 */
class BonsaiParityTest {
    // MARK: Swift-shim style recorder, independent of the production BonsaiRecorder

    private class RefCommand(
        val path: DoubleArray,
        val t: DoubleArray,
        val opacity: Double,
        val color: DoubleArray?,
        val gradient: List<DoubleArray>?,
        val gradientPoints: DoubleArray?,
        val width: Double?,
        val cap: Int,
    )

    /** Mirrors CGAffineTransform translatedBy/scaledBy/rotated(by:) and the shim's GraphicsContext. */
    private class ReferenceRecorder : BonsaiGraphics {
        val commands = ArrayList<RefCommand>()
        private var t = doubleArrayOf(1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
        private var opacity = 1.0
        private val stack = ArrayList<Pair<DoubleArray, Double>>()

        override fun save() { stack.add(t.copyOf() to opacity) }
        override fun restore() { val (m, o) = stack.removeAt(stack.size - 1); t = m; opacity = o }

        override fun translate(x: Double, y: Double) {
            t[4] = t[4] + t[0] * x + t[2] * y
            t[5] = t[5] + t[1] * x + t[3] * y
        }

        override fun scale(x: Double, y: Double) {
            t[0] *= x; t[1] *= x; t[2] *= y; t[3] *= y
        }

        override fun rotate(radians: Double) {
            val c = Math.cos(radians)
            val s = Math.sin(radians)
            val a = t[0]; val b = t[1]; val cc = t[2]; val d = t[3]
            t[0] = c * a + s * cc
            t[1] = c * b + s * d
            t[2] = -s * a + c * cc
            t[3] = -s * b + c * d
        }

        override fun setOpacity(value: Double) { opacity = value }

        private fun record(path: BonsaiPath, paint: BonsaiPaint, width: Double?, cap: BonsaiCap) {
            val rgba = { c: BonsaiColor -> doubleArrayOf(c.red, c.green, c.blue, c.alpha) }
            val solid = paint as? BonsaiPaint.Solid
            val grad = paint as? BonsaiPaint.LinearGradient
            commands.add(
                RefCommand(
                    path.values, t.copyOf(), opacity,
                    solid?.let { rgba(it.color) },
                    grad?.colors?.map(rgba),
                    grad?.let { doubleArrayOf(it.start.x, it.start.y, it.end.x, it.end.y) },
                    width,
                    when (cap) { BonsaiCap.Round -> 1; BonsaiCap.Square -> 2; BonsaiCap.Butt -> 0 },
                ),
            )
        }

        override fun fill(path: BonsaiPath, paint: BonsaiPaint) = record(path, paint, null, BonsaiCap.Butt)
        override fun stroke(path: BonsaiPath, paint: BonsaiPaint, width: Double, cap: BonsaiCap) =
            record(path, paint, width, cap)
    }

    // MARK: Comparison

    private class Stats {
        var frames = 0
        var commands = 0
        var maxDeviation = 0.0
        var worst = ""
        val failures = ArrayList<String>()

        fun note(deviation: Double, where: String) {
            if (deviation > maxDeviation) { maxDeviation = deviation; worst = where }
        }
    }

    private fun JSONArray.doubles() = DoubleArray(length()) { getDouble(it) }

    private fun compare(actual: DoubleArray, expected: DoubleArray, what: String, stats: Stats, where: String): String? {
        if (actual.size != expected.size) return "$what length ${actual.size} != ${expected.size}"
        var bad: String? = null
        for (i in actual.indices) {
            val d = Math.abs(actual[i] - expected[i])
            stats.note(d, "$where $what[$i]")
            if (d > TOLERANCE && bad == null) bad = "$what[$i] ${actual[i]} vs Swift ${expected[i]}"
        }
        return bad
    }

    /** Returns null when the frame matches, else a description of the first mismatch. */
    private fun compareFrame(frame: JSONObject, stats: Stats): String? {
        val style = BonsaiStyle.fromRawValue(frame.getString("style"))!!
        val day = frame.getInt("day")
        val vitality = frame.getDouble("vitality")
        val where = "${style.rawValue} day $day vitality $vitality"

        val bounds = bonsaiContentRect(day, style)
        compare(doubleArrayOf(bounds.x, bounds.y, bounds.width, bounds.height), frame.getJSONArray("bounds").doubles(), "bounds", stats, where)
            ?.let { return "$where: $it" }

        val recorder = ReferenceRecorder()
        drawBonsai(day, style, vitality, recorder)
        val expected = frame.getJSONArray("commands")
        if (recorder.commands.size != expected.length()) {
            return "$where: ${recorder.commands.size} commands, Swift drew ${expected.length()}"
        }
        for (i in recorder.commands.indices) {
            val cmd = recorder.commands[i]
            val e = expected.getJSONObject(i)
            val at = "$where cmd $i"
            compare(cmd.path, e.getJSONArray("p").doubles(), "path", stats, at)?.let { return "$at: $it" }
            compare(cmd.t, e.getJSONArray("t").doubles(), "transform", stats, at)?.let { return "$at: $it" }
            compare(doubleArrayOf(cmd.opacity), doubleArrayOf(e.getDouble("o")), "opacity", stats, at)?.let { return "$at: $it" }
            if (e.has("c") != (cmd.color != null)) return "$at: paint kind differs (solid vs gradient)"
            if (cmd.color != null) {
                compare(cmd.color, e.getJSONArray("c").doubles(), "color", stats, at)?.let { return "$at: $it" }
            } else {
                val g = e.getJSONArray("g")
                if (g.length() != cmd.gradient!!.size) return "$at: gradient stops ${cmd.gradient.size} != ${g.length()}"
                for (s in cmd.gradient.indices) {
                    compare(cmd.gradient[s], g.getJSONArray(s).doubles(), "stop$s", stats, at)?.let { return "$at: $it" }
                }
                compare(cmd.gradientPoints!!, e.getJSONArray("s").doubles(), "gradientPoints", stats, at)?.let { return "$at: $it" }
            }
            if (e.has("w") != (cmd.width != null)) return "$at: fill vs stroke differs"
            if (cmd.width != null) {
                compare(doubleArrayOf(cmd.width), doubleArrayOf(e.getDouble("w")), "width", stats, at)?.let { return "$at: $it" }
                if (cmd.cap != e.getInt("cap")) return "$at: cap ${cmd.cap} != ${e.getInt("cap")}"
            }
            stats.commands++
        }
        stats.frames++
        return null
    }

    private fun lines(stream: InputStream): Sequence<String> =
        BufferedReader(InputStreamReader(GZIPInputStream(stream), Charsets.UTF_8)).lineSequence().filter { it.isNotBlank() }

    private fun runFrames(source: Sequence<String>, stats: Stats) {
        for (line in source) {
            compareFrame(JSONObject(line), stats)?.let { stats.failures.add(it) }
        }
    }

    private fun report(name: String, stats: Stats) {
        val text = "$name: ${stats.frames} frames, ${stats.commands} commands compared, " +
            "max deviation ${"%.6f".format(stats.maxDeviation)} (${stats.worst}), tolerance $TOLERANCE, " +
            "${stats.failures.size} mismatched frames"
        println(text)
        File("build/bonsai-parity").apply { mkdirs() }.resolve("$name.txt").writeText(text + "\n")
    }

    private fun assertClean(stats: Stats) {
        if (stats.failures.isNotEmpty()) {
            fail("${stats.failures.size} frames differ from Swift. First:\n" + stats.failures.take(10).joinToString("\n"))
        }
    }

    // MARK: Fixtures and locations

    private fun repoFile(relative: String): File? {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.exists()) return candidate
            dir = dir.parentFile
        }
        return null
    }

    private fun manifest(): JSONObject {
        val stream = javaClass.getResourceAsStream("/bonsai/manifest.json")
        assertNotNull("Missing bonsai fixture manifest; run scripts/sync-android-bonsai.py", stream)
        return JSONObject(stream!!.bufferedReader().readText())
    }

    private fun sha256(file: File) =
        MessageDigest.getInstance("SHA-256").digest(file.readBytes()).joinToString("") { "%02x".format(it) }

    // MARK: Tests

    @Test
    fun swiftRendererMatchesFixtureManifest() {
        val source = repoFile("Shared/Bonsai/BonsaiRenderer.swift")
        assumeTrue("Swift renderer not reachable from this checkout", source != null)
        val adapter = repoFile("scripts/android-bonsai/RecordingGraphics.swift")!!
        val manifest = manifest()
        assertEquals(
            "Shared/Bonsai/BonsaiRenderer.swift changed. Port the change to BonsaiRenderer.kt, then run scripts/sync-android-bonsai.py.",
            manifest.getString("sourceSHA256"), sha256(source!!),
        )
        assertEquals(
            "scripts/android-bonsai/RecordingGraphics.swift changed. Run scripts/sync-android-bonsai.py.",
            manifest.getString("adapterSHA256"), sha256(adapter),
        )
    }

    @Test
    fun sampledFixtureMatchesSwift() {
        val manifest = manifest()
        val stream = javaClass.getResourceAsStream("/bonsai/sampled.jsonl.gz")
        assertNotNull("Missing sampled bonsai fixture", stream)
        val stats = Stats()
        runFrames(lines(stream!!), stats)
        report("sampled", stats)
        assertEquals(manifest.getInt("sampledFrameCount"), stats.frames + stats.failures.size)
        assertClean(stats)
        assertTrue("fixture should include low-vitality frames", manifest.getJSONArray("lowVitality").length() > 0)
    }

    @Test
    fun fullSweepMatchesSwift() {
        val configured = System.getenv("BONSAI_FULL_DIR")
        val dir = if (configured != null) File(configured) else (repoFile("android/app/build/bonsai-full") ?: File("build/bonsai-full"))
        assumeTrue("No full Swift export at $dir; run scripts/sync-android-bonsai.py to create it", dir.isDirectory)
        val exportInfo = JSONObject(File(dir, "manifest.json").readText())
        assertEquals(
            "Full export is stale; rerun scripts/sync-android-bonsai.py",
            manifest().getString("sourceSHA256"), exportInfo.getString("sourceSHA256"),
        )
        val stats = Stats()
        for (style in BonsaiStyle.entries) {
            val file = File(dir, "${style.rawValue}.jsonl.gz")
            assertTrue("Missing ${file.name}", file.exists())
            file.inputStream().use { runFrames(lines(it), stats) }
        }
        report("full-sweep", stats)
        assertEquals("every day 0...365 of every style", BonsaiStyle.entries.size * 366, stats.frames + stats.failures.size)
        assertEquals(exportInfo.getInt("frameCount"), stats.frames + stats.failures.size)
        assertClean(stats)
    }

    @Test
    fun productionRecorderResolvesTransformsLikeTheReference() {
        for (style in BonsaiStyle.entries) {
            for (day in intArrayOf(0, 1, 7, 8, 100, 365)) {
                val reference = ReferenceRecorder()
                val production = BonsaiRecorder()
                drawBonsai(day, style, 0.6, reference)
                drawBonsai(day, style, 0.6, production)
                assertEquals("${style.rawValue} $day", reference.commands.size, production.commands.size)
                for (i in reference.commands.indices) {
                    val a = reference.commands[i]
                    val b = production.commands[i]
                    for (k in 0 until 6) assertEquals("${style.rawValue} $day cmd $i t[$k]", a.t[k], b.transform[k], 1e-12)
                    assertEquals(a.opacity, b.opacity, 0.0)
                    assertEquals(a.width != null, b.isStroke)
                }
            }
        }
    }

    @Test
    fun pathBoundingRectIsTightAndExcludesControlPoints() {
        val path = BonsaiPath()
        path.move(Pt(0.0, 0.0))
        path.quad(to = Pt(10.0, 0.0), control = Pt(5.0, 20.0))
        path.close()
        assertEquals(BRect(0.0, 0.0, 10.0, 10.0), path.boundingRect())
    }

    @Test
    fun styleNamesMatchSwift() {
        assertEquals(
            listOf("traditional", "cascade", "windswept", "sakura", "maple", "pine"),
            BonsaiStyle.entries.map { it.rawValue },
        )
        assertEquals(
            listOf("Traditional", "Cascading", "Windswept", "Cherry Blossom", "Japanese Maple", "Black Pine"),
            BonsaiStyle.entries.map { it.displayName },
        )
    }

    private companion object {
        const val TOLERANCE = 0.01
    }
}
