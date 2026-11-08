package br.com.ascensaodosoberano.world

enum class WorldSceneKind {
    WILDERNESS,
    CAPITAL,
    CITY,
    VILLAGE,
    DUNGEON,
    TOWER,
    RUINS,
    LANDMARK
}

data class WorldSceneProfile(
    val locationId: String,
    val locationName: String,
    val region: WorldRegion?,
    val kind: WorldSceneKind,
    val cameraZoom: Float,
    val isSafeArea: Boolean
)

/**
 * Perfil visual/geográfico de cada localidade do mapa oficial.
 *
 * A câmera usa este perfil para aproximar suavemente ao entrar em cidades,
 * vilas e pontos de interesse, sem teletransportar o jogador nem alterar
 * a posição compartilhada no mundo.
 */
object WorldSceneCatalog {

    private val unknown = WorldSceneProfile(
        locationId = "",
        locationName = "Terras Selvagens",
        region = null,
        kind = WorldSceneKind.WILDERNESS,
        cameraZoom = 1f,
        isSafeArea = false
    )

    fun profileFor(locationId: String): WorldSceneProfile {
        val point = WorldMapData.findPoint(locationId) ?: return unknown.copy(
            locationId = locationId
        )

        val kind = when (point.type) {
            WorldPointType.CAPITAL -> WorldSceneKind.CAPITAL
            WorldPointType.CITY -> WorldSceneKind.CITY
            WorldPointType.VILLAGE -> WorldSceneKind.VILLAGE
            WorldPointType.DUNGEON -> WorldSceneKind.DUNGEON
            WorldPointType.TOWER -> WorldSceneKind.TOWER
            WorldPointType.RUINS -> WorldSceneKind.RUINS
            WorldPointType.LANDMARK -> WorldSceneKind.LANDMARK
        }

        val zoom = when (kind) {
            WorldSceneKind.CAPITAL -> 1.28f
            WorldSceneKind.CITY -> 1.23f
            WorldSceneKind.VILLAGE -> 1.16f
            WorldSceneKind.DUNGEON,
            WorldSceneKind.TOWER,
            WorldSceneKind.RUINS -> 1.20f
            WorldSceneKind.LANDMARK,
            WorldSceneKind.WILDERNESS -> 1f
        }

        return WorldSceneProfile(
            locationId = point.id,
            locationName = point.name,
            region = point.region,
            kind = kind,
            cameraZoom = zoom,
            isSafeArea = kind == WorldSceneKind.CAPITAL ||
                kind == WorldSceneKind.CITY ||
                kind == WorldSceneKind.VILLAGE
        )
    }
}
