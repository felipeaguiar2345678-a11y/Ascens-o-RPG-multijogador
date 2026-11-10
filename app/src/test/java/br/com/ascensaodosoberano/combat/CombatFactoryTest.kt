package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.AtaqueCriatura
import br.com.ascensaodosoberano.world.CriaturaGerada
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CombatFactoryTest {
    @Test
    fun criaturaGeradaAbreCombateComDadosEEstadoInicialCorretos() {
        val hero = Combatant(
            name = "Aventureiro",
            maxHp = 120,
            hp = 120,
            attack = 25,
            defense = 8
        )
        val creature = CriaturaGerada(
            id = "serpente_de_cristal",
            nome = "Serpente de Cristal",
            rank = "TRANSCENDENTE",
            nivel = 42,
            vidaMaxima = 860,
            ataque = 74,
            defesa = 31,
            manaMaxima = 420,
            agilidade = 55,
            poderMagico = 91,
            experienciaBase = 350,
            perigo = 80,
            chefe = true,
            ataques = listOf(
                AtaqueCriatura(
                    id = "lanca_cristalina",
                    nome = "Lança Cristalina"
                )
            )
        )

        val state = CombatFactory.createCombat(hero, creature)

        assertEquals(CombatPhase.PLAYER_TURN, state.phase)
        assertEquals("Serpente de Cristal", state.enemy.name)
        assertEquals(860, state.enemy.maxHp)
        assertEquals(860, state.enemy.hp)
        assertEquals(74, state.enemy.attack)
        assertEquals(31, state.enemy.defense)
        assertEquals(420, state.enemy.maxMana)
        assertEquals("TRANSCENDENTE", state.enemy.rank)
        assertEquals(42, state.enemy.level)
        assertEquals(350, state.enemy.xpReward)
        assertTrue(state.enemy.isBoss)
        assertEquals("lanca_cristalina", state.enemy.attacks.single().id)
    }

    @Test
    fun criaturaNoturnaRecebeMultiplicadorSomenteQuandoCombateEhNoturno() {
        val hero = Combatant("Aventureiro", 100, 100, 20, 5)
        val creature = CriaturaGerada(
            nome = "Predador Noturno",
            vidaMaxima = 100,
            ataque = 20,
            manaMaxima = 30,
            atividadeNoturna = true,
            ataques = listOf(AtaqueCriatura(nome = "Mordida"))
        )

        val day = CombatFactory.createCombat(hero, creature, isNight = false)
        val night = CombatFactory.createCombat(hero, creature, isNight = true)

        assertEquals(100, day.enemy.maxHp)
        assertEquals(200, night.enemy.maxHp)
        assertEquals(20, day.enemy.attack)
        assertEquals(40, night.enemy.attack)
    }
}
