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
    @Test fun ecossistemaDesconhecidoMantemFallbackDeFloresta() {
        assertEquals(CombatSceneKind.FLORESTA, CombatSceneProfile.resolve("clareira"))
    }
}
