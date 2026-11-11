package br.com.ascensaodosoberano.exploration

/**
 * Lugares da aventura textual. Não contém coordenadas, câmera ou referências
 * ao mapa: cada local fornece apenas identidade narrativa e ecossistema.
 */
data class NarrativeLocation(
    val id: String,
    val name: String,
    val regionId: String
)

object NarrativeLocationCatalog {
    private val locations = listOf(
        NarrativeLocation("guilda_aurelia", "Guilda dos Aventureiros de Aurelia", "central_wilds"),
        NarrativeLocation("aurelia", "Aurelia", "central_wilds"),
        NarrativeLocation("cidade_do_sol", "Cidade do Sol", "central_wilds"),
        NarrativeLocation("arkanis", "Arkanis", "central_wilds"),
        NarrativeLocation("mina_dourada", "Mina Dourada", "central_wilds"),
        NarrativeLocation("torre_sabedoria", "Torre da Sabedoria", "central_wilds"),
        NarrativeLocation("vila_esperanca", "Vila Esperança", "central_wilds"),

        NarrativeLocation("clareira_inicial", "Clareira Inicial", "dark_forest"),
        NarrativeLocation("dark_forest", "Floresta das Sombras", "dark_forest"),
        NarrativeLocation("floresta_sombras", "Floresta das Sombras", "dark_forest"),
        NarrativeLocation("eldarion", "Eldarion", "dark_forest"),
        NarrativeLocation("vila_verdejante", "Vila Verdejante", "dark_forest"),
        NarrativeLocation("torre_natureza", "Torre da Natureza", "dark_forest"),
        NarrativeLocation("ruinas_elficas", "Ruínas Élficas", "forgotten_ruins"),
        NarrativeLocation("forgotten_ruins", "Ruínas Esquecidas", "forgotten_ruins"),

        NarrativeLocation("fortaleza_glacial", "Fortaleza Glacial", "frost_mountains"),
        NarrativeLocation("caverna_gelo", "Caverna do Gelo", "frost_mountains"),
        NarrativeLocation("pico_aurora", "Pico da Aurora", "frost_mountains"),

        NarrativeLocation("valdracon", "Valdracon", "imperial_frontier"),
        NarrativeLocation("forte_guarda", "Forte da Guarda", "imperial_frontier"),
        NarrativeLocation("catacumbas_reais", "Catacumbas Reais", "imperial_frontier"),
        NarrativeLocation("vila_helios", "Vila Hélios", "imperial_frontier"),

        NarrativeLocation("malachar", "Malachar", "shadowlands"),
        NarrativeLocation("templo_sombrio", "Templo Sombrio", "shadowlands"),
        NarrativeLocation("covil_mortos", "Covil dos Mortos", "shadowlands"),
        NarrativeLocation("vila_necropole", "Vila Necrópole", "shadowlands"),

        NarrativeLocation("tharion", "Tharion", "ancestral_desert"),
        NarrativeLocation("oasis_perdido", "Oásis Perdido", "ancestral_desert"),
        NarrativeLocation("ruinas_antigas", "Ruínas Antigas", "ancestral_desert"),
        NarrativeLocation("caverna_escorpiao", "Caverna do Escorpião", "ancestral_desert"),

        NarrativeLocation("kyrath", "Kyrath", "eternal_sea"),
        NarrativeLocation("ilha_serpente", "Ilha da Serpente", "eternal_sea"),
        NarrativeLocation("torre_oceano", "Torre do Oceano", "eternal_sea"),

        NarrativeLocation("vale_abismo", "Vale do Abismo", "abyss_valley"),
        NarrativeLocation("abyss_valley", "Vale do Abismo", "abyss_valley"),
        NarrativeLocation("nhar_zul", "Terras Mortas de Nhar-Zul", "dead_lands"),
        NarrativeLocation("terras_mortas", "Terras Mortas de Nhar-Zul", "dead_lands"),
        NarrativeLocation("dead_lands", "Terras Mortas de Nhar-Zul", "dead_lands")
    ).associateBy { it.id }

    fun find(id: String): NarrativeLocation? =
        locations[id.trim().lowercase()]

    fun displayName(id: String): String =
        find(id)?.name ?: id.replace('_', ' ').replaceFirstChar { it.uppercase() }

    fun all(): List<NarrativeLocation> = locations.values.toList()
}
