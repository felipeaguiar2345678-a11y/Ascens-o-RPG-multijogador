package br.com.ascensaodosoberano.exploration

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GuildMissionSystemTest {
    @Test
    fun raridadesPossuemPesosConfiguradosQueSomamDezMil() {
        assertEquals(10_000, MissionRarity.entries.sumOf { it.weight })
        assertEquals(
            listOf("Comum", "Incomum", "Rara", "Épica", "Lendária", "Mítica", "Divina", "World"),
            MissionRarity.entries.map { it.label }
        )
    }

    @Test
    fun contratoMantemAMesmaRaridadeDuranteASessao() {
        val first = GuildMissionCatalog.find("guild_dark_forest_e")
        val second = GuildMissionCatalog.find("guild_dark_forest_e")
        assertEquals(first?.rarity, second?.rarity)
        assertEquals(first?.rewardGold, second?.rewardGold)
    }

    @Test
    fun recompensaBaseCresceComORankParaAMesmaRegiao() {
        val ranks = listOf("e", "d", "c", "b", "a", "s", "ss", "sss")
        val missions = ranks.map { GuildMissionCatalog.find("guild_dark_forest_$it")!! }
        val normalizedGold = missions.map { it.rewardGold / it.rarityMultiplier }
        val normalizedXp = missions.map { it.rewardXp / it.rarityMultiplier }
        assertTrue(normalizedGold.zipWithNext().all { (a, b) -> b > a })
        assertTrue(normalizedXp.zipWithNext().all { (a, b) -> b > a })
    }
}
