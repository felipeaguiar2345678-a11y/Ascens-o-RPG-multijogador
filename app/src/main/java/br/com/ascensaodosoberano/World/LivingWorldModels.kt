package br.com.ascensaodosoberano.world

/**
 * Modelo de domínio para a simulação persistente do mundo compartilhado.
 * Estes tipos não fazem chamadas de rede: o servidor deverá persistir e avançar
 * os estados usando o mesmo conjunto de regras para todos os jogadores.
 */

enum class NpcNeed {
    FOOD, WATER, REST, SAFETY, BELONGING, MEDICINE
}

enum class NpcActivity {
    SLEEPING, WORKING, TRAVELLING, TRADING, EATING, SOCIALIZING, GUARDING, SEEKING_HELP
}

data class NpcRoutineEntry(
    val startHour: Int,
    val endHour: Int,
    val activity: NpcActivity,
    val locationId: String
) {
    fun contains(hour: Int): Boolean =
        if (startHour <= endHour) hour in startHour until endHour
        else hour >= startHour || hour < endHour
}

data class NpcWorldState(
    val id: String,
    val name: String,
    val homeLocationId: String,
    val currentLocationId: String,
    val factionId: String? = null,
    val alive: Boolean = true,
    val needs: Map<NpcNeed, Int> = NpcNeed.entries.associateWith { 0 },
    val routine: List<NpcRoutineEntry> = emptyList(),
    val memoryFlags: Set<String> = emptySet(),
    val activeProblemIds: Set<String> = emptySet(),
    val lastSimulationEpochMillis: Long = 0L
) {
    fun activityAt(hour: Int): NpcRoutineEntry? =
        routine.firstOrNull { it.contains(hour.coerceIn(0, 23)) }
}

enum class WorldProblemStatus {
    AVAILABLE, ACCEPTED, RESOLVED, FAILED, EXPIRED
}

enum class WorldConsequenceType {
    POPULATION, PROSPERITY, SECURITY, FACTION_REPUTATION, RESOURCE_STOCK, TERRITORY_CONTROL
}

data class WorldConsequence(
    val type: WorldConsequenceType,
    val targetId: String,
    val amount: Int,
    val description: String
)

data class NpcWorldProblem(
    val id: String,
    val title: String,
    val description: String,
    val issuerNpcId: String,
    val locationId: String,
    val status: WorldProblemStatus = WorldProblemStatus.AVAILABLE,
    val requiredItemIds: Map<String, Int> = emptyMap(),
    val requiredCreatureSpeciesIds: Map<String, Int> = emptyMap(),
    val prerequisiteProblemIds: Set<String> = emptySet(),
    val successConsequences: List<WorldConsequence> = emptyList(),
    val failureConsequences: List<WorldConsequence> = emptyList(),
    val expiresAtEpochMillis: Long? = null
)

data class SettlementWorldState(
    val id: String,
    val name: String,
    val population: Int,
    val prosperity: Int = 50,
    val security: Int = 50,
    val foodStock: Int = 50,
    val medicineStock: Int = 0,
    val controllingFactionId: String? = null,
    val besiegingFactionId: String? = null,
    val siegeProgress: Int = 0,
    val lastSimulationEpochMillis: Long = 0L
)

data class FactionWorldState(
    val id: String,
    val name: String,
    val strength: Int,
    val controlledSettlementIds: Set<String> = emptySet(),
    val relations: Map<String, Int> = emptyMap()
)

data class CreatureEcologyState(
    val speciesId: String,
    val ecosystemId: String,
    val population: Int,
    val foodAvailability: Int = 50,
    val territorialPressure: Int = 0,
    val generation: Int = 1,
    val evolutionProgress: Int = 0,
    val inheritedTraits: Set<String> = emptySet(),
    val lastSimulationEpochMillis: Long = 0L
)

data class CreatureEcologyChange(
    val populationDelta: Int,
    val evolutionProgressDelta: Int,
    val newGeneration: Int,
    val unlockedTrait: String? = null
)

