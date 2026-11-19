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
        val evidence = MissionProgressEngine.apply(hunt, progress, MissionEvent(
            type = MissionEventType.EVIDENCE_FOUND, targetId = "prova_rato",
            regionId = "dark_forest", locationId = "clareira_inicial"
        ))
        assertTrue(evidence.accepted)
        assertFalse(evidence.newlyCompleted)
        progress = evidence.progress
        val final = MissionProgressEngine.apply(hunt, progress, MissionEvent(
            type = MissionEventType.CREATURE_DEFEATED, creatureName = "Rato selvagem",
            creatureRank = "E", regionId = "dark_forest", locationId = "clareira_inicial"
        ))
        assertTrue(final.accepted); assertTrue(final.newlyCompleted); assertTrue(final.progress.completed)
        assertEquals(3, final.progress.counters["kills"])
    }

    @Test fun matchesAiGeneratedCreatureNamesWithoutFixedEnemyDatabase() {
        val generatedTarget = hunt.copy(
            title = "Caçada: feras da nevasca",
            objective = "Derrote 3 feras da nevasca."
        )
        val result = MissionProgressEngine.apply(generatedTarget, MissionProgress(), MissionEvent(
            type = MissionEventType.CREATURE_DEFEATED,
            creatureId = "criatura_gerada_987",
            creatureName = "Lobo da Nevasca",
            creatureRank = "E",
            regionId = "dark_forest",
            locationId = "clareira_inicial"
        ))
        assertTrue(result.accepted)
        assertEquals(1, result.progress.counters["kills"])
    }

    @Test fun specialRankCollectionMissionCanStillRegisterItsMainObjective() {
        val specialGathering = hunt.copy(
            title = "Contrato lendário: ervas do eclipse",
            rank = "SS",
            type = "Coleta",
            objective = "Obtenha 5 unidades de ervas do eclipse.",
            special = true
        )
        val result = MissionProgressEngine.apply(specialGathering, MissionProgress(), MissionEvent(
            type = MissionEventType.MATERIAL_OBTAINED,
            itemId = "erva_eclipse_01",
            regionId = "dark_forest",
            locationId = "clareira_inicial"
        ))
        assertTrue(result.accepted)
        assertEquals(1, result.progress.counters["materials"])
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

    private val raid = GuildMission(
        id = "cripta_teste", title = "Raid de Masmorra: Cripta dos Primeiros Ossos",
        rank = "E", type = "Raid de masmorra", regionId = "forgotten_ruins",
        regionName = "Ruínas Esquecidas", destinationId = "ruinas_elficas",
        destinationName = "Ruínas Élficas", summary = "Teste",
        objective = "Conclua a incursão em etapas: atravesse a entrada, vença os grupos, encontre o núcleo e derrote o guardião final.",
        rewardGold = 55, rewardXp = 110, recommendedLevel = 1, special = true
    )

    @Test fun raidRequiresEveryUniqueStageIncludingFinalGuardian() {
        var progress = MissionProgress()
        val steps = listOf("entrada", "grupos", "nucleo")
        for (step in steps) {
            val result = MissionProgressEngine.apply(raid, progress, MissionEvent(
                type = MissionEventType.RAID_STEP_COMPLETED, targetId = step,
                regionId = "forgotten_ruins", locationId = "ruinas_elficas"
            ))
            assertTrue(result.accepted)
            assertFalse(result.newlyCompleted)
            progress = result.progress
        }
        val guardian = MissionProgressEngine.apply(raid, progress, MissionEvent(
            type = MissionEventType.REGIONAL_BOSS_DEFEATED, isBoss = true,
            creatureId = "guardiao_cripta", creatureRank = "E",
            regionId = "forgotten_ruins", locationId = "ruinas_elficas"
        ))
        assertTrue(guardian.accepted)
        assertTrue(guardian.newlyCompleted)
    }

    @Test fun raidRejectsDuplicateStageAndWrongDestination() {
        val first = MissionProgressEngine.apply(raid, MissionProgress(), MissionEvent(
            type = MissionEventType.RAID_STEP_COMPLETED, targetId = "entrada",
            regionId = "forgotten_ruins", locationId = "ruinas_elficas"
        ))
        val duplicate = MissionProgressEngine.apply(raid, first.progress, MissionEvent(
            type = MissionEventType.RAID_STEP_COMPLETED, targetId = "entrada",
            regionId = "forgotten_ruins", locationId = "ruinas_elficas"
        ))
        assertFalse(duplicate.accepted)
        val wrongPlace = MissionProgressEngine.apply(raid, first.progress, MissionEvent(
            type = MissionEventType.RAID_STEP_COMPLETED, targetId = "grupos",
            regionId = "forgotten_ruins", locationId = "clareira_inicial"
        ))
        assertFalse(wrongPlace.accepted)
    }

    @Test fun rejectsTheSameConfirmedEventTwice() {
        val event = MissionEvent(
            type = MissionEventType.CREATURE_DEFEATED,
            creatureName = "Rato selvagem",
            creatureRank = "E",
            regionId = "dark_forest",
            locationId = "clareira_inicial",
            eventId = "combate-solo-123"
        )
        val first = MissionProgressEngine.apply(hunt, MissionProgress(), event)
        assertTrue(first.accepted)
        val repeated = MissionProgressEngine.apply(hunt, first.progress, event)
        assertFalse(repeated.accepted)
        assertEquals(1, repeated.progress.counters["kills"])
        assertEquals(1, repeated.progress.processedEventIds.size)
    }

}
