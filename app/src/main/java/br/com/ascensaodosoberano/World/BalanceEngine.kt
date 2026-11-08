
package br.com.ascensaodosoberano.world

import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

data class BalanceContext(
    val playerLevel: Int,
    val playerRank: String,
    val enemyLevel: Int,
    val enemyRank: String,
    val enemyMaxHp: Int,
    val enemyAttack: Int,
    val enemyDefense: Int,
    val enemyBaseXp: Int,
    val danger: Int,
    val isBoss: Boolean,
    val playerContribution: Float = 1f
)

data class BalancedDamage(
    val damage: Int,
    val critical: Boolean,
    val description: String
)

data class BalancedReward(
    val xp: Int,
    val dangerMultiplier: Float,
    val difficultyMultiplier: Float,
    val contributionMultiplier: Float
)

object BalanceEngine {

    private val rankPower = mapOf(
        "E" to 1,
        "D" to 2,
        "C" to 3,
        "B" to 4,
        "A" to 5,
        "S" to 6,
        "SS" to 7,
        "SSS" to 8
    )

    private fun rankValue(rank: String): Int {
        return rankPower[rank.uppercase()] ?: 1
    }

    fun calculateDamage(
        proposedDamage: Int,
        playerHp: Int,
        playerMaxHp: Int,
        danger: Int,
        enemyRank: String,
        isBoss: Boolean
    ): BalancedDamage {

        val safeDanger = danger.coerceIn(1, 100)
        val hp = playerHp.coerceAtLeast(0)
        val maxHp = playerMaxHp.coerceAtLeast(1)

        val dangerFactor = 0.65f + safeDanger / 100f
        val bossFactor = if (isBoss) 1.20f else 1f
        val rankFactor = 1f + rankValue(enemyRank) * 0.04f

        val proposed = max(1, proposedDamage)

        val adjusted = (
            proposed * dangerFactor * bossFactor * rankFactor
        ).toInt().coerceAtLeast(1)

        // Evita que um único ataque comum elimine o jogador.
        val damageLimit = max(
            1,
            (maxHp * if (isBoss) 0.45f else 0.30f).toInt()
        )

        val finalDamage = min(adjusted, damageLimit)

        return BalancedDamage(
            damage = finalDamage,
            critical = adjusted > damageLimit,
            description = if (adjusted > damageLimit) {
                "O dano foi limitado pelo equilíbrio do combate."
            } else {
                "Dano aprovado pela avaliação de perigo."
            }
        )
    }

    fun calculateXp(context: BalanceContext): BalancedReward {

        val levelDifference =
            context.enemyLevel - context.playerLevel

        val difficultyMultiplier = when {
            levelDifference >= 10 -> 1.60f
            levelDifference >= 5 -> 1.35f
            levelDifference >= 2 -> 1.15f
            levelDifference >= -2 -> 1.00f
            levelDifference >= -5 -> 0.75f
            else -> 0.50f
        }

        val dangerMultiplier =
            0.75f + context.danger.coerceIn(1, 100) / 200f

        val contributionMultiplier =
            context.playerContribution.coerceIn(0f, 1f)

        val bossMultiplier =
            if (context.isBoss) 2.0f else 1.0f

        val rankMultiplier =
            1f + rankValue(context.enemyRank) * 0.08f

        val calculatedXp = (
            context.enemyBaseXp *
            difficultyMultiplier *
            dangerMultiplier *
            contributionMultiplier *
            bossMultiplier *
            rankMultiplier
        ).toInt()

        // Limite inicial para impedir recompensas abusivas.
        val xpLimit = max(
            context.enemyBaseXp,
            context.enemyBaseXp * 3
        )

        return BalancedReward(
            xp = calculatedXp.coerceIn(1, xpLimit),
            dangerMultiplier = dangerMultiplier,
            difficultyMultiplier = difficultyMultiplier,
            contributionMultiplier = contributionMultiplier
        )
    }
    fun calcularResistenciaQuebra(
        multiplicadorPoder: Float
    ): Int {
        val poderSeguro = multiplicadorPoder.coerceAtLeast(0f)

        val resistencia = (20 + poderSeguro * 40).toInt()

        return resistencia.coerceIn(20, 200)
    }
    fun generateDanger(
        enemyRank: String,
        isBoss: Boolean
    ): Int {
        val base = rankValue(enemyRank) * 12
        val bossBonus = if (isBoss) 20 else 0
        val variation = Random.nextInt(-5, 11)

        return (base + bossBonus + variation)
            .coerceIn(1, 100)
    }
}