object LivingWorldRules {
    fun advanceNpcNeeds(
        npc: NpcWorldState,
        elapsedHours: Int,
        dangerAtLocation: Int
    ): NpcWorldState {
        if (!npc.alive || elapsedHours <= 0) return npc
        val danger = dangerAtLocation.coerceIn(0, 100)
        val needs = npc.needs.toMutableMap()
        needs[NpcNeed.FOOD] = ((needs[NpcNeed.FOOD] ?: 0) + elapsedHours * 3).coerceAtMost(100)
        needs[NpcNeed.WATER] = ((needs[NpcNeed.WATER] ?: 0) + elapsedHours * 5).coerceAtMost(100)
        needs[NpcNeed.REST] = ((needs[NpcNeed.REST] ?: 0) + elapsedHours * 2).coerceAtMost(100)
        needs[NpcNeed.SAFETY] = ((needs[NpcNeed.SAFETY] ?: 0) + danger * elapsedHours / 20).coerceAtMost(100)
        return npc.copy(needs = needs)
    }

    fun activityFor(npc: NpcWorldState, hour: Int): NpcActivity =
        npc.activityAt(hour)?.activity ?: NpcActivity.SOCIALIZING

    fun canOfferProblem(
        problem: NpcWorldProblem,
        completedProblemIds: Set<String>,
        nowEpochMillis: Long
    ): Boolean =
        problem.status == WorldProblemStatus.AVAILABLE &&
            problem.prerequisiteProblemIds.all { it in completedProblemIds } &&
            (problem.expiresAtEpochMillis == null || nowEpochMillis < problem.expiresAtEpochMillis)

    fun advanceEcology(
        ecology: CreatureEcologyState,
        elapsedDays: Int,
        huntingPressure: Int
    ): Pair<CreatureEcologyState, CreatureEcologyChange> {
        if (elapsedDays <= 0) return ecology to CreatureEcologyChange(0, 0, ecology.generation)
        val food = ecology.foodAvailability.coerceIn(0, 100)
        val hunting = huntingPressure.coerceIn(0, 100)
        val pressure = ecology.territorialPressure.coerceIn(0, 100)
        val populationDelta = when {
            hunting >= 70 -> -elapsedDays.coerceAtMost(10)
            food >= 65 && pressure <= 45 -> elapsedDays.coerceAtMost(10)
            food <= 20 || pressure >= 85 -> -(elapsedDays / 2).coerceAtLeast(1)
            else -> 0
        }
        val evolutionDelta = (elapsedDays * (1 + pressure / 25) + hunting / 20).coerceAtMost(100)
        val totalProgress = ecology.evolutionProgress + evolutionDelta
        val evolved = totalProgress >= 100
        val trait = if (evolved) when {
            hunting >= 60 -> "CAÇADOR_ESQUIVO"
            pressure >= 60 -> "ADAPTAÇÃO_TERRITORIAL"
            food <= 25 -> "RESISTÊNCIA À ESCASSEZ"
            else -> "VIGOR_ADAPTATIVO"
        } else null
        val nextGeneration = if (evolved) ecology.generation + 1 else ecology.generation
        val next = ecology.copy(
            population = (ecology.population + populationDelta).coerceAtLeast(0),
            generation = nextGeneration,
            evolutionProgress = if (evolved) totalProgress - 100 else totalProgress,
            inheritedTraits = if (trait == null) ecology.inheritedTraits else ecology.inheritedTraits + trait
        )
        return next to CreatureEcologyChange(populationDelta, evolutionDelta, nextGeneration, trait)
    }

    fun advanceSiege(settlement: SettlementWorldState, dailyPressure: Int): SettlementWorldState {
        if (settlement.besiegingFactionId.isNullOrBlank() || dailyPressure <= 0) return settlement
        val progress = (settlement.siegeProgress + dailyPressure.coerceAtMost(100)).coerceAtMost(100)
        return if (progress >= 100) settlement.copy(
            controllingFactionId = settlement.besiegingFactionId,
            besiegingFactionId = null,
            siegeProgress = 0,
            security = (settlement.security - 20).coerceAtLeast(0)
        ) else settlement.copy(siegeProgress = progress)
    }
}
