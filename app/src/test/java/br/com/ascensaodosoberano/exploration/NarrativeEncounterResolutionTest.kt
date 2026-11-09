package br.com.ascensaodosoberano.exploration

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotNull
import org.junit.Test

class NarrativeEncounterResolutionTest {
    @Test
    fun cidadePodeReceberEncontroQuandoANarrativaDescreverUmaAmeaca() {
        assertNotNull(
            ExplorationSystem.regionForNarrativeLocation("aurelia")
        )
        assertEquals(
            "central_wilds",
            ExplorationSystem.regionForNarrativeLocation("aurelia")?.ecosystemId
        )
    }

    @Test
    fun regrasAntigasDeLocalSeguroContinuamSeparadasDaNarrativa() {
        assertNull(ExplorationSystem.regionForWorldPoint("aurelia"))
        assertNotNull(ExplorationSystem.regionForNarrativeLocation("aurelia"))
    }

    @Test
    fun localidadeNarrativaDesconhecidaNaoRecebeBiomaInventado() {
        assertNull(ExplorationSystem.regionForNarrativeLocation("local_sem_catalogo"))
    }
}
