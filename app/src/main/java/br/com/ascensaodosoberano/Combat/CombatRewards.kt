
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

    fun getTopDamageDealers(
        participants: CombatParticipants
    ): List<PlayerContribution> {

        val highestDamage = participants.players.maxOfOrNull {
            it.damageDealt
        } ?: return emptyList()

        return participants.players.filter {
            it.damageDealt == highestDamage
        }
    }
}
