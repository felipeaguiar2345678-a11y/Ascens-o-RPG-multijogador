
package br.com.ascensaodosoberano.character

data class LevelUpResult(
    val profile: CharacterProfile,
    val levelsGained: Int
)

object ProgressionSystem {

    const val ATTRIBUTE_POINTS_PER_LEVEL = 5

    fun xpForNextLevel(level: Int): Int {
        return level.coerceAtLeast(1) * 100
    }

    fun gainXp(
        profile: CharacterProfile,
        amount: Int
    ): LevelUpResult {

        var level = profile.level.coerceAtLeast(1)
        var xp = profile.xp + amount.coerceAtLeast(0)
        var levelsGained = 0

        while (xp >= xpForNextLevel(level)) {
            xp -= xpForNextLevel(level)
            level++
            levelsGained++
        }

        return LevelUpResult(
            profile = profile.copy(
                level = level,
                xp = xp,
                attributePoints = profile.attributePoints +
                    (levelsGained * ATTRIBUTE_POINTS_PER_LEVEL)
            ),
            levelsGained = levelsGained
        )
    }

    fun spendAttributePoint(
        profile: CharacterProfile,
        attribute: String
    ): CharacterProfile {

        if (profile.attributePoints <= 0) {
            return profile
        }

        val updatedAttributes = when (attribute.lowercase()) {
            "forca" -> profile.attributes.copy(
                strength = profile.attributes.strength + 1
            )

            "inteligencia" -> profile.attributes.copy(
                intelligence = profile.attributes.intelligence + 1
            )

            "agilidade" -> profile.attributes.copy(
                agility = profile.attributes.agility + 1
            )

            "vitalidade" -> profile.attributes.copy(
                vitality = profile.attributes.vitality + 1
            )

            "espirito" -> profile.attributes.copy(
                spirit = profile.attributes.spirit + 1
            )

            else -> return profile
        }

        return profile.copy(
            attributes = updatedAttributes,
            attributePoints = profile.attributePoints - 1
        )
    }
}
