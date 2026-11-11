package br.com.ascensaodosoberano.exploration

/**
 * Regras oficiais da guilda. O rank é independente do nível e só muda após
 * a confirmação de um exame de promoção contra o chefe do rank atual.
 */
object GuildRankProgression {
    val ranks = listOf("E", "D", "C", "B", "A", "S", "SS", "SSS")

    fun normalize(rank: String): String = rank.uppercase().takeIf { it in ranks } ?: "E"
    fun nextRank(rank: String): String? {
        val index = ranks.indexOf(normalize(rank))
        return ranks.getOrNull(index + 1)
    }

    fun canAcceptMission(playerRank: String, missionRank: String): Boolean {
        val player = ranks.indexOf(normalize(playerRank))
        val mission = ranks.indexOf(normalize(missionRank))
        return mission in 0..player
    }

    fun promotionBossId(playerRank: String): String? {
        val rank = normalize(playerRank)
        return if (rank == "SSS") null else "guild_promotion_boss_${rank.lowercase()}"
    }

    fun canPromote(
        playerRank: String,
        defeatedBossIds: List<String>,
        bossId: String,
        damageContributionPercent: Int
    ): Boolean {
        val expected = promotionBossId(playerRank) ?: return false
        return bossId == expected && damageContributionPercent >= 10 &&
            expected !in defeatedBossIds
    }

    fun promote(playerRank: String): String =
        nextRank(playerRank) ?: normalize(playerRank)
}

/** Identidade fixa do exame: o servidor deve validar este ID contra a vitória real. */
data class GuildPromotionExam(
    val currentRank: String,
    val targetRank: String,
    val bossId: String,
    val bossRank: String,
    val bossName: String,
    val regionId: String,
    val regionName: String,
    val destinationId: String,
    val objective: String = "Derrotar o chefe de promoção e registrar sua contribuição."
)

object GuildPromotionCatalog {
    fun examFor(rank: String): GuildPromotionExam? {
        val current = GuildRankProgression.normalize(rank)
        val next = GuildRankProgression.nextRank(current) ?: return null
        val (regionId, regionName, destinationId, bossName) = when (current) {
            "E" -> listOf("dark_forest", "Floresta Arcana", "clareira_inicial", "Guardião da Clareira")
            "D" -> listOf("frost_mountains", "Montanhas Gélidas", "caverna_gelo", "Sentinela Glacial")
            "C" -> listOf("central_wilds", "Região Central", "ruinas_esquecidas", "Colosso das Ruínas")
            "B" -> listOf("imperial_frontier", "Terras do Império", "catacumbas_reais", "Cavaleiro Imperial Caído")
            "A" -> listOf("ancestral_desert", "Deserto Ancestral", "ruinas_antigas", "Soberano das Dunas")
            "S" -> listOf("shadowlands", "Terras das Sombras", "templo_sombrio", "Arauto das Sombras")
            else -> listOf("eternal_sea", "Mar Eterno", "torre_oceano", "Abissal Primordial")
        }
        return GuildPromotionExam(
            currentRank = current,
            targetRank = next,
            bossId = GuildRankProgression.promotionBossId(current)!!,
            bossRank = current,
            bossName = bossName,
            regionId = regionId,
            regionName = regionName,
            destinationId = destinationId
        )
    }
}
