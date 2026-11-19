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

    @Test fun regionalBossMissionCompletesAfterValidBossDefeat() {
        val mission = hunt.copy(
            title = "Chefe regional: Guardião da Clareira",
            type = "Chefe regional",
            objective = "Derrote o chefe regional Guardião da Clareira."
        )
        val result = MissionProgressEngine.apply(mission, MissionProgress(), MissionEvent(
            type = MissionEventType.REGIONAL_BOSS_DEFEATED,
            creatureId = "guardiao_clareira",
            creatureName = "Guardião da Clareira",
            creatureRank = "E",
            isBoss = true,
            regionId = "dark_forest",
            locationId = "clareira_inicial"
        ))
        assertTrue(result.accepted)
        assertTrue(result.newlyCompleted)
        assertTrue(result.progress.completed)
    }

    @Test fun regionalBossMissionRejectsBossAboveContractRank() {
        val mission = hunt.copy(title = "Chefe regional: Guardião", type = "Chefe regional")
        val result = MissionProgressEngine.apply(mission, MissionProgress(), MissionEvent(
            type = MissionEventType.REGIONAL_BOSS_DEFEATED,
            creatureId = "guardiao",
            creatureRank = "D",
            isBoss = true,
            regionId = "dark_forest",
            locationId = "clareira_inicial"
        ))
        assertFalse(result.accepted)
    }

    @Test fun collectionMissionRejectsDifferentMaterial() {
        val mission = hunt.copy(
            title = "Recolher ervas luminosas",
            type = "Coleta",
            objective = "Obtenha 5 unidades de ervas luminosas."
        )
        val result = MissionProgressEngine.apply(mission, MissionProgress(), MissionEvent(
            type = MissionEventType.MATERIAL_OBTAINED,
            itemId = "cristal_gelo",
            itemName = "Cristal de gelo",
            regionId = "dark_forest",
            locationId = "clareira_inicial"
        ))
        assertFalse(result.accepted)
        assertEquals(0, result.progress.counters["materials"] ?: 0)
    }

    @Test fun collectionMissionAcceptsRequestedMaterial() {
        val mission = hunt.copy(
            title = "Recolher ervas luminosas",
            type = "Coleta",
            objective = "Obtenha 5 unidades de ervas luminosas."
        )
        val result = MissionProgressEngine.apply(mission, MissionProgress(), MissionEvent(
            type = MissionEventType.MATERIAL_OBTAINED,
            itemId = "erva_luminosa",
            itemName = "Erva luminosa",
            amount = 5,
            regionId = "dark_forest",
            locationId = "clareira_inicial"
        ))
        assertTrue(result.accepted)
        assertTrue(result.newlyCompleted)
        assertEquals(5, result.progress.counters["materials"])
    }

    @Test fun everyNarrativeObjectiveTypeAcceptsOnlyItsMatchingEvent() {
        val cases = listOf(
            Triple("Exploração", MissionEventType.LOCATION_DISCOVERED, "locations"),
            Triple("Investigação", MissionEventType.EVIDENCE_FOUND, "evidence"),
            Triple("Escolta", MissionEventType.ESCORT_STEP_COMPLETED, "escort"),
            Triple("Proteção", MissionEventType.PROTECTED_TARGET_SURVIVED, "protection"),
            Triple("Rastreamento", MissionEventType.TRACKING_CLUE_FOUND, "tracking"),
            Triple("Purificação", MissionEventType.CORRUPTION_SOURCE_CLEARED, "purification")
        )
        for ((type, eventType, counter) in cases) {
            val mission = hunt.copy(type = type, title = "$type: objetivo regional", objective = "Conclua 1 etapa.")
            val result = MissionProgressEngine.apply(mission, MissionProgress(), MissionEvent(
                type = eventType,
                targetId = "etapa_confirmada",
                regionId = "dark_forest",
                locationId = "clareira_inicial"
            ))
            assertTrue("$type deveria aceitar seu evento", result.accepted)
            assertTrue("$type deveria concluir", result.newlyCompleted)
            assertEquals(1, result.progress.counters[counter])
        }
    }

    @Test fun rejectsEventsWithInvalidAmountOrWrongRegion() {
        val invalidAmount = MissionProgressEngine.apply(hunt, MissionProgress(), MissionEvent(
            type = MissionEventType.CREATURE_DEFEATED,
            amount = 0,
            creatureName = "Rato selvagem",
            creatureRank = "E",
            regionId = "dark_forest",
            locationId = "clareira_inicial"
        ))
        assertFalse(invalidAmount.accepted)

        val wrongRegion = MissionProgressEngine.apply(hunt, MissionProgress(), MissionEvent(
            type = MissionEventType.CREATURE_DEFEATED,
            creatureName = "Rato selvagem",
            creatureRank = "E",
            regionId = "forgotten_ruins",
            locationId = "clareira_inicial"
        ))
        assertFalse(wrongRegion.accepted)
    }

    @Test fun collectionCanResolveTargetFromMissionTitleWhenObjectiveHasNoQuantityPhrase() {
        val mission = hunt.copy(
            title = "Entregar um selo imperial",
            type = "Coleta",
            objective = "Entregue o selo imperial à Guilda."
        )
        val result = MissionProgressEngine.apply(mission, MissionProgress(), MissionEvent(
            type = MissionEventType.MATERIAL_OBTAINED,
            itemId = "selo_imperial",
            itemName = "Selo imperial",
            regionId = "dark_forest",
            locationId = "clareira_inicial"
        ))
        assertTrue(result.accepted)
        assertTrue(result.newlyCompleted)
    }

    @Test fun oneDefeatNeverCountsAsMultipleKills() {
        val result = MissionProgressEngine.apply(hunt, MissionProgress(), MissionEvent(
            type = MissionEventType.CREATURE_DEFEATED,
            amount = 999,
            creatureName = "Rato selvagem",
            creatureRank = "E",
            regionId = "dark_forest",
            locationId = "clareira_inicial"
        ))
        assertTrue(result.accepted)
        assertEquals(1, result.progress.counters["kills"])
        assertFalse(result.progress.completed)
    }

    @Test fun epicCollectionRequiresCompatibleCreatureAndArtifact() {
        val mission = hunt.copy(
            title = "Recolher cristais de gelo",
            type = "Coleta",
            objective = "Obtenha 1 unidade de cristais de gelo. Conclua em uma área perigosa e supere uma criatura de rank compatível. Recupere um artefato raro."
        )
        val material = MissionProgressEngine.apply(mission, MissionProgress(), MissionEvent(
            type = MissionEventType.MATERIAL_OBTAINED, itemId = "cristal_gelo", itemName = "Cristais de gelo",
            amount = 1, regionId = "dark_forest", locationId = "clareira_inicial"
        ))
        assertTrue(material.accepted)
        assertFalse(material.newlyCompleted)
        val creature = MissionProgressEngine.apply(mission, material.progress, MissionEvent(
            type = MissionEventType.CREATURE_DEFEATED, creatureId = "fera_e", creatureName = "Fera",
            creatureRank = "E", regionId = "dark_forest", locationId = "clareira_inicial"
        ))
        assertTrue(creature.accepted)
        assertFalse(creature.newlyCompleted)
        val artifact = MissionProgressEngine.apply(mission, creature.progress, MissionEvent(
            type = MissionEventType.MATERIAL_OBTAINED, itemId = "artefato_raro", itemName = "Artefato raro",
            targetId = "artifact", regionId = "dark_forest", locationId = "clareira_inicial"
        ))
        assertTrue(artifact.accepted)
        assertTrue(artifact.newlyCompleted)
    }

    @Test fun worldCollectionRequiresWorldBossRelicAndUniqueSample() {
        val mission = hunt.copy(
            title = "Contrato World: água ancestral", rank = "SSS", type = "Coleta",
            objective = "Obtenha 1 unidade de água ancestral e uma amostra única. Conclua em uma zona extrema, derrote um chefe World e recupere uma relíquia única."
        )
        val material = MissionProgressEngine.apply(mission, MissionProgress(), MissionEvent(
            type = MissionEventType.MATERIAL_OBTAINED, itemId = "agua_ancestral", itemName = "Água ancestral",
            amount = 1, regionId = "dark_forest", locationId = "clareira_inicial"
        ))
        assertTrue(material.accepted)
        val sample = MissionProgressEngine.apply(mission, material.progress, MissionEvent(
            type = MissionEventType.MATERIAL_OBTAINED, itemId = "amostra_unica", itemName = "Amostra única",
            targetId = "sample", regionId = "dark_forest", locationId = "clareira_inicial"
        ))
        assertTrue(sample.accepted)
        assertFalse(sample.newlyCompleted)
        val boss = MissionProgressEngine.apply(mission, sample.progress, MissionEvent(
            type = MissionEventType.REGIONAL_BOSS_DEFEATED, creatureId = "boss_world", creatureName = "Entidade World",
            creatureRank = "WORLD", isBoss = true, regionId = "dark_forest", locationId = "clareira_inicial"
        ))
        assertTrue(boss.accepted)
        assertFalse(boss.newlyCompleted)
        val relic = MissionProgressEngine.apply(mission, boss.progress, MissionEvent(
            type = MissionEventType.MATERIAL_OBTAINED, itemId = "reliquia_unica", itemName = "Relíquia única",
            targetId = "artifact", regionId = "dark_forest", locationId = "clareira_inicial"
        ))
        assertTrue(relic.accepted)
        assertTrue(relic.newlyCompleted)
    }
}
