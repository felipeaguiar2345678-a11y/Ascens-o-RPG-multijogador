package br.com.ascensaodosoberano.combat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RewardDistributionTest {

    @Test
    fun experienciaEhDivididaEntreTodosOsParticipantes() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 100),
                PlayerContribution("p2", "Jogador 2", 40),
                PlayerContribution("p3", "Jogador 3", 0)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 101)

        assertEquals(listOf(34, 34, 33), rewards.map { it.xp })
    }

    @Test
    fun itensSaoEntreguesSomenteAoMaiorDano() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 100),
                PlayerContribution("p2", "Jogador 2", 40),
                PlayerContribution("p3", "Jogador 3", 10)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 90)

        assertTrue(rewards.single { it.playerId == "p1" }.receivesItems)
        assertFalse(rewards.single { it.playerId == "p2" }.receivesItems)
        assertFalse(rewards.single { it.playerId == "p3" }.receivesItems)
    }

    @Test
    fun empateNoMaiorDanoEntregaItensATodos() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 100),
                PlayerContribution("p2", "Jogador 2", 100),
                PlayerContribution("p3", "Jogador 3", 40)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 90)

        assertTrue(rewards.single { it.playerId == "p1" }.receivesItems)
        assertTrue(rewards.single { it.playerId == "p2" }.receivesItems)
        assertFalse(rewards.single { it.playerId == "p3" }.receivesItems)
    }

    @Test
    fun semDanoRegistradoNinguemRecebeItens() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 0),
                PlayerContribution("p2", "Jogador 2", 0)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 50)

        assertTrue(rewards.none { it.receivesItems })
        assertEquals(listOf(25, 25), rewards.map { it.xp })
    }

    @Test
    fun maioresCausadoresDeDanoIgnoramContribuicaoZero() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 0),
                PlayerContribution("p2", "Jogador 2", 0)
            )
        )

        assertTrue(CombatContributionSystem.getTopDamageDealers(participants).isEmpty())
    }

    @Test
    fun listaVaziaNaoGeraRecompensas() {
        assertTrue(
            RewardDistributionSystem.distribute(CombatParticipants(), 100).isEmpty()
        )
    }

    @Test
    fun experienciaNegativaEhTratadaComoZero() {
        val participants = CombatParticipants(
            players = listOf(PlayerContribution("p1", "Jogador 1", 10))
        )

        val rewards = RewardDistributionSystem.distribute(participants, -20)

        assertEquals(0, rewards.single().xp)
    }
}
