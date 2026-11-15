package br.com.ascensaodosoberano.combat

data class PlayerReward(
    val playerId: String,
    val xp: Int,
    val receivesItems: Boolean
)

object RewardDistributionSystem {

    fun distribute(
        participants: CombatParticipants,
        totalXp: Int,
        enemyMaxHp: Int
    ): List<PlayerReward> {
        // UID ordenado mantém a divisão do resto e os desempates iguais em todos os aparelhos.
        val players = participants.players.sortedBy { it.playerId }
        if (players.isEmpty()) return emptyList()

        val xpTotal = totalXp.coerceAtLeast(0)
        val xpPerPlayer = xpTotal / players.size
        val remainder = xpTotal % players.size

        // Apenas o maior causador de dano recebe itens, ovos e equipamentos.
        // Mantemos o mínimo de 10% para impedir saque por participação insignificante.
        // Em empate, vence o UID alfabeticamente menor, de forma determinística.
        val maiorDanoElegivel = players
            .filter { CombatContributionSystem.hasLootEligibility(it.damageDealt, enemyMaxHp) }
            .maxOfOrNull { it.damageDealt.coerceAtLeast(0) }
        val vencedorDoSaque = if (maiorDanoElegivel == null) null else {
            players.firstOrNull {
                it.damageDealt.coerceAtLeast(0) == maiorDanoElegivel &&
                    CombatContributionSystem.hasLootEligibility(it.damageDealt, enemyMaxHp)
            }?.playerId
        }

        return players.mapIndexed { index, player ->
            val xpIndividual = xpPerPlayer + if (index < remainder) 1 else 0
            PlayerReward(
                playerId = player.playerId,
                xp = xpIndividual,
                receivesItems = player.playerId == vencedorDoSaque
            )
        }
    }
}