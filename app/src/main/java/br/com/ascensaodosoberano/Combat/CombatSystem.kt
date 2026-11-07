
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.AtaqueCriatura
import br.com.ascensaodosoberano.world.AIAction
import br.com.ascensaodosoberano.world.AICombatContext
import br.com.ascensaodosoberano.world.BalanceContext
import br.com.ascensaodosoberano.world.BalanceEngine
import br.com.ascensaodosoberano.world.WorldAI

enum class CombatPhase {
    PLAYER_TURN,
    ENEMY_TURN,
    VICTORY,
    DEFEAT,
    ENEMY_ESCAPED
}

data class Combatant(
    val name: String,
    val maxHp: Int,
    val hp: Int,
    val attack: Int,
    val defense: Int,
    val mana: Int = 0,
    val maxMana: Int = mana,
    val rank: String = "E",
    val level: Int = 1,
    val danger: Int = 30,
    val xpReward: Int = 0,
    val isBoss: Boolean = false,
    val agility: Int = 5,
val magicPower: Int = 15,
val attacks: List<AtaqueCriatura> = emptyList()
) {
    val isAlive: Boolean
        get() = hp > 0
}

data class CombatState(
    val hero: Combatant,
    val enemy: Combatant,
    val phase: CombatPhase = CombatPhase.PLAYER_TURN,
    val turn: Int = 1,
    val log: List<String> = emptyList(),
    val enemyDefending: Boolean = false,
    val playerDefending: Boolean = false,
    val defenseReduction: Int = 0,
    val playerContribution: Float = 1f,
    val xpGained: Int = 0,
    val playerVulnerable: Boolean = false,
val enemyVulnerable: Boolean = false,
val pendingEffectsOnHero: List<String> = emptyList(),

// Controle de carregamento das habilidades
val carregandoHabilidadeJogador: AtaqueCriatura? = null,
val turnosRestantesCarregamentoJogador: Int = 0,

val carregandoHabilidadeInimigo: AtaqueCriatura? = null,
val turnosRestantesCarregamentoInimigo: Int = 0,
val custoManaHabilidadeInimigoCarregando: Int = 0,
val danoHabilidadeInimigoCarregando: Int = 0,
// Quebra do ataque carregado do jogador
val quebraAtaqueCarregadoJogador: Int = 0,
val quebraAtaqueCarregadoMaximaJogador: Int = 0,

// Quebra do ataque carregado do inimigo
val quebraAtaqueCarregadoInimigo: Int = 0,
val quebraAtaqueCarregadoMaximaInimigo: Int = 0,
// Controle de atordoamento
val turnosAtordoadoInimigo: Int = 0,

// Controle individual de recarga por habilidade
val recargasJogador: Map<String, Int> = emptyMap(),
val recargasInimigo: Map<String, Int> = emptyMap()
)

object CombatSystem {

    fun startCombat(
        hero: Combatant,
        enemy: Combatant
    ): CombatState {
        return CombatState(
            hero = hero,
            enemy = enemy,
            log = listOf("Combate iniciado contra ${enemy.name}!")
        )
    }

