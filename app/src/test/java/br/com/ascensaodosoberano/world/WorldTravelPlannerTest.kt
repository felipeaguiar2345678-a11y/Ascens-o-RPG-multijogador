package br.com.ascensaodosoberano.world

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WorldTravelPlannerTest {

    @Test
    fun todosOsPontosDoMundoPodemSerAlcancadosDaClareiraInicial() {
        WorldMapData.points.forEach { destino ->
            val plano = WorldTravelPlanner.createPlan("clareira_inicial", destino.id)
            assertNotNull("Destino sem rota: ${destino.name}", plano)
        }
    }

    @Test
    fun viagemEntreClareiraEAureliaPossuiRotaValida() {
        val plano = WorldTravelPlanner.createPlan("clareira_inicial", "aurelia")
        assertNotNull(plano)
        assertTrue(plano!!.route.isNotEmpty())
        assertTrue(plano.totalDistance > 0f)
        assertEquals("Aurelia", plano.destination.name)
    }

    @Test
    fun origemIgualAoDestinoNaoCriaDistanciaFalsa() {
        val plano = WorldTravelPlanner.createPlan("aurelia", "aurelia")
        assertNotNull(plano)
        assertTrue(plano!!.route.isEmpty())
        assertEquals(0f, plano.totalDistance, 0.0001f)
    }
}
