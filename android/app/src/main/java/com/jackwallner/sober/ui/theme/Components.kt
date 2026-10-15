package com.jackwallner.sober.ui.theme

import android.view.WindowManager
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider

/** Press feedback for custom buttons, the SwiftUI `.buttonStyle(.plain)` dim. */
fun Modifier.pressable(
    enabled: Boolean = true,
    role: Role = Role.Button,
    label: String? = null,
    onClick: () -> Unit,
): Modifier = composed {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val alpha by animateFloatAsState(if (pressed) 0.6f else 1f, tween(90), label = "press")
    this
        .graphicsLayer { this.alpha = alpha }
        .clickable(interactionSource = source, indication = null, enabled = enabled, role = role, onClickLabel = label, onClick = onClick)
}

/** `.background(color, in: RoundedRectangle)` plus an optional hairline stroke. */
fun Modifier.card(
    color: Color = SoberColors.cardSurface,
    corner: Dp = 18.dp,
    stroke: Color? = SoberColors.ringTrack,
    strokeWidth: Dp = 1.dp,
): Modifier {
    val shape = RoundedCornerShape(corner)
    val base = this.clip(shape).background(color, shape)
    return if (stroke != null) base.border(strokeWidth, stroke, shape) else base
}

fun Modifier.capsule(color: Color, stroke: Color? = null): Modifier {
    val base = this.clip(CircleShape).background(color, CircleShape)
    return if (stroke != null) base.border(1.dp, stroke, CircleShape) else base
}

/** Full-width capsule primary button (`Capsule().fill(brandPrimary)`). */
@Composable
fun PrimaryCapsule(
    text: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
    tag: String? = null,
    onClick: () -> Unit,
) {
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = 50.dp)
            .graphicsLayer { alpha = if (enabled) 1f else 0.5f }
            .capsule(SoberColors.brandPrimary)
            .semantics { contentDescription = text }
            .then(if (tag != null) Modifier.testTagCompat(tag) else Modifier)
            .pressable(enabled = enabled && !loading, onClick = onClick)
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (loading) {
            CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
        } else {
            Text(text, style = SoberType.body(FontWeight.SemiBold), color = Color.White, textAlign = TextAlign.Center)
        }
    }
}

/** The iOS `.bordered` button: tinted translucent capsule-ish fill. */
@Composable
fun BorderedButton(
    text: String,
    modifier: Modifier = Modifier,
    tint: Color = SoberColors.brandPrimary,
    small: Boolean = false,
    style: TextStyle = if (small) SoberType.caption(FontWeight.SemiBold) else SoberType.body(FontWeight.Medium),
    onClick: () -> Unit,
) {
    Box(
        modifier
            .clip(RoundedCornerShape(if (small) 8.dp else 12.dp))
            .background(tint.copy(alpha = 0.12f))
            .pressable(onClick = onClick)
            .padding(horizontal = if (small) 10.dp else 14.dp, vertical = if (small) 6.dp else 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = style, color = tint, textAlign = TextAlign.Center)
    }
}

/** Plain text action, the SwiftUI default `Button("…")`. */
@Composable
fun TextAction(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = SoberColors.brandPrimary,
    style: TextStyle = SoberType.body(),
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Box(
        modifier
            .heightIn(min = 44.dp)
            .graphicsLayer { alpha = if (enabled) 1f else 0.4f }
            .pressable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = style, color = color)
    }
}

@Composable
fun SymbolIcon(name: String, tint: Color, size: Dp = 20.dp, modifier: Modifier = Modifier) {
    Icon(symbol(name), contentDescription = null, tint = tint, modifier = modifier.size(size))
}

/**
 * The inline navigation bar of a sheet or pushed screen: optional leading and
 * trailing actions with a centred title.
 */
@Composable
fun SheetBar(
    title: String,
    leading: (@Composable RowScope.() -> Unit)? = null,
    trailing: (@Composable RowScope.() -> Unit)? = null,
    background: Color = SoberColors.background,
) {
    Box(Modifier.fillMaxWidth().background(background).height(52.dp).padding(horizontal = 8.dp)) {
        Row(Modifier.align(Alignment.CenterStart), verticalAlignment = Alignment.CenterVertically) { leading?.invoke(this) }
        Text(
            title,
            style = SoberType.rounded(17.sp, FontWeight.SemiBold),
            color = SoberColors.textPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            modifier = Modifier.align(Alignment.Center).widthIn(max = 220.dp).semantics { heading() },
        )
        Row(Modifier.align(Alignment.CenterEnd), verticalAlignment = Alignment.CenterVertically) { trailing?.invoke(this) }
    }
}

