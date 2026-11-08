package br.com.ascensaodosoberano.companions

import androidx.compose.ui.graphics.Color

/** Raridade de saque é independente do rank da criatura (E a SSS). */
enum class RarityTier {
    COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC, DIVINE, ANCESTRAL, WORLD
}

object RarityVisuals {
    fun normalize(value: String): RarityTier = when (
        value.trim().uppercase()
            .replace('Á', 'A').replace('É', 'E').replace('Í', 'I')
            .replace('Ó', 'O').replace('Ú', 'U')
    ) {
        "INCOMUM", "UNCOMMON" -> RarityTier.UNCOMMON
        "RARO", "RARE" -> RarityTier.RARE
        "EPICO", "EPIC" -> RarityTier.EPIC
        "LENDARIO", "LEGENDARY" -> RarityTier.LEGENDARY
        "MITICO", "MYTHIC" -> RarityTier.MYTHIC
        "DIVINO", "DIVINE" -> RarityTier.DIVINE
        "ANCESTRAL", "ANCIENT" -> RarityTier.ANCESTRAL
        "WORLD", "MUNDIAL", "MUNDO" -> RarityTier.WORLD
        else -> RarityTier.COMMON
    }

    fun color(value: String): Color = when (normalize(value)) {
        RarityTier.COMMON -> Color(0xFFB7B9C2)
        RarityTier.UNCOMMON -> Color(0xFF65C879)
        RarityTier.RARE -> Color(0xFF55A8F2)
        RarityTier.EPIC -> Color(0xFFB47BE8)
        RarityTier.LEGENDARY -> Color(0xFFFFC94D)
        RarityTier.MYTHIC -> Color(0xFFB66DFF)
        RarityTier.DIVINE -> Color(0xFFF3F7FF)
        RarityTier.ANCESTRAL -> Color(0xFFC98A45)
        RarityTier.WORLD -> Color(0xFFFF3038)
    }

    fun label(value: String): String = when (normalize(value)) {
        RarityTier.COMMON -> "Comum"
        RarityTier.UNCOMMON -> "Incomum"
        RarityTier.RARE -> "Raro"
        RarityTier.EPIC -> "Épico"
        RarityTier.LEGENDARY -> "Lendário"
        RarityTier.MYTHIC -> "Mítico"
        RarityTier.DIVINE -> "Divino"
        RarityTier.ANCESTRAL -> "Ancestral"
        RarityTier.WORLD -> "World"
    }

    /** Cor exclusiva para rank de ovo/criatura; não representa raridade de item. */
    fun creatureRankColor(rank: String): Color = when (rank.trim().uppercase()) {
        "D" -> Color(0xFF65C879)
        "C" -> Color(0xFF55A8F2)
        "B" -> Color(0xFFB47BE8)
        "A" -> Color(0xFFFFC94D)
        "S" -> Color(0xFFFF8B45)
        "SS" -> Color(0xFF69DCEB)
        "SSS" -> Color(0xFFF3F7FF)
        else -> Color(0xFFB7B9C2)
    }
}
