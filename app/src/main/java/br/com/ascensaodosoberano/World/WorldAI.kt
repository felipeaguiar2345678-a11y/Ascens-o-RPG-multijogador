package br.com.ascensaodosoberano.world

import kotlin.math.roundToInt
import kotlin.random.Random

enum class AIAction { ATTACK, DEFEND, SPECIAL, RETREAT }

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
    val attackCooldowns: Map<String, Int> = emptyMap(),
    val enemyDefense: Int = 0,
    val enemyAgility: Int = 0,
    val enemyMagicPower: Int = 0,
    val playerDefense: Int = 0,
    val enemyArchetype: String = "AUTO",
    val enemyRarity: String = "COMUM",
    val heroDefending: Boolean = false,
    val heroVulnerable: Boolean = false,
    val enemyVulnerable: Boolean = false
)

data class AICombatDecision(
    val action: AIAction,
    val explanation: String,
    val proposedDamage: Int = 0,
    val selectedAttack: AtaqueCriatura? = null,
    val selectedManaCost: Int = 0,
    val selectedChargeTurns: Int = 0,
    val bossPhase: Int = 1
)

object WorldAI {
    private data class SkillCandidate(
        val skill: AtaqueCriatura,
        val manaCost: Int,
        val expectedDamage: Int,
        val tacticalScore: Float
    )

    private fun manaRange(attack: AtaqueCriatura): Pair<Int, Int> {
        val base = attack.custoMana.coerceAtLeast(0)
        val minimum = attack.custoManaMinimo.coerceAtLeast(0)
        val maximum = attack.custoManaMaximo.coerceAtLeast(0)
        if (minimum == 0 && maximum == 0) return base to base
        if (minimum == 0) return base.coerceAtMost(maximum) to maximum
        if (maximum == 0) return minimum to maxOf(minimum, base)
        return minimum to maxOf(minimum, maximum)
    }

