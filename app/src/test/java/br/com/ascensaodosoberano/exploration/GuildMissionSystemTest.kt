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
    fun ofertasMantemIdentidadeERaridadeDuranteASessao() {
        val first = GuildMissionCatalog.all()
        val second = GuildMissionCatalog.all()
        assertEquals(first.map { it.id }, second.map { it.id })
        assertEquals(first.map { it.rarity }, second.map { it.rarity })
        assertEquals(first.size, first.map { it.id }.distinct().size)
    }

    @Test
    fun recompensaBaseCresceComORankParaAMesmaRegiao() {
        val ranks = listOf("e", "d", "c", "b", "a", "s", "ss", "sss")
        val ofertas = GuildMissionCatalog.all().filter { it.regionId == "dark_forest" }
        val missions = ranks.map { rank ->
            ofertas.first { it.rank.equals(rank, ignoreCase = true) }
        }
        val normalizedGold = missions.map { it.rewardGold / it.rarityMultiplier }
        val normalizedXp = missions.map { it.rewardXp / it.rarityMultiplier }
        assertTrue(normalizedGold.zipWithNext().all { (a, b) -> b > a })
        assertTrue(normalizedXp.zipWithNext().all { (a, b) -> b > a })
    }
}