/** A back chevron for pushed screens inside a sheet or tab. */
@Composable
fun BackChevron(label: String = "Back", onClick: () -> Unit) {
    Row(
        Modifier.heightIn(min = 44.dp).semantics { contentDescription = label }.pressable(onClick = onClick).padding(end = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SymbolIcon("chevron.left", SoberColors.brandPrimary, 30.dp)
        Text(label, style = SoberType.body(), color = SoberColors.brandPrimary)
    }
}

@Composable
fun BarIcon(name: String, label: String, tint: Color = SoberColors.brandPrimary, tag: String? = null, onClick: () -> Unit) {
    Box(
        Modifier.size(44.dp)
            .semantics { contentDescription = label }
            .then(if (tag != null) Modifier.testTagCompat(tag) else Modifier)
            .pressable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        SymbolIcon(name, tint, 24.dp)
    }
}

/** Large left-aligned title for a tab root (`.navigationTitle` large mode). */
@Composable
fun LargeTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        style = SoberType.rounded(32.sp, FontWeight.Bold),
        color = SoberColors.textPrimary,
        modifier = modifier.padding(horizontal = 20.dp).padding(top = 4.dp, bottom = 8.dp).semantics { heading() },
    )
}

// MARK: - Inset grouped list

/**
 * One `Section` of an `.insetGrouped` list on the cream background: optional
 * uppercase header, white rounded rows separated by hairlines, optional footer.
 */
@Composable
fun InsetSection(
    header: String? = null,
    footer: String? = null,
    modifier: Modifier = Modifier,
    rows: @Composable InsetScope.() -> Unit,
) {
    Column(modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 22.dp)) {
        if (header != null) {
            Text(
                header.uppercase(),
                style = SoberType.rounded(13.sp),
                color = SoberColors.textSecondary,
                modifier = Modifier.padding(start = 16.dp, bottom = 7.dp).semantics { heading() },
            )
        }
        val boundaries = remember { mutableListOf<Int>() }
        val inset = with(androidx.compose.ui.platform.LocalDensity.current) { 16.dp.toPx() }
        Layout(
            content = { InsetScope.rows() },
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color.White)
                .drawWithContent {
                    drawContent()
                    boundaries.forEach { y ->
                        drawLine(Color(0x33000000), androidx.compose.ui.geometry.Offset(inset, y.toFloat()),
                            androidx.compose.ui.geometry.Offset(size.width, y.toFloat()), strokeWidth = 0.5.dp.toPx())
                    }
                },
        ) { measurables, constraints ->
            val placeables = measurables.map { it.measure(constraints.copy(minHeight = 0)) }
            val width = constraints.maxWidth
            val height = placeables.sumOf { it.height }
            layout(width, height) {
                boundaries.clear()
                var y = 0
                placeables.forEachIndexed { index, placeable ->
                    if (index > 0 && placeable.height > 0) boundaries.add(y)
                    placeable.placeRelative(0, y)
                    y += placeable.height
                }
            }
        }
        if (footer != null) {
            Text(
                footer,
                style = SoberType.rounded(13.sp),
                color = SoberColors.textSecondary,
                modifier = Modifier.padding(horizontal = 16.dp).padding(top = 7.dp),
            )
        }
    }
}

object InsetScope {
    /** A row with the standard 16dp insets; the section draws the hairlines between rows. */
    @Composable
    fun Item(
        modifier: Modifier = Modifier,
        padding: PaddingValues = PaddingValues(horizontal = 16.dp, vertical = 11.dp),
        divider: Boolean = true,
        onClick: (() -> Unit)? = null,
        content: @Composable () -> Unit,
    ) {
        Box(
            modifier.fillMaxWidth()
                .heightIn(min = 44.dp)
                .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
                .padding(padding),
            contentAlignment = Alignment.CenterStart,
        ) { content() }
    }
}

/** iOS-style switch row content. */
@Composable
fun ToggleRow(label: String, checked: Boolean, tag: String? = null, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = SoberType.body(), color = SoberColors.textPrimary, modifier = Modifier.weight(1f))
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            modifier = if (tag != null) Modifier.testTagCompat(tag) else Modifier,
            colors = SwitchDefaults.colors(
                checkedTrackColor = SoberColors.brandPrimary,
                checkedThumbColor = Color.White,
                uncheckedTrackColor = SoberColors.ringTrack,
                uncheckedThumbColor = Color.White,
                uncheckedBorderColor = Color.Transparent,
            ),
        )
    }
}

