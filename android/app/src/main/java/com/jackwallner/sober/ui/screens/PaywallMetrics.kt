package com.jackwallner.sober.ui.screens

import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.Modifier
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * `PaywallMetrics`: one page, never two. `size` says how much room this
 * device has, and every dimension is a lerp between a compact value and a
 * roomy one, so a taller screen gets a bigger page rather than a stretched one.
 * Above a threshold the page shows more (benefit details and a label).
 */
class PaywallMetrics(val pageHeight: Float) {
    val size: Float
    val ramp: Float
    val showsExpandedBenefits: Boolean

    init {
        val span = ROOMY - COMPACT
        val raw = ((pageHeight - COMPACT) / span).let { if (it.isFinite()) it.coerceIn(0f, 1f) else 0f }
        size = raw
        showsExpandedBenefits = raw >= EXPANSION_THRESHOLD
        ramp = if (showsExpandedBenefits) maxOf(0f, raw - EXPANSION_COST / span) else raw
    }

    fun lerp(compact: Float, roomy: Float): Float = compact + (roomy - compact) * ramp
    private fun slowLerp(compact: Float, roomy: Float): Float = compact + (roomy - compact) * (ramp * ramp)
    private fun dp(compact: Float, roomy: Float): Dp = lerp(compact, roomy).dp
    private fun sp(compact: Float, roomy: Float): TextUnit = lerp(compact, roomy).sp

    val blockGap: Dp get() = slowLerp(9f, 20f).dp
    val maxBlockGap: Dp get() = (slowLerp(9f, 20f) + lerp(9f, 14f)).dp
    fun stackTopPadding(hasCloseButton: Boolean): Dp = if (hasCloseButton) dp(34f, 44f) else dp(8f, 18f)
    val horizontalGutter: Dp get() = dp(20f, 22f)
    val cardRadius: Dp get() = dp(18f, 22f)

    val heroLineSpacing: Dp get() = dp(2f, 5f)
    val heroEyebrowSize: TextUnit get() = sp(11f, 12.5f)
    val heroAmountSize: TextUnit get() = sp(34f, 46f)
    val heroHeadlineSize: TextUnit get() = sp(25f, 30f)
    val heroSubheadSize: TextUnit get() = sp(14.5f, 16.5f)

    val benefitIconSize: Dp get() = dp(26f, 33f)
    val benefitGlyphSize: Dp get() = dp(13f, 16f)
    val benefitTitleSize: TextUnit get() = sp(15f, 17f)
    val benefitDetailSize: TextUnit get() = sp(12f, 13.5f)
    val benefitRowSpacing: Dp get() = dp(4f, 8f)
    val benefitCardPaddingV: Dp get() = dp(9f, 14f)
    val benefitCardPaddingH: Dp get() = dp(13f, 18f)
    val sectionLabelSize: TextUnit get() = sp(10.5f, 11.5f)

    val planSpacing: Dp get() = slowLerp(6f, 10f).dp
    val planMinHeight: Dp get() = dp(52f, 62f)
    val planPaddingV: Dp get() = dp(7f, 11.5f)
    val planPaddingH: Dp get() = dp(15f, 18f)
    val planTitleSize: TextUnit get() = sp(15f, 17f)
    val planSubtitleSize: TextUnit get() = sp(12f, 13.5f)
    val planPriceSize: TextUnit get() = sp(15f, 17.5f)
    val planAnchorSize: TextUnit get() = sp(12f, 13.5f)
    val planBadgeSize: TextUnit get() = sp(10f, 10.5f)
    val planRadioSize: Dp get() = dp(22f, 26f)
    val planRadius: Dp get() = dp(16f, 20f)

    val timelinePaddingV: Dp get() = dp(8f, 12f)
    val timelinePaddingH: Dp get() = dp(12f, 15f)
    val timelineMarkerSize: Dp get() = dp(28f, 33f)
    val timelineGlyphSize: Dp get() = dp(12f, 14f)
    val timelineTitleSize: TextUnit get() = sp(12f, 13f)
    val timelineDetailSize: TextUnit get() = sp(11.5f, 12.5f)
    val timelineRowGap: Dp get() = dp(6f, 8f)
    val timelineColumnGap: Dp get() = dp(5f, 7f)

    val ctaHeight: Dp get() = dp(52f, 57f)
    val ctaTitleSize: TextUnit get() = sp(17f, 18.5f)
    val ctaRadius: Dp get() = dp(16f, 19f)
    val dockSpacing: Dp get() = slowLerp(8f, 11f).dp
    val dockInnerSpacing: Dp get() = slowLerp(9f, 12f).dp
    val disclosureSize: TextUnit get() = sp(12f, 12.5f)
    val trustSize: TextUnit get() = sp(12f, 12.5f)
    val footerSize: TextUnit get() = sp(12f, 12.5f)

    companion object {
        /** iPhone anchors (672/838pt) moved up 60dp: Android type and the gesture inset run taller. */
        const val COMPACT = 732f
        const val ROOMY = 898f
        const val EXPANSION_COST = 35f
        const val EXPANSION_THRESHOLD = 0.55f
        val compact = PaywallMetrics(COMPACT)
    }
}

/** A block on the paywall page and how eagerly it takes leftover height. */
class PageBlock(val stretch: Float = 0f, val content: @Composable (bounded: Boolean) -> Unit)

/**
 * `PaywallPageLayout`: lays the blocks down one page and splits what is left
 * evenly between them (bounded), giving the rest to blocks that opted in.
 * When the blocks want more than the page, it reports its natural height and
 * the scroll view takes over. Blocks are composed twice: once to learn their
 * natural height, once at the height they are given.
 */
@Composable
fun PaywallPageLayout(pageHeight: Dp, minGap: Dp, maxGap: Dp, blocks: List<PageBlock>, modifier: Modifier = Modifier) {
    SubcomposeLayout(modifier) { constraints ->
        val width = constraints.maxWidth
        val loose = Constraints(minWidth = width, maxWidth = width, minHeight = 0, maxHeight = Constraints.Infinity)
        val natural = blocks.mapIndexed { index, block ->
            subcompose("natural$index") { block.content(false) }.sumOf { it.measure(loose).height }
        }
        val visible = natural.count { it > 0 }
        val gaps = maxOf(0, visible - 1)
        val minGapPx = minGap.roundToPx()
        val maxGapPx = maxGap.roundToPx()
        val height = maxOf(natural.sum() + minGapPx * gaps, pageHeight.roundToPx())
        var free = height - natural.sum()
        var gap = 0
        if (gaps > 0) {
            gap = (free / gaps).coerceIn(minGapPx, maxGapPx)
            free -= gap * gaps
        }
        val weights = blocks.mapIndexed { index, block -> if (natural[index] > 0) block.stretch else 0f }
        val totalWeight = weights.sum()
        val heights = natural.mapIndexed { index, h -> if (free > 0 && totalWeight > 0) h + (free * weights[index] / totalWeight).toInt() else h }
        val placeables = blocks.mapIndexed { index, block ->
            subcompose("final$index") { block.content(true) }.map {
                it.measure(Constraints(minWidth = width, maxWidth = width, minHeight = heights[index], maxHeight = maxOf(heights[index], 0)))
            }
        }
        layout(width, height) {
            var y = 0
            placeables.forEachIndexed { index, list ->
                list.forEach { it.placeRelative(0, y) }
                if (heights[index] > 0) y += heights[index] + gap
            }
        }
    }
}
