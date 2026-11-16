package br.com.ascensaodosoberano.world
import org.junit.Assert.assertEquals
import org.junit.Test
class WorldSceneImageApiTest {
    @Test fun florestaSombriaUsaCenarioDeFlorestaQuandoBiomaEFloresta() {
        assertEquals("floresta", WorldSceneImageApi.sceneIdForContext("Floresta Sombria", "Terras das Sombras"))
    }
    @Test fun biomaNevadoUsaCenarioDeNeve() {
        assertEquals("neve", WorldSceneImageApi.sceneIdForContext("Montanhas Gélidas", "Região Central"))
    }
    @Test fun ruinasUsamCenarioProprio() {
        assertEquals("ruinas", WorldSceneImageApi.sceneIdForContext("Ruínas Esquecidas", "Império"))
    }
    @Test fun regiaoDasSombrasUsaCenarioSombrioQuandoBiomaNaoEInformado() {
        assertEquals("sombras", WorldSceneImageApi.sceneIdForContext("", "Terras das Sombras"))
    }
}