    fun playerDefend(state: CombatState): CombatState {
        if (state.phase != CombatPhase.PLAYER_TURN) return state

        val modifier = (
            (state.hero.agility - state.enemy.agility) / 3
        ).coerceIn(-3, 3)

        val dice = DiceSystem.rollD20(modifier)

        val rollLog =
            "Rolagem de defesa: ${dice.naturalRoll} + ${dice.modifier} = ${dice.total}. ${dice.description}"

        return when (dice.outcome) {

            DiceOutcome.CATASTROPHIC_FAILURE ->
                state.copy(
                    phase = CombatPhase.ENEMY_TURN,
                    playerVulnerable = true,
                    playerDefending = false,
                    defenseReduction = 0,
                    log = state.log + rollLog +
                        "Falha catastrófica! Você perdeu o equilíbrio e ficou vulnerável!"
                )

            DiceOutcome.FAILURE,
            DiceOutcome.WEAK_RESULT ->
                state.copy(
                    phase = CombatPhase.ENEMY_TURN,
                    playerDefending = false,
                    defenseReduction = 0,
                    log = state.log + rollLog +
                        "Sua defesa foi insuficiente!"
                )

            DiceOutcome.SUCCESS ->
                state.copy(
                    phase = CombatPhase.ENEMY_TURN,
                    playerDefending = true,
                    defenseReduction = 30,
                    log = state.log + rollLog +
                        "Defesa bem-sucedida! Próximo dano reduzido em 30%."
                )

            DiceOutcome.EXCEPTIONAL_SUCCESS ->
                state.copy(
                    phase = CombatPhase.ENEMY_TURN,
                    playerDefending = true,
                    defenseReduction = 50,
                    log = state.log + rollLog +
                        "Defesa excepcional! Próximo dano reduzido em 50%."
                )

            DiceOutcome.EXTRAORDINARY_SUCCESS ->
                state.copy(
                    phase = CombatPhase.ENEMY_TURN,
                    playerDefending = true,
                    defenseReduction = 75,
                    log = state.log + rollLog +
                        "DEFESA EXTRAORDINÁRIA! Próximo dano reduzido em 75%."
                )
        }
    }

    
fun playerAttack(state: CombatState): CombatState {
    if (state.phase != CombatPhase.PLAYER_TURN) return state

    val modifier = (
        (state.hero.agility - state.enemy.agility) / 3
    ).coerceIn(-3, 3)

    val dice = DiceSystem.rollD20(modifier)

    val rollLog =
        "Rolagem de ataque: ${dice.naturalRoll} + ${dice.modifier} = ${dice.total}. ${dice.description}"

    if (
        dice.outcome == DiceOutcome.CATASTROPHIC_FAILURE ||
        dice.outcome == DiceOutcome.FAILURE ||
        dice.outcome == DiceOutcome.WEAK_RESULT
    ) {
        val catastrophic =
            dice.outcome == DiceOutcome.CATASTROPHIC_FAILURE

        val consequence = if (catastrophic) {
            "Você perdeu o equilíbrio e ficou vulnerável ao inimigo!"
        } else {
            "Seu ataque não acertou o alvo!"
        }

        return state.copy(
            phase = CombatPhase.ENEMY_TURN,
            enemyDefending = false,
            playerVulnerable = state.playerVulnerable || catastrophic,
            log = state.log + rollLog + consequence
        )
    }

    var damage = (state.hero.attack - state.enemy.defense)
        .coerceAtLeast(1)

    when (dice.outcome) {
        DiceOutcome.EXCEPTIONAL_SUCCESS ->
            damage = (damage * 1.5).toInt()

        DiceOutcome.EXTRAORDINARY_SUCCESS ->
            damage *= 2

        else -> Unit
    }

    if (state.enemyDefending) {
        damage = (damage / 2).coerceAtLeast(1)
    }

    val vulnerabilityBonus = state.enemyVulnerable

    if (vulnerabilityBonus) {
        damage = (damage * 1.5).toInt().coerceAtLeast(1)
    }

    val updatedEnemy = state.enemy.copy(
        hp = (state.enemy.hp - damage).coerceAtLeast(0)
    )

    val damageLog = "${state.hero.name} causou $damage de dano!"

    val vulnerabilityLog = if (vulnerabilityBonus) {
        "Você explorou a vulnerabilidade do inimigo! Dano aumentado em 50%!"
    } else {
        ""
    }

    val resultLog = when (dice.outcome) {
        DiceOutcome.EXCEPTIONAL_SUCCESS ->
            "Ataque excepcional! Dano aumentado!"

        DiceOutcome.EXTRAORDINARY_SUCCESS ->
            "ACERTO EXTRAORDINÁRIO! Você encontrou uma abertura e causou dano devastador!"

        else -> ""
    }

    // Calcula a redução da barra de quebra separadamente do dano ao HP.
    val ataqueCarregando = state.carregandoHabilidadeInimigo

    val podeReduzirQuebra =
        ataqueCarregando?.podeSerInterrompida == true &&
        state.quebraAtaqueCarregadoInimigo > 0

    val reducaoQuebra = if (podeReduzirQuebra) {
        (damage * 25) / 100
    } else {
        0
    }

    val novaQuebra = (
        state.quebraAtaqueCarregadoInimigo - reducaoQuebra
    ).coerceAtLeast(0)

    val habilidadeInterrompida =
        podeReduzirQuebra &&
        novaQuebra == 0

    val quebraLog = when {
        habilidadeInterrompida ->
            "A Quebra do Ataque Carregado foi completada! " +
                "${state.enemy.name} teve ${ataqueCarregando?.nome} interrompida!"

        podeReduzirQuebra && reducaoQuebra > 0 ->
            "A barra de quebra do inimigo perdeu $reducaoQuebra pontos! " +
                "Restam $novaQuebra pontos!"

        else -> ""
    }

    val newLog = state.log + rollLog +
        resultLog + vulnerabilityLog + damageLog + quebraLog

    // A vitória tem prioridade: inimigo derrotado não precisa ser atordoado.
    if (!updatedEnemy.isAlive) {
        val reward = calculateVictoryXp(
            state.hero,
            updatedEnemy,
            state.playerContribution
        )

        return state.copy(
            enemy = updatedEnemy,
            enemyDefending = false,
            enemyVulnerable = false,
            carregandoHabilidadeInimigo = null,
            turnosRestantesCarregamentoInimigo = 0,
            custoManaHabilidadeInimigoCarregando = 0,
            danoHabilidadeInimigoCarregando = 0,
            quebraAtaqueCarregadoInimigo = 0,
            quebraAtaqueCarregadoMaximaInimigo = 0,
            turnosAtordoadoInimigo = 0,
            phase = CombatPhase.VICTORY,
            xpGained = reward,
            log = newLog +
                "${updatedEnemy.name} foi derrotado!" +
                "Você recebeu $reward XP!"
        )
    }

    return state.copy(
        enemy = updatedEnemy,
        enemyDefending = false,
        enemyVulnerable = false,

        quebraAtaqueCarregadoInimigo =
            if (habilidadeInterrompida) 0 else novaQuebra,

        quebraAtaqueCarregadoMaximaInimigo =
            if (habilidadeInterrompida) {
                0
            } else {
                state.quebraAtaqueCarregadoMaximaInimigo
            },

        carregandoHabilidadeInimigo =
            if (habilidadeInterrompida) {
                null
            } else {
                state.carregandoHabilidadeInimigo
            },

        turnosRestantesCarregamentoInimigo =
            if (habilidadeInterrompida) {
                0
            } else {
                state.turnosRestantesCarregamentoInimigo
            },

        custoManaHabilidadeInimigoCarregando =
            if (habilidadeInterrompida) {
                0
            } else {
                state.custoManaHabilidadeInimigoCarregando
            },

        danoHabilidadeInimigoCarregando =
            if (habilidadeInterrompida) {
                0
            } else {
                state.danoHabilidadeInimigoCarregando
            },

        turnosAtordoadoInimigo =
            if (habilidadeInterrompida) 1
            else state.turnosAtordoadoInimigo,

        phase = CombatPhase.ENEMY_TURN,
        log = newLog +
            if (habilidadeInterrompida) {
                "${state.enemy.name} ficou atordoado por 1 turno!"
            } else {
                ""
            }
    )
}


