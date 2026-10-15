package com.jackwallner.sober.ui.theme

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.Air
import androidx.compose.material.icons.filled.AllInclusive
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.Brush
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CheckCircleOutline
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Diamond
import androidx.compose.material.icons.filled.Eco
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FilterDrama
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.HourglassBottom
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.LocalFlorist
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material.icons.filled.MilitaryTech
import androidx.compose.material.icons.filled.MonetizationOn
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.MonitorWeight
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material.icons.filled.Park
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.RestartAlt
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Sell
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.Thunderstorm
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material.icons.filled.ZoomOutMap
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * SF Symbol names used by the iOS views, mapped to their closest Material
 * glyph so screens can be ported with the same names they use on iOS.
 */
fun symbol(name: String): ImageVector = when (name) {
    "leaf.fill" -> Icons.Filled.Eco
    "chart.line.uptrend.xyaxis" -> Icons.AutoMirrored.Filled.ShowChart
    "ellipsis.circle" -> Icons.Filled.MoreHoriz
    "paintbrush.pointed" -> Icons.Filled.Brush
    "gearshape" -> Icons.Filled.Settings
    "arrow.uturn.backward" -> Icons.AutoMirrored.Filled.Undo
    "arrow.counterclockwise" -> Icons.Filled.RestartAlt
    "sparkles", "sparkle" -> Icons.Filled.AutoAwesome
    "checkmark.circle.fill" -> Icons.Filled.CheckCircle
    "checkmark.circle" -> Icons.Filled.CheckCircleOutline
    "checkmark" -> Icons.Filled.Check
    "drop.fill" -> Icons.Filled.WaterDrop
    "wind" -> Icons.Filled.Air
    "chevron.right" -> Icons.Filled.ChevronRight
    "chevron.left" -> Icons.Filled.ChevronLeft
    "cloud.rain.fill" -> Icons.Filled.Thunderstorm
    "cloud.fill" -> Icons.Filled.Cloud
    "cloud.sun.fill" -> Icons.Filled.FilterDrama
    "sun.max.fill" -> Icons.Filled.WbSunny
    "gift.fill" -> Icons.Filled.CardGiftcard
    "flag.fill" -> Icons.Filled.Flag
    "heart.fill" -> Icons.Filled.Favorite
    "chart.bar.xaxis", "chart.bar.fill" -> Icons.Filled.BarChart
    "lock.fill" -> Icons.Filled.Lock
    "lock.open.fill" -> Icons.Filled.LockOpen
    "dollarsign.circle.fill" -> Icons.Filled.MonetizationOn
    "flame.fill" -> Icons.Filled.LocalFireDepartment
    "scalemass.fill" -> Icons.Filled.MonitorWeight
    "checkmark.seal.fill" -> Icons.Filled.WorkspacePremium
    "calendar" -> Icons.Filled.CalendarMonth
    "book.fill" -> Icons.AutoMirrored.Filled.MenuBook
    "book.closed.fill" -> Icons.Filled.Book
    "crown.fill", "crown" -> Icons.Filled.EmojiEvents
    "tree.fill" -> Icons.Filled.Park
    "arrow.triangle.2.circlepath" -> Icons.Filled.Sync
    "hourglass" -> Icons.Filled.HourglassBottom
    "link" -> Icons.Filled.Link
    "heart.text.square.fill" -> Icons.Filled.MonitorHeart
    "bell.badge.fill" -> Icons.Filled.NotificationsActive
    "bell.fill" -> Icons.Filled.Notifications
    "bell.slash.fill" -> Icons.Filled.NotificationsOff
    "flag.checkered" -> Icons.Filled.SportsScore
    "infinity" -> Icons.Filled.AllInclusive
    "xmark.circle.fill" -> Icons.Filled.Cancel
    "xmark" -> Icons.Filled.Close
    "wifi.exclamationmark" -> Icons.Filled.WifiOff
    "arrow.left.arrow.right" -> Icons.Filled.SwapHoriz
    "square.and.pencil" -> Icons.Filled.EditNote
    "pencil" -> Icons.Filled.Edit
    "trash" -> Icons.Filled.Delete
    "shuffle" -> Icons.Filled.Shuffle
    "phone.fill" -> Icons.Filled.Phone
    "cross.case.fill" -> Icons.Filled.MedicalServices
    "magnifyingglass" -> Icons.Filled.Search
    "envelope.fill" -> Icons.Filled.Email
    "arrow.up.forward" -> Icons.Filled.NorthEast
    "exclamationmark.triangle.fill" -> Icons.Filled.Warning
    "exclamationmark.triangle" -> Icons.Filled.WarningAmber
    "clock.fill" -> Icons.Filled.Schedule
    "tag.fill" -> Icons.Filled.Sell
    "shield.lefthalf.filled" -> Icons.Filled.Shield
    "star.fill" -> Icons.Filled.Star
    "medal.fill" -> Icons.Filled.MilitaryTech
    "trophy.fill" -> Icons.Filled.EmojiEvents
    "diamond.fill" -> Icons.Filled.Diamond
    "arrow.up.left.and.down.right.magnifyingglass" -> Icons.Filled.ZoomOutMap
    "camera.macro" -> Icons.Filled.LocalFlorist
    else -> Icons.Filled.Eco
}
