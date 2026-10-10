package com.jackwallner.sober.ui.bonsai

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Debug-only visual check (launch extra `gallery`): every style across the year, like the Swift #Preview. */
@Composable
fun BonsaiGallery() {
    val days = listOf(0, 3, 7, 10, 30, 90, 180, 365)
    Column(Modifier.fillMaxSize().background(Color(0xFFEBF5DB)).statusBarsPadding().verticalScroll(rememberScrollState()).padding(4.dp)) {
        BonsaiStyle.entries.forEach { style ->
            Text(style.displayName, fontSize = 11.sp)
            Row {
                days.forEach { day -> BonsaiView(day, style, 1.0, Modifier.size(44.dp)) }
            }
            Row {
                days.forEach { day -> BonsaiView(day, style, 1.0, Modifier.size(44.dp), fill = true) }
            }
        }
    }
}
