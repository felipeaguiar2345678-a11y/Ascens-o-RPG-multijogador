
package br.com.ascensaodosoberano.world

import kotlin.random.Random

enum class AIAction {
    ATTACK,
    DEFEND,
    SPECIAL,
    RETREAT
}

data class AICombatContext(
    val enemyHp: Int,
    val enemyMaxHp: Int,
    val playerHp: Int,
    val playerMaxHp: Int,
    val enemyMana: Int,
    val enemyManaMax: Int,
    val enemyRank: String,
    val turn: Int,
    val enemyAttack: Int = 1,
    val enemyLevel: Int = 1,
    val danger: Int = 30,
    val isBoss: Boolean = false,
    val attacks: List<AtaqueCriatura> = emptyList(),
    val attackCooldowns: Map<String, Int> = emptyMap()
)

data class AICombatDecision(
    val action: AIAction,
    val explanation: String,
    val proposedDamage: Int = 0,
    val selectedAttack: AtaqueCriatura? = null,
    val selectedManaCost: Int = 0,
    val selectedChargeTurns: Int = 0
)
object WorldAI {

    
private fun getManaCostRange(
    attack: AtaqueCriatura
): Pair<Int, Int> {

    val base = attack.custoMana.coerceAtLeast(0)
    val minimum = attack.custoManaMinimo.coerceAtLeast(0)
    val maximum = attack.custoManaMaximo.coerceAtLeast(0)

    // Nenhuma faixa informada: usa o custo fixo.
    if (minimum == 0 && maximum == 0) {
        return base to base
    }

    // Apenas o máximo foi informado.
    if (minimum == 0) {
        return base.coerceAtMost(maximum) to maximum
    }

    // Apenas o mínimo foi informado.
    if (maximum == 0) {
        return minimum to maxOf(minimum, base)
    }

    // Os dois limites foram informados.
    return minimum to maxOf(minimum, maximum)
}

private fun getDefaultManaCostRange(
    attack: AtaqueCriatura
): Pair<Int, Int> {

    if (
        attack.tipoDano.equals("FISICO", ignoreCase = true) &&
        attack.elemento.equals("NEUTRO", ignoreCase = true) &&
        attack.efeitos.isEmpty()
    ) {
        return 0 to 0
    }

    val power = attack.multiplicador.coerceAtLeast(0f)

    return when {
        power <= 0.75f -> 3 to 8
        power <= 1.0f -> 9 to 18
        power <= 1.5f -> 19 to 35
        power <= 2.0f -> 36 to 60
        power <= 3.0f -> 61 to 100
        else -> 101 to 180
    }
}

private fun getMinimumManaCost(
    attack: AtaqueCriatura
): Int {
    val hasCustomCost =
        attack.custoMana > 0 ||
        attack.custoManaMinimo > 0 ||
        attack.custoManaMaximo > 0

    return if (hasCustomCost) {
        getManaCostRange(attack).first
    } else {
        getDefaultManaCostRange(attack).first
    }
}

    
private fun rollManaCost(
    attack: AtaqueCriatura,
    availableMana: Int
): Int? {

    val hasCustomCost =
        attack.custoMana > 0 ||
        attack.custoManaMinimo > 0 ||
        attack.custoManaMaximo > 0

    val (minimum, maximum) = if (hasCustomCost) {
        getManaCostRange(attack)
    } else {
        getDefaultManaCostRange(attack)
    }

    if (availableMana < minimum) {
        return null
    }

    val affordableMaximum = maximum.coerceAtMost(
        availableMana
    )

    return if (affordableMaximum == minimum) {
        minimum
    } else {
        Random.nextInt(minimum, affordableMaximum + 1)
    }
}

