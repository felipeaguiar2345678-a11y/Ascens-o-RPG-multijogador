package br.com.ascensaodosoberano.exploration

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotNull
import org.junit.Test

class ExplorationRegionMappingTest {
    @Test
    fun clareiraInicialPertenceAFlorestaSombria() {
        assertEquals("dark_forest", ExplorationSystem.regionForWorldPoint("clareira_inicial")?.id)
    }

    @Test
    fun ruinasRespeitamOBiomaEmQueEstao() {
        assertEquals("forgotten_ruins", ExplorationSystem.regionForWorldPoint("ruinas_elficas")?.id)
        assertEquals("ancestral_desert", ExplorationSystem.regionForWorldPoint("ruinas_antigas")?.id)
    }

    @Test
    fun pontosSelvagensDasSeteRegioesPossuemEcossistema() {
        assertEquals("frost_mountains", ExplorationSystem.regionForWorldPoint("caverna_gelo")?.id)
        assertEquals("imperial_frontier", ExplorationSystem.regionForWorldPoint("catacumbas_reais")?.id)
        assertEquals("central_wilds", ExplorationSystem.regionForWorldPoint("mina_dourada")?.id)
        assertEquals("shadowlands", ExplorationSystem.regionForWorldPoint("templo_sombrio")?.id)
        assertEquals("eternal_sea", ExplorationSystem.regionForWorldPoint("ilha_serpente")?.id)
    }

    @Test
    fun regioesDeAltoRiscoPossuemMapeamento() {
        assertEquals("abyss_valley", ExplorationSystem.regionForWorldPoint("vale_abismo")?.id)
        assertEquals("dead_lands", ExplorationSystem.regionForWorldPoint("nhar_zul")?.id)
    }

    @Test
    fun cidadesNaoGeramEncontrosSelvagensAutomaticos() {
        assertNull(ExplorationSystem.regionForWorldPoint("aurelia"))
        assertNull(ExplorationSystem.regionForWorldPoint("eldarion"))
        assertNull(ExplorationSystem.regionForWorldPoint("malachar"))
    }

    @Test
    fun identificadoresDesconhecidosNaoInventamEcossistema() {
        assertNull(ExplorationSystem.regionForWorldPoint("local_desconhecido"))
        assertNotNull(ExplorationSystem.regionForWorldPoint("clareira_inicial"))
    }
}