/** The iOS `Stepper`: a label and a joined − / + control. */
@Composable
fun StepperRow(
    label: @Composable RowScope.() -> Unit,
    canDecrement: Boolean,
    canIncrement: Boolean,
    onDecrement: () -> Unit,
    onIncrement: () -> Unit,
    decrementLabel: String = "Decrement",
    incrementLabel: String = "Increment",
) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically, content = label)
        Spacer(Modifier.width(12.dp))
        Row(
            Modifier.height(32.dp).clip(RoundedCornerShape(8.dp)).background(Color(0xFFEFEDEA)),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            StepperHalf("−", canDecrement, decrementLabel, onDecrement)
            Box(Modifier.width(1.dp).fillMaxHeight().padding(vertical = 7.dp).background(Color(0x33000000)))
            StepperHalf("+", canIncrement, incrementLabel, onIncrement)
        }
    }
}

@Composable
private fun StepperHalf(symbol: String, enabled: Boolean, label: String, onClick: () -> Unit) {
    Box(
        Modifier.width(46.dp).fillMaxHeight()
            .semantics { contentDescription = label }
            .graphicsLayer { alpha = if (enabled) 1f else 0.3f }
            .pressable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(symbol, style = SoberType.rounded(22.sp), color = SoberColors.textPrimary)
    }
}

/** A borderless multi-line text field with a placeholder, like a `TextField` in a Form. */
@Composable
fun PlainTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    minLines: Int = 1,
    maxLines: Int = 4,
    style: TextStyle = SoberType.body(),
) {
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        textStyle = style.copy(color = SoberColors.textPrimary),
        cursorBrush = SolidColor(SoberColors.brandPrimary),
        minLines = minLines,
        maxLines = maxLines,
        modifier = modifier.fillMaxWidth(),
        decorationBox = { inner ->
            Box {
                if (value.isEmpty()) Text(placeholder, style = style, color = Color(0xFFB8B4AC))
                inner()
            }
        },
    )
}

/** iOS segmented picker. */
@Composable
fun SegmentedPicker(options: List<String>, selected: String, label: (String) -> String = { it }, onSelect: (String) -> Unit) {
    Row(
        Modifier.fillMaxWidth().height(34.dp).clip(RoundedCornerShape(9.dp)).background(Color(0xFFEEEDEA)).padding(2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        options.forEach { option ->
            val active = option == selected
            Box(
                Modifier.weight(1f).fillMaxHeight()
                    .clip(RoundedCornerShape(7.dp))
                    .background(if (active) Color.White else Color.Transparent)
                    .semantics { contentDescription = label(option) }
                    .pressable(role = Role.Tab) { onSelect(option) },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    label(option),
                    style = SoberType.rounded(12.sp, if (active) FontWeight.SemiBold else FontWeight.Medium),
                    color = SoberColors.textPrimary,
                    maxLines = 1,
                )
            }
        }
    }
}

// MARK: - Sheets and alerts

enum class SheetHeight { FULL, LARGE, MEDIUM, COMPACT }

/**
 * A page sheet that slides up over everything. Back or the scrim dismisses it.
 * `FULL` covers the screen (a `fullScreenCover`); the rest leave the status
 * bar strip, half the screen, or a fixed short height visible above.
 */
@Composable
fun SoberSheet(
    visible: Boolean,
    onDismiss: () -> Unit,
    height: SheetHeight = SheetHeight.LARGE,
    dismissible: Boolean = true,
    background: Color = SoberColors.background,
    content: @Composable () -> Unit,
) {
    val state = remember { MutableTransitionState(false) }
    state.targetState = visible
    if (!state.currentState && !state.targetState && state.isIdle) return
    val dismiss = rememberUpdatedState(onDismiss)
    val canDismiss = rememberUpdatedState(dismissible)
    Dialog(
        onDismissRequest = { if (canDismiss.value) dismiss.value() },
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
    ) {
        val view = LocalView.current
        LaunchedEffect(view) {
            (view.parent as? DialogWindowProvider)?.window?.let { window ->
                window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
                window.setWindowAnimations(0)
            }
        }
        Box(Modifier.fillMaxSize()) {
            if (height != SheetHeight.FULL) {
                AnimatedVisibility(state, enter = fadeIn(tween(250)), exit = fadeOut(tween(250))) {
                    Box(
                        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.3f)).clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                        ) { if (canDismiss.value) dismiss.value() },
                    )
                }
            }
            AnimatedVisibility(
                state,
                enter = slideInVertically(tween(320)) { it },
                exit = slideOutVertically(tween(260)) { it },
                modifier = Modifier.fillMaxSize(),
            ) {
                BackHandler { if (canDismiss.value) dismiss.value() }
                val statusTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
                // Short sheets ride up above the keyboard; tall ones shrink and scroll.
                val lift = if (height == SheetHeight.COMPACT || height == SheetHeight.MEDIUM) Modifier.imePadding() else Modifier
                Box(Modifier.fillMaxSize().then(lift), contentAlignment = Alignment.BottomCenter) {
                    val shape = RoundedCornerShape(topStart = 14.dp, topEnd = 14.dp)
                    val sized = when (height) {
                        SheetHeight.FULL -> Modifier.fillMaxSize()
                        SheetHeight.LARGE -> Modifier.fillMaxSize().padding(top = statusTop + 10.dp).clip(shape)
                        SheetHeight.MEDIUM -> Modifier.fillMaxWidth().fillMaxHeight(0.62f).clip(shape)
                        SheetHeight.COMPACT -> Modifier.fillMaxWidth().heightIn(max = 420.dp).clip(shape)
                    }
                    Box(
                        sized
                            .background(background)
                            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
                            // A dialog is its own window: opt in to test tags as resource ids again.
                            .semantics { testTagsAsResourceId = true }
                            .then(if (height == SheetHeight.LARGE || height == SheetHeight.FULL) Modifier.imePadding() else Modifier),
                    ) {
                        if (height == SheetHeight.FULL) {
                            Column(Modifier.fillMaxSize().statusBarsPadding()) { content() }
                        } else {
                            content()
                        }
                    }
                }
            }
        }
    }
}

