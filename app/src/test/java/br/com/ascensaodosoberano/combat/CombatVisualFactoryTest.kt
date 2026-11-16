package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.CriaturaGerada
import org.junit.Assert.assertEquals
import org.junit.Test

class CombatVisualFactoryTest {
    private val heroi = Combatant(
        name = "Aventureiro",
        maxHp = 100,
        hp = 100,
        attack = 20,
        defense = 10
    )

    @Test
    fun arteIconeDaCriaturaChegaAoInimigoNoCombate() {
        val criatura = CriaturaGerada(
            id = "lobo-da-floresta",
            nome = "Lobo da Floresta",
            imagemIconeCaminho = "https://cdn.exemplo.com/lobo.png"
        )

        val combate = CombatFactory.createCombat(heroi, criatura)

        assertEquals("https://cdn.exemplo.com/lobo.png", combate.enemy.spriteUrl)
    }

    @Test
    fun arteDetalhadaEhUsadaQuandoNaoExisteIcone() {
        val criatura = CriaturaGerada(
            id = "guardiao",
            nome = "Guardião",
            imagemDetalhadaCaminho = "https://cdn.exemplo.com/guardiao.png"
        )

        val combate = CombatFactory.createCombat(heroi, criatura)

        assertEquals("https://cdn.exemplo.com/guardiao.png", combate.enemy.spriteUrl)
    }

    @Test
    fun florestaDasSombrasNaoRecebePaletaDaRegiaoSombras() {
        val cena = CombatSceneProfile.resolve("Floresta Arcana · Floresta das Sombras")
        assertEquals(CombatSceneKind.FLORESTA, cena)
    }

    @Test
    fun cadaBiomaPrincipalMantemSuaCenaDeCombate() {
        assertEquals(CombatSceneKind.NEVE, CombatSceneProfile.resolve("Montanhas Gélidas · Passagem Nevada"))
        assertEquals(CombatSceneKind.DESERTO, CombatSceneProfile.resolve("Deserto Ancestral · Dunas"))
        assertEquals(CombatSceneKind.MAR, CombatSceneProfile.resolve("Mar Eterno · Costa"))
        assertEquals(CombatSceneKind.RUINAS, CombatSceneProfile.resolve("Ruínas Antigas"))
        assertEquals(CombatSceneKind.IMPERIO, CombatSceneProfile.resolve("Império · Campos Imperiais"))
        assertEquals(CombatSceneKind.CENTRAL, CombatSceneProfile.resolve("Região Central · Terras Selvagens Centrais"))
    }

    @Test
    fun regiaoSombrasContinuaComSuaIdentidadeVisual() {
        val cena = CombatSceneProfile.resolve("Terras das Sombras · Vale do Abismo")
        assertEquals(CombatSceneKind.SOMBRAS, cena)
    }
}
