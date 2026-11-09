package br.com.ascensaodosoberano.combat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CombatSystemTacticsTest {

    private fun combatant(
        name: String,
        hp: Int = 100,
        attack: Int = 20,
        boss: Boolean = false
    ) = Combatant(
        name = name,
        maxHp = 100,
        hp = hp,
        attack = attack,
        defense = 5,
        mana = 0,
        maxMana = 0,
        isBoss = boss,
        danger = 80
    )

    @Test
    fun persistentDamageTicksAtTheStartOfThePlayersTurn() {
        val state = CombatState(
            hero = combatant("Herói"),
            enemy = combatant("Goblin"),
            efeitosAtivosJogador = CombatStatusEngine.fromSkill(
                listOf("QUEIMADURA"), 1, 100
            )
        )

        val result = CombatSystem.playerAttack(state)

        assertEquals(96, result.hero.hp)
        assertTrue(result.efeitosAtivosJogador.isEmpty())
    }

    @Test
    fun persistentDamageCanDefeatAnEnemyBeforeItsAction() {
        val state = CombatState(
            hero = combatant("Herói"),
            enemy = combatant("Lobo"),
            phase = CombatPhase.ENEMY_TURN,
            efeitosAtivosInimigo = CombatStatusEngine.fromSkill(
                listOf("ENVENENAMENTO"), 1, 100
            )
        )

        val result = CombatSystem.enemyAttack(state)

        assertEquals(97, result.enemy.hp)
        assertTrue(result.efeitosAtivosInimigo.isEmpty())
    }

    @Test
    fun bossGainsItsSecondPhaseWhenHealthFallsBelowTwoThirds() {
        val state = CombatState(
            hero = combatant("Herói"),
            enemy = combatant("Guardião", hp = 60, attack = 20, boss = true),
            phase = CombatPhase.ENEMY_TURN
        )

        val result = CombatSystem.enemyAttack(state)

        assertEquals(2, result.bossPhase)
        assertTrue(result.enemy.attack > 20)
        assertTrue(result.log.any { it.contains("segunda fase") })
    }
}
