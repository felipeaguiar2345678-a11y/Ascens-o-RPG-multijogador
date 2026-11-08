package br.com.ascensaodosoberano.world

import kotlin.math.max
import kotlin.math.min

enum class SettlementCondition {
    NORMAL, THREATENED, BESIEGED, CONQUERED, RECONQUEST, RECOVERING
}

data class WorldPopulation(
    val speciesId: String = "",
    val ecosystemId: String = "",
    val population: Int = 0,
    val danger: Int = 1,
    val rank: String = "E",
    val hasNest: Boolean = false,
    val hasLeader: Boolean = false
)

data class WorldSettlement(
    val id: String = "",
    val name: String = "",
    val ecosystemId: String = "",
    val defense: Int = 1,
    val hostileInvaders: Int = 0,
    val condition: SettlementCondition = SettlementCondition.NORMAL,
    val recoveryProgress: Int = 0,
    val isAurelia: Boolean = false
)

data class WorldHistoryEvent(
    val id: String = "",
    val type: String = "",
    val locationId: String = "",
    val description: String = "",
    val occurredAtMillis: Long = 0
)

data class PersistentWorldState(
    val lastSimulatedAtMillis: Long = 0,
    val populations: List<WorldPopulation> = emptyList(),
    val settlements: List<WorldSettlement> = emptyList(),
    val history: List<WorldHistoryEvent> = emptyList(),
    val simulationRevision: Long = 0
)

data class WorldAdvanceResult(
    val state: PersistentWorldState,
    val elapsedIntervals: Int,
    val eventsCreated: Int
)

/**
 * Simulação por intervalos de 15 minutos: o mundo avança mesmo sem jogadores online.
 * O horário atual deve vir de uma fonte confiável do servidor, nunca de input do jogador.
 */
object PersistentWorldSimulation {
    const val INTERVAL_MILLIS = 15L * 60L * 1000L
    private const val MAX_CATCH_UP_INTERVALS = 30 * 24 * 4

    fun advance(state: PersistentWorldState, trustedServerNowMillis: Long): WorldAdvanceResult {
        val elapsed = ((trustedServerNowMillis - state.lastSimulatedAtMillis) / INTERVAL_MILLIS)
            .coerceIn(0L, MAX_CATCH_UP_INTERVALS.toLong()).toInt()
        if (elapsed <= 0) return WorldAdvanceResult(state, 0, 0)

        var populations = state.populations
        var settlements = state.settlements
        val events = mutableListOf<WorldHistoryEvent>()

        repeat(elapsed) { interval ->
            val simulatedAt = state.lastSimulatedAtMillis + (interval + 1L) * INTERVAL_MILLIS

            populations = populations.map { population ->
                val pressure = population.danger.coerceIn(1, 100)
                val growth = when {
                    population.population <= 0 -> 0
                    pressure >= 80 -> 1
                    pressure >= 45 -> 2
                    else -> 3
                }
                val nextPopulation = (population.population + growth).coerceAtMost(10_000)
                population.copy(
                    population = nextPopulation,
                    hasNest = population.hasNest || nextPopulation >= 12,
                    hasLeader = population.hasLeader || nextPopulation >= 30
                )
            }

            settlements = settlements.map { city ->
                if (city.isAurelia) {
                    // Aurelia pode sofrer cerco, mas nunca muda para CONQUERED.
                    val pressure = populations.filter { it.ecosystemId == city.ecosystemId }
                        .sumOf { (it.population / 25).coerceAtMost(8) }
                    val threatened = pressure >= city.defense
                    if (threatened && city.condition == SettlementCondition.NORMAL) {
                        events += WorldHistoryEvent(
                            "siege-${city.id}-$simulatedAt", "CERCO", city.id,
                            "Criaturas se aproximaram das defesas de Aurelia.", simulatedAt
                        )
                        city.copy(condition = SettlementCondition.BESIEGED)
                    } else if (!threatened && city.condition == SettlementCondition.BESIEGED) {
                        city.copy(condition = SettlementCondition.NORMAL)
                    } else city
                } else {
                    when (city.condition) {
                        SettlementCondition.CONQUERED -> city
                        SettlementCondition.RECOVERING -> {
                            val progress = city.recoveryProgress + 1
                            if (progress >= 8) {
                                events += WorldHistoryEvent(
                                    "rebuilt-${city.id}-$simulatedAt", "RECONSTRUCAO", city.id,
                                    "${city.name} concluiu uma etapa importante da reconstrução.", simulatedAt
                                )
                                city.copy(condition = SettlementCondition.NORMAL, recoveryProgress = 0)
                            } else city.copy(condition = SettlementCondition.RECOVERING, recoveryProgress = progress)
                        }
                        else -> {
                            val pressure = populations.filter { it.ecosystemId == city.ecosystemId }
                                .sumOf { (it.population / 20).coerceAtMost(10) }
                            val hostile = if (pressure >= city.defense / 2) city.hostileInvaders + 1
                                else (city.hostileInvaders - 1).coerceAtLeast(0)
                            val nextCondition = when {
                                hostile >= city.defense * 2 -> SettlementCondition.CONQUERED
                                hostile >= city.defense -> SettlementCondition.BESIEGED
                                hostile >= city.defense / 2 -> SettlementCondition.THREATENED
                                else -> SettlementCondition.NORMAL
                            }
                            if (nextCondition != city.condition) {
                                val type = if (nextCondition == SettlementCondition.CONQUERED) "CONQUISTA" else "AMEACA"
                                events += WorldHistoryEvent(
                                    "$type-${city.id}-$simulatedAt", type, city.id,
                                    when (nextCondition) {
                                        SettlementCondition.CONQUERED -> "${city.name} foi tomada por forças hostis."
                                        SettlementCondition.BESIEGED -> "${city.name} está sob cerco."
                                        SettlementCondition.THREATENED -> "${city.name} está ameaçada."
                                        else -> "${city.name} voltou a ficar estável."
                                    }, simulatedAt
                                )
                            }
                            city.copy(
                                hostileInvaders = hostile,
                                condition = if (city.isAurelia && nextCondition == SettlementCondition.CONQUERED)
                                    SettlementCondition.BESIEGED else nextCondition
                            )
                        }
                    }
                }
            }
        }

        val updated = state.copy(
            lastSimulatedAtMillis = state.lastSimulatedAtMillis + elapsed * INTERVAL_MILLIS,
            populations = populations,
            settlements = settlements,
            history = (state.history + events).takeLast(500),
            simulationRevision = state.simulationRevision + elapsed
        )
        return WorldAdvanceResult(updated, elapsed, events.size)
    }

    /** Cada inimigo precisa ser derrotado. Só o último inicia a reconquista. */
    fun defeatInvader(state: PersistentWorldState, settlementId: String): PersistentWorldState {
        val updated = state.settlements.map { city ->
            if (city.id != settlementId || city.isAurelia ||
                city.condition !in setOf(SettlementCondition.CONQUERED, SettlementCondition.BESIEGED, SettlementCondition.RECONQUEST)
            ) city
            else {
                val remaining = max(0, city.hostileInvaders - 1)
                if (remaining == 0) city.copy(
                    hostileInvaders = 0,
                    condition = SettlementCondition.RECOVERING,
                    recoveryProgress = 0
                ) else city.copy(
                    hostileInvaders = remaining,
                    condition = SettlementCondition.RECONQUEST
                )
            }
        }
        return state.copy(settlements = updated)
    }
}