    fun decideMonsterAction(
        context: AICombatContext
    ): AICombatDecision {

        val enemyHp = context.enemyHp.toFloat() /
            context.enemyMaxHp.coerceAtLeast(1)

        val playerHp = context.playerHp.toFloat() /
            context.playerMaxHp.coerceAtLeast(1)

        val mana = context.enemyMana.coerceAtLeast(0)
        val danger = context.danger.coerceIn(1, 100)
        val roll = Random.nextInt(100)

        // Considera apenas habilidades que a criatura
        // consegue pagar pelo menos no custo mínimo.
        val ataquesDisponiveis = context.attacks.filter {
    it.chanceUso > 0 &&
        (context.attackCooldowns[it.id] ?: 0) <= 0 &&
        getMinimumManaCost(it) <= mana
}

        val ataqueEscolhido = ataquesDisponiveis
            .filter {
                Random.nextInt(100) <
                    it.chanceUso.coerceIn(0, 100)
            }
            .randomOrNull()

        val custoSorteado = ataqueEscolhido?.let {
            rollManaCost(it, mana)
        }

        val podeUsarEspecial = if (context.attacks.isEmpty()) {
            mana >= 20
        } else {
            ataqueEscolhido != null && custoSorteado != null
        }

        val action = when {
            enemyHp <= 0.10f &&
                !context.isBoss &&
                roll < 70 ->
                AIAction.RETREAT

            enemyHp < 0.30f && roll < 45 ->
                AIAction.DEFEND

            podeUsarEspecial &&
                roll < (25 + danger / 3) ->
                AIAction.SPECIAL

            playerHp < 0.25f && roll < 80 ->
                AIAction.ATTACK

            roll < 25 ->
                AIAction.DEFEND

            else ->
                AIAction.ATTACK
        }

        val selectedAttack = if (action == AIAction.SPECIAL) {
            ataqueEscolhido
        } else {
            null
        }

        val selectedManaCost = when (action) {
            AIAction.SPECIAL ->
                if (selectedAttack != null) {
                    custoSorteado ?: 0
                } else {
                    20
                }

            else -> 0
        }

        val damageMultiplier = when (action) {
            AIAction.ATTACK ->
                Random.nextDouble(0.85, 1.20)

            AIAction.SPECIAL ->
                if (selectedAttack != null) {
                    selectedAttack.multiplicador
                        .toDouble()
                        .coerceAtLeast(0.0)
                } else {
                    Random.nextDouble(1.30, 1.80)
                }

            else -> 0.0
        }

        val baseDamage = selectedAttack?.danoBase
            ?.takeIf { it > 0 }
            ?: context.enemyAttack

        val proposedDamage = (
            baseDamage * damageMultiplier
        ).toInt().coerceAtLeast(0)

        val explanation = when (action) {
            AIAction.ATTACK ->
                "O inimigo analisou sua situação e decidiu atacar!"

            AIAction.DEFEND ->
                "O inimigo percebeu o perigo e assumiu uma posição defensiva."

            AIAction.SPECIAL ->
                if (selectedAttack != null) {
                    "${context.enemyRank}: a criatura utilizou ${selectedAttack.nome}!"
                } else {
                    "O inimigo concentrou energia e preparou uma habilidade especial!"
                }

            AIAction.RETREAT ->
                "O inimigo avaliou o risco e decidiu fugir!"
        }

        return AICombatDecision(
    action = action,
    explanation = explanation,
    proposedDamage = proposedDamage,
    selectedAttack = selectedAttack,
    selectedManaCost = selectedManaCost,
    selectedChargeTurns = selectedAttack?.turnosCarregamento?.coerceAtMost(2) ?: 0
)
    }

    fun generateWorldReaction(
        regionName: String,
        dangerLevel: Int
    ): String {
        return when {
            dangerLevel >= 90 ->
                "Uma presença aterradora altera a atmosfera de $regionName."

            dangerLevel >= 60 ->
                "Movimentos estranhos são percebidos em $regionName."

            dangerLevel >= 30 ->
                "A região $regionName apresenta sinais de atividade."

            else ->
                "A região $regionName permanece relativamente tranquila."
        }
    }
}
