package br.com.ascensaodosoberano.character

data class CharacterAppearance(
    val skinId: String = "pele_01",
    val faceId: String = "rosto_01",
    val hairId: String = "cabelo_01",
    val hairColorId: String = "castanho",
    val eyeId: String = "olhos_01",
    val outfitId: String = "roupa_inicial_01",
    val generatedImagePath: String = "",
    val generatedImageUrl: String = "",
    val generationId: String = "",
    val visualVersion: Int = 1,
    val idleSpritePath: String = "",
    val walkingSpritesPath: String = "",
    val directionalSpritesPath: String = ""
)