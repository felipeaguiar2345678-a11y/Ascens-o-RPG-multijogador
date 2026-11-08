package br.com.ascensaodosoberano.world

import org.junit.Assert.assertEquals
import org.junit.Test

class WorldDirectorProbabilityTest {

    private val context = WorldContext(
        regionName = "Floresta Arcana",
        regionRank = "C",
        dangerLevel = 20,
        bossChance = 4.0,
        ecosystemId = "dark_forest",
        biome = "floresta sombria"
    )

    @Test
    fun limiteInferiorDoSorteioPodeGerarChefe() {
        assertEquals(
            WorldEventType.BOSS,
            WorldDirector.generateEventForRoll(context, 0).type
        )
        assertEquals(
            WorldEventType.BOSS,
            WorldDirector.generateEventForRoll(context, 399).type
        )
    }

    @Test
    fun limiteEntreChefeEEncontroEhExato() {
        assertEquals(
            WorldEventType.ENCOUNTER,
            WorldDirector.generateEventForRoll(context, 400).type
        )
        assertEquals(
            WorldEventType.ENCOUNTER,
            WorldDirector.generateEventForRoll(context, 1_999).type
        )
    }

    @Test
    fun restanteDaChanceEhDistribuidoEntreEventosPacificados() {
        assertEquals(
            WorldEventType.QUEST,
            WorldDirector.generateEventForRoll(context, 2_000).type
        )
        assertEquals(
            WorldEventType.TREASURE,
            WorldDirector.generateEventForRoll(context, 5_200).type
        )
        assertEquals(
            WorldEventType.NPC,
            WorldDirector.generateEventForRoll(context, 7_600).type
        )
        assertEquals(
            WorldEventType.NOTHING,
            WorldDirector.generateEventForRoll(context, 9_200).type
        )
    }

    @Test
    fun chanceDeChefeTemPrecisaoDeUmCentésimoDePorcento() {
        val contexto = context.copy(dangerLevel = 1, bossChance = 0.01)
        assertEquals(
            WorldEventType.BOSS,
            WorldDirector.generateEventForRoll(contexto, 0).type
        )
        assertEquals(
            WorldEventType.ENCOUNTER,
            WorldDirector.generateEventForRoll(contexto, 1).type
        )
    }

    @Test
    fun perigoMaximoComChanceTotalDeChefeSempreGeraChefe() {
        val contexto = context.copy(dangerLevel = 100, bossChance = 100.0)
        assertEquals(
            WorldEventType.BOSS,
            WorldDirector.generateEventForRoll(contexto, 0).type
        )
        assertEquals(
            WorldEventType.BOSS,
            WorldDirector.generateEventForRoll(contexto, 9_999).type
        )
    }

    @Test
    fun chanceNegativaDeChefeEhLimitadaAZero() {
        val contexto = context.copy(dangerLevel = 20, bossChance = -5.0)
        assertEquals(
            WorldEventType.ENCOUNTER,
            WorldDirector.generateEventForRoll(contexto, 0).type
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejeitaSorteioForaDaFaixa() {
        WorldDirector.generateEventForRoll(context, 10_000)
    }
}
