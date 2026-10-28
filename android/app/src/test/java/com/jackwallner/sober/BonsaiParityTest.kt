package com.jackwallner.sober

import com.jackwallner.sober.ui.bonsai.Affine
import com.jackwallner.sober.ui.bonsai.BRect
import com.jackwallner.sober.ui.bonsai.BonsaiClip
import com.jackwallner.sober.ui.bonsai.BonsaiInk
import com.jackwallner.sober.ui.bonsai.BonsaiLayer
import com.jackwallner.sober.ui.bonsai.BonsaiMotion
import com.jackwallner.sober.ui.bonsai.BonsaiPath
import com.jackwallner.sober.ui.bonsai.BonsaiScene
import com.jackwallner.sober.ui.bonsai.BonsaiStyle
import com.jackwallner.sober.ui.bonsai.BonsaiWind
import com.jackwallner.sober.ui.bonsai.Pt
import com.jackwallner.sober.ui.bonsai.bonsaiContentRect
import com.jackwallner.sober.ui.bonsai.bonsaiScene
import com.jackwallner.sober.ui.bonsai.limbStretch
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.security.MessageDigest
import java.util.zip.GZIPInputStream
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * The Kotlin bonsai port must draw what the Swift original draws. scripts/sync-android-bonsai.py
 * records the real Swift scenes (src/test/resources/bonsai); this test rebuilds each scene and
 * compares, layer by layer, the ink, the clip chain, the wind motion and how much of a 2 unit
 * sampling grid the layer covers (count and centroid, with its clips applied). Coverage is measured
 * on the geometry rather than on the path commands, because Android combines path booleans with
 * PathOperation where SwiftUI uses Path.union.
 *
 * - swiftBonsaiFilesMatchManifest fails the moment any Swift file in Shared/Bonsai changes. Port the
 *   change to Kotlin, then rerun the script; re-recording without porting fails the scene test.
 * - Wind math is compared tightly. Airborne petals and leaves are not recorded (they move every
 *   frame); check them in the debug gallery against iOS.
 */
class BonsaiParityTest {
    private class Stats {
        var frames = 0
        var layers = 0
        var worstCount = 0.0
        var worstWhere = ""
        val failures = ArrayList<String>()
    }

    // MARK: Fixtures

