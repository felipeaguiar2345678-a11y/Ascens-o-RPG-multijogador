package br.com.ascensaodosoberano.world

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WorldAICombatTest {

    private fun context(
        hp: Int = 100,
        boss: Boolean = false,
        attacks: List<AtaqueCriatura> = emptyList(),
        cooldowns: Map<String, Int> = emptyMap(),
        mana: Int = 100,
        heroDefending: Boolean = false
    ) = AICombatContext(
        enemyHp = hp,
        enemyMaxHp = 100,
        playerHp = 100,
        playerMaxHp = 100,
        enemyMana = mana,
        enemyManaMax = 100,
        enemyRank = if (boss) "S" else "C",
        turn = 4,
        enemyAttack = 30,
        enemyLevel = 10,
        danger = 80,
        isBoss = boss,
        attacks = attacks,
        attackCooldowns = cooldowns,
        enemyDefense = 12,
        enemyAgility = 20,
        enemyMagicPower = 80,
        heroDefending = heroDefending
    )

    @Test
    fun magicSkillUsesCreatureMagicPowerWhenCalculatingDamage() {
        val skill = AtaqueCriatura(
            id = "explosao_arcana",
            nome = "Explosão Arcana",
            tipoDano = "MAGICO",
            danoBase = 20,
            multiplicador = 1f,
            custoMana = 10,
            chanceUso = 100
        )
        val decision = WorldAI.decideMonsterAction(context(attacks = listOf(skill)))

        assertEquals(AIAction.SPECIAL, decision.action)
        assertEquals(100, decision.proposedDamage)
        assertEquals(skill.id, decision.selectedAttack?.id)
    }

    @Test
    fun skillOnCooldownIsNeverSelected() {
        val skill = AtaqueCriatura(
            id = "golpe_carregado",
            nome = "Golpe Carregado",
            danoBase = 100,
            multiplicador = 2f,
            custoMana = 10,
            chanceUso = 100
        )
        val decision = WorldAI.decideMonsterAction(
            context(attacks = listOf(skill), cooldowns = mapOf(skill.id to 2))
        )

        assertNotEquals(AIAction.SPECIAL, decision.action)
        assertEquals(null, decision.selectedAttack)
    }

    @Test
    fun bossEntersFinalPhaseAtOneThirdHealthAndNeverRetreats() {
        val decision = WorldAI.decideMonsterAction(context(hp = 25, boss = true))

        assertEquals(3, decision.bossPhase)
        assertNotEquals(AIAction.RETREAT, decision.action)
    }

    @Test
    fun creatureCanBeClassifiedByItsGeneratedAbilities() {
        val creature = CriaturaGerada(
            nome = "Aranha Tóxica",
            rank = "B",
            ataque = 30,
            defesa = 12,
            ataques = listOf(
                AtaqueCriatura(id = "mordida", efeitos = listOf("ENVENENAMENTO"))
            )
        )

        assertEquals("VENENOSO", WorldAI.inferArchetype(creature))
    }

    @Test
    fun defensiveCreaturesReceiveTheirOwnTacticalIdentity() {
        val creature = CriaturaGerada(
            nome = "Tartaruga de Pedra",
            ataque = 10,
            defesa = 30
        )

        assertTrue(WorldAI.inferArchetype(creature) == "DEFENSOR")
    }
}
