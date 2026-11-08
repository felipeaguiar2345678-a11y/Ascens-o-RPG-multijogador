package br.com.ascensaodosoberano.character

import br.com.ascensaodosoberano.companions.PlayerInventory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ProgressionSystemTest {
    @Test
    fun jogadorCaidoNaoRecebePenalidadeEnquantoAliadosContinuamVivos() {
        assertEquals(
            false,
            ProgressionSystem.shouldApplyDefeatPenalty(
                cooperativeBattle = true,
                allPartyMembersDefeated = false,
                soloPlayerDefeated = true
            )
        )
        assertEquals(
            true,
            ProgressionSystem.shouldApplyDefeatPenalty(
                cooperativeBattle = true,
                allPartyMembersDefeated = true,
                soloPlayerDefeated = false
            )
        )
    }

    @Test
    fun derrotaRemoveMetadeDoXpAcumuladoERecalculaNivel() {
        val perfil = CharacterProfile(
            name = "Teste",
            level = 3,
            xp = 150,
            characterClass = CharacterSystem.predefinedClasses.first(),
            inventory = PlayerInventory(gold = 1000L)
        )
        val resultado = ProgressionSystem.applyDefeatPenalty(perfil)
        assertEquals(450L, resultado.totalXpBefore)
        assertEquals(225L, resultado.totalXpAfter)
        assertEquals(2, resultado.profile.level)
        assertEquals(125, resultado.profile.xp)
    }

    @Test
    fun derrotaRemoveVintePorCentoDoOuroERenasceNoUltimoPontoSeguro() {
        val perfil = CharacterProfile(
            name = "Teste",
            level = 1,
            xp = 40,
            characterClass = CharacterSystem.predefinedClasses.first(),
            currentWorldPointId = "ruinas_elficas",
            respawnPointId = "aurelia",
            inventory = PlayerInventory(gold = 999L)
        )
        val resultado = ProgressionSystem.applyDefeatPenalty(perfil)
        assertEquals(800L, resultado.profile.inventory.gold)
        assertEquals(199L, resultado.goldLost)
        assertEquals("aurelia", resultado.profile.currentWorldPointId)
        assertTrue(resultado.profile.worldY < 0.5f)
    }

    @Test
    fun pontoDeRenascimentoInvalidoVoltaParaClareiraInicial() {
        val perfil = CharacterProfile(
            name = "Teste",
            level = 1,
            xp = 0,
            characterClass = CharacterSystem.predefinedClasses.first(),
            respawnPointId = "localidade_inexistente"
        )
        val resultado = ProgressionSystem.applyDefeatPenalty(perfil)
        assertEquals("clareira_inicial", resultado.profile.currentWorldPointId)
        assertEquals("clareira_inicial", resultado.profile.respawnPointId)
    }
}