/** An alert in the app palette. `destructive` paints the confirm action red. */
@Composable
fun SoberAlert(
    title: String,
    message: String?,
    confirmTitle: String = "OK",
    onConfirm: () -> Unit,
    onDismiss: () -> Unit = onConfirm,
    dismissTitle: String? = null,
    destructive: Boolean = false,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = SoberColors.cardSurface,
        titleContentColor = SoberColors.textPrimary,
        textContentColor = SoberColors.textSecondary,
        title = { Text(title, style = SoberType.body(FontWeight.SemiBold)) },
        text = message?.let { { Text(it, style = SoberType.subhead()) } },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(confirmTitle, style = SoberType.body(FontWeight.SemiBold), color = if (destructive) SoberColors.danger else SoberColors.brandPrimary)
            }
        },
        dismissButton = dismissTitle?.let {
            { TextButton(onClick = onDismiss) { Text(it, style = SoberType.body(), color = SoberColors.brandPrimary) } }
        },
    )
}

/** Bottom padding so scrolling content clears the gesture bar. */
@Composable
fun navBarPadding(extra: Dp = 24.dp): PaddingValues =
    PaddingValues(bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + extra)

@Composable
fun ProgressSpinner(color: Color = SoberColors.brandPrimary, size: Dp = 22.dp) {
    CircularProgressIndicator(color = color, strokeWidth = 2.dp, modifier = Modifier.size(size))
}

@Composable
fun Hairline(modifier: Modifier = Modifier) {
    HorizontalDivider(modifier, thickness = 0.5.dp, color = Color(0x33000000))
}

fun Modifier.testTagCompat(tag: String): Modifier = this.testTag(tag)

/**
 * The iOS slider: a thin rounded track and a round white thumb with a soft
 * shadow, instead of Material's thick split track.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun SoberSlider(
    value: Float,
    onValueChange: (Float) -> Unit,
    valueRange: ClosedFloatingPointRange<Float>,
    step: Float,
    activeColor: Color,
    inactiveColor: Color,
    modifier: Modifier = Modifier,
) {
    val steps = ((valueRange.endInclusive - valueRange.start) / step).toInt() - 1
    androidx.compose.material3.Slider(
        value = value,
        onValueChange = { onValueChange((Math.round(it / step) * step).coerceIn(valueRange.start, valueRange.endInclusive)) },
        valueRange = valueRange,
        steps = steps,
        modifier = modifier,
        thumb = {
            Box(
                Modifier.size(28.dp)
                    .shadow(3.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.25f), spotColor = Color.Black.copy(alpha = 0.25f))
                    .background(Color.White, CircleShape),
            )
        },
        track = { state ->
            val fraction = ((state.value - state.valueRange.start) / (state.valueRange.endInclusive - state.valueRange.start)).coerceIn(0f, 1f)
            Box(Modifier.fillMaxWidth().height(4.dp).clip(CircleShape).background(inactiveColor)) {
                Box(Modifier.fillMaxWidth(fraction).height(4.dp).background(activeColor))
            }
        },
    )
}

/**
 * A SwiftUI-style `.shadow(color:radius:y:)` drawn behind a rounded shape.
 * Elevation shadows drew grey slabs over content on the emulator GPU.
 */
fun Modifier.softShadow(color: Color, radius: Dp, offsetY: Dp, corner: Dp): Modifier = this.drawBehind {
    val paint = android.graphics.Paint().apply {
        isAntiAlias = true
        this.color = android.graphics.Color.TRANSPARENT
        setShadowLayer(radius.toPx(), 0f, offsetY.toPx(), color.toArgb())
    }
    drawIntoCanvas {
        it.nativeCanvas.drawRoundRect(0f, 0f, size.width, size.height, corner.toPx(), corner.toPx(), paint)
    }
}