    fun enemyAttack(state: CombatState): CombatState {
        if (state.phase != CombatPhase.ENEMY_TURN) return state
            // Verifica se o inimigo está atordoado
    if (state.turnosAtordoadoInimigo > 0) {
        return state.copy(
            turnosAtordoadoInimigo =
                state.turnosAtordoadoInimigo - 1,
            phase = CombatPhase.PLAYER_TURN,
            turn = state.turn + 1,
            log = state.log +
                "${state.enemy.name} está atordoado e perdeu este turno!"
        )
    }
                // Verifica se o inimigo já está carregando uma habilidade.
        val ataqueCarregando = state.carregandoHabilidadeInimigo

        if (ataqueCarregando != null) {
            val turnosRestantes = (
                state.turnosRestantesCarregamentoInimigo - 1
            ).coerceAtLeast(0)

            // Ainda precisa carregar: devolve o turno ao jogador.
            if (turnosRestantes > 0) {
                return state.copy(
                    turnosRestantesCarregamentoInimigo = turnosRestantes,
                    phase = CombatPhase.PLAYER_TURN,
                    turn = state.turn + 1,
                    log = state.log +
                        "${state.enemy.name} continua carregando ${ataqueCarregando.nome}! " +
                        "Restam $turnosRestantes turno(s)!"
                )
            }

            // O carregamento terminou: prepara a execução.
            val danoPreparado = state.danoHabilidadeInimigoCarregando

            val logExecucao = state.log +
                "${state.enemy.name} concluiu o carregamento de ${ataqueCarregando.nome}!"

            // Limpa o carregamento antes de executar.
            val estadoLimpo = state.copy(
                carregandoHabilidadeInimigo = null,
                turnosRestantesCarregamentoInimigo = 0,
                custoManaHabilidadeInimigoCarregando = 0,
                danoHabilidadeInimigoCarregando = 0,
                quebraAtaqueCarregadoInimigo = 0,
                quebraAtaqueCarregadoMaximaInimigo = 0
            )

            // Mana já foi descontada no início do carregamento.
            return performEnemyAttack(
                estadoLimpo,
                danoPreparado,
                logExecucao,
                true,
                0
            )
        }

        val decision = WorldAI.decideMonsterAction(
            AICombatContext(
                enemyHp = state.enemy.hp,
                enemyMaxHp = state.enemy.maxHp,
                playerHp = state.hero.hp,
                playerMaxHp = state.hero.maxHp,
                enemyMana = state.enemy.mana,
                enemyManaMax = state.enemy.maxMana,
                enemyRank = state.enemy.rank,
                turn = state.turn,
                enemyAttack = state.enemy.attack,
                enemyLevel = state.enemy.level,
                danger = state.enemy.danger,
                isBoss = state.enemy.isBoss,
attacks = state.enemy.attacks
            )
        )

        val actionLog = state.log + decision.explanation

        return when (decision.action) {

            AIAction.ATTACK ->
                performEnemyAttack(
                    state,
                    decision.proposedDamage,
                    actionLog,
                    false
                )

            AIAction.SPECIAL -> {
    if (state.enemy.mana < decision.selectedManaCost) {
        performEnemyAttack(
            state,
            decision.proposedDamage,
            actionLog,
            false
        )
    } else {
        val attack = decision.selectedAttack

        if (
            attack != null &&
            decision.selectedChargeTurns > 0
        ) {
            val resistance = if (attack.podeSerInterrompida) {
                BalanceEngine.calcularResistenciaQuebra(
                    attack.multiplicador
                )
            } else {
                0
            }

            val updatedEnemy = state.enemy.copy(
                mana = (
                    state.enemy.mana -
                    decision.selectedManaCost
                ).coerceAtLeast(0)
            )

            state.copy(
                enemy = updatedEnemy,
                carregandoHabilidadeInimigo = attack,
                turnosRestantesCarregamentoInimigo =
                    decision.selectedChargeTurns,
                custoManaHabilidadeInimigoCarregando =
                    decision.selectedManaCost,
                danoHabilidadeInimigoCarregando =
                    decision.proposedDamage,
                quebraAtaqueCarregadoInimigo = resistance,
                quebraAtaqueCarregadoMaximaInimigo = resistance,
                phase = CombatPhase.PLAYER_TURN,
                turn = state.turn + 1,
                log = actionLog +
                    "${state.enemy.name} começou a carregar ${attack.nome}!" +
                    if (attack.podeSerInterrompida) {
                        " A Quebra do Ataque Carregado começou em $resistance pontos!"
                    } else {
                        " Esta habilidade não pode ser interrompida!"
                    }
            )
        } else {
            performEnemyAttack(
                state,
                decision.proposedDamage,
                actionLog,
                true,
                decision.selectedManaCost
            )
        }
    }
}

            AIAction.DEFEND ->
                state.copy(
                    phase = CombatPhase.PLAYER_TURN,
                    turn = state.turn + 1,
                    enemyDefending = true,
                    log = actionLog +
                        "${state.enemy.name} está se defendendo!"
                )

            AIAction.RETREAT ->
                state.copy(
                    phase = CombatPhase.ENEMY_ESCAPED,
                    log = actionLog +
                        "${state.enemy.name} fugiu do combate!"
                )
        }
    }

