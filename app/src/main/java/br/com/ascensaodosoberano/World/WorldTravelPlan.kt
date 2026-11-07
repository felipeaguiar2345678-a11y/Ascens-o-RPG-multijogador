package br.com.ascensaodosoberano.world

data class WorldTravelPlan(
    val origin: WorldMapPoint,
    val destination: WorldMapPoint,
    val route: List<WorldRoute>,
    val totalDistance: Float,
    val estimatedTime: Float
)

object WorldTravelPlanner {

    fun createPlan(
        startId: String,
        destinationId: String
    ): WorldTravelPlan? {

        // Verifica se os dois locais existem.
        val origin = WorldMapData.findPoint(startId)
            ?: return null

        val destination = WorldMapData.findPoint(destinationId)
            ?: return null

        // Calcula o caminho.
        val route = WorldRouteSystem.findRoute(
            startId,
            destinationId
        ) ?: return null

        // Calcula distância e duração.
        val distance = WorldRouteSystem.totalDistance(route)

        val time = WorldRouteSystem.estimatedTravelTime(route)

        return WorldTravelPlan(
            origin = origin,
            destination = destination,
            route = route,
            totalDistance = distance,
            estimatedTime = time
        )
    }
}