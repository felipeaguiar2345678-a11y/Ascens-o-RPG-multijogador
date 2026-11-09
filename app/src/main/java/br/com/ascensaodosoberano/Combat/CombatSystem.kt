
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
val attacks: List<AtaqueCriatura> = emptyList(),
    val spriteUrl: String = "",
    val aiArchetype: String = "AUTO",
    val rarity: String = "COMUM"
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
val efeitosAtivosJogador: List<CombatStatusEffect> = emptyList(),
val efeitosAtivosInimigo: List<CombatStatusEffect> = emptyList(),
val bossPhase: Int = 1,

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
val recargasInimigo: Map<String, Int> = emptyMap(),
val especialCarga: Int = 0,
val especialUsado: Boolean = false,
val turnosAtordoadoJogador: Int = 0,
val efeitoVisualAtual: String = ""
)

object SkillDamageCalculator {
    fun powerFor(hero: Combatant, skill: AtaqueCriatura): Int =
        if (skill.tipoDano.equals("MAGICO", ignoreCase = true) ||
            skill.tipoDano.equals("MÁGICO", ignoreCase = true)
        ) hero.magicPower else hero.attack

    fun estimatedDamage(hero: Combatant, skill: AtaqueCriatura): Int =
        (skill.danoBase.coerceAtLeast(0) +
            powerFor(hero, skill).coerceAtLeast(0) * skill.multiplicador.coerceAtLeast(0f))
            .toInt().coerceAtLeast(1)
}

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

    fun playerDefend(input: CombatState): CombatState {
        if (input.phase != CombatPhase.PLAYER_TURN) return input
        val state = tickHeroEffects(input)
        if (state.phase != CombatPhase.PLAYER_TURN) return state
        if (state.turnosAtordoadoJogador > 0) return state.copy(
            turnosAtordoadoJogador = (state.turnosAtordoadoJogador - 1).coerceAtLeast(0),
            phase = CombatPhase.ENEMY_TURN,
            turn = state.turn + 1,
            log = state.log + "Você está atordoado e perdeu sua ação."
        )

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
                    especialCarga = (state.especialCarga + 10).coerceAtMost(100),
                    log = state.log + rollLog +
                        "Defesa bem-sucedida! Próximo dano reduzido em 30%."
                )

            DiceOutcome.EXCEPTIONAL_SUCCESS ->
                state.copy(
                    phase = CombatPhase.ENEMY_TURN,
                    playerDefending = true,
                    defenseReduction = 50,
                    especialCarga = (state.especialCarga + 15).coerceAtMost(100),
                    log = state.log + rollLog +
                        "Defesa excepcional! Próximo dano reduzido em 50%."
                )

            DiceOutcome.EXTRAORDINARY_SUCCESS ->
                state.copy(
                    phase = CombatPhase.ENEMY_TURN,
                    playerDefending = true,
                    defenseReduction = 75,
                    especialCarga = (state.especialCarga + 20).coerceAtMost(100),
                    log = state.log + rollLog +
                        "DEFESA EXTRAORDINÁRIA! Próximo dano reduzido em 75%."
                )
        }
    }

    
