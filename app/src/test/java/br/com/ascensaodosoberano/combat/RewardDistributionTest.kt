package br.com.ascensaodosoberano.combat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RewardDistributionTest {

    @Test
    fun experienciaEhDivididaEQuemMaisCausaDanoRecebeBonusDeVinteECincoPorCento() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 100),
                PlayerContribution("p2", "Jogador 2", 40),
                PlayerContribution("p3", "Jogador 3", 0)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 120)

        assertEquals(listOf(50, 40, 40), rewards.map { it.xp })
    }

    @Test
    fun todosPodemReceberItensIndependentementeDoDano() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 100),
                PlayerContribution("p2", "Jogador 2", 40),
                PlayerContribution("p3", "Jogador 3", 1)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 90)

        assertTrue(rewards.all { it.receivesItems })
    }

    @Test
    fun empateNoMaiorDanoDaBonusDeXpAosEmpatados() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 100),
                PlayerContribution("p2", "Jogador 2", 100),
                PlayerContribution("p3", "Jogador 3", 40)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 120)

        assertEquals(50, rewards.single { it.playerId == "p1" }.xp)
        assertEquals(50, rewards.single { it.playerId == "p2" }.xp)
        assertEquals(40, rewards.single { it.playerId == "p3" }.xp)
    }

    @Test
    fun danoZeroNaoBloqueiaSaqueNemConcedeBonusDeDano() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 0),
                PlayerContribution("p2", "Jogador 2", 0)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 50)

        assertTrue(rewards.all { it.receivesItems })
        assertEquals(listOf(25, 25), rewards.map { it.xp })
        assertTrue(CombatContributionSystem.getTopDamageDealers(participants).isEmpty())
    }


    @Test
    fun experienciaBaixaEhDivididaSemCriarXpExtraEComRestoDeterministico() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 10),
                PlayerContribution("p2", "Jogador 2", 5),
                PlayerContribution("p3", "Jogador 3", 0)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 2)

        assertEquals(1, rewards.single { it.playerId == "p1" }.xp)
        assertEquals(1, rewards.single { it.playerId == "p2" }.xp)
        assertEquals(0, rewards.single { it.playerId == "p3" }.xp)
        assertEquals(2, rewards.sumOf { it.xp })
    }

    @Test
    fun zeroXpNaoEhElevadoArtificialmenteParaCadaIntegrante() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 10),
                PlayerContribution("p2", "Jogador 2", 5),
                PlayerContribution("p3", "Jogador 3", 0)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 0)

        assertEquals(listOf(0, 0, 0), rewards.map { it.xp })
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
        assertTrue(rewards.single().receivesItems)
    }

    @Test
    fun bonusDeXpUsaVinteECincoPorCentoDaParteDoJogador() {
        assertEquals(125, RewardDistributionSystem.applyTopDamageBonus(100, 50, 50))
        assertEquals(100, RewardDistributionSystem.applyTopDamageBonus(100, 49, 50))
        assertEquals(100, RewardDistributionSystem.applyTopDamageBonus(100, 0, 0))
    }
}
