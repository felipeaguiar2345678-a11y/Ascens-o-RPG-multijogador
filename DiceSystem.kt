
package br.com.ascensaodosoberano.combat

import kotlin.random.Random

enum class DiceOutcome {
    CATASTROPHIC_FAILURE,
    FAILURE,
    WEAK_RESULT,
    SUCCESS,
    EXCEPTIONAL_SUCCESS,
    EXTRAORDINARY_SUCCESS
}

data class DiceResult(
    val naturalRoll: Int,
    val modifier: Int,
    val total: Int,
    val outcome: DiceOutcome,
    val description: String
)

object DiceSystem {

    fun rollD20(
        modifier: Int = 0
    ): DiceResult {

        val roll = Random.nextInt(1, 21)
        val total = roll + modifier

        val outcome = when {
            roll == 1 -> DiceOutcome.CATASTROPHIC_FAILURE
            roll == 20 -> DiceOutcome.EXTRAORDINARY_SUCCESS
            total <= 5 -> DiceOutcome.FAILURE
            total <= 9 -> DiceOutcome.WEAK_RESULT
            total <= 14 -> DiceOutcome.SUCCESS
            else -> DiceOutcome.EXCEPTIONAL_SUCCESS
        }

        val description = when (outcome) {
            DiceOutcome.CATASTROPHIC_FAILURE ->
                "Falha catastrófica!"

            DiceOutcome.FAILURE ->
                "Falha!"

            DiceOutcome.WEAK_RESULT ->
                "Resultado insuficiente."

            DiceOutcome.SUCCESS ->
                "Sucesso!"

            DiceOutcome.EXCEPTIONAL_SUCCESS ->
                "Sucesso excepcional!"

            DiceOutcome.EXTRAORDINARY_SUCCESS ->
                "Resultado extraordinário!"
        }

        return DiceResult(
            naturalRoll = roll,
            modifier = modifier,
            total = total,
            outcome = outcome,
            description = description
        )
    }
}
