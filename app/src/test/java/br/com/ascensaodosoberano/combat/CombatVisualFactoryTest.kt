package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.CriaturaGerada
import br.com.ascensaodosoberano.R
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
    @Test
    fun cadaEcossistemaPossuiUmaIlustracaoDeArenaExclusiva() {
        val recursos = CombatSceneKind.values().map(CombatSceneAssets::drawableFor)
        assertEquals(CombatSceneKind.values().size, recursos.distinct().size)
        assertEquals(R.drawable.arena_floresta_arcana, CombatSceneAssets.drawableFor(CombatSceneKind.FLORESTA))
        assertEquals(R.drawable.arena_sombras, CombatSceneAssets.drawableFor(CombatSceneKind.SOMBRAS))
        assertEquals(R.drawable.arena_neve, CombatSceneAssets.drawableFor(CombatSceneKind.NEVE))
        assertEquals(R.drawable.arena_deserto, CombatSceneAssets.drawableFor(CombatSceneKind.DESERTO))
        assertEquals(R.drawable.arena_mar, CombatSceneAssets.drawableFor(CombatSceneKind.MAR))
        assertEquals(R.drawable.arena_ruinas, CombatSceneAssets.drawableFor(CombatSceneKind.RUINAS))
        assertEquals(R.drawable.arena_imperio, CombatSceneAssets.drawableFor(CombatSceneKind.IMPERIO))
        assertEquals(R.drawable.arena_central, CombatSceneAssets.drawableFor(CombatSceneKind.CENTRAL))
    }

}
