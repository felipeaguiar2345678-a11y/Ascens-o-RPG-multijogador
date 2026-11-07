
package br.com.ascensaodosoberano.world

enum class WorldRegion(
    val displayName: String
) {
    MONTANHAS_GELIDAS("Região das Montanhas Gélidas"),
    FLORESTA_ARCANA("Região da Floresta Arcana"),
    IMPERIO("Região do Império"),
    CENTRAL("Região Central"),
    SOMBRAS("Região das Sombras"),
    DESERTO_ANCESTRAL("Região do Deserto Ancestral"),
    
    MAR_ETERNAL("Região do Mar Eterno")
    }

enum class WorldPointType {
    CAPITAL,
    CITY,
    VILLAGE,
    DUNGEON,
    TOWER,
    RUINS,
    LANDMARK
}

data class WorldMapPoint(
    val id: String,
    val name: String,
    val region: WorldRegion,
    val type: WorldPointType,
    val x: Float,
    val y: Float
)

object WorldMapData {

    // Coordenadas normalizadas da imagem:
    // X: esquerda (0) até direita (1)
    // Y: cima (0) até baixo (1)

    val points = listOf(

        // Região Central
        WorldMapPoint(
            "aurelia",
            "Aurelia",
            WorldRegion.CENTRAL,
            WorldPointType.CAPITAL,
            0.54f, 0.47f
        ),
        WorldMapPoint(
            "cidade_do_sol",
            "Cidade do Sol",
            WorldRegion.CENTRAL,
            WorldPointType.CITY,
            0.41f, 0.39f
        ),
        WorldMapPoint(
            "arkanis",
            "Arkanis",
            WorldRegion.CENTRAL,
            WorldPointType.CITY,
            0.63f, 0.39f
        ),
        WorldMapPoint(
            "mina_dourada",
            "Mina Dourada",
            WorldRegion.CENTRAL,
            WorldPointType.DUNGEON,
            0.38f, 0.53f
        ),
        WorldMapPoint(
            "torre_sabedoria",
            "Torre da Sabedoria",
            WorldRegion.CENTRAL,
            WorldPointType.TOWER,
            0.65f, 0.55f
        ),
        WorldMapPoint(
            "vila_esperanca",
            "Vila Esperança",
            WorldRegion.CENTRAL,
            WorldPointType.VILLAGE,
            0.53f, 0.59f
        ),

        // Floresta Arcana
        WorldMapPoint(
    "clareira_inicial",
    "Clareira Inicial",
    WorldRegion.FLORESTA_ARCANA,
    WorldPointType.LANDMARK,
    0.55f, 0.32f
),
WorldMapPoint(
    "eldarion",
    "Eldarion",
    WorldRegion.FLORESTA_ARCANA,
    WorldPointType.CITY,
    0.62f, 0.20f
),
        WorldMapPoint(
            "vila_verdejante",
            "Vila Verdejante",
            WorldRegion.FLORESTA_ARCANA,
            WorldPointType.VILLAGE,
            0.50f, 0.20f
        ),
        WorldMapPoint(
            "torre_natureza",
            "Torre da Natureza",
            WorldRegion.FLORESTA_ARCANA,
            WorldPointType.TOWER,
            0.71f, 0.10f
        ),
        WorldMapPoint(
            "ruinas_elficas",
            "Ruínas Élficas",
            WorldRegion.FLORESTA_ARCANA,
            WorldPointType.RUINS,
            0.78f, 0.22f
        ),

        // Montanhas Gélidas
        WorldMapPoint(
            "fortaleza_glacial",
            "Fortaleza Glacial",
            WorldRegion.MONTANHAS_GELIDAS,
            WorldPointType.CITY,
            0.14f, 0.18f
        ),
        WorldMapPoint(
            "caverna_gelo",
            "Caverna do Gelo",
            WorldRegion.MONTANHAS_GELIDAS,
            WorldPointType.DUNGEON,
            0.29f, 0.17f
        ),
        WorldMapPoint(
            "pico_aurora",
            "Pico da Aurora",
            WorldRegion.MONTANHAS_GELIDAS,
            WorldPointType.LANDMARK,
            0.38f, 0.07f
        ),

        // Império
        WorldMapPoint(
            "valdracon",
            "Valdracon",
            WorldRegion.IMPERIO,
            WorldPointType.CITY,
            0.19f, 0.39f
        ),
        WorldMapPoint(
            "forte_guarda",
            "Forte da Guarda",
            WorldRegion.IMPERIO,
            WorldPointType.CITY,
            0.07f, 0.40f
        ),
        WorldMapPoint(
            "catacumbas_reais",
            "Catacumbas Reais",
            WorldRegion.IMPERIO,
            WorldPointType.DUNGEON,
            0.13f, 0.51f
        ),
        WorldMapPoint(
            "vila_helios",
            "Vila Hélios",
            WorldRegion.IMPERIO,
            WorldPointType.VILLAGE,
            0.30f, 0.46f
        ),

        // Sombras
        WorldMapPoint(
            "malachar",
            "Malachar",
            WorldRegion.SOMBRAS,
            WorldPointType.CITY,
            0.89f, 0.43f
        ),
        WorldMapPoint(
            "templo_sombrio",
            "Templo Sombrio",
            WorldRegion.SOMBRAS,
            WorldPointType.DUNGEON,
            0.80f, 0.40f
        ),
        WorldMapPoint(
            "covil_mortos",
            "Covil dos Mortos",
            WorldRegion.SOMBRAS,
            WorldPointType.DUNGEON,
            0.84f, 0.54f
        ),
        WorldMapPoint(
            "vila_necropole",
            "Vila Necrópole",
            WorldRegion.SOMBRAS,
            WorldPointType.VILLAGE,
            0.81f, 0.62f
        ),

        // Deserto Ancestral
        WorldMapPoint(
            "tharion",
            "Tharion",
            WorldRegion.DESERTO_ANCESTRAL,
            WorldPointType.CITY,
            0.20f, 0.72f
        ),
        WorldMapPoint(
            "oasis_perdido",
            "Oásis Perdido",
            WorldRegion.DESERTO_ANCESTRAL,
            WorldPointType.VILLAGE,
            0.08f, 0.65f
        ),
        WorldMapPoint(
            "ruinas_antigas",
            "Ruínas Antigas",
            WorldRegion.DESERTO_ANCESTRAL,
            WorldPointType.RUINS,
            0.09f, 0.79f
        ),
        WorldMapPoint(
            "caverna_escorpiao",
            "Caverna do Escorpião",
            WorldRegion.DESERTO_ANCESTRAL,
            WorldPointType.DUNGEON,
            0.39f, 0.76f
        ),

        // Mar Eterno
        WorldMapPoint(
            "kyrath",
            "Kyrath",
            WorldRegion.MAR_ETERNAL,
            WorldPointType.CITY,
            0.71f, 0.76f
        ),
        WorldMapPoint(
            "ilha_serpente",
            "Ilha da Serpente",
            WorldRegion.MAR_ETERNAL,
            WorldPointType.LANDMARK,
            0.91f, 0.75f
        ),
        WorldMapPoint(
            "torre_oceano",
            "Torre do Oceano",
            WorldRegion.MAR_ETERNAL,
            WorldPointType.TOWER,
            0.80f, 0.87f
        )
    )

    val capital: WorldMapPoint
        get() = points.first { it.id == "aurelia" }

    fun pointsInRegion(
        region: WorldRegion
    ): List<WorldMapPoint> {
        return points.filter { it.region == region }
    }

    fun findPoint(
        id: String
    ): WorldMapPoint? {
        return points.find { it.id == id }
    }
}
