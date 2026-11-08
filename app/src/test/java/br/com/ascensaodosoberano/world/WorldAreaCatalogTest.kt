package br.com.ascensaodosoberano.world

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WorldAreaCatalogTest {
    @Test
    fun mapaDoBetaIncluiAureliaMasNaoLiberaOutrasCidadesCentrais() {
        val pontos = WorldMapData.pointsAvailableForBeta(WorldRegion.FLORESTA_ARCANA)
        val ids = pontos.map { it.id }.toSet()
        assertTrue(ids.contains("clareira_inicial"))
        assertTrue(ids.contains("aurelia"))
        assertFalse(ids.contains("cidade_do_sol"))
        assertFalse(ids.contains("arkanis"))
        assertFalse(ids.contains("malachar"))
    }

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
        WorldAreaCatalog.all()
            .filter { it.id != WorldAreaId.FLORESTA_ARCANA }
            .forEach { assertFalse(WorldAreaCatalog.isInitiallyPlayable(it.id)) }
    }

    @Test
    fun todosOsPontosDaFlorestaPertencemAoEcossistemaJogavelDoBeta() {
        WorldMapData.pointsInRegion(WorldRegion.FLORESTA_ARCANA).forEach { point ->
            assertEquals(
                WorldAreaId.FLORESTA_ARCANA,
                WorldAreaCatalog.forWorldPoint(point.id)?.id
            )
        }
    }

    @Test
    fun saidasDaAreaInicialAindaNaoAtivamTransicoes() {
        assertTrue(WorldAreaCatalog.get(WorldAreaId.FLORESTA_ARCANA).gates.isEmpty())
        assertTrue(WorldAreaCatalog.get(WorldAreaId.MONTANHAS_GELIDAS).gates.isEmpty())
        assertNull(
            WorldAreaCatalog.transitionAt(
                WorldAreaId.FLORESTA_ARCANA,
                x = 0.86f,
                y = 0.08f
            )
        )
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
