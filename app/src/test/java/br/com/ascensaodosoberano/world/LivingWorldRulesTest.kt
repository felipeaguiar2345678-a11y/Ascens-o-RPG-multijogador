package br.com.ascensaodosoberano.world

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LivingWorldRulesTest {
    @Test
    fun necessidadesDosNpcsAumentamComTempoEPerigo() {
        val npc = NpcWorldState(
            id = "guarda_01",
            name = "Aren",
            homeLocationId = "vila_verdejante",
            currentLocationId = "vila_verdejante"
        )
        val atualizado = LivingWorldRules.advanceNpcNeeds(npc, elapsedHours = 4, dangerAtLocation = 80)
        assertEquals(12, atualizado.needs[NpcNeed.FOOD])
        assertEquals(20, atualizado.needs[NpcNeed.WATER])
        assertEquals(8, atualizado.needs[NpcNeed.REST])
        assertEquals(16, atualizado.needs[NpcNeed.SAFETY])
    }

    @Test
    fun rotinaDoNpcAceitaHorarioQueAtravessaMeiaNoite() {
        val npc = NpcWorldState(
            id = "vigia",
            name = "Vigia",
            homeLocationId = "portao",
            currentLocationId = "portao",
            routine = listOf(NpcRoutineEntry(22, 6, NpcActivity.GUARDING, "portao"))
        )
        assertEquals(NpcActivity.GUARDING, LivingWorldRules.activityFor(npc, 23))
        assertEquals(NpcActivity.GUARDING, LivingWorldRules.activityFor(npc, 3))
        assertEquals(NpcActivity.SOCIALIZING, LivingWorldRules.activityFor(npc, 12))
    }

    @Test
    fun problemaSoFicaDisponivelAposPreRequisitosEAntesDoPrazo() {
        val problem = NpcWorldProblem(
            id = "remedio_vila",
            title = "Remédios para a vila",
            description = "A curandeira precisa de ervas.",
            issuerNpcId = "curandeira",
            locationId = "vila_verdejante",
            prerequisiteProblemIds = setOf("ervas_perdidas"),
            expiresAtEpochMillis = 10_000L
        )
        assertFalse(LivingWorldRules.canOfferProblem(problem, emptySet(), 5_000L))
        assertTrue(LivingWorldRules.canOfferProblem(problem, setOf("ervas_perdidas"), 5_000L))
        assertFalse(LivingWorldRules.canOfferProblem(problem, setOf("ervas_perdidas"), 10_000L))
    }

    @Test
    fun ecologiaPodeAumentarPopulacaoEDesbloquearAdaptacao() {
        val ecology = CreatureEcologyState(
            speciesId = "lobo_musgo",
            ecosystemId = "dark_forest",
            population = 12,
            foodAvailability = 90,
            territorialPressure = 70,
            evolutionProgress = 90
        )
        val (next, change) = LivingWorldRules.advanceEcology(ecology, elapsedDays = 3, huntingPressure = 10)
        assertEquals(12, next.population)
        assertEquals(2, next.generation)
        assertEquals("ADAPTAÇÃO_TERRITORIAL", change.unlockedTrait)
        assertTrue("ADAPTAÇÃO_TERRITORIAL" in next.inheritedTraits)
    }

    @Test
    fun populacaoCresceQuandoHaAlimentoEPoucaPressaoTerritorial() {
        val ecology = CreatureEcologyState(
            speciesId = "coelho_lunar",
            ecosystemId = "arcane_forest",
            population = 8,
            foodAvailability = 90,
            territorialPressure = 20
        )
        val (next, change) = LivingWorldRules.advanceEcology(ecology, elapsedDays = 3, huntingPressure = 0)
        assertEquals(11, next.population)
        assertEquals(3, change.populationDelta)
    }

    @Test
    fun cercoConcluidoMudaControleDoPovoado() {
        val settlement = SettlementWorldState(
            id = "vila_verdejante",
            name = "Vila Verdejante",
            population = 120,
            controllingFactionId = "guarda_verde",
            besiegingFactionId = "bando_cinzento",
            siegeProgress = 80,
            security = 60
        )
        val next = LivingWorldRules.advanceSiege(settlement, dailyPressure = 25)
        assertEquals("bando_cinzento", next.controllingFactionId)
        assertEquals(null, next.besiegingFactionId)
        assertEquals(0, next.siegeProgress)
        assertEquals(40, next.security)
    }
}
