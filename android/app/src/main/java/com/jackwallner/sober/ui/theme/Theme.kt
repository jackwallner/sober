package com.jackwallner.sober.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.sober.R

/**
 * D1 "Slow morning", the same fixed warm-light palette as `Theme.swift`. The
 * iOS app forces light mode, so there is no night variant here either.
 */
object SoberColors {
    val background = Color(0xFFF6EFE0)
    val cardSurface = Color(0xFFFFFDF9)
    val cardSurfaceLight = Color.White
    val ringTrack = Color(0xFFE2D9CA)
    val textPrimary = Color(0xFF1A1A18)
    val textSecondary = Color(0xFF5B564C)
    val textTertiary = Color(0xFF8E8778)

    val brandPrimary = Color(0xFF2F5B45)
    val brandSecondary = Color(0xFF4F8568)
    val accent = Color(0xFFC49C6C)
    val streakFlame = Color(0xFFD9733C)
    val success = brandPrimary
    val warning = accent
    val danger = Color(0xFFC65B4D)

    /** Error text on the brand gradient (onboarding). */
    val onBrandError = Color(0xFFFFD1B8)

    val gardenOverlayScrim = Color.Black.copy(alpha = 0.42f)
    val checkInDoneFill = brandPrimary.copy(alpha = 0.14f)
    val skyTop = Color(0xFFD4E2E7)
}

object SoberGeo {
    val cardRadius = 22.dp
    val cardPadding = 22.dp
}

/** The single spacing scale, as `Theme.Space`. */
object Space {
    val xs = 4.dp
    val s = 8.dp
    val m = 12.dp
    val l = 16.dp
    val xl = 24.dp
    val xxl = 32.dp
}

object SoberBrushes {
    /** `Theme.brandGradient`: top-leading to bottom-trailing moss. */
    val brand: Brush = Brush.linearGradient(listOf(SoberColors.brandPrimary, SoberColors.brandSecondary))

    /** `Theme.skyGradient`: a morning wash settling into the cream chrome. */
    val sky: Brush = Brush.verticalGradient(listOf(SoberColors.skyTop, SoberColors.background))
}

/**
 * Two voices, as on iOS: a serif for the page (titles, hero numerals) and a
 * rounded sans for everything chatty. Newsreader stands in for New York and
 * Nunito for SF Rounded; both are variable fonts bundled under the OFL.
 */
@OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
object SoberFonts {
    private val weights = listOf(FontWeight.Normal, FontWeight.Medium, FontWeight.SemiBold, FontWeight.Bold, FontWeight.ExtraBold, FontWeight.Black)

    val rounded = FontFamily(weights.map { variable(R.font.nunito, it, FontStyle.Normal) })
    val serif = FontFamily(
        weights.map { variable(R.font.newsreader, it, FontStyle.Normal) } +
            weights.map { variable(R.font.newsreader_italic, it, FontStyle.Italic) },
    )

    private fun variable(res: Int, weight: FontWeight, style: FontStyle) = Font(
        res,
        weight,
        style,
        variationSettings = FontVariation.Settings(FontVariation.weight(weight.weight)),
    )
}

/** `Theme.display/title/heading/body/subhead/caption`, sizes unchanged. */
object SoberType {
    fun display(size: TextUnit = 34.sp, weight: FontWeight = FontWeight.SemiBold) = serif(size, weight)
    fun title(size: TextUnit = 26.sp, weight: FontWeight = FontWeight.SemiBold) = serif(size, weight)
    fun heading(size: TextUnit = 20.sp, weight: FontWeight = FontWeight.SemiBold) = serif(size, weight)
    fun body(weight: FontWeight = FontWeight.Normal) = rounded(17.sp, weight)
    fun subhead(weight: FontWeight = FontWeight.Normal) = rounded(15.sp, weight)
    fun caption(weight: FontWeight = FontWeight.Normal) = rounded(12.sp, weight)

    /** Hero numerals: serif italic, "written in a journal". */
    fun bigNumber(size: TextUnit) = TextStyle(
        fontFamily = SoberFonts.serif,
        fontWeight = FontWeight.Medium,
        fontStyle = FontStyle.Italic,
        fontSize = size,
        lineHeight = size * 1.08f,
    )

    fun serif(size: TextUnit, weight: FontWeight = FontWeight.Normal) =
        TextStyle(fontFamily = SoberFonts.serif, fontWeight = weight, fontSize = size, lineHeight = size * 1.2f)

    fun rounded(size: TextUnit, weight: FontWeight = FontWeight.Normal) =
        TextStyle(fontFamily = SoberFonts.rounded, fontWeight = weight, fontSize = size, lineHeight = size * 1.3f)

    /** The plain system voice iOS uses in a few spots (`.system(size:weight:)`). */
    fun system(size: TextUnit, weight: FontWeight = FontWeight.Normal) =
        TextStyle(fontFamily = SoberFonts.rounded, fontWeight = weight, fontSize = size, lineHeight = size * 1.25f)
}

@Composable
fun SoberTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = SoberColors.brandPrimary,
            onPrimary = Color.White,
            secondary = SoberColors.brandSecondary,
            background = SoberColors.background,
            surface = SoberColors.cardSurface,
            onSurface = SoberColors.textPrimary,
            onBackground = SoberColors.textPrimary,
            surfaceVariant = SoberColors.cardSurface,
            onSurfaceVariant = SoberColors.textSecondary,
            outline = SoberColors.ringTrack,
            error = SoberColors.danger,
        ),
        typography = MaterialTheme.typography.copy(
            bodyLarge = SoberType.body(),
            bodyMedium = SoberType.subhead(),
            bodySmall = SoberType.caption(),
            labelLarge = SoberType.subhead(FontWeight.SemiBold),
            titleLarge = SoberType.heading(),
        ),
        content = content,
    )
}
