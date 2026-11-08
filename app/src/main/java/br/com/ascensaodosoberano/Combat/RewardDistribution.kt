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
        // A ordem por UID torna a distribuição do resto idêntica em todos os aparelhos.
        val players = participants.players.sortedBy { it.playerId }
        if (players.isEmpty()) return emptyList()

        val xpTotal = totalXp.coerceAtLeast(0)
        val xpPerPlayer = xpTotal / players.size
        val remainder = xpTotal % players.size

        return players.mapIndexed { index, player ->
            val xpIndividual = xpPerPlayer + if (index < remainder) 1 else 0
            PlayerReward(
                playerId = player.playerId,
                xp = xpIndividual,
                receivesItems = true
            )
        }
    }
}
