package com.jackwallner.sober.ui.theme

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Spacer
import com.jackwallner.sober.ui.Format
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/**
 * The iOS compact `DatePicker` row: a label and a tinted date chip that opens
 * the calendar, limited to `range`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DateRow(label: String, date: LocalDate, range: ClosedRange<LocalDate>, tag: String? = null, onPick: (LocalDate) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = SoberType.body(), color = SoberColors.textPrimary)
        Spacer(Modifier.weight(1f))
        Text(
            Format.mediumDate(date) + if (date.year != LocalDate.now().year) ", ${date.year}" else "",
            style = SoberType.body(),
            color = SoberColors.brandPrimary,
            modifier = Modifier
                .clip(RoundedCornerShape(8.dp))
                .background(Color(0xFFEFEDEA))
                .semantics { contentDescription = "$label, ${Format.mediumDate(date)} ${date.year}" }
                .then(if (tag != null) Modifier.testTagCompat(tag) else Modifier)
                .pressable { open = true }
                .padding(horizontal = 11.dp, vertical = 6.dp),
        )
    }
    if (open) {
        val startMillis = range.start.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
        val endMillis = range.endInclusive.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
        val state = rememberDatePickerState(
            initialSelectedDateMillis = date.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis in startMillis..endMillis
                override fun isSelectableYear(year: Int) = year in range.start.year..range.endInclusive.year
            },
        )
        val colors = DatePickerDefaults.colors(
            containerColor = SoberColors.cardSurface,
            selectedDayContainerColor = SoberColors.brandPrimary,
            todayDateBorderColor = SoberColors.brandPrimary,
            todayContentColor = SoberColors.brandPrimary,
            selectedYearContainerColor = SoberColors.brandPrimary,
        )
        DatePickerDialog(
            onDismissRequest = { open = false },
            colors = colors,
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { onPick(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()) }
                    open = false
                }) { Text("Done", style = SoberType.body(FontWeight.SemiBold), color = SoberColors.brandPrimary) }
            },
            dismissButton = { TextButton(onClick = { open = false }) { Text("Cancel", style = SoberType.body(), color = SoberColors.brandPrimary) } },
        ) {
            DatePicker(state = state, showModeToggle = false, colors = colors)
        }
    }
}
