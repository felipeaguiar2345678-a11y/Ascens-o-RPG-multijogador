
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

        // A lista representa quem participou da batalha; contribuição de dano
        // não é requisito para receber recompensa.
        val players = participants.players

        if (players.isEmpty()) return emptyList()

        val xpPerPlayer = totalXp / players.size
        val remainder = totalXp % players.size

        return players.mapIndexed { index, player ->
            PlayerReward(
                playerId = player.playerId,
                xp = xpPerPlayer + if (index < remainder) 1 else 0,
                receivesItems = true
            )
        }
    }
}
