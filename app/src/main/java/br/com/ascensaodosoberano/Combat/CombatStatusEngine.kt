package br.com.ascensaodosoberano.combat

data class CombatStatusEffect(
    val type: String,
    val turnsRemaining: Int,
    val damagePerTurn: Int
)

data class CombatStatusTick(
    val damage: Int,
    val remainingEffects: List<CombatStatusEffect>,
    val expiredTypes: List<String>
)

/** Efeitos persistentes de combate, separados da lógica de interface. */
object CombatStatusEngine {

    fun fromSkill(
        effects: List<String>,
        durationTurns: Int,
        targetMaxHp: Int
    ): List<CombatStatusEffect> {
        val duration = durationTurns.coerceIn(1, 5)
        val maxHp = targetMaxHp.coerceAtLeast(1)
        return effects.mapNotNull { raw ->
            val normalized = raw.trim().uppercase()
            when {
                normalized.contains("VENEN") || normalized.contains("TOXINA") ->
                    CombatStatusEffect("ENVENENAMENTO", duration, (maxHp * 0.035f).toInt().coerceAtLeast(1))
                normalized.contains("QUEIM") || normalized.contains("INCEND") ->
                    CombatStatusEffect("QUEIMADURA", duration, (maxHp * 0.04f).toInt().coerceAtLeast(1))
                normalized.contains("SANGR") || normalized.contains("HEMORR") ->
                    CombatStatusEffect("SANGRAMENTO", duration, (maxHp * 0.03f).toInt().coerceAtLeast(1))
                else -> null
            }
        }.distinctBy { it.type }
    }

    fun merge(
        current: List<CombatStatusEffect>,
        incoming: List<CombatStatusEffect>
    ): List<CombatStatusEffect> {
        return (current + incoming)
            .groupBy { it.type }
            .map { (type, effects) ->
                CombatStatusEffect(
                    type = type,
                    turnsRemaining = effects.maxOf { it.turnsRemaining }.coerceIn(0, 5),
                    damagePerTurn = effects.maxOf { it.damagePerTurn }.coerceAtLeast(0)
                )
            }
            .filter { it.turnsRemaining > 0 }
            .sortedBy { it.type }
    }

    fun tick(effects: List<CombatStatusEffect>): CombatStatusTick {
        val active = effects.filter { it.turnsRemaining > 0 }
        val damage = active.sumOf { it.damagePerTurn }.coerceAtLeast(0)
        val remaining = active.mapNotNull { effect ->
            val turns = (effect.turnsRemaining - 1).coerceAtLeast(0)
            if (turns == 0) null else effect.copy(turnsRemaining = turns)
        }
        val expired = active.filter { it.turnsRemaining <= 1 }.map { it.type }
        return CombatStatusTick(damage, remaining, expired)
    }
}