    private fun repoFile(relative: String): File? {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.exists()) return candidate
            dir = dir.parentFile
        }
        return null
    }

    private fun resource(name: String) = javaClass.getResourceAsStream("/bonsai/$name")

    private fun manifest(): JSONObject {
        val stream = resource("manifest.json")
        assertNotNull("Missing bonsai fixture manifest; run scripts/sync-android-bonsai.py", stream)
        return JSONObject(stream!!.bufferedReader().readText())
    }

    private fun sha256(file: File) =
        MessageDigest.getInstance("SHA-256").digest(file.readBytes()).joinToString("") { "%02x".format(it) }

    private fun JSONArray.doubles() = DoubleArray(length()) { getDouble(it) }

    // MARK: Coverage

    private class Coverage(val count: Int, val sx: Double, val sy: Double)

    /** The sampling grid shared with export-main.swift: 2 unit cells over the 600x600 design square, offset off the integer edges. */
    private fun coverage(layer: BonsaiLayer, clips: List<BonsaiClip>): Coverage {
        val box = if (layer.isStroke) strokeBox(layer) else layer.path.boundingRect().let { floatArrayOf(it.minX.toFloat(), it.minY.toFloat(), it.maxX.toFloat(), it.maxY.toFloat()) }
        var x0 = box[0] - 1.0; var y0 = box[1] - 1.0; var x1 = box[2] + 1.0; var y1 = box[3] + 1.0
        for (c in clips) if (!c.inverse) {
            val b = c.path.boundingRect()
            x0 = max(x0, b.minX - 1); y0 = max(y0, b.minY - 1); x1 = min(x1, b.maxX + 1); y1 = min(y1, b.maxY + 1)
        }
        val i0 = max(0, ceil((x0 - GRID_X) / GRID - 0.5).toInt())
        val i1 = min(CELLS - 1, floor((x1 - GRID_X) / GRID - 0.5).toInt())
        val j0 = max(0, ceil((y0 - GRID_Y) / GRID - 0.5).toInt())
        val j1 = min(CELLS - 1, floor((y1 - GRID_Y) / GRID - 0.5).toInt())
        val line = if (layer.isStroke) polylines(layer.path) else emptyList()
        var count = 0
        var sx = 0.0
        var sy = 0.0
        for (j in j0..j1) {
            for (i in i0..i1) {
                val x = (i + 0.5) * GRID + GRID_X
                val y = (j + 0.5) * GRID + GRID_Y
                val hit = if (layer.isStroke) onStroke(line, x, y, layer.strokeWidth / 2, layer.cap == com.jackwallner.sober.ui.bonsai.BonsaiCap.Round)
                else layer.path.contains(x, y)
                if (!hit) continue
                if (clips.any { it.path.contains(x, y) == it.inverse }) continue
                count++; sx += x; sy += y
            }
        }
        return Coverage(count, if (count > 0) sx / count else 0.0, if (count > 0) sy / count else 0.0)
    }

    private fun strokeBox(layer: BonsaiLayer): FloatArray {
        val half = layer.strokeWidth / 2
        var x0 = Double.MAX_VALUE; var y0 = Double.MAX_VALUE; var x1 = -Double.MAX_VALUE; var y1 = -Double.MAX_VALUE
        for (line in polylines(layer.path)) for (k in 0 until line.size / 2) {
            x0 = min(x0, line[2 * k] - half); x1 = max(x1, line[2 * k] + half)
            y0 = min(y0, line[2 * k + 1] - half); y1 = max(y1, line[2 * k + 1] + half)
        }
        return floatArrayOf(x0.toFloat(), y0.toFloat(), x1.toFloat(), y1.toFloat())
    }

    /** A stroke's centre line, flattened: one point list per subpath. */
    private fun polylines(path: BonsaiPath): List<DoubleArray> {
        val out = ArrayList<DoubleArray>()
        var cur = ArrayList<Double>()
        var cx = 0.0
        var cy = 0.0
        fun flush() { if (cur.size >= 4) out.add(cur.toDoubleArray()); cur = ArrayList() }
        path.forEachOp { op, v, i ->
            when (op) {
                BonsaiPath.OP_MOVE.toInt() -> { flush(); cur.add(v[i]); cur.add(v[i + 1]); cx = v[i]; cy = v[i + 1] }
                BonsaiPath.OP_LINE.toInt() -> { cur.add(v[i]); cur.add(v[i + 1]); cx = v[i]; cy = v[i + 1] }
                BonsaiPath.OP_QUAD.toInt() -> {
                    for (k in 1..16) {
                        val t = k / 16.0
                        val u = 1 - t
                        cur.add(u * u * cx + 2 * u * t * v[i] + t * t * v[i + 2])
                        cur.add(u * u * cy + 2 * u * t * v[i + 1] + t * t * v[i + 3])
                    }
                    cx = v[i + 2]; cy = v[i + 3]
                }
                BonsaiPath.OP_CLOSE.toInt() -> flush()
            }
        }
        flush()
        return out
    }

    private fun onStroke(lines: List<DoubleArray>, x: Double, y: Double, half: Double, round: Boolean): Boolean {
        for (line in lines) {
            val n = line.size / 2
            for (k in 0 until n - 1) {
                val ax = line[2 * k]; val ay = line[2 * k + 1]
                val bx = line[2 * k + 2]; val by = line[2 * k + 3]
                val dx = bx - ax; val dy = by - ay
                val l2 = dx * dx + dy * dy
                val t = if (l2 == 0.0) 0.0 else ((x - ax) * dx + (y - ay) * dy) / l2
                val interior = k > 0 && t < 0 || k < n - 2 && t > 1
                if (t in 0.0..1.0) {
                    if (hypot(x - (ax + t * dx), y - (ay + t * dy)) <= half) return true
                } else if (round || interior) {
                    val ex = if (t < 0) ax else bx
                    val ey = if (t < 0) ay else by
                    if (hypot(x - ex, y - ey) <= half) return true
                }
            }
        }
        return false
    }

    // MARK: Comparison

    private fun near(a: Double, b: Double, tol: Double) = abs(a - b) <= tol

    private fun compareMotion(actual: BonsaiMotion, e: JSONArray): String? = when (e.getString(0)) {
        "still" -> if (actual == BonsaiMotion.Still) null else "expected still, got $actual"
        "bent" -> if (actual == BonsaiMotion.Bent) null else "expected bent, got $actual"
        "drift" -> {
            val d = actual as? BonsaiMotion.Drift
            if (d == null || !near(d.at.x, e.getDouble(1), 1e-3) || !near(d.at.y, e.getDouble(2), 1e-3)) "expected drift ${e.doubles().toList()}, got $actual" else null
        }
        else -> {
            val l = actual as? BonsaiMotion.Limb
            if (l == null || !near(l.from.x, e.getDouble(1), 1e-3) || !near(l.from.y, e.getDouble(2), 1e-3) ||
                !near(l.to.x, e.getDouble(3), 1e-3) || !near(l.to.y, e.getDouble(4), 1e-3)
            ) "expected limb ${e.toString()}, got $actual" else null
        }
    }

    private fun compareInk(ink: BonsaiInk, e: Any): String? {
        if (ink is BonsaiInk.Color) {
            val a = e as? JSONArray ?: return "solid vs gradient"
            val got = doubleArrayOf(ink.color.red, ink.color.green, ink.color.blue, ink.color.alpha)
            for (k in 0 until 4) if (!near(got[k], a.getDouble(k), 0.002)) return "ink[$k] ${got[k]} vs Swift ${a.getDouble(k)}"
            return null
        }
        val g = e as? JSONObject ?: return "gradient vs solid"
        ink as BonsaiInk.Linear
        val stops = g.getJSONArray("g")
        if (stops.length() != ink.colors.size) return "gradient stops ${ink.colors.size} vs ${stops.length()}"
        for (s in ink.colors.indices) {
            val c = ink.colors[s]
            val a = stops.getJSONArray(s)
            val got = doubleArrayOf(c.red, c.green, c.blue, c.alpha)
            for (k in 0 until 4) if (!near(got[k], a.getDouble(k), 0.002)) return "stop$s[$k] ${got[k]} vs Swift ${a.getDouble(k)}"
        }
        val p = g.getJSONArray("s").doubles()
        val got = doubleArrayOf(ink.start.x, ink.start.y, ink.end.x, ink.end.y)
        for (k in 0 until 4) if (!near(got[k], p[k], 0.01)) return "gradient point[$k] ${got[k]} vs Swift ${p[k]}"
        return null
    }

    /** Null when the frame matches, else the first mismatch. */
    private fun compareFrame(f: JSONObject, stats: Stats): String? {
        val style = BonsaiStyle.fromRawValue(f.getString("style"))!!
        val day = f.getInt("day")
        val vitality = f.getDouble("vitality")
        val scale = f.getDouble("scale")
        val where = "${style.rawValue} day $day vitality $vitality scale $scale"

        val rect = bonsaiContentRect(day, style)
        val er = f.getJSONArray("rect").doubles()
        val got = doubleArrayOf(rect.x, rect.y, rect.width, rect.height)
        for (k in 0 until 4) if (!near(got[k], er[k], 0.01)) return "$where: content rect[$k] ${got[k]} vs Swift ${er[k]}"

        val scene: BonsaiScene = bonsaiScene(day, style, vitality, scale)
        val pivot = f.getJSONArray("pivot").doubles()
        if (!near(scene.pivot.x, pivot[0], 1e-3) || !near(scene.pivot.y, pivot[1], 1e-3)) return "$where: pivot ${scene.pivot} vs ${pivot.toList()}"
        if (scene.sprout != f.getBoolean("sprout")) return "$where: sprout flag differs"

        val motions = f.getJSONArray("motions")
        if (scene.motions.size != motions.length()) return "$where: ${scene.motions.size} motions, Swift ${motions.length()}"
        for (m in scene.motions.indices) compareMotion(scene.motions[m], motions.getJSONArray(m))?.let { return "$where motion $m: $it" }

        val clips = f.getJSONArray("clips")
        if (scene.clips.size != clips.length()) return "$where: ${scene.clips.size} clip chains, Swift ${clips.length()}"
        for (c in scene.clips.indices) {
            val chain = clips.getJSONArray(c)
            if (scene.clips[c].size != chain.length()) return "$where clip chain $c: ${scene.clips[c].size} clips, Swift ${chain.length()}"
            for (k in scene.clips[c].indices) {
                val e = chain.getJSONArray(k)
                val clip = scene.clips[c][k]
                if (clip.inverse != (e.getInt(0) == 1)) return "$where clip $c.$k: inverse flag differs"
                val b = clip.path.boundingRect()
                val gb = doubleArrayOf(b.minX, b.minY, b.maxX, b.maxY)
                for (q in 0 until 4) if (!near(gb[q], e.getDouble(1 + q), 0.75)) return "$where clip $c.$k bounds[$q] ${gb[q]} vs Swift ${e.getDouble(1 + q)}"
            }
        }

        val layers = f.getJSONArray("layers")
        if (scene.layers.size != layers.length()) return "$where: ${scene.layers.size} layers, Swift ${layers.length()}"
        for (n in scene.layers.indices) {
            val layer = scene.layers[n]
            val e = layers.getJSONArray(n)
            val at = "$where layer $n" + (if (layer.isStroke) " (stroke ${"%.2f".format(layer.strokeWidth)} ${layer.cap})" else "")
            if (layer.clip != e.getInt(0)) return "$at: clip ${layer.clip} vs Swift ${e.getInt(0)}"
            if (layer.motion != e.getInt(1)) return "$at: motion ${layer.motion} vs Swift ${e.getInt(1)}"
            compareInk(layer.ink, e.get(2))?.let { return "$at: $it" }
            // A stroke of a path boolean has no centre line to measure; ink, clip and motion still compare.
            if (layer.isStroke && layer.path.isComposite) { stats.layers++; continue }
            val cov = coverage(layer, scene.clips[layer.clip])
            val count = e.getInt(3)
            val sx = e.getDouble(4)
            val sy = e.getDouble(5)
            val countTol = if (layer.isStroke) 6 + 0.25 * count else 2 + 0.015 * count
            val centroidTol = if (layer.isStroke) 1.0 + 12 / sqrt(max(count, 1).toDouble()) else 0.35 + 6 / sqrt(max(count, 1).toDouble())
            val dev = abs(cov.count - count) / countTol
            if (dev > stats.worstCount) { stats.worstCount = dev; stats.worstWhere = "$at (${cov.count} vs $count)" }
            if (abs(cov.count - count) > countTol) return "$at: covers ${cov.count} cells, Swift ${count}"
            if (count > 0 && cov.count > 0 && hypot(cov.sx - sx, cov.sy - sy) > centroidTol) {
                return "$at: centroid (${cov.sx}, ${cov.sy}) vs Swift ($sx, $sy), $count cells"
            }
            stats.layers++
        }
        stats.frames++
        return null
    }

    private fun assertClean(stats: Stats) {
        if (stats.failures.isNotEmpty()) {
            fail("${stats.failures.size} scenes differ from Swift. First:\n" + stats.failures.take(12).joinToString("\n"))
        }
    }

    // MARK: Tests

    @Test
    fun swiftBonsaiFilesMatchManifest() {
        val shared = repoFile("Shared/Bonsai")
        assumeTrue("Swift bonsai files not reachable from this checkout", shared != null && shared.isDirectory)
        val recorded = manifest().getJSONObject("files")
        val current = HashMap<String, String>()
        shared!!.listFiles { f -> f.name.endsWith(".swift") }!!.forEach { current["Shared/Bonsai/${it.name}"] = sha256(it) }
        repoFile("scripts/android-bonsai/export-main.swift")?.let { current["scripts/android-bonsai/export-main.swift"] = sha256(it) }
        val stale = (current.keys + recorded.keys().asSequence()).toSortedSet().filter { current[it] != recorded.optString(it, null) }
        assertTrue(
            "Swift bonsai changed since the Android fixtures were recorded: $stale. " +
                "Port the change to the Kotlin files under ui/bonsai/, then run scripts/sync-android-bonsai.py.",
            stale.isEmpty(),
        )
    }

    @Test
    fun scenesMatchSwift() {
        val m = manifest()
        val stream = resource("sampled.jsonl.gz")
        assertNotNull("Missing sampled bonsai fixture", stream)
        val stats = Stats()
        BufferedReader(InputStreamReader(GZIPInputStream(stream!!), Charsets.UTF_8)).lineSequence().filter { it.isNotBlank() }.forEach { line ->
            compareFrame(JSONObject(line), stats)?.let { stats.failures.add(it) }
        }
        val text = "scenes: ${stats.frames} matched, ${stats.failures.size} differ, ${stats.layers} layers compared, " +
            "worst layer ${"%.2f".format(stats.worstCount)} of its tolerance (${stats.worstWhere})"
        println(text)
        File("build/bonsai-parity").apply { mkdirs() }.resolve("scenes.txt").writeText(text + "\n")
        assertEquals(m.getInt("frameCount"), stats.frames + stats.failures.size)
        assertClean(stats)
    }

    @Test
    fun windMathMatchesSwift() {
        val stream = resource("wind.jsonl")
        assertNotNull("Missing wind fixture", stream)
        val pivot = Pt(300.0, 410.0)
        var poses = 0
        stream!!.bufferedReader().lineSequence().filter { it.isNotBlank() }.forEach { line ->
            val e = JSONObject(line)
            val wind = BonsaiWind(e.getDouble("t"))
            assertEquals("bend at ${e.getDouble("t")}", e.getDouble("bend"), wind.bendShear(false), 1e-9)
            assertEquals("sprout bend at ${e.getDouble("t")}", e.getDouble("bendSprout"), wind.bendShear(true), 1e-9)
            val drift = e.getJSONArray("drift")
            for (k in 0 until drift.length()) {
                val d = drift.getJSONArray(k).doubles()
                val got = wind.drift(d[0], d[1], pivot)
                assertEquals("drift x", d[2], got.x, 1e-9)
                assertEquals("drift y", d[3], got.y, 1e-9)
            }
            val fall = e.getJSONArray("fall")
            for (k in 0 until fall.length()) {
                val a = fall.getJSONArray(k).doubles()
                val got = wind.fall(a[0], a[1], a[2], a[3], a[4], a[5])
                assertEquals("fall x", a[6], got.x, 1e-9)
                assertEquals("fall y", a[7], got.y, 1e-9)
                assertEquals("fall rot", a[8], got.rotDeg, 1e-9)
                assertEquals("fall opacity", a[9], got.opacity, 1e-9)
            }
            poses++
        }
        assertEquals(manifest().getInt("windCount"), poses)
    }

    @Test
    fun limbStretchHoldsTheRootAndCarriesTheTip() {
        val a = Pt(100.0, 300.0)
        val b = Pt(180.0, 220.0)
        val t = limbStretch(a, b, 3.0, -2.0)
        val root = t.apply(a)
        val tip = t.apply(b)
        assertEquals(a.x, root.x, 1e-9); assertEquals(a.y, root.y, 1e-9)
        assertEquals(b.x + 3.0, tip.x, 1e-9); assertEquals(b.y - 2.0, tip.y, 1e-9)
        val mid = t.apply(Pt(140.0, 260.0))
        assertEquals(141.5, mid.x, 1e-9); assertEquals(259.0, mid.y, 1e-9)
    }

    @Test
    fun affineMatchesCoreGraphicsOrder() {
        // CGAffineTransform(translationX: 10, y: 20).rotated(by: 90 deg) sends (1, 0) to (10, 21).
        val p = Affine().translatedBy(10.0, 20.0).rotated(Math.PI / 2).apply(Pt(1.0, 0.0))
        assertEquals(10.0, p.x, 1e-12)
        assertEquals(21.0, p.y, 1e-12)
    }

    @Test
    fun pathBooleansEvaluateLazily() {
        val a = BonsaiPath.rect(0.0, 0.0, 10.0, 10.0)
        val b = BonsaiPath.rect(5.0, 5.0, 10.0, 10.0)
        assertTrue(a.union(b).contains(12.0, 12.0))
        assertFalse(a.intersection(b).contains(2.0, 2.0))
        assertTrue(a.intersection(b).contains(7.0, 7.0))
        assertFalse(a.subtracting(b).contains(7.0, 7.0))
        assertTrue(a.subtracting(b).contains(2.0, 2.0))
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
        const val GRID = 2.0
        const val GRID_X = 0.137
        const val GRID_Y = 0.291
        const val CELLS = 300
    }
}
