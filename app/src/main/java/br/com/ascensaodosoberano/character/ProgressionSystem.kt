
package br.com.ascensaodosoberano.character

import br.com.ascensaodosoberano.world.WorldAreaCatalog
import br.com.ascensaodosoberano.world.WorldMapData
import br.com.ascensaodosoberano.world.WorldPointType

data class LevelUpResult(
    val profile: CharacterProfile,
    val levelsGained: Int
)

data class DefeatPenaltyResult(
    val profile: CharacterProfile,
    val totalXpBefore: Long,
    val totalXpAfter: Long,
    val goldLost: Long,
    val levelsLost: Int
)

object ProgressionSystem {

    const val ATTRIBUTE_POINTS_PER_LEVEL = 5

    /** XP do perfil é o progresso do nível; converte nível + XP em XP acumulado. */
    fun totalAccumulatedXp(profile: CharacterProfile): Long {
        val level = profile.level.coerceAtLeast(1)
        val xpDosNiveisAnteriores = (1 until level).sumOf { xpForNextLevel(it).toLong() }
        return xpDosNiveisAnteriores + profile.xp.coerceAtLeast(0).toLong()
    }

    fun applyDefeatPenalty(profile: CharacterProfile): DefeatPenaltyResult {
        val totalAntes = totalAccumulatedXp(profile)
        val totalDepois = totalAntes / 2L
        var nivel = 1
        var xpRestante = totalDepois
        while (xpRestante >= xpForNextLevel(nivel).toLong() && nivel < 100_000) {
            xpRestante -= xpForNextLevel(nivel).toLong()
            nivel++
        }

        val pontoSeguro = profile.respawnPointId.takeIf { id ->
            val point = WorldMapData.findPoint(id)
            id == "clareira_inicial" || point?.type in setOf(
                WorldPointType.CAPITAL,
                WorldPointType.CITY,
                WorldPointType.VILLAGE
            )
        } ?: "clareira_inicial"
        val spawn = WorldAreaCatalog.forWorldPoint(pontoSeguro)?.spawn
            ?: WorldAreaCatalog.initialArea().spawn
        val ouroAntes = profile.inventory.gold.coerceAtLeast(0L)
        val ouroPerdido = (ouroAntes / 100L) * 20L + ((ouroAntes % 100L) * 20L) / 100L
        val ouroDepois = ouroAntes - ouroPerdido
        val atualizado = profile.copy(
            level = nivel,
            xp = xpRestante.coerceAtMost(Int.MAX_VALUE.toLong()).toInt(),
            currentWorldPointId = pontoSeguro,
            worldX = spawn.x,
            worldY = spawn.y,
            inventory = profile.inventory.copy(gold = ouroDepois)
        )
        return DefeatPenaltyResult(
            profile = atualizado,
            totalXpBefore = totalAntes,
            totalXpAfter = totalDepois,
            goldLost = ouroPerdido,
            levelsLost = (profile.level - nivel).coerceAtLeast(0)
        )
    }

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
