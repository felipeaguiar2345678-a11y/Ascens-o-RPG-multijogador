package br.com.ascensaodosoberano.world

/**
 * Planta geográfica local da Floresta Arcana.
 * Coordenadas normalizadas: (0,0) noroeste; (1,1) sudeste.
 * A câmera acompanha o jogador, mas todos os clientes usam esta mesma planta.
 */
enum class ForestLandmarkKind {
    START_CLEARING, VILLAGE, CITY, TOWER, RUINS, CAMP, WATERFALL, BOSS_LAIR, GATE
}

data class ForestLandmark(
    val id: String,
    val name: String,
    val kind: ForestLandmarkKind,
    val x: Float,
    val y: Float,
    val radius: Float
)

data class ForestPath(
    val id: String,
    val points: List<Pair<Float, Float>>,
    val width: Float,
    val paved: Boolean = false
)

object ForestAreaMapLayout {
    const val AREA_ID = "floresta_arcana"

    val landmarks = listOf(
        ForestLandmark("clareira_inicial", "Clareira Inicial", ForestLandmarkKind.START_CLEARING, .52f, .78f, .105f),
        ForestLandmark("acampamento_viajantes", "Acampamento dos Viajantes", ForestLandmarkKind.CAMP, .43f, .70f, .035f),
        ForestLandmark("vila_verdejante", "Vila Verdejante", ForestLandmarkKind.VILLAGE, .30f, .48f, .075f),
        ForestLandmark("eldarion", "Eldarion", ForestLandmarkKind.CITY, .66f, .35f, .105f),
        ForestLandmark("torre_natureza", "Torre da Natureza", ForestLandmarkKind.TOWER, .84f, .24f, .045f),
        ForestLandmark("ruinas_elficas", "Ruínas Élficas", ForestLandmarkKind.RUINS, .16f, .30f, .075f),
        ForestLandmark("cascata_prateada", "Cascata Prateada", ForestLandmarkKind.WATERFALL, .25f, .70f, .055f),
        ForestLandmark("covil_raiz_antiga", "Covil da Raiz Antiga", ForestLandmarkKind.BOSS_LAIR, .78f, .70f, .06f),
        ForestLandmark("ponte_das_geadas", "Ponte das Geadas", ForestLandmarkKind.GATE, .87f, .09f, .035f),
        ForestLandmark("estrada_de_aurelia", "Estrada para Aurelia", ForestLandmarkKind.GATE, .50f, .98f, .025f)
    )

    val paths = listOf(
        ForestPath("trilha_principal", listOf(.52f to .78f, .47f to .68f, .39f to .59f, .30f to .48f, .36f to .39f, .49f to .34f, .66f to .35f), .025f),
        ForestPath("trilha_norte", listOf(.66f to .35f, .73f to .26f, .84f to .24f, .87f to .09f), .018f),
        ForestPath("trilha_das_ruinas", listOf(.49f to .34f, .34f to .29f, .16f to .30f), .018f),
        ForestPath("trilha_cascata", listOf(.52f to .78f, .39f to .75f, .25f to .70f, .18f to .55f, .30f to .48f), .016f),
        ForestPath("trilha_covil", listOf(.66f to .35f, .72f to .48f, .78f to .70f), .018f),
        ForestPath("estrada_aurelia", listOf(.52f to .78f, .53f to .88f, .50f to .98f), .028f, paved = true)
    )

    // Curso d'água principal e lago são marcos geográficos fixos da área.
    val river = listOf(.08f to .62f, .18f to .66f, .25f to .70f, .34f to .65f,
        .43f to .58f, .50f to .52f, .61f to .55f, .70f to .63f, .78f to .70f, .91f to .67f)
    val lakeCenter = .12f to .78f
    val lakeRadius = .075f

    fun landmark(id: String): ForestLandmark? = landmarks.firstOrNull { it.id == id }
}
