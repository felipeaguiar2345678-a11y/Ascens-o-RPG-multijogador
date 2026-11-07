
package br.com.ascensaodosoberano.world

enum class WorldRouteType {
    MAIN_ROAD,
    SECONDARY_ROAD,
    SEA_ROUTE
}

data class WorldRoute(
    val fromId: String,
    val toId: String,
    val type: WorldRouteType,
    val distance: Float
)

object WorldRouteSystem {

    // Conexões baseadas nas estradas do mapa de referência.
    // As distâncias são valores iniciais para o sistema de viagem.

    val routes = listOf(

        // Região Central
        WorldRoute("aurelia", "cidade_do_sol", WorldRouteType.MAIN_ROAD, 1.5f),
        WorldRoute("aurelia", "arkanis", WorldRouteType.MAIN_ROAD, 1.4f),
        WorldRoute("aurelia", "vila_esperanca", WorldRouteType.MAIN_ROAD, 1.2f),
        WorldRoute("aurelia", "mina_dourada", WorldRouteType.SECONDARY_ROAD, 1.8f),
        WorldRoute("aurelia", "torre_sabedoria", WorldRouteType.SECONDARY_ROAD, 1.7f),
        WorldRoute("cidade_do_sol", "mina_dourada", WorldRouteType.SECONDARY_ROAD, 1.4f),
        WorldRoute("arkanis", "torre_sabedoria", WorldRouteType.SECONDARY_ROAD, 1.5f),

        // Floresta Arcana
        WorldRoute(
            "clareira_inicial",
            "aurelia",
            WorldRouteType.MAIN_ROAD,
            1.0f
        ),
        WorldRoute(
            "clareira_inicial",
            "vila_verdejante",
            WorldRouteType.SECONDARY_ROAD,
            1.4f
        ),
        WorldRoute("cidade_do_sol", "vila_verdejante", WorldRouteType.MAIN_ROAD, 2.0f),
        WorldRoute("vila_verdejante", "eldarion", WorldRouteType.MAIN_ROAD, 1.5f),
        WorldRoute("eldarion", "torre_natureza", WorldRouteType.SECONDARY_ROAD, 1.7f),
        WorldRoute("eldarion", "ruinas_elficas", WorldRouteType.SECONDARY_ROAD, 1.8f),

// Montanhas Gélidas
WorldRoute("cidade_do_sol", "fortaleza_glacial", WorldRouteType.MAIN_ROAD, 2.0f),
WorldRoute("fortaleza_glacial", "caverna_gelo", WorldRouteType.SECONDARY_ROAD, 1.6f),
        WorldRoute("fortaleza_glacial", "pico_aurora", WorldRouteType.SECONDARY_ROAD, 2.2f),

        // Império
        WorldRoute("cidade_do_sol", "valdracon", WorldRouteType.MAIN_ROAD, 2.0f),
        WorldRoute("valdracon", "forte_guarda", WorldRouteType.SECONDARY_ROAD, 1.4f),
        WorldRoute("valdracon", "vila_helios", WorldRouteType.SECONDARY_ROAD, 1.6f),
        WorldRoute("vila_helios", "catacumbas_reais", WorldRouteType.SECONDARY_ROAD, 1.7f),

        // Sombras
        WorldRoute("arkanis", "templo_sombrio", WorldRouteType.SECONDARY_ROAD, 2.0f),
        WorldRoute("templo_sombrio", "malachar", WorldRouteType.MAIN_ROAD, 1.8f),
        WorldRoute("malachar", "covil_mortos", WorldRouteType.SECONDARY_ROAD, 1.7f),
        WorldRoute("covil_mortos", "vila_necropole", WorldRouteType.SECONDARY_ROAD, 1.5f),

        // Deserto Ancestral
        WorldRoute("mina_dourada", "tharion", WorldRouteType.MAIN_ROAD, 2.8f),
        WorldRoute("tharion", "oasis_perdido", WorldRouteType.SECONDARY_ROAD, 1.8f),
        WorldRoute("tharion", "ruinas_antigas", WorldRouteType.SECONDARY_ROAD, 1.6f),
        WorldRoute("tharion", "caverna_escorpiao", WorldRouteType.SECONDARY_ROAD, 2.0f),

        // Mar Eterno
        WorldRoute("vila_esperanca", "kyrath", WorldRouteType.MAIN_ROAD, 2.5f),
        WorldRoute("kyrath", "ilha_serpente", WorldRouteType.SEA_ROUTE, 2.0f),
        WorldRoute("kyrath", "torre_oceano", WorldRouteType.SEA_ROUTE, 2.2f)
    )

    fun routesFrom(pointId: String): List<WorldRoute> {
        return routes.filter {
            it.fromId == pointId || it.toId == pointId
        }
    }

    fun findRoute(
    startId: String,
    destinationId: String
): List<WorldRoute>? {

    if (startId == destinationId) {
        return emptyList()
    }

    val distances = mutableMapOf<String, Float>()
    val previous = mutableMapOf<String, WorldRoute>()

    val queue = java.util.PriorityQueue<Pair<String, Float>>(
        compareBy { it.second }
    )

    distances[startId] = 0f
    queue.add(startId to 0f)

    while (queue.isNotEmpty()) {

        val (current, currentDistance) = queue.poll()

        if (currentDistance > (distances[current] ?: Float.MAX_VALUE)) {
            continue
        }

        if (current == destinationId) {
            break
        }

        for (route in routesFrom(current)) {

            val next = if (route.fromId == current) {
                route.toId
            } else {
                route.fromId
            }

            val newDistance = currentDistance + route.distance
            val oldDistance = distances[next] ?: Float.MAX_VALUE

            if (newDistance < oldDistance) {
                distances[next] = newDistance
                previous[next] = route
                queue.add(next to newDistance)
            }
        }
    }

    if (destinationId !in previous) {
        return null
    }

    val result = mutableListOf<WorldRoute>()
    var cursor = destinationId

    while (cursor != startId) {

        val step = previous[cursor] ?: return null

        result.add(step)

        cursor = if (step.fromId == cursor) {
            step.toId
        } else {
            step.fromId
        }
    }

    return result.reversed()
}
    fun totalDistance(path: List<WorldRoute>): Float {
        return path.fold(0f) { total, route ->
            total + route.distance
        }
    }
    fun estimatedTravelTime(path: List<WorldRoute>): Float {
    return path.fold(0f) { total, route ->
        val speed = when (route.type) {
            WorldRouteType.MAIN_ROAD -> 1.0f
            WorldRouteType.SECONDARY_ROAD -> 0.7f
            WorldRouteType.SEA_ROUTE -> 1.2f
        }

        total + (route.distance / speed)
    }
}
}