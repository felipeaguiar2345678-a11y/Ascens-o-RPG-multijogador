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

        val xpPerPlayer = totalXp.coerceAtLeast(0) / players.size
        val remainder = totalXp.coerceAtLeast(0) % players.size
        val highestDamage = players.maxOfOrNull { it.damageDealt } ?: 0
        val topDamageIds = if (highestDamage > 0) {
            players.filter { it.damageDealt == highestDamage }
                .map { it.playerId }
                .toSet()
        } else {
            emptySet()
        }

        return players.mapIndexed { index, player ->
            PlayerReward(
                playerId = player.playerId,
                xp = xpPerPlayer + if (index < remainder) 1 else 0,
                receivesItems = player.playerId in topDamageIds
            )
        }
    }
}
