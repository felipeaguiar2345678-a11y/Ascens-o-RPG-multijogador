package br.com.ascensaodosoberano.combat

data class PlayerReward(
    val playerId: String,
    val xp: Int,
    val receivesItems: Boolean
)

object RewardDistributionSystem {

    fun distribute(
        participants: CombatParticipants,
        totalXp: Int
    ): List<PlayerReward> {
        val players = participants.players
        if (players.isEmpty()) return emptyList()

        val xpTotal = totalXp.coerceAtLeast(0)
        val xpPerPlayer = xpTotal / players.size
        val remainder = xpTotal % players.size
        val highestDamage = players.maxOfOrNull { it.damageDealt } ?: 0

        return players.mapIndexed { index, player ->
            val xpBase = xpPerPlayer + if (index < remainder) 1 else 0
            val isTopDamageDealer = highestDamage > 0 &&
                player.damageDealt > 0 &&
                player.damageDealt == highestDamage
            PlayerReward(
                playerId = player.playerId,
                xp = applyTopDamageBonus(xpBase, player.damageDealt, highestDamage),
                receivesItems = isTopDamageDealer
            )
        }
    }

    fun applyTopDamageBonus(
        baseXp: Int,
        playerDamage: Int,
        highestDamage: Int
    ): Int {
        val xp = baseXp.coerceAtLeast(0)
        val isTopDamageDealer = highestDamage > 0 &&
            playerDamage > 0 &&
            playerDamage == highestDamage

        if (!isTopDamageDealer) return xp

        return ((xp.toLong() * 125L + 50L) / 100L)
            .coerceAtMost(Int.MAX_VALUE.toLong())
            .toInt()
    }
}
