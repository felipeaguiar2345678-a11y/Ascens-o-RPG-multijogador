package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.AtaqueCriatura
import br.com.ascensaodosoberano.world.CriaturaGerada
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CombatFactoryTest {

    private val hero = Combatant(
        name = "Aventureiro",
        maxHp = 120,
        hp = 120,
        attack = 25,
        defense = 10
    )

    @Test
    fun nocturnalCreatureGetsModerateNightBonusInsteadOfDoubleStats() {
        val creature = CriaturaGerada(
            nome = "Lobo da Noite",
            vidaMaxima = 100,
            ataque = 50,
            defesa = 20,
            manaMaxima = 40,
            agilidade = 30,
            poderMagico = 10,
            atividadeNoturna = true
        )

        val enemy = CombatFactory.createCombat(hero, creature, isNight = true).enemy

        assertEquals(115, enemy.maxHp)
        assertEquals(56, enemy.attack)
        assertEquals(22, enemy.defense)
        assertEquals(44, enemy.maxMana)
    }

    @Test
    fun creatureArchetypeIsInferredFromItsGeneratedAbilities() {
        val creature = CriaturaGerada(
            nome = "Aranha Tóxica",
            ataques = listOf(
                AtaqueCriatura(id = "mordida", efeitos = listOf("ENVENENAMENTO"))
            )
        )

        val enemy = CombatFactory.createCombat(hero, creature).enemy

        assertEquals("VENENOSO", enemy.aiArchetype)
    }

    @Test
    fun daytimeDoesNotApplyNocturnalBonus() {
        val creature = CriaturaGerada(
            nome = "Morcego",
            vidaMaxima = 100,
            ataque = 20,
            atividadeNoturna = true
        )

        val enemy = CombatFactory.createCombat(hero, creature, isNight = false).enemy

        assertEquals(100, enemy.maxHp)
        assertEquals(20, enemy.attack)
        assertTrue(enemy.maxHp > 0)
    }
}