fun playerAttack(input: CombatState): CombatState {
    if (input.phase != CombatPhase.PLAYER_TURN) return input
    val state = tickHeroEffects(input)
    if (state.phase != CombatPhase.PLAYER_TURN) return state
    if (state.turnosAtordoadoJogador > 0) {
        return state.copy(
            turnosAtordoadoJogador = (state.turnosAtordoadoJogador - 1).coerceAtLeast(0),
            phase = CombatPhase.ENEMY_TURN,
            turn = state.turn + 1,
            log = state.log + "Você está atordoado e perdeu sua ação."
        )
    }
    if (state.carregandoHabilidadeJogador != null) return state.copy(log = state.log + "Conclua ou libere a habilidade carregada antes de agir.")

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
        especialCarga = (state.especialCarga + 20).coerceAtMost(100),

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



    fun playerUseSkill(input: CombatState, skillId: String): CombatState {
        if (input.phase != CombatPhase.PLAYER_TURN) return input
        val state = tickHeroEffects(input)
        if (state.phase != CombatPhase.PLAYER_TURN) return state
        consumeHeroTurnIfStunned(state)?.let { return it }
        if (state.carregandoHabilidadeJogador != null) return state
        val skill = state.hero.attacks.firstOrNull { it.id == skillId } ?: return state
        if ((state.recargasJogador[skill.id] ?: 0) > 0) return state.copy(log = state.log + "${skill.nome} ainda está em recarga.")
        val manaCost = skill.custoMana.coerceAtLeast(0)
        if (state.hero.mana < manaCost) return state.copy(log = state.log + "Mana insuficiente para ${skill.nome}.")
        val cooldowns = state.recargasJogador + (skill.id to (skill.turnosRecarga.coerceAtLeast(0) + 1))
        val hero = state.hero.copy(mana = (state.hero.mana - manaCost).coerceAtLeast(0))
        val baseDamage = SkillDamageCalculator.estimatedDamage(hero, skill)
        if (skill.turnosCarregamento > 0) {
            val breakMax = if (skill.podeSerInterrompida) {
                BalanceEngine.calcularResistenciaQuebra(skill.multiplicador)
            } else 0
            return state.copy(
                hero = hero, carregandoHabilidadeJogador = skill,
                turnosRestantesCarregamentoJogador = skill.turnosCarregamento.coerceAtMost(2),
                quebraAtaqueCarregadoJogador = breakMax,
                quebraAtaqueCarregadoMaximaJogador = breakMax,
                recargasJogador = cooldowns, phase = CombatPhase.ENEMY_TURN,
                efeitoVisualAtual = "CARREGANDO",
                log = state.log + "${hero.name} começou a carregar ${skill.nome}."
            )
        }
        return resolvePlayerSkill(state.copy(hero = hero, recargasJogador = cooldowns), skill, baseDamage, false)
    }

    fun playerContinueCharge(input: CombatState): CombatState {
        if (input.phase != CombatPhase.PLAYER_TURN) return input
        val state = tickHeroEffects(input)
        if (state.phase != CombatPhase.PLAYER_TURN || state.carregandoHabilidadeJogador == null) return state
        consumeHeroTurnIfStunned(state)?.let { return it }
        val remaining = (state.turnosRestantesCarregamentoJogador - 1).coerceAtLeast(0)
        return state.copy(
            turnosRestantesCarregamentoJogador = remaining,
            phase = CombatPhase.ENEMY_TURN,
            efeitoVisualAtual = "CARREGANDO",
            log = state.log + if (remaining == 0) "O carregamento foi concluído. Prepare-se para liberar o ataque!" else "Você continua concentrando energia. Restam $remaining turno(s)."
        )
    }

    fun playerReleaseChargedSkill(input: CombatState): CombatState {
        if (input.phase != CombatPhase.PLAYER_TURN) return input
        val state = tickHeroEffects(input)
        if (state.phase != CombatPhase.PLAYER_TURN) return state
        consumeHeroTurnIfStunned(state)?.let { return it }
        val skill = state.carregandoHabilidadeJogador ?: return state
        if (state.phase != CombatPhase.PLAYER_TURN || state.turnosRestantesCarregamentoJogador > 0) return state
        val baseDamage = SkillDamageCalculator.estimatedDamage(state.hero, skill)
        val cleared = state.copy(
            carregandoHabilidadeJogador = null,
            turnosRestantesCarregamentoJogador = 0,
            quebraAtaqueCarregadoJogador = 0,
            quebraAtaqueCarregadoMaximaJogador = 0
        )
        return resolvePlayerSkill(cleared, skill, baseDamage, true)
    }

    private fun resolvePlayerSkill(state: CombatState, skill: AtaqueCriatura, baseDamage: Int, charged: Boolean): CombatState {
        val dice = DiceSystem.rollD20(((state.hero.agility - state.enemy.agility) / 3).coerceIn(-3, 3))
        if (dice.outcome == DiceOutcome.CATASTROPHIC_FAILURE || dice.outcome == DiceOutcome.FAILURE || dice.outcome == DiceOutcome.WEAK_RESULT) {
            return state.copy(
                phase = CombatPhase.ENEMY_TURN,
                playerVulnerable = dice.outcome == DiceOutcome.CATASTROPHIC_FAILURE,
                efeitoVisualAtual = "FALHA",
                log = state.log + "${skill.nome}: ${dice.description}. A habilidade não acertou."
            )
        }
        var damage = (baseDamage - state.enemy.defense).coerceAtLeast(1)
        if (dice.outcome == DiceOutcome.EXCEPTIONAL_SUCCESS) damage = (damage * 1.5f).toInt()
        if (dice.outcome == DiceOutcome.EXTRAORDINARY_SUCCESS) damage *= 2
        if (state.enemyDefending) damage = (damage / 2).coerceAtLeast(1)
        if (state.enemyVulnerable) damage = (damage * 1.5f).toInt().coerceAtLeast(1)
        val updatedEnemy = state.enemy.copy(hp = (state.enemy.hp - damage).coerceAtLeast(0))
        val inflictedDot = CombatStatusEngine.fromSkill(
            skill.efeitos, skill.duracaoTurnos, state.enemy.maxHp
        )
        val activeEnemyEffects = CombatStatusEngine.merge(
            state.efeitosAtivosInimigo, inflictedDot
        )
        val appliesEnemyStun = skill.efeitos.any { it.contains("ATORD", true) || it.contains("STUN", true) }
        val appliesEnemyVulnerability = skill.efeitos.any { it.contains("VULNER", true) }
        val breakDamage = (skill.danoQuebra.takeIf { it > 0 } ?: (damage * if (skill.categoria == "DEVASTADOR") 0.8f else 0.45f).toInt()).coerceAtLeast(1)
        val breakNow = if (state.carregandoHabilidadeInimigo != null && skill.podeSerInterrompida) (state.quebraAtaqueCarregadoInimigo - breakDamage).coerceAtLeast(0) else state.quebraAtaqueCarregadoInimigo
        val interrupted = state.carregandoHabilidadeInimigo != null && skill.podeSerInterrompida && breakNow == 0
        val defeated = !updatedEnemy.isAlive
        val reward = if (defeated) calculateVictoryXp(state.hero, updatedEnemy, state.playerContribution) else 0
        return state.copy(
            enemy = updatedEnemy,
            enemyDefending = false,
            enemyVulnerable = appliesEnemyVulnerability,
            efeitosAtivosInimigo = activeEnemyEffects,
            especialCarga = (state.especialCarga + 12 + if (charged) 8 else 0).coerceAtMost(100),
            carregandoHabilidadeInimigo = if (interrupted) null else state.carregandoHabilidadeInimigo,
            turnosRestantesCarregamentoInimigo = if (interrupted) 0 else state.turnosRestantesCarregamentoInimigo,
            quebraAtaqueCarregadoInimigo = if (interrupted) 0 else breakNow,
            quebraAtaqueCarregadoMaximaInimigo = if (interrupted) 0 else state.quebraAtaqueCarregadoMaximaInimigo,
            danoHabilidadeInimigoCarregando = if (interrupted) 0 else state.danoHabilidadeInimigoCarregando,
            custoManaHabilidadeInimigoCarregando = if (interrupted) 0 else state.custoManaHabilidadeInimigoCarregando,
            turnosAtordoadoInimigo = when {
                appliesEnemyStun -> maxOf(state.turnosAtordoadoInimigo, 1)
                interrupted && skill.categoria == "DEVASTADOR" -> 2
                interrupted -> 1
                else -> state.turnosAtordoadoInimigo
            },
            phase = if (defeated) CombatPhase.VICTORY else CombatPhase.ENEMY_TURN,
            xpGained = reward,
            efeitoVisualAtual = skill.elemento.uppercase(),
            log = state.log + "${state.hero.name} usou ${skill.nome} e causou $damage de dano!" +
                (if (inflictedDot.isNotEmpty()) " Efeito aplicado: ${inflictedDot.joinToString { it.type }}." else "") +
                (if (appliesEnemyStun) " A criatura foi atordoada!" else "") +
                (if (interrupted) " O ataque carregado do inimigo foi interrompido!" else "") +
                (if (defeated) " ${updatedEnemy.name} foi derrotado! Você recebeu $reward XP." else "")
        )
    }

    fun playerSpecial(input: CombatState): CombatState {
        if (input.phase != CombatPhase.PLAYER_TURN) return input
        val state = tickHeroEffects(input)
        if (state.phase != CombatPhase.PLAYER_TURN || state.especialUsado || state.especialCarga < 100) return state
        consumeHeroTurnIfStunned(state)?.let { return it }
        val strongest = state.hero.attacks.sortedByDescending { it.danoBase * it.multiplicador }.take(2)
        val first = strongest.getOrNull(0)
        val second = strongest.getOrNull(1)
        val firstPower = first?.let { SkillDamageCalculator.estimatedDamage(state.hero, it).toFloat() }
            ?: state.hero.attack.toFloat()
        val secondPower = second?.let { SkillDamageCalculator.estimatedDamage(state.hero, it).toFloat() }
            ?: firstPower
        val averageBase = if (second != null) ((firstPower + secondPower) / 2f).toInt() else firstPower.toInt()
        val blended = AtaqueCriatura(
            id = "especial_supremo", nome = "Ressonância Suprema",
            descricao = "Combinação das duas habilidades mais poderosas.",
            tipoDano = "MAGICO",
            elemento = listOfNotNull(first?.elemento, second?.elemento).distinct().joinToString("+").ifBlank { "NEUTRO" },
            danoBase = averageBase.coerceAtLeast(1),
            multiplicador = 1f,
            efeitos = (first?.efeitos.orEmpty() + second?.efeitos.orEmpty()).distinct(),
            podeSerInterrompida = false,
            categoria = "DEVASTADOR"
        )
        val prepared = state.copy(especialUsado = true, especialCarga = 0, efeitoVisualAtual = "RESSONANCIA")
        return resolvePlayerSkill(prepared, blended, blended.danoBase, true)
    }

    private fun tickPlayerCooldowns(state: CombatState): Map<String, Int> =
        state.recargasJogador.mapValues { (_, turns) -> (turns - 1).coerceAtLeast(0) }.filterValues { it > 0 }

    private fun tickEnemyCooldowns(state: CombatState): Map<String, Int> =
        state.recargasInimigo.mapValues { (_, turns) -> (turns - 1).coerceAtLeast(0) }.filterValues { it > 0 }

    fun enemyAttack(input: CombatState): CombatState {
        if (input.phase != CombatPhase.ENEMY_TURN) return input
        var state = input.copy(
            recargasInimigo = tickEnemyCooldowns(input),
            recargasJogador = tickPlayerCooldowns(input)
        )
        state = tickEnemyEffects(state)
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
                0,
                attackEffects = ataqueCarregando.efeitos,
                effectDuration = ataqueCarregando.duracaoTurnos
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
attacks = state.enemy.attacks,
                attackCooldowns = state.recargasInimigo,
                enemyDefense = state.enemy.defense,
                enemyAgility = state.enemy.agility,
                enemyMagicPower = state.enemy.magicPower,
                playerDefense = state.hero.defense,
                enemyArchetype = state.enemy.aiArchetype,
                enemyRarity = state.enemy.rarity,
                heroDefending = state.playerDefending,
                heroVulnerable = state.playerVulnerable,
                enemyVulnerable = state.enemyVulnerable
            )
        )

        state = applyBossPhase(state, decision.bossPhase)
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
                recargasInimigo = state.recargasInimigo + (attack.id to (attack.turnosRecarga.coerceAtLeast(0) + 1)),
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
                state.copy(
                    recargasInimigo = if (decision.selectedAttack != null)
                        state.recargasInimigo + (decision.selectedAttack.id to (decision.selectedAttack.turnosRecarga.coerceAtLeast(0) + 1))
                    else state.recargasInimigo
                ),
                decision.proposedDamage,
                actionLog,
                true,
                decision.selectedManaCost,
                attackEffects = decision.selectedAttack?.efeitos.orEmpty(),
                effectDuration = decision.selectedAttack?.duracaoTurnos ?: 0
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
    manaCost: Int = 20,
    attackEffects: List<String> = emptyList(),
    effectDuration: Int = 0
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
        val inflictedDot = CombatStatusEngine.fromSkill(
            attackEffects, effectDuration, state.hero.maxHp
        )
        val activeHeroEffects = CombatStatusEngine.merge(
            state.efeitosAtivosJogador, inflictedDot
        )
        val appliesStun = attackEffects.any { it.contains("ATORD", true) || it.contains("STUN", true) }
        val appliesVulnerability = attackEffects.any { it.contains("VULNER", true) }
        val playerChargeBreak = if (
            state.carregandoHabilidadeJogador?.podeSerInterrompida == true &&
            state.quebraAtaqueCarregadoJogador > 0
        ) (state.quebraAtaqueCarregadoJogador - (damage * 25 / 100).coerceAtLeast(1)).coerceAtLeast(0)
        else state.quebraAtaqueCarregadoJogador
        val playerChargeInterrupted =
            state.carregandoHabilidadeJogador?.podeSerInterrompida == true &&
                state.quebraAtaqueCarregadoJogador > 0 && playerChargeBreak == 0

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
                playerVulnerable = appliesVulnerability,
                efeitosAtivosJogador = activeHeroEffects,
                pendingEffectsOnHero = activeHeroEffects.map { it.type },
                carregandoHabilidadeJogador = null,
                turnosRestantesCarregamentoJogador = 0,
                quebraAtaqueCarregadoJogador = 0,
                quebraAtaqueCarregadoMaximaJogador = 0,
                phase = CombatPhase.DEFEAT,
                log = currentLog + rollLog +
                    resultMessage + vulnerabilityMessage +
                    attackMessage + "Você foi derrotado!"
            )
        }

        return state.copy(
            hero = updatedHero,
            enemy = updatedEnemy,
            playerVulnerable = appliesVulnerability,
            efeitosAtivosJogador = activeHeroEffects,
            pendingEffectsOnHero = activeHeroEffects.map { it.type },
            playerDefending = false,
            defenseReduction = 0,
            carregandoHabilidadeJogador = if (playerChargeInterrupted) null else state.carregandoHabilidadeJogador,
            turnosRestantesCarregamentoJogador = if (playerChargeInterrupted) 0 else state.turnosRestantesCarregamentoJogador,
            quebraAtaqueCarregadoJogador = if (playerChargeInterrupted) 0 else playerChargeBreak,
            quebraAtaqueCarregadoMaximaJogador = if (playerChargeInterrupted) 0 else state.quebraAtaqueCarregadoMaximaJogador,
            turnosAtordoadoJogador = when {
                appliesStun -> maxOf(state.turnosAtordoadoJogador, 1)
                playerChargeInterrupted && (state.enemy.isBoss || state.enemy.rank in listOf("S", "SS", "SSS") || damage >= state.hero.maxHp / 4) -> 2
                playerChargeInterrupted -> 1
                else -> state.turnosAtordoadoJogador
            },
            especialCarga = (state.especialCarga + (damage * 100 / state.hero.maxHp.coerceAtLeast(1)).coerceAtLeast(3)).coerceAtMost(100),
            efeitoVisualAtual = if (playerChargeInterrupted) "INTERRUPCAO" else if (special) "IMPACTO" else "DANO",
            phase = CombatPhase.PLAYER_TURN,
            turn = state.turn + 1,
            log = currentLog +
                rollLog +
                resultMessage +
                vulnerabilityMessage +
                attackMessage +
                balancedDamage.description +
                (if (inflictedDot.isNotEmpty()) " Efeito aplicado: ${inflictedDot.joinToString { it.type }}." else "") +
                (if (appliesStun) " Você foi atordoado!" else "") +
                (if (playerChargeInterrupted) " Seu carregamento foi interrompido e você ficou atordoado!" else "") +
                "Seu turno começou!"
        )
    }


    private fun consumeHeroTurnIfStunned(state: CombatState): CombatState? {
        if (state.turnosAtordoadoJogador <= 0) return null
        return state.copy(
            turnosAtordoadoJogador = (state.turnosAtordoadoJogador - 1).coerceAtLeast(0),
            phase = CombatPhase.ENEMY_TURN,
            turn = state.turn + 1,
            log = state.log + "Você está atordoado e perdeu sua ação."
        )
    }

    private fun tickHeroEffects(input: CombatState): CombatState {
        if (input.efeitosAtivosJogador.isEmpty()) return input
        val tick = CombatStatusEngine.tick(input.efeitosAtivosJogador)
        val hero = input.hero.copy(hp = (input.hero.hp - tick.damage).coerceAtLeast(0))
        val message = if (tick.damage > 0) "Os efeitos ativos causaram ${tick.damage} de dano em você." else ""
        val expired = if (tick.expiredTypes.isNotEmpty()) " Efeito encerrado: ${tick.expiredTypes.joinToString()}." else ""
        val updated = input.copy(
            hero = hero,
            efeitosAtivosJogador = tick.remainingEffects,
            pendingEffectsOnHero = tick.remainingEffects.map { it.type },
            log = input.log + listOf(message + expired).filter { it.isNotBlank() }
        )
        return if (!hero.isAlive) updated.copy(
            phase = CombatPhase.DEFEAT,
            carregandoHabilidadeJogador = null,
            turnosRestantesCarregamentoJogador = 0,
            log = updated.log + "Você foi derrotado pelos efeitos persistentes!"
        ) else updated
    }

    private fun tickEnemyEffects(input: CombatState): CombatState {
        if (input.efeitosAtivosInimigo.isEmpty()) return input
        val tick = CombatStatusEngine.tick(input.efeitosAtivosInimigo)
        val enemy = input.enemy.copy(hp = (input.enemy.hp - tick.damage).coerceAtLeast(0))
        val message = if (tick.damage > 0) "Os efeitos ativos causaram ${tick.damage} de dano em ${enemy.name}." else ""
        val expired = if (tick.expiredTypes.isNotEmpty()) " Efeito encerrado: ${tick.expiredTypes.joinToString()}." else ""
        val updated = input.copy(
            enemy = enemy,
            efeitosAtivosInimigo = tick.remainingEffects,
            log = input.log + listOf(message + expired).filter { it.isNotBlank() }
        )
        if (enemy.isAlive) return updated
        val reward = calculateVictoryXp(updated.hero, enemy, updated.playerContribution)
        return updated.copy(
            phase = CombatPhase.VICTORY,
            xpGained = reward,
            carregandoHabilidadeInimigo = null,
            turnosRestantesCarregamentoInimigo = 0,
            log = updated.log + "${enemy.name} foi derrotado pelos efeitos persistentes! Você recebeu $reward XP."
        )
    }

    private fun applyBossPhase(input: CombatState, targetPhase: Int): CombatState {
        if (!input.enemy.isBoss || targetPhase <= input.bossPhase) return input
        val oldAttack = when (input.bossPhase.coerceIn(1, 3)) { 1 -> 1f; 2 -> 1.12f; else -> 1.28f }
        val newAttack = when (targetPhase.coerceIn(1, 3)) { 1 -> 1f; 2 -> 1.12f; else -> 1.28f }
        val oldDefense = when (input.bossPhase.coerceIn(1, 3)) { 1 -> 1f; 2 -> 1.08f; else -> 1.16f }
        val newDefense = when (targetPhase.coerceIn(1, 3)) { 1 -> 1f; 2 -> 1.08f; else -> 1.16f }
        val oldMagic = when (input.bossPhase.coerceIn(1, 3)) { 1 -> 1f; 2 -> 1.15f; else -> 1.30f }
        val newMagic = when (targetPhase.coerceIn(1, 3)) { 1 -> 1f; 2 -> 1.15f; else -> 1.30f }
        val enemy = input.enemy.copy(
            attack = (input.enemy.attack * newAttack / oldAttack).toInt().coerceAtLeast(1),
            defense = (input.enemy.defense * newDefense / oldDefense).toInt().coerceAtLeast(0),
            agility = (input.enemy.agility * newAttack / oldAttack).toInt().coerceAtLeast(1),
            magicPower = (input.enemy.magicPower * newMagic / oldMagic).toInt().coerceAtLeast(1),
            mana = (input.enemy.mana + (input.enemy.maxMana * 0.12f).toInt()).coerceAtMost(input.enemy.maxMana)
        )
        val phaseName = if (targetPhase == 2) "segunda fase" else "fase final"
        return input.copy(
            enemy = enemy,
            bossPhase = targetPhase,
            log = input.log + "${enemy.name} entrou na $phaseName! Seus atributos aumentaram e parte de sua mana foi restaurada."
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
