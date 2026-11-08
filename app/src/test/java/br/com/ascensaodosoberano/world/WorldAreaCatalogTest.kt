package br.com.ascensaodosoberano.world

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WorldAreaCatalogTest {
    @Test
    fun todosOsPontosDoMapaGlobalPertencemAUmaArea() {
        WorldMapData.points.forEach { point ->
            assertNotNull("Ponto sem área: ${point.id}", WorldAreaCatalog.forWorldPoint(point.id))
        }
    }

    @Test
    fun florestaArcanaEhAUnicaAreaInicialmenteLiberada() {
        val liberadas = WorldAreaCatalog.all().filter { it.playable }
        assertEquals(1, liberadas.size)
        assertEquals(WorldAreaId.FLORESTA_ARCANA, liberadas.single().id)
        assertFalse(WorldAreaCatalog.isInitiallyPlayable(WorldAreaId.MONTANHAS_GELIDAS))
    }

    @Test
    fun limiteDaFlorestaConectaComMontanhasPelaPonteDasGeadas() {
        val transicao = WorldAreaCatalog.transitionAt(
            WorldAreaId.FLORESTA_ARCANA,
            x = 0.86f,
            y = 0.08f
        )
        assertNotNull(transicao)
        assertEquals(WorldAreaId.MONTANHAS_GELIDAS, transicao?.to)
        assertEquals("ponte_das_geadas", transicao?.gateId)
        assertEquals(0.18f, transicao?.spawn?.x ?: 0f)
        assertEquals(0.88f, transicao?.spawn?.y ?: 0f)
    }

    @Test
    fun foraDasPassagensNaoOcorreTrocaDeArea() {
        assertNull(
            WorldAreaCatalog.transitionAt(
                WorldAreaId.FLORESTA_ARCANA,
                x = 0.5f,
                y = 0.5f
            )
        )
    }

    @Test
    fun todasAsAreasUsamEcossistemasIndependentes() {
        val ecossistemas = WorldAreaCatalog.all().map { it.ecosystemId }
        assertEquals(ecossistemas.size, ecossistemas.toSet().size)
        assertTrue(WorldAreaCatalog.initialArea().pointIds.contains("clareira_inicial"))
    }
}
