package br.com.ascensaodosoberano.world

enum class ForestLandmarkKind {
    START_CLEARING, CAMP, VILLAGE, CITY, TOWER, RUINS, WATERFALL, BOSS_LAIR, GATE
}

data class ForestLandmark(
    val id: String,
    val name: String,
    val x: Float,
    val y: Float,
    val kind: ForestLandmarkKind,
    val radius: Float = 0.9f
)

data class ForestPath(
    val id: String,
    val points: List<Pair<Float, Float>>,
    val width: Float = 0.10f,
    val paved: Boolean = false
)

object ForestAreaMapLayout {
    val landmarks = listOf(
        ForestLandmark("clareira_inicial", "Clareira Inicial", .52f, .78f, ForestLandmarkKind.START_CLEARING, 1.15f),
        ForestLandmark("acampamento_viajantes", "Acampamento dos Viajantes", .43f, .70f, ForestLandmarkKind.CAMP),
        ForestLandmark("vila_verdejante", "Vila Verdejante", .30f, .48f, ForestLandmarkKind.VILLAGE, 1.2f),
        ForestLandmark("eldarion", "Eldarion", .66f, .35f, ForestLandmarkKind.CITY, 1.35f),
        ForestLandmark("torre_natureza", "Torre da Natureza", .84f, .24f, ForestLandmarkKind.TOWER),
        ForestLandmark("ruinas_elficas", "Ruínas Élficas", .16f, .30f, ForestLandmarkKind.RUINS, 1.1f),
        ForestLandmark("cascata_prateada", "Cascata Prateada", .25f, .70f, ForestLandmarkKind.WATERFALL, 1.2f),
        ForestLandmark("covil_raiz_antiga", "Covil da Raiz Antiga", .78f, .70f, ForestLandmarkKind.BOSS_LAIR, 1.15f),
        ForestLandmark("ponte_das_geadas", "Ponte das Geadas", .87f, .09f, ForestLandmarkKind.GATE, 1.0f),
        ForestLandmark("estrada_de_aurelia", "Estrada para Aurelia", .50f, .98f, ForestLandmarkKind.GATE, 1.0f)
    )

    val paths = listOf(
        ForestPath("trilha_principal", listOf(.52f to .78f, .43f to .70f, .30f to .48f, .48f to .42f, .66f to .35f), .12f),
        ForestPath("trilha_norte", listOf(.66f to .35f, .78f to .29f, .84f to .24f, .87f to .09f), .09f),
        ForestPath("trilha_ruinas", listOf(.30f to .48f, .22f to .40f, .16f to .30f), .08f),
        ForestPath("trilha_cascata", listOf(.43f to .70f, .32f to .72f, .25f to .70f), .08f),
        ForestPath("trilha_covil", listOf(.52f to .78f, .65f to .77f, .78f to .70f), .08f),
        ForestPath("estrada_aurelia", listOf(.52f to .78f, .51f to .88f, .50f to .98f), .16f, true)
    )

    val river = listOf(.05f to .55f, .18f to .58f, .30f to .63f, .42f to .61f, .54f to .55f, .64f to .48f, .76f to .43f, .94f to .45f)

    fun landmark(id: String): ForestLandmark? = landmarks.firstOrNull { it.id == id }
}
