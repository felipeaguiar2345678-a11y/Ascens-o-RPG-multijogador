
package br.com.ascensaodosoberano.combat

data class PlayerContribution(
    val playerId: String,
    val playerName: String,
    val damageDealt: Int = 0
)

data class CombatParticipants(
    val players: List<PlayerContribution> = emptyList()
)

object CombatContributionSystem {

    fun registerDamage(
        participants: CombatParticipants,
        playerId: String,
        playerName: String,
        damage: Int
    ): CombatParticipants {

        if (damage <= 0) return participants

        val existing = participants.players.find {
            it.playerId == playerId
        }

        return if (existing == null) {
            participants.copy(
                players = participants.players + PlayerContribution(
                    playerId = playerId,
                    playerName = playerName,
                    damageDealt = damage
                )
            )
        } else {
            participants.copy(
                players = participants.players.map {
                    if (it.playerId == playerId) {
                        it.copy(
                            damageDealt = it.damageDealt + damage
                        )
                    } else {
                        it
                    }
                }
            )
        }
    }

    fun damagePercentage(damage: Int, enemyMaxHp: Int): Double {
        if (enemyMaxHp <= 0) return 0.0
        return (
            damage.coerceAtLeast(0).toDouble() * 100.0 / enemyMaxHp.toDouble()
        ).coerceIn(0.0, 100.0)
    }

    fun hasLootEligibility(damage: Int, enemyMaxHp: Int): Boolean {
        if (enemyMaxHp <= 0) return false
        return damage.coerceAtLeast(0).toLong() * 100L >= enemyMaxHp.toLong() * 10L
    }

    fun getTopDamageDealers(
        participants: CombatParticipants
    ): List<PlayerContribution> {

        val highestDamage = participants.players.maxOfOrNull {
            it.damageDealt
        }?.takeIf { it > 0 } ?: return emptyList()

        return participants.players.filter {
            it.damageDealt == highestDamage
        }
    }
}
