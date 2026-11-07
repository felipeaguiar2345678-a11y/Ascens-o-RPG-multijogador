package br.com.ascensaodosoberano.world

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WorldSystemsTest {
    @Test
    fun cicloGlobalTemDezMinutosDeDiaECincoDeNoite() {
        assertEquals(WorldTimePhase.DAY, WorldCycleSystem.calculate(0L).phase)
        assertEquals(WorldTimePhase.SUNSET, WorldCycleSystem.calculate(540_000L).phase)
        assertEquals(WorldTimePhase.NIGHT, WorldCycleSystem.calculate(600_000L).phase)
        assertEquals(WorldTimePhase.DAWN, WorldCycleSystem.calculate(840_000L).phase)
        assertEquals(WorldTimePhase.DAY, WorldCycleSystem.calculate(900_000L).phase)
        assertTrue(WorldCycleSystem.calculate(600_000L).isNight)
        assertTrue(WorldCycleSystem.calculate(840_000L).isNight)
        assertFalse(WorldCycleSystem.calculate(540_000L).isNight)
    }

    @Test
    fun aureliaNuncaPodeSerConquistada() {
        val state = PersistentWorldState(
            lastSimulatedAtMillis = 0L,
            populations = listOf(
                WorldPopulation("criatura-gerada", "aurelia", 10_000, 100)
            ),
            settlements = listOf(
                WorldSettlement("aurelia", "Aurelia", "aurelia", 1, isAurelia = true)
            )
        )
        val result = PersistentWorldSimulation.advance(state, PersistentWorldSimulation.INTERVAL_MILLIS)
        assertFalse(result.state.settlements.single().condition == SettlementCondition.CONQUERED)
        assertEquals(SettlementCondition.BESIEGED, result.state.settlements.single().condition)
    }

    @Test
    fun reconquistaSoComecaDepoisDoUltimoInvasor() {
        val state = PersistentWorldState(
            lastSimulatedAtMillis = 0L,
            populations = emptyList(),
            settlements = listOf(
                WorldSettlement(
                    id = "malachar", name = "Malachar", ecosystemId = "malachar",
                    defense = 10, hostileInvaders = 2,
                    condition = SettlementCondition.CONQUERED
                )
            )
        )
        val first = PersistentWorldSimulation.defeatInvader(state, "malachar")
        assertEquals(SettlementCondition.RECONQUEST, first.settlements.single().condition)
        assertEquals(1, first.settlements.single().hostileInvaders)

        val second = PersistentWorldSimulation.defeatInvader(first, "malachar")
        assertEquals(SettlementCondition.RECOVERING, second.settlements.single().condition)
        assertEquals(0, second.settlements.single().hostileInvaders)
    }
}
