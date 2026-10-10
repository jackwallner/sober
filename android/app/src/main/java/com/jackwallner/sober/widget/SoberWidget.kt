package com.jackwallner.sober.widget

import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontStyle
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.jackwallner.sober.MainActivity
import com.jackwallner.sober.R
import com.jackwallner.sober.SoberApplication
import com.jackwallner.sober.model.GardenGrowth
import com.jackwallner.sober.model.JourneyDays
import com.jackwallner.sober.ui.Format
import com.jackwallner.sober.ui.bonsai.renderBonsaiBitmap
import com.jackwallner.sober.ui.screens.bonsaiStyleFor
import java.time.ZoneId

/**
 * The "Sober Days" widget: the day count with the bonsai at the garden's
 * growth (streak plus slip carryover), on the brand gradient.
 */
class SoberWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(SMALL, MEDIUM))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val graph = (context.applicationContext as SoberApplication).graph
        provideContent {
            val state = graph.store.state
            val clock = graph.clock
            val days = JourneyDays.current(state, clock)
            val treeDays = GardenGrowth.treeDays(days, state.garden.carryoverDays)
            val cycle = GardenGrowth.cycle(treeDays)
            val stage = GardenGrowth.stage(treeDays)
            val stageTitle = if (cycle.completed > 0) "Year ${cycle.completed + 1} · ${stage.title}" else stage.title
            val style = bonsaiStyleFor(state.garden.speciesId)
            val start = JourneyDays.active(state)?.start?.atZone(ZoneId.systemDefault())?.toLocalDate()
            val size = LocalSize.current
            val wide = size.width >= MEDIUM.width
            val density = context.resources.displayMetrics.density
            val treeWidth = if (wide) size.width / 2 else size.width
            val bitmap = renderBonsaiBitmap(
                cycle.dayInCycle, style, state.garden.vitality,
                (treeWidth.value * density).toInt().coerceAtLeast(64),
                (size.height.value * density).toInt().coerceAtLeast(64),
                fill = !wide,
            )
            val unit = if (days == 1) "day sober" else "days sober"
            Box(
                GlanceModifier.fillMaxSize().background(ImageProvider(R.drawable.widget_background))
                    .clickable(actionStartActivity<MainActivity>()),
            ) {
                if (wide) {
                    Row(GlanceModifier.fillMaxSize().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Image(ImageProvider(bitmap), contentDescription = null, modifier = GlanceModifier.width(treeWidth - 18.dp).height(size.height - 24.dp))
                        Spacer(GlanceModifier.width(12.dp))
                        Column {
                            Text("$days", style = TextStyle(color = white(1f), fontSize = 40.sp, fontStyle = FontStyle.Italic, fontWeight = FontWeight.Medium))
                            Text(unit, style = TextStyle(color = white(0.85f), fontSize = 12.sp))
                            Text(stageTitle, style = TextStyle(color = white(0.75f), fontSize = 11.sp, fontWeight = FontWeight.Medium), modifier = GlanceModifier.padding(top = 2.dp))
                            if (start != null) Text("Since ${Format.mediumDate(start)}", style = TextStyle(color = white(0.6f), fontSize = 11.sp))
                        }
                    }
                } else {
                    Image(ImageProvider(bitmap), contentDescription = if (days == 1) "1 day sober" else "$days days sober", modifier = GlanceModifier.fillMaxSize())
                    Column(GlanceModifier.fillMaxSize().padding(top = 6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("$days", style = TextStyle(color = white(1f), fontSize = 30.sp, fontStyle = FontStyle.Italic, fontWeight = FontWeight.Medium))
                        Text(unit, style = TextStyle(color = white(0.95f), fontSize = 11.sp, fontWeight = FontWeight.Medium))
                    }
                }
            }
        }
    }

    private fun white(alpha: Float) = ColorProvider(Color.White.copy(alpha = alpha))

    companion object {
        val SMALL = DpSize(110.dp, 110.dp)
        val MEDIUM = DpSize(250.dp, 110.dp)
    }
}

class SoberWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = SoberWidget()
}
