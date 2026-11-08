package br.com.ascensaodosoberano.world

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ForestAreaMapLayoutTest {
    @Test
    fun mapaInicialTemPontosDeInteresseVariados() {
        val tipos = ForestAreaMapLayout.landmarks.map { it.kind }.toSet()
        assertTrue(tipos.contains(ForestLandmarkKind.START_CLEARING))
        assertTrue(tipos.contains(ForestLandmarkKind.VILLAGE))
        assertTrue(tipos.contains(ForestLandmarkKind.CITY))
        assertTrue(tipos.contains(ForestLandmarkKind.TOWER))
        assertTrue(tipos.contains(ForestLandmarkKind.RUINS))
        assertTrue(tipos.contains(ForestLandmarkKind.WATERFALL))
        assertTrue(tipos.contains(ForestLandmarkKind.BOSS_LAIR))
        assertEquals(10, ForestAreaMapLayout.landmarks.size)
    }

    @Test
    fun todosOsCaminhosPossuemPeloMenosDoisPontosDentroDaArea() {
        assertTrue(ForestAreaMapLayout.paths.isNotEmpty())
        ForestAreaMapLayout.paths.forEach { path ->
            assertTrue(path.points.size >= 2)
            path.points.forEach { (x, y) ->
                assertTrue("${path.id}: x=$x", x in 0f..1f)
                assertTrue("${path.id}: y=$y", y in 0f..1f)
            }
        }
    }

    @Test
    fun clareiraInicialEhAEntradaPrincipalEConectaComEstradaDeAurelia() {
        val clareira = ForestAreaMapLayout.landmark("clareira_inicial")
        assertEquals(.52f, clareira?.x ?: 0f, .001f)
        assertEquals(.78f, clareira?.y ?: 0f, .001f)
        assertTrue(ForestAreaMapLayout.paths.any { it.id == "estrada_aurelia" })
    }

    @Test
    fun ponteDasGeadasFicaNaBordaNorteDaFloresta() {
        val ponte = ForestAreaMapLayout.landmark("ponte_das_geadas")
        assertTrue((ponte?.y ?: 1f) < .15f)
        assertEquals(ForestLandmarkKind.GATE, ponte?.kind)
    }
}
