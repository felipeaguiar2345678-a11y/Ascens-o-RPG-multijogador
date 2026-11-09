package br.com.ascensaodosoberano.world

import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class AutonomousAdventurerAITest {

    private fun adventurer(
        health: Int = 100,
        stamina: Int = 100,
        missionId: String? = null,
        personality: AdventurerPersonality = AdventurerPersonality(
            temperament = AdventurerTemperament.CURIOSO,
            courage = 65,
            ambition = 70,
            curiosity = 80,
            sociability = 55,
            loyalty = 60,
            caution = 35
        )
    ) = AutonomousAdventurer(
        id = "npc-1",
        displayName = "Lia",
        role = AdventurerRole.EXPLORADOR,
        level = 10,
        health = health,
        maxHealth = 100,
        stamina = stamina,
        maxStamina = 100,
        worldPointId = "vila_verdejante",
        personality = personality,
        currentMissionId = missionId
    )

    @Test
    fun woundedAdventurerSeeksShelter() {
        val world = AdventurerWorldSnapshot(
            worldPointId = "floresta",
            regionId = "floresta_arcana",
            danger = 70,
            hasShelter = true,
            currentEpochMillis = 1_000_000L
        )
        val result = AutonomousAdventurerAI.decide(adventurer(health = 10), world, Random(1))
        assertEquals(AdventurerActionType.PROCURAR_ABRIGO, result.action)
        assertEquals(100, result.priority)
    }

    @Test
    fun criticallyWoundedAdventurerRestsInSafeZone() {
        val world = AdventurerWorldSnapshot(
            worldPointId = "aurelia",
            regionId = "aurelia",
            isSettlement = true,
            isSafeZone = true,
            currentEpochMillis = 1_000_000L
        )
        val result = AutonomousAdventurerAI.decide(adventurer(health = 15), world, Random(2))
        assertEquals(AdventurerActionType.DESCANSAR, result.action)
    }

    @Test
    fun adventurerContinuesAcceptedMission() {
        val world = AdventurerWorldSnapshot(
            worldPointId = "floresta_arcana",
            regionId = "floresta_arcana",
            currentEpochMillis = 1_000_000L
        )
        val result = AutonomousAdventurerAI.decide(
            adventurer(missionId = "missao-raiz-antiga"), world, Random(3)
        )
        assertEquals(AdventurerActionType.CONTINUAR_MISSAO, result.action)
        assertEquals("missao-raiz-antiga", result.missionId)
    }

    @Test
    fun compatibleMissionCanBeAccepted() {
        val mission = AdventurerMissionOffer(
            id = "proteger-vila",
            recommendedLevel = 10,
            danger = 25,
            rewardGold = 100,
            rewardExperience = 150,
            targetWorldPointId = "vila_verdejante"
        )
        val world = AdventurerWorldSnapshot(
            worldPointId = "aurelia",
            regionId = "aurelia",
            isSettlement = true,
            availableMissionOffers = listOf(mission),
            currentEpochMillis = 1_000_000L
        )
        val result = AutonomousAdventurerAI.decide(adventurer(), world, Random(4))
        assertEquals(AdventurerActionType.ACEITAR_MISSAO, result.action)
        assertEquals("proteger-vila", result.missionId)
        assertNotNull(result.destinationWorldPointId)
    }

    @Test
    fun decisionRespectsCooldown() {
        val world = AdventurerWorldSnapshot(
            worldPointId = "aurelia",
            regionId = "aurelia",
            currentEpochMillis = 2_000_000L
        )
        val npc = adventurer().copy(decisionCooldownUntilEpochMillis = 3_000_000L)
        val result = AutonomousAdventurerAI.decide(npc, world, Random(5))
        assertEquals(AdventurerActionType.AGUARDAR, result.action)
    }
}
