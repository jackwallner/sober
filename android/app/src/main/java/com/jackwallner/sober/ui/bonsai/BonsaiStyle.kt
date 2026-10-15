package com.jackwallner.sober.ui.bonsai

/** Mirror of Shared/Bonsai/BonsaiView.swift's BonsaiStyle (raw values and display names). */
enum class BonsaiStyle(val rawValue: String, val displayName: String) {
    Traditional("traditional", "Traditional"),
    Cascade("cascade", "Cascading"),
    Windswept("windswept", "Windswept"),
    Sakura("sakura", "Cherry Blossom"),
    Maple("maple", "Japanese Maple"),
    Pine("pine", "Black Pine");

    companion object {
        fun fromRawValue(raw: String): BonsaiStyle? = entries.firstOrNull { it.rawValue == raw }
    }
}
