package br.com.ascensaodosoberano.exploration

import org.junit.Assert.*
import org.junit.Test

class MissionProgressEngineTest {
    private val hunt = GuildMission(
        id = "ratos_clareira", title = "Caçada: ratos da clareira", rank = "E",
        type = "Caçada", regionId = "dark_forest", regionName = "Floresta Arcana",
        destinationId = "clareira_inicial", destinationName = "Clareira Inicial",
        summary = "Teste",
        objective = "Derrote 3 ratos selvagens de rank E e recolha provas da ameaça.",
        rewardGold = 52, rewardXp = 105, recommendedLevel = 1
    )

    @Test fun countsValidKillsUntilHuntCompletes() {
        var progress = MissionProgress()
        repeat(2) {
            val result = MissionProgressEngine.apply(hunt, progress, MissionEvent(
                type = MissionEventType.CREATURE_DEFEATED, creatureName = "Rato selvagem",
                creatureRank = "E", regionId = "dark_forest", locationId = "clareira_inicial"
            ))
            assertTrue(result.accepted); assertFalse(result.newlyCompleted); progress = result.progress
        }
        val final = MissionProgressEngine.apply(hunt, progress, MissionEvent(
            type = MissionEventType.CREATURE_DEFEATED, creatureName = "Rato selvagem",
            creatureRank = "E", regionId = "dark_forest", locationId = "clareira_inicial"
        ))
        assertTrue(final.accepted); assertTrue(final.newlyCompleted); assertTrue(final.progress.completed)
        assertEquals(3, final.progress.counters["kills"])
    }

    @Test fun rejectsCreatureAboveContractRank() {
        val result = MissionProgressEngine.apply(hunt, MissionProgress(), MissionEvent(
            type = MissionEventType.CREATURE_DEFEATED, creatureName = "Rato selvagem",
            creatureRank = "D", regionId = "dark_forest", locationId = "clareira_inicial"
        ))
        assertFalse(result.accepted); assertFalse(result.progress.completed)
    }

    @Test fun rejectsCreatureFromAnotherLocation() {
        val result = MissionProgressEngine.apply(hunt, MissionProgress(), MissionEvent(
            type = MissionEventType.CREATURE_DEFEATED, creatureName = "Rato selvagem",
            creatureRank = "E", regionId = "dark_forest", locationId = "ruinas_elficas"
        ))
        assertFalse(result.accepted)
    }

    @Test fun rejectsProgressAfterCompletion() {
        val completed = MissionProgress(mapOf("kills" to 3), true)
        val result = MissionProgressEngine.apply(hunt, completed, MissionEvent(
            type = MissionEventType.CREATURE_DEFEATED, creatureName = "Rato selvagem",
            creatureRank = "E", regionId = "dark_forest", locationId = "clareira_inicial"
        ))
        assertFalse(result.accepted); assertFalse(result.newlyCompleted)
        assertEquals(3, result.progress.counters["kills"])
    }
}