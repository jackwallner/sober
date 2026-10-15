package com.jackwallner.sober.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.sober.content.Species
import com.jackwallner.sober.data.PitchIntent
import com.jackwallner.sober.model.GardenGrowth
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.theme.SheetBar
import com.jackwallner.sober.ui.theme.SoberBrushes
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberGeo
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.TextAction
import com.jackwallner.sober.ui.theme.card
import com.jackwallner.sober.ui.theme.pressable
import com.jackwallner.sober.ui.theme.testTagCompat

/**
 * `GardenCustomizationView`: the species picker. Bloom+ is the only gate; a
 * free user keeps the starter tree and gets a pitch for the rest.
 */
@Composable
fun GardenCustomizationSheet(onClose: () -> Unit) {
    val graph = LocalGraph.current
    val store = graph.store
    val isPro = graph.subscriptions.isPro
    val garden = store.state.garden
    val treeDays = store.treeDays
    val dayInCycle = GardenGrowth.cycle(treeDays).dayInCycle
    val species = graph.content.species

    Column(Modifier.fillMaxSize()) {
        SheetBar("Your Tree", trailing = { TextAction("Done", style = SoberType.body(FontWeight.SemiBold), onClick = onClose) })
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            GardenScene(
                days = treeDays,
                vitality = garden.vitality,
                activeStyleId = garden.speciesId,
                isPro = isPro,
                completedTreeStyles = garden.completedTreeStyles,
                modifier = Modifier.fillMaxWidth().height(280.dp),
            )
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("Bonsai Species", style = SoberType.body(), color = SoberColors.textPrimary)
                Text(
                    if (isPro) "Switch anytime. Your day count and growth carry over to whichever tree you choose."
                    else "Bloom+ unlocks every species so you can switch your tree whenever you like. Your streak grows whichever one you pick.",
                    style = SoberType.caption(), color = SoberColors.textSecondary,
                )
            }
            SpeciesGrid(species, garden.speciesId, isPro, dayInCycle) { item, unlocked ->
                if (unlocked) store.selectSpecies(item.id, isPro)
                else graph.coordinator.requestLockedFeature(PitchIntent.GARDEN_SPECIES)
            }
        }
        if (!isPro) {
            Column(Modifier.fillMaxWidth().background(SoberColors.background)) {
                Box(Modifier.fillMaxWidth().height(1.dp).background(SoberColors.ringTrack))
                Column(
                    Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 16.dp).padding(top = 12.dp, bottom = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Row(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(SoberGeo.cardRadius)).background(SoberBrushes.brand)
                            .testTagCompat("customize.unlockAll")
                            .pressable { graph.coordinator.requestLockedFeature(PitchIntent.GARDEN_SPECIES) }
                            .padding(vertical = 15.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        SymbolIcon("crown.fill", Color.White, 18.dp)
                        Spacer(Modifier.width(8.dp))
                        Text("Unlock all ${species.size} trees", style = SoberType.body(FontWeight.SemiBold), color = Color.White)
                    }
                    Text("Swap any species anytime · your streak keeps growing", style = SoberType.caption(), color = SoberColors.textSecondary, textAlign = TextAlign.Center)
                }
            }
        }
    }
}

@Composable
private fun SpeciesGrid(species: List<Species>, activeId: String, isPro: Boolean, dayInCycle: Int, onTap: (Species, Boolean) -> Unit) {
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val columns = maxOf(1, ((maxWidth + 14.dp) / (104.dp + 14.dp)).toInt())
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            species.chunked(columns).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    row.forEach { item ->
                        val unlocked = canUseSpecies(item.id, isPro)
                        val active = item.id == activeId
                        Column(
                            Modifier.weight(1f)
                                .semantics(mergeDescendants = true) {
                                    contentDescription = item.name + when {
                                        active -> ", growing"
                                        !unlocked -> ", locked"
                                        else -> ""
                                    }
                                }
                                .testTagCompat("species.${item.id}")
                                .pressable { onTap(item, unlocked) },
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            SpeciesThumb(
                                item, if (unlocked) dayInCycle else 120, unlocked,
                                modifier = Modifier.fillMaxWidth().height(92.dp)
                                    .border(2.5.dp, if (active) SoberColors.brandPrimary else Color.Transparent, RoundedCornerShape(14.dp)),
                                corner = 14.dp,
                                lockSize = 15.dp,
                            )
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                                Text(
                                    item.name,
                                    style = SoberType.caption(if (active) FontWeight.Bold else FontWeight.Normal),
                                    color = if (active) SoberColors.brandPrimary else SoberColors.textSecondary,
                                    maxLines = 1,
                                    modifier = Modifier.weight(1f, fill = false),
                                )
                                if (active) SymbolIcon("checkmark.circle.fill", SoberColors.brandPrimary, 12.dp)
                                else if (!unlocked) SymbolIcon("crown.fill", SoberColors.accent, 12.dp)
                            }
                        }
                    }
                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}

/** `GardenCollectionView` embedded in a list: one row per species. */
@Composable
fun GardenCollection(activeStyleId: String, isPro: Boolean, modifier: Modifier = Modifier) {
    val graph = LocalGraph.current
    Column(modifier, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        graph.content.species.forEach { item ->
            val usable = canUseSpecies(item.id, isPro)
            val active = item.id == activeStyleId
            Row(
                Modifier.fillMaxWidth()
                    .card(if (usable) SoberColors.cardSurface else SoberColors.cardSurfaceLight, 14.dp,
                        if (active) SoberColors.brandPrimary.copy(alpha = 0.5f) else null, 1.5.dp)
                    .then(if (!usable) Modifier.pressable { graph.coordinator.requestLockedFeature(PitchIntent.GARDEN_SPECIES) } else Modifier)
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                SpeciesThumb(item, 120, usable, Modifier.size(56.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(item.name, style = SoberType.subhead(FontWeight.SemiBold), color = if (usable) SoberColors.textPrimary else SoberColors.textSecondary, maxLines = 1)
                    Text(item.description, style = SoberType.caption(), color = SoberColors.textSecondary, maxLines = 2)
                }
                when {
                    active -> Box(Modifier.semantics { contentDescription = "Currently growing" }) { SymbolIcon("checkmark.seal.fill", SoberColors.success, 24.dp) }
                    !usable -> Box(Modifier.semantics { contentDescription = "Locked. Tap row to learn about Bloom+" }) { SymbolIcon("lock.fill", SoberColors.textTertiary, 18.dp) }
                }
            }
        }
    }
}
