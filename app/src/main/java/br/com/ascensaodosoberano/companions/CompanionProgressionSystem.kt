
package br.com.ascensaodosoberano.companions

import kotlin.math.roundToInt

data class CompanionLevelUpResult(
    val companion: Companion,
    val levelsGained: Int,
    val xpReceived: Int
)

object CompanionProgressionSystem {

    const val XP_PERCENT_FROM_PLAYER = 50

    fun xpForNextLevel(level: Int): Int {
        return (level.coerceAtLeast(1).toLong() * 100L)
            .coerceAtMost(Int.MAX_VALUE.toLong())
            .toInt()
    }

    fun gainXp(
        companion: Companion,
        playerXp: Int
    ): CompanionLevelUpResult {

        val xpReceived =
            (playerXp.coerceAtLeast(0) * XP_PERCENT_FROM_PLAYER) / 100

        var level = companion.level.coerceAtLeast(1)

        var xp = companion.xp.coerceAtLeast(0).toLong() +
            xpReceived.toLong()

        var levelsGained = 0

        while (
            level < Int.MAX_VALUE &&
            xp >= xpForNextLevel(level).toLong()
        ) {
            xp -= xpForNextLevel(level).toLong()
            level++
            levelsGained++
        }

        val novoCompanheiro = atualizarAtributos(
            companion = companion,
            level = level,
            xp = xp.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
        )

        return CompanionLevelUpResult(
            companion = novoCompanheiro,
            levelsGained = levelsGained,
            xpReceived = xpReceived
        )
    }

    /**
     * Nível 1 = 20%
     * Nível 11 = 40%
     * Nível 21 = 60%
     *
     * Limite máximo de crescimento: 60%.
     */
    private fun percentualDeCrescimento(level: Int): Int {
        return (
            20 + ((level - 1).coerceAtLeast(0) * 2)
        ).coerceAtMost(60)
    }

    private fun calcularAtributo(
        original: Int,
        percentual: Int,
        modificadorMutacao: Int,
        permitirZero: Boolean = false
    ): Int {

        val valorBase =
            (original.coerceAtLeast(0) * percentual / 100f)
                .roundToInt()

        val valorFinal =
            (valorBase * (100 + modificadorMutacao) / 100f)
                .roundToInt()

        return if (permitirZero) {
            valorFinal.coerceAtLeast(0)
        } else {
            valorFinal.coerceAtLeast(1)
        }
    }

    private fun atualizarAtributos(
        companion: Companion,
        level: Int,
        xp: Int
    ): Companion {

        val percentual = percentualDeCrescimento(level)

        val novoEstagio = when {
            percentual < 40 -> "FILHOTE"
            percentual < 60 -> "ADOLESCENTE"
            else -> "ADULTO"
        }

        val proporcaoVida = if (companion.maxHp > 0) {
            companion.hp.toFloat() / companion.maxHp.toFloat()
        } else {
            1f
        }.coerceIn(0f, 1f)

        val novaVidaMaxima = calcularAtributo(
            companion.originalMaxHp,
            percentual,
            companion.mutationHpPercent
        )

        val novaVida = (
            novaVidaMaxima * proporcaoVida
        ).roundToInt().coerceIn(0, novaVidaMaxima)

        // Seleciona as imagens correspondentes ao estágio atual.
        val imagens = when (novoEstagio) {
            "FILHOTE" -> Triple(
                companion.filhoteImagemIconeCaminho,
                companion.filhoteImagemDetalhadaCaminho,
                companion.filhoteImagemSpriteCaminho
            )

            "ADOLESCENTE" -> Triple(
                companion.adolescenteImagemIconeCaminho,
                companion.adolescenteImagemDetalhadaCaminho,
                companion.adolescenteImagemSpriteCaminho
            )

            else -> Triple(
                companion.adultoImagemIconeCaminho,
                companion.adultoImagemDetalhadaCaminho,
                companion.adultoImagemSpriteCaminho
            )
        }

        return companion.copy(
            level = level,
            xp = xp,
            stage = novoEstagio,

            maxHp = novaVidaMaxima,
            hp = novaVida,

            attack = calcularAtributo(
                companion.originalAttack,
                percentual,
                companion.mutationAttackPercent
            ),

            defense = calcularAtributo(
                companion.originalDefense,
                percentual,
                companion.mutationDefensePercent
            ),

            agility = calcularAtributo(
                companion.originalAgility,
                percentual,
                companion.mutationAgilityPercent
            ),

            magicPower = calcularAtributo(
                companion.originalMagicPower,
                percentual,
                companion.mutationMagicPercent,
                permitirZero = true
            ),

            imagemIconeCaminho = imagens.first
                .ifBlank { companion.imagemIconeCaminho },

            imagemDetalhadaCaminho = imagens.second
                .ifBlank { companion.imagemDetalhadaCaminho },

            imagemSpriteCaminho = imagens.third
                .ifBlank { companion.imagemSpriteCaminho }
        )
    }
}