    private fun performEnemyAttack(
    state: CombatState,
    proposedDamage: Int,
    currentLog: List<String>,
    special: Boolean,
    manaCost: Int = 20
): CombatState {

        val modifier = (
            (state.enemy.agility - state.hero.agility) / 3
        ).coerceIn(-3, 3)

        val dice = DiceSystem.rollD20(modifier)

        val rollLog =
            "Rolagem do inimigo: ${dice.naturalRoll} + ${dice.modifier} = ${dice.total}. ${dice.description}"

        val updatedEnemy = if (special) {
            state.enemy.copy(
                mana = (state.enemy.mana - manaCost).coerceAtLeast(0)
            )
        } else {
            state.enemy
        }

        if (
            dice.outcome == DiceOutcome.CATASTROPHIC_FAILURE ||
            dice.outcome == DiceOutcome.FAILURE ||
            dice.outcome == DiceOutcome.WEAK_RESULT
        ) {
            val catastrophic =
                dice.outcome == DiceOutcome.CATASTROPHIC_FAILURE

            val failureMessage = if (catastrophic) {
                "${state.enemy.name} sofreu uma falha crítica e ficou vulnerável!"
            } else {
                "${state.enemy.name} errou o ataque!"
            }

            return state.copy(
                enemy = updatedEnemy,
                enemyVulnerable = state.enemyVulnerable || catastrophic,
                phase = CombatPhase.PLAYER_TURN,
                turn = state.turn + 1,
                log = currentLog + rollLog + failureMessage +
                    "Seu turno começou!"
            )
        }

        val damageAfterDefense =
            (proposedDamage - state.hero.defense).coerceAtLeast(1)

        var adjustedDamage = damageAfterDefense

        when (dice.outcome) {
            DiceOutcome.EXCEPTIONAL_SUCCESS ->
                adjustedDamage = (adjustedDamage * 1.5).toInt()

            DiceOutcome.EXTRAORDINARY_SUCCESS ->
                adjustedDamage *= 2

            else -> Unit
        }


        val vulnerabilityBonus = state.playerVulnerable

        if (vulnerabilityBonus) {
            adjustedDamage =
                (adjustedDamage * 1.5).toInt().coerceAtLeast(1)
        }

        // Aplica a redução da defesa do jogador.
        if (state.playerDefending) {
            adjustedDamage = (
                adjustedDamage *
                (100 - state.defenseReduction) / 100
            ).coerceAtLeast(1)
        }

        val balancedDamage = BalanceEngine.calculateDamage(

            proposedDamage = adjustedDamage,
            playerHp = state.hero.hp,
            playerMaxHp = state.hero.maxHp,
            danger = state.enemy.danger,
            enemyRank = state.enemy.rank,
            isBoss = state.enemy.isBoss
        )

        val damage = balancedDamage.damage

        val updatedHero = state.hero.copy(
            hp = (state.hero.hp - damage).coerceAtLeast(0)
        )

        val vulnerabilityMessage = if (vulnerabilityBonus) {
            "O inimigo explorou sua vulnerabilidade! Dano aumentado em 50%!"
        } else {
            ""
        }

        val attackMessage = if (special) {
            "${state.enemy.name} usou uma habilidade especial e causou $damage de dano!"
        } else {
            "${state.enemy.name} causou $damage de dano!"
        }

        val resultMessage = when (dice.outcome) {
            DiceOutcome.EXCEPTIONAL_SUCCESS ->
                "Ataque excepcional do inimigo! Dano aumentado!"

            DiceOutcome.EXTRAORDINARY_SUCCESS ->
                "ATAQUE EXTRAORDINÁRIO! O inimigo encontrou uma abertura devastadora!"

            else -> ""
        }

        if (!updatedHero.isAlive) {
            return state.copy(
                playerDefending = false,
                defenseReduction = 0,
                hero = updatedHero,
                enemy = updatedEnemy,
                playerVulnerable = false,
                phase = CombatPhase.DEFEAT,
                log = currentLog + rollLog +
                    resultMessage + vulnerabilityMessage +
                    attackMessage + "Você foi derrotado!"
            )
        }

        return state.copy(
            hero = updatedHero,
            enemy = updatedEnemy,
            playerVulnerable = false,
            playerDefending = false,
            defenseReduction = 0,
            phase = CombatPhase.PLAYER_TURN,
            turn = state.turn + 1,
            log = currentLog +
                rollLog +
                resultMessage +
                vulnerabilityMessage +
                attackMessage +
                balancedDamage.description +
                "Seu turno começou!"
        )
    }

    private fun calculateVictoryXp(
        hero: Combatant,
        enemy: Combatant,
        contribution: Float
    ): Int {
        return BalanceEngine.calculateXp(
            BalanceContext(
                playerLevel = hero.level,
                playerRank = hero.rank,
                enemyLevel = enemy.level,
                enemyRank = enemy.rank,
                enemyMaxHp = enemy.maxHp,
                enemyAttack = enemy.attack,
                enemyDefense = enemy.defense,
                enemyBaseXp = enemy.xpReward,
                danger = enemy.danger,
                isBoss = enemy.isBoss,
                playerContribution = contribution
            )
        ).xp
    }
}
