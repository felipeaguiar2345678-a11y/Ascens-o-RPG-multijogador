package br.com.ascensaodosoberano.combat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CombatFleeTest {
    @Test
    fun fugaSoPodeSerTentadaNoTurnoDoJogador() {
        val state = CombatSystem.startCombat(
            hero = Combatant("Herói", 100, 100, 20, 5),
            enemy = Combatant("Criatura", 100, 100, 15, 4)
        ).copy(phase = CombatPhase.ENEMY_TURN)

        assertEquals(state, CombatSystem.playerFlee(state))
    }

    @Test
    fun tentativaDeFugaSempreRegistraRolagemEConsomeAcao() {
        val state = CombatSystem.startCombat(
            hero = Combatant("Herói", 100, 100, 20, 5, agility = 30),
            enemy = Combatant("Criatura", 100, 100, 15, 4, agility = 1)
        )

        val result = CombatSystem.playerFlee(state)

        assertTrue(
            result.phase == CombatPhase.ENEMY_ESCAPED ||
                result.phase == CombatPhase.ENEMY_TURN
        )
        assertEquals(state.log.size + 1, result.log.size)
        assertTrue(result.log.last().contains("Tentativa de fuga"))
        if (result.phase == CombatPhase.ENEMY_TURN) {
            assertTrue(result.playerVulnerable)
        }
    }

    @Test
    fun fugaNaoPodeSerUsadaDuranteCarregamentoDeHabilidade() {
        val skill = br.com.ascensaodosoberano.world.AtaqueCriatura(
            id = "golpe_carregado",
            nome = "Golpe Carregado",
            turnosCarregamento = 2
        )
        val state = CombatSystem.startCombat(
            hero = Combatant("Herói", 100, 100, 20, 5),
            enemy = Combatant("Criatura", 100, 100, 15, 4)
        ).copy(carregandoHabilidadeJogador = skill)

        val result = CombatSystem.playerFlee(state)

        assertEquals(CombatPhase.PLAYER_TURN, result.phase)
        assertTrue(result.log.last().contains("libere ou interrompa"))
    }
}
