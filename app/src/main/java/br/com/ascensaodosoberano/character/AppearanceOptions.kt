package br.com.ascensaodosoberano.character

data class AppearanceOption(
    val id: String,
    val name: String,
    val previewColor: Long = 0xFF808080
)

object AppearanceOptions {

    val skinTones = listOf(
        AppearanceOption("pele_01", "Clara", 0xFFFFDFC4),
        AppearanceOption("pele_02", "Bege", 0xFFEBC09A),
        AppearanceOption("pele_03", "Morena", 0xFFB87950),
        AppearanceOption("pele_04", "Escura", 0xFF75452F),
        AppearanceOption("pele_05", "Retinta", 0xFF432719)
    )

    val faces = listOf(
        AppearanceOption("rosto_01", "Jovem"),
        AppearanceOption("rosto_02", "Maduro"),
        AppearanceOption("rosto_03", "Marcado"),
        AppearanceOption("rosto_04", "Delicado")
    )

    val hairstyles = listOf(
        AppearanceOption("cabelo_01", "Curto"),
        AppearanceOption("cabelo_02", "Longo"),
        AppearanceOption("cabelo_03", "Médio"),
        AppearanceOption("cabelo_04", "Trançado"),
        AppearanceOption("cabelo_05", "Moicano"),
        AppearanceOption("cabelo_06", "Careca")
    )

    val hairColors = listOf(
        AppearanceOption("preto", "Preto", 0xFF202020),
        AppearanceOption("castanho", "Castanho", 0xFF70452D),
        AppearanceOption("loiro", "Loiro", 0xFFE5C16B),
        AppearanceOption("branco", "Branco", 0xFFE8E8E8),
        AppearanceOption("vermelho", "Vermelho", 0xFFB83A32),
        AppearanceOption("azul", "Azul", 0xFF3768C5),
        AppearanceOption("roxo", "Roxo", 0xFF8546B5)
    )

    val eyeStyles = listOf(
        AppearanceOption("olhos_01", "Normal"),
        AppearanceOption("olhos_02", "Intenso"),
        AppearanceOption("olhos_03", "Místico"),
        AppearanceOption("olhos_04", "Dracônico")
    )

    val outfits = listOf(
        AppearanceOption("roupa_inicial_01", "Aventureiro"),
        AppearanceOption("roupa_inicial_02", "Guerreiro"),
        AppearanceOption("roupa_inicial_03", "Mago"),
        AppearanceOption("roupa_inicial_04", "Assassino"),
        AppearanceOption("roupa_inicial_05", "Nobre")
    )
}