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
    fun rerrolagemCriaNovasOfertasSemReutilizarIds() {
        val first = GuildMissionCatalog.all()
        val rerolled = GuildMissionCatalog.rerollOffers()
        assertTrue(rerolled.isNotEmpty())
        assertEquals(rerolled.size, rerolled.map { it.id }.distinct().size)
        assertTrue(first.map { it.id }.intersect(rerolled.map { it.id }.toSet()).isEmpty())
    }

    @Test
    fun catalogoIncluiCacasFracasERaidDeMasmorraRankE() {
        val initial = GuildMissionCatalog.all().filter { it.rank == "E" }
        assertTrue(initial.any { it.title.contains("ratos", ignoreCase = true) })
        assertTrue(initial.any { it.title.contains("javalis", ignoreCase = true) })
        assertTrue(initial.any { it.title.contains("goblins", ignoreCase = true) })
        assertTrue(initial.any { it.title.contains("esqueletos", ignoreCase = true) })
        assertTrue(initial.any { it.type == "Raid de masmorra" && it.special })
        assertTrue(initial.filter { it.title.startsWith("Caçada:") || it.type == "Raid de masmorra" }
            .all { it.recommendedLevel == 1 && it.difficultyMultiplier <= 1.5 })
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
