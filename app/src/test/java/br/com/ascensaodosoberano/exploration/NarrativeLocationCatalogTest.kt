package br.com.ascensaodosoberano.exploration

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotNull
import org.junit.Test

class NarrativeLocationCatalogTest {
    @Test
    fun localidadesTextuaisNaoDependemDeCoordenadasOuPontosDoMapa() {
        assertEquals("Aurelia", NarrativeLocationCatalog.displayName("aurelia"))
        assertEquals("central_wilds", ExplorationSystem.regionForNarrativeLocation("aurelia")?.id)
        assertEquals("shadowlands", ExplorationSystem.regionForNarrativeLocation("malachar")?.id)
        assertEquals("ancestral_desert", ExplorationSystem.regionForNarrativeLocation("tharion")?.id)
    }

    @Test
    fun locaisSelvagensEMasmasPossuemEcossistemaNarrativo() {
        assertEquals("dark_forest", ExplorationSystem.regionForNarrativeLocation("clareira_inicial")?.id)
        assertEquals("forgotten_ruins", ExplorationSystem.regionForNarrativeLocation("ruinas_elficas")?.id)
        assertEquals("frost_mountains", ExplorationSystem.regionForNarrativeLocation("caverna_gelo")?.id)
        assertEquals("eternal_sea", ExplorationSystem.regionForNarrativeLocation("ilha_serpente")?.id)
    }

    @Test
    fun localDesconhecidoNaoRecebeRegiaoInventada() {
        assertNull(NarrativeLocationCatalog.find("continente_desconhecido"))
        assertNull(ExplorationSystem.regionForNarrativeLocation("continente_desconhecido"))
    }

    @Test
    fun catalogoPossuiLugaresComNomeLegivel() {
        assertNotNull(NarrativeLocationCatalog.find("ruinas_antigas"))
        assertEquals("Ruínas Antigas", NarrativeLocationCatalog.displayName("ruinas_antigas"))
        assertEquals("Lugar sem registro", NarrativeLocationCatalog.displayName("lugar_sem_registro"))
    }
}
