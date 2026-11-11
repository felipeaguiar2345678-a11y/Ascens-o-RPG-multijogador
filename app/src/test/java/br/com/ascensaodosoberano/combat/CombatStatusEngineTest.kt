package br.com.ascensaodosoberano.combat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CombatStatusEngineTest {

    @Test
    fun poisonBurnAndBleedBecomePersistentEffects() {
        val effects = CombatStatusEngine.fromSkill(
            listOf("ENVENENAMENTO", "QUEIMADURA", "SANGRAMENTO"),
            durationTurns = 3,
            targetMaxHp = 100
        )

        assertEquals(3, effects.size)
        assertEquals(10, effects.sumOf { it.damagePerTurn })
        assertTrue(effects.all { it.turnsRemaining == 3 })
    }

    @Test
    fun repeatedStatusRefreshesDurationWithoutStackingDuplicateDamage() {
        val first = CombatStatusEngine.fromSkill(listOf("VENENO"), 2, 100)
        val second = CombatStatusEngine.fromSkill(listOf("ENVENENAMENTO"), 4, 100)
        val merged = CombatStatusEngine.merge(first, second)

        assertEquals(1, merged.size)
        assertEquals(4, merged.single().turnsRemaining)
        assertEquals(3, merged.single().damagePerTurn)
    }

    @Test
    fun statusTickDealsDamageAndExpiresAtZero() {
        val effects = CombatStatusEngine.fromSkill(listOf("QUEIMADURA"), 1, 100)
        val tick = CombatStatusEngine.tick(effects)

        assertEquals(4, tick.damage)
        assertTrue(tick.remainingEffects.isEmpty())
        assertEquals(listOf("QUEIMADURA"), tick.expiredTypes)
    }
}