    private fun defaultManaRange(attack: AtaqueCriatura): Pair<Int, Int> {
        if (attack.tipoDano.equals("FISICO", true) &&
            attack.elemento.equals("NEUTRO", true) && attack.efeitos.isEmpty()
        ) return 0 to 0
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

    private fun manaCostRange(attack: AtaqueCriatura): Pair<Int, Int> {
        val custom = attack.custoMana > 0 ||
            attack.custoManaMinimo > 0 || attack.custoManaMaximo > 0
        return if (custom) manaRange(attack) else defaultManaRange(attack)
    }

    fun inferArchetype(creature: CriaturaGerada): String {
        val effects = creature.ataques.flatMap { it.efeitos }
            .joinToString(" ").uppercase()
        return when {
            creature.chefe -> "CHEFE"
            listOf("VENENO", "ENVENEN", "TOXINA").any { it in effects } -> "VENENOSO"
            creature.poderMagico > creature.ataque * 1.25f -> "ARCANO"
            creature.agilidade > creature.defesa * 1.5f -> "VELOZ"
            creature.defesa > creature.ataque * 1.2f -> "DEFENSOR"
            creature.ataque > creature.defesa * 1.5f -> "BRUTAMONTES"
            else -> "EQUILIBRADO"
        }
    }

    private fun resolveArchetype(context: AICombatContext): String {
        if (context.enemyArchetype != "AUTO") return context.enemyArchetype.uppercase()
        return when {
            context.isBoss -> "CHEFE"
            context.enemyMagicPower > context.enemyAttack * 1.25f -> "ARCANO"
            context.enemyAgility > context.enemyDefense * 1.5f -> "VELOZ"
            context.enemyDefense > context.enemyAttack * 1.2f -> "DEFENSOR"
            context.enemyAttack > context.enemyDefense * 1.5f -> "BRUTAMONTES"
            else -> "EQUILIBRADO"
        }
    }

    private fun stableRoll(context: AICombatContext, salt: Int): Int {
        val seed = context.turn * 7919 + context.enemyHp * 31 +
            context.playerHp * 17 + context.enemyLevel * 13 + salt
        return Random(seed).nextInt(100)
    }

    private fun skillCandidates(context: AICombatContext): List<SkillCandidate> {
        return context.attacks.mapNotNull { skill ->
            if (skill.id.isBlank() || skill.chanceUso <= 0) return@mapNotNull null
            if ((context.attackCooldowns[skill.id] ?: 0) > 0) return@mapNotNull null
            val range = manaCostRange(skill)
            val minimum = range.first.coerceAtLeast(0)
            val maximum = range.second.coerceAtLeast(minimum)
            if (context.enemyMana < minimum) return@mapNotNull null
            val affordableMax = maximum.coerceAtMost(context.enemyMana)
            if (stableRoll(context, skill.id.hashCode()) >= skill.chanceUso.coerceIn(0, 100)) {
                return@mapNotNull null
            }
            val cost = if (affordableMax <= minimum) minimum else minimum +
                stableRoll(context, skill.id.hashCode() xor 0x51) % (affordableMax - minimum + 1)

            val magical = skill.tipoDano.contains("MAG", ignoreCase = true)
            val relevantPower = if (magical) context.enemyMagicPower else context.enemyAttack
            val raw = (skill.danoBase.coerceAtLeast(0) +
                relevantPower.coerceAtLeast(0) * skill.multiplicador.coerceAtLeast(0f))
                .roundToInt().coerceAtLeast(1)
            val effectBonus = skill.efeitos.sumOf { effect ->
                when {
                    effect.contains("ATORD", true) -> 0.22
                    effect.contains("VENEN", true) || effect.contains("QUEIM", true) -> 0.18
                    effect.contains("VULNER", true) -> 0.16
                    effect.contains("SANGR", true) -> 0.14
                    else -> 0.04
                }
            }.coerceAtMost(0.45)
            val chargePenalty = skill.turnosCarregamento.coerceIn(0, 2) * 0.22
            val guardBreakBonus = if (context.heroDefending &&
                (magical || skill.efeitos.isNotEmpty())) 0.18 else 0.0
            val score = raw * (1.0 + effectBonus + guardBreakBonus) * (1.0 - chargePenalty)
            SkillCandidate(skill, cost, raw, score.toFloat())
        }
    }

    fun decideMonsterAction(context: AICombatContext): AICombatDecision {
        val enemyRatio = context.enemyHp.coerceAtLeast(0).toFloat() /
            context.enemyMaxHp.coerceAtLeast(1)
        val playerRatio = context.playerHp.coerceAtLeast(0).toFloat() /
            context.playerMaxHp.coerceAtLeast(1)
        val danger = context.danger.coerceIn(1, 100)
        val archetype = resolveArchetype(context)
        val bossPhase = if (!context.isBoss) 1 else when {
            enemyRatio <= 0.33f -> 3
            enemyRatio <= 0.66f -> 2
            else -> 1
        }

        val candidates = skillCandidates(context)
        val chosen = candidates.maxByOrNull { it.tacticalScore }
        val fallbackSpecial = context.attacks.isEmpty() && context.enemyMana >= 20
        val canUseSpecial = chosen != null || fallbackSpecial
        val basicDamage = context.enemyAttack.coerceAtLeast(1)
        val specialDamage = chosen?.expectedDamage
            ?: if (fallbackSpecial) (basicDamage * 1.55f).roundToInt() else 0

        var attackScore = 44f
        var defendScore = 17f
        var specialScore = if (canUseSpecial) 40f else -100f
        var retreatScore = -100f

        when (archetype) {
            "BRUTAMONTES" -> attackScore += 10f
            "VELOZ" -> attackScore += 7f
            "ARCANO" -> specialScore += 8f
            "VENENOSO" -> specialScore += 10f
            "DEFENSOR" -> defendScore += 13f
            "PREDADOR" -> attackScore += 8f
        }
        if (context.heroVulnerable) attackScore += 20f
        if (context.enemyVulnerable) attackScore += 8f
        if (context.heroDefending) {
            attackScore -= 7f
            if (chosen?.skill?.efeitos?.isNotEmpty() == true) specialScore += 13f
        }
        if (enemyRatio <= 0.35f) defendScore += 28f + (0.35f - enemyRatio) * 45f
        if (enemyRatio <= 0.18f && !context.isBoss) {
            retreatScore = 52f + (0.18f - enemyRatio) * 180f
        }
        if (playerRatio <= 0.25f) attackScore += 9f

        if (canUseSpecial && chosen != null) {
            val advantage = (chosen.tacticalScore / basicDamage - 1f).coerceIn(-0.5f, 1.5f)
            specialScore += advantage * 22f + (danger / 100f) * 5f
            if (chosen.skill.turnosCarregamento > 0) specialScore -= 8f
        } else if (fallbackSpecial) {
            specialScore += 8f
        }

        if (context.isBoss) {
            retreatScore = -100f
            specialScore += when (bossPhase) {
                3 -> 18f
                2 -> 10f
                else -> 4f
            }
            if (bossPhase >= 2) attackScore += 5f
            if (bossPhase == 3) defendScore += 5f
        }

        attackScore += stableRoll(context, 101) / 100f * 3f
        defendScore += stableRoll(context, 202) / 100f * 3f
        specialScore += stableRoll(context, 303) / 100f * 3f

        val action = listOf(
            AIAction.ATTACK to attackScore,
            AIAction.DEFEND to defendScore,
            AIAction.SPECIAL to specialScore,
            AIAction.RETREAT to retreatScore
        ).maxByOrNull { it.second }?.first ?: AIAction.ATTACK

        val selectedAttack = if (action == AIAction.SPECIAL) chosen?.skill else null
        val manaCost = if (action == AIAction.SPECIAL) chosen?.manaCost ?: 20 else 0
        val proposedDamage = when (action) {
            AIAction.ATTACK -> basicDamage
            AIAction.SPECIAL -> specialDamage
            else -> 0
        }

        val phaseMessage = if (!context.isBoss) "" else when (bossPhase) {
            3 -> "O chefe está em sua fase final e luta sem reservas."
            2 -> "O chefe entrou em uma nova fase e intensificou seus ataques."
            else -> "O chefe observa seus movimentos e prepara sua estratégia."
        }
        val explanation = when (action) {
            AIAction.ATTACK -> when {
                context.heroVulnerable -> "A criatura percebeu sua abertura e avançou para puni-la!"
                context.heroDefending -> "A criatura tentou contornar sua guarda com um ataque calculado."
                archetype == "VELOZ" -> "A criatura veloz atacou antes que você pudesse reagir."
                archetype == "BRUTAMONTES" -> "A criatura concentrou sua força em um golpe pesado."
                else -> "A criatura avaliou a situação e escolheu atacar."
            }
            AIAction.DEFEND -> "A criatura recuou para uma postura defensiva e protegeu seus pontos vitais."
            AIAction.SPECIAL -> if (selectedAttack != null) {
                "A criatura escolheu ${selectedAttack.nome} para explorar sua estratégia."
            } else "A criatura concentrou energia e preparou um ataque especial."
            AIAction.RETREAT -> "Ferida e em desvantagem, a criatura decidiu fugir para sobreviver."
        }

        return AICombatDecision(
            action = action,
            explanation = listOf(phaseMessage, explanation).filter { it.isNotBlank() }.joinToString(" "),
            proposedDamage = proposedDamage,
            selectedAttack = selectedAttack,
            selectedManaCost = manaCost,
            selectedChargeTurns = selectedAttack?.turnosCarregamento?.coerceIn(0, 2) ?: 0,
            bossPhase = bossPhase
        )
    }

    fun generateWorldReaction(regionName: String, dangerLevel: Int): String {
        return when {
            dangerLevel >= 90 -> "Uma presença aterradora altera a atmosfera de $regionName."
            dangerLevel >= 60 -> "Movimentos estranhos são percebidos em $regionName."
            dangerLevel >= 30 -> "A região $regionName apresenta sinais de atividade."
            else -> "A região $regionName permanece relativamente tranquila."
        }
    }
}
