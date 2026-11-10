package br.com.ascensaodosoberano.combat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RewardDistributionTest {

    @Test
    fun experienciaEhDivididaIgualmenteSemBonusPorDano() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 100),
                PlayerContribution("p2", "Jogador 2", 40),
                PlayerContribution("p3", "Jogador 3", 0)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 120, enemyMaxHp = 1_000)

        assertEquals(listOf(40, 40, 40), rewards.map { it.xp })
    }

    @Test
    fun apenasQuemCausaPeloMenosDezPorCentoRecebeChanceDeSaque() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 350),
                PlayerContribution("p2", "Jogador 2", 100),
                PlayerContribution("p3", "Jogador 3", 99)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 90, enemyMaxHp = 1_000)

        assertTrue(rewards.single { it.playerId == "p1" }.receivesItems)
        assertTrue(rewards.single { it.playerId == "p2" }.receivesItems)
        assertTrue(!rewards.single { it.playerId == "p3" }.receivesItems)
        assertEquals(90, rewards.sumOf { it.xp })
    }

    @Test
    fun danoEEmpateNaoAlteramAExperienciaCompartilhada() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 100),
                PlayerContribution("p2", "Jogador 2", 100),
                PlayerContribution("p3", "Jogador 3", 40)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 120, enemyMaxHp = 1_000)

        assertEquals(40, rewards.single { it.playerId == "p1" }.xp)
        assertEquals(40, rewards.single { it.playerId == "p2" }.xp)
        assertEquals(40, rewards.single { it.playerId == "p3" }.xp)
        assertTrue(rewards.single { it.playerId == "p1" }.receivesItems)
        assertTrue(rewards.single { it.playerId == "p2" }.receivesItems)
        assertTrue(!rewards.single { it.playerId == "p3" }.receivesItems)
    }

    @Test
    fun danoAbaixoDeDezPorCentoNaoGeraSaqueMasNaoBloqueiaXp() {
        val participants = CombatParticipants(
            players = listOf(
                PlayerContribution("p1", "Jogador 1", 0),
                PlayerContribution("p2", "Jogador 2", 0)
            )
        )

        val rewards = RewardDistributionSystem.distribute(participants, 50, enemyMaxHp = 1_000)

        assertTrue(rewards.none { it.receivesItems })
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

        val rewards = RewardDistributionSystem.distribute(participants, 2, enemyMaxHp = 1_000)

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

        val rewards = RewardDistributionSystem.distribute(participants, 0, enemyMaxHp = 1_000)

        assertEquals(listOf(0, 0, 0), rewards.map { it.xp })
    }

    @Test
    fun listaVaziaNaoGeraRecompensas() {
        assertTrue(
            RewardDistributionSystem.distribute(CombatParticipants(), 100, enemyMaxHp = 1_000).isEmpty()
        )
    }

    @Test
    fun experienciaNegativaEhTratadaComoZero() {
        val participants = CombatParticipants(
            players = listOf(PlayerContribution("p1", "Jogador 1", 10))
        )

        val rewards = RewardDistributionSystem.distribute(participants, -20, enemyMaxHp = 1_000)

        assertEquals(0, rewards.single().xp)
        assertTrue(!rewards.single().receivesItems)
    }

    @Test
    fun ordemDosParticipantesNaoAlteraQuemRecebeOXPRestante() {
        val a = PlayerContribution("a", "Jogador A", 0)
        val b = PlayerContribution("b", "Jogador B", 100)
        val c = PlayerContribution("c", "Jogador C", 10)
        val primeiro = RewardDistributionSystem.distribute(CombatParticipants(listOf(c, b, a)), 2, enemyMaxHp = 1_000)
        val segundo = RewardDistributionSystem.distribute(CombatParticipants(listOf(a, b, c)), 2, enemyMaxHp = 1_000)
        assertEquals(primeiro, segundo)
        assertEquals(1, primeiro.single { it.playerId == "a" }.xp)
        assertEquals(1, primeiro.single { it.playerId == "b" }.xp)
        assertEquals(0, primeiro.single { it.playerId == "c" }.xp)
    }

    @Test
    fun exatamenteDezPorCentoJaEhElegivel() {
        assertTrue(CombatContributionSystem.hasLootEligibility(100, 1_000))
        assertTrue(!CombatContributionSystem.hasLootEligibility(99, 1_000))
    }

    @Test
    fun porcentagemDeDanoEhLimitadaAZeroECem() {
        assertEquals(0.0, CombatContributionSystem.damagePercentage(-5, 1_000), 0.001)
        assertEquals(100.0, CombatContributionSystem.damagePercentage(1_500, 1_000), 0.001)
        assertEquals(0.0, CombatContributionSystem.damagePercentage(100, 0), 0.001)
    }
}
