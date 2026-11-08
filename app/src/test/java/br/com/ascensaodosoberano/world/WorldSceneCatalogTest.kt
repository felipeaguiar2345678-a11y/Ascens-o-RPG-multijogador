package br.com.ascensaodosoberano.world

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WorldSceneCatalogTest {

    @Test
    fun todasAsLocalidadesDoMapaPossuemPerfilVisual() {
        WorldMapData.points.forEach { point ->
            val profile = WorldSceneCatalog.profileFor(point.id)
            assertEquals(point.id, profile.locationId)
            assertEquals(point.name, profile.locationName)
            assertEquals(point.region, profile.region)
        }
    }

    @Test
    fun capitalECidadesRecebemAproximacaoMaiorQueAreasSelvagens() {
        val aurelia = WorldSceneCatalog.profileFor("aurelia")
        val malachar = WorldSceneCatalog.profileFor("malachar")
        val clareira = WorldSceneCatalog.profileFor("clareira_inicial")

        assertEquals(WorldSceneKind.CAPITAL, aurelia.kind)
        assertEquals(WorldSceneKind.CITY, malachar.kind)
        assertTrue(aurelia.cameraZoom > clareira.cameraZoom)
        assertTrue(malachar.cameraZoom > clareira.cameraZoom)
    }

    @Test
    fun cidadesEVilasSaoAreasSegurasMasDungeonsNao() {
        assertTrue(WorldSceneCatalog.profileFor("aurelia").isSafeArea)
        assertTrue(WorldSceneCatalog.profileFor("vila_verdejante").isSafeArea)
        assertFalse(WorldSceneCatalog.profileFor("ruinas_elficas").isSafeArea)
        assertFalse(WorldSceneCatalog.profileFor("caverna_gelo").isSafeArea)
    }

    @Test
    fun localidadeDesconhecidaUsaPerfilSelvagemSemInventarRegiao() {
        val profile = WorldSceneCatalog.profileFor("local_desconhecido")
        assertEquals(WorldSceneKind.WILDERNESS, profile.kind)
        assertEquals(1f, profile.cameraZoom)
        assertEquals(null, profile.region)
    }
}
