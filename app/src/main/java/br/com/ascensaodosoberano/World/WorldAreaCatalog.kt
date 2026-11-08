package br.com.ascensaodosoberano.world

/**
 * O mundo é carregado em áreas contínuas e independentes, conectadas por passagens.
 * Os pontos do mapa global continuam servindo como referência geográfica e de viagem;
 * areaId identifica o cenário local completo que os jogadores compartilham.
 */
enum class WorldAreaId {
    FLORESTA_ARCANA,
    MONTANHAS_GELIDAS,
    REGIAO_CENTRAL,
    IMPERIO,
    TERRAS_DAS_SOMBRAS,
    DESERTO_ANCESTRAL,
    MAR_ETERNAL
}

data class AreaSpawn(
    val x: Float,
    val y: Float
)

data class AreaGate(
    val id: String,
    val name: String,
    val targetArea: WorldAreaId,
    val targetSpawn: AreaSpawn,
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float
) {
    fun contains(x: Float, y: Float): Boolean =
        x in left..right && y in top..bottom
}

data class WorldAreaDefinition(
    val id: WorldAreaId,
    val name: String,
    val region: WorldRegion,
    val ecosystemId: String,
    val biomeKey: String,
    val spawn: AreaSpawn,
    val pointIds: Set<String>,
    val gates: List<AreaGate>,
    val playable: Boolean
)

data class AreaTransition(
    val from: WorldAreaId,
    val to: WorldAreaId,
    val gateId: String,
    val gateName: String,
    val spawn: AreaSpawn
)

object WorldAreaCatalog {
    private val areas = listOf(
        WorldAreaDefinition(
            id = WorldAreaId.FLORESTA_ARCANA,
            name = "Floresta Arcana",
            region = WorldRegion.FLORESTA_ARCANA,
            ecosystemId = "dark_forest",
            biomeKey = "floresta_arcana",
            spawn = AreaSpawn(0.52f, 0.78f),
            pointIds = setOf(
                "clareira_inicial", "eldarion", "vila_verdejante",
                "torre_natureza", "ruinas_elficas"
            ),
            gates = emptyList(),
            playable = true
        ),
        WorldAreaDefinition(
            id = WorldAreaId.MONTANHAS_GELIDAS,
            name = "Montanhas Gélidas",
            region = WorldRegion.MONTANHAS_GELIDAS,
            ecosystemId = "frost_mountains",
            biomeKey = "montanhas_gelidas",
            spawn = AreaSpawn(0.18f, 0.88f),
            pointIds = setOf("fortaleza_glacial", "caverna_gelo", "pico_aurora"),
            gates = emptyList(),
            playable = false
        ),
        WorldAreaDefinition(
            id = WorldAreaId.REGIAO_CENTRAL,
            name = "Região Central",
            region = WorldRegion.CENTRAL,
            ecosystemId = "central_wilds",
            biomeKey = "campos_centrais",
            spawn = AreaSpawn(0.52f, 0.12f),
            pointIds = setOf(
                "aurelia", "cidade_do_sol", "arkanis", "mina_dourada",
                "torre_sabedoria", "vila_esperanca"
            ),
            gates = emptyList(),
            playable = false
        ),
        WorldAreaDefinition(
            id = WorldAreaId.IMPERIO,
            name = "Terras do Império",
            region = WorldRegion.IMPERIO,
            ecosystemId = "imperial_frontier",
            biomeKey = "fronteira_imperial",
            spawn = AreaSpawn(0.5f, 0.9f),
            pointIds = setOf("valdracon", "forte_guarda", "catacumbas_reais", "vila_helios"),
            gates = emptyList(),
            playable = false
        ),
        WorldAreaDefinition(
            id = WorldAreaId.TERRAS_DAS_SOMBRAS,
            name = "Terras das Sombras",
            region = WorldRegion.SOMBRAS,
            ecosystemId = "shadowlands",
            biomeKey = "terras_sombrias",
            spawn = AreaSpawn(0.5f, 0.9f),
            pointIds = setOf("malachar", "templo_sombrio", "covil_mortos", "vila_necropole"),
            gates = emptyList(),
            playable = false
        ),
        WorldAreaDefinition(
            id = WorldAreaId.DESERTO_ANCESTRAL,
            name = "Deserto Ancestral",
            region = WorldRegion.DESERTO_ANCESTRAL,
            ecosystemId = "ancestral_desert",
            biomeKey = "deserto_ancestral",
            spawn = AreaSpawn(0.5f, 0.9f),
            pointIds = setOf("tharion", "oasis_perdido", "ruinas_antigas", "caverna_escorpiao"),
            gates = emptyList(),
            playable = false
        ),
        WorldAreaDefinition(
            id = WorldAreaId.MAR_ETERNAL,
            name = "Mar Eterno",
            region = WorldRegion.MAR_ETERNAL,
            ecosystemId = "eternal_sea",
            biomeKey = "mar_eterno",
            spawn = AreaSpawn(0.5f, 0.9f),
            pointIds = setOf("kyrath", "ilha_serpente", "torre_oceano"),
            gates = emptyList(),
            playable = false
        )
    )

    fun all(): List<WorldAreaDefinition> = areas

    fun get(id: WorldAreaId): WorldAreaDefinition =
        areas.first { it.id == id }

    fun initialArea(): WorldAreaDefinition = get(WorldAreaId.FLORESTA_ARCANA)

    fun forWorldPoint(pointId: String): WorldAreaDefinition? =
        areas.firstOrNull { pointId in it.pointIds }

    fun transitionAt(areaId: WorldAreaId, x: Float, y: Float): AreaTransition? {
        val gate = get(areaId).gates.firstOrNull { it.contains(x, y) } ?: return null
        return AreaTransition(
            from = areaId,
            to = gate.targetArea,
            gateId = gate.id,
            gateName = gate.name,
            spawn = gate.targetSpawn
        )
    }

    fun isInitiallyPlayable(id: WorldAreaId): Boolean = get(id).playable
}
