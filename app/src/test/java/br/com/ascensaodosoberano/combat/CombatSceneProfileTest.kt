package br.com.ascensaodosoberano.combat

import org.junit.Assert.assertEquals
import org.junit.Test

class CombatSceneProfileTest {
    @Test fun biomasGelidosUsamTemaDeNeve() {
        assertEquals(CombatSceneKind.NEVE, CombatSceneProfile.resolve("Montanhas Gélidas"))
    }
    @Test fun valeDoAbismoUsaTemaDasSombras() {
        assertEquals(CombatSceneKind.SOMBRAS, CombatSceneProfile.resolve("Vale do Abismo"))
    }
    @Test fun biomasMarinhosUsamTemaDoMar() {
        assertEquals(CombatSceneKind.MAR, CombatSceneProfile.resolve("Costa do Mar Eterno"))
    }
    @Test fun ruinasSaoDiferenciadasDaFloresta() {
        assertEquals(CombatSceneKind.RUINAS, CombatSceneProfile.resolve("Ruínas Esquecidas"))
    }
    @Test fun todosOsIdsOficiaisSelecionamOSeuCenario() {
        assertEquals(CombatSceneKind.FLORESTA, CombatSceneProfile.resolve("dark_forest"))
        assertEquals(CombatSceneKind.RUINAS, CombatSceneProfile.resolve("forgotten_ruins"))
        assertEquals(CombatSceneKind.SOMBRAS, CombatSceneProfile.resolve("abyss_valley"))
        assertEquals(CombatSceneKind.SOMBRAS, CombatSceneProfile.resolve("dead_lands"))
        assertEquals(CombatSceneKind.NEVE, CombatSceneProfile.resolve("frost_mountains"))
        assertEquals(CombatSceneKind.IMPERIO, CombatSceneProfile.resolve("imperial_frontier"))
        assertEquals(CombatSceneKind.CENTRAL, CombatSceneProfile.resolve("central_wilds"))
        assertEquals(CombatSceneKind.DESERTO, CombatSceneProfile.resolve("ancestral_desert"))
        assertEquals(CombatSceneKind.MAR, CombatSceneProfile.resolve("eternal_sea"))
    }

    @Test fun nomesPortuguesesDosEcossistemasSelecionamOCenarioCorreto() {
        assertEquals(CombatSceneKind.FLORESTA, CombatSceneProfile.resolve("Floresta das Sombras · floresta sombria"))
        assertEquals(CombatSceneKind.RUINAS, CombatSceneProfile.resolve("Ruínas Esquecidas · ruínas antigas"))
        assertEquals(CombatSceneKind.SOMBRAS, CombatSceneProfile.resolve("Vale do Abismo · vale abissal"))
        assertEquals(CombatSceneKind.SOMBRAS, CombatSceneProfile.resolve("Terras das Sombras · terras sombrias"))
        assertEquals(CombatSceneKind.NEVE, CombatSceneProfile.resolve("Montanhas Gélidas · montanhas nevadas"))
        assertEquals(CombatSceneKind.IMPERIO, CombatSceneProfile.resolve("Fronteiras do Império · campos imperiais"))
        assertEquals(CombatSceneKind.CENTRAL, CombatSceneProfile.resolve("Terras Selvagens Centrais · campos e bosques centrais"))
        assertEquals(CombatSceneKind.DESERTO, CombatSceneProfile.resolve("Deserto Ancestral"))
        assertEquals(CombatSceneKind.MAR, CombatSceneProfile.resolve("Mar Eterno · ilhas e costa"))
    }

    @Test fun ecossistemaDesconhecidoMantemFallbackDeFloresta() {
        assertEquals(CombatSceneKind.FLORESTA, CombatSceneProfile.resolve("clareira"))
    }
}
