
package br.com.ascensaodosoberano.character

object CharacterAIPrompt {

    fun generate(
        characterName: String,
        appearance: CharacterAppearance
    ): String {

        val skin = AppearanceOptions.skinTones
            .firstOrNull { it.id == appearance.skinId }?.name ?: "Clara"

        val face = AppearanceOptions.faces
            .firstOrNull { it.id == appearance.faceId }?.name ?: "Jovem"

        val hair = AppearanceOptions.hairstyles
            .firstOrNull { it.id == appearance.hairId }?.name ?: "Curto"

        val hairColor = AppearanceOptions.hairColors
            .firstOrNull { it.id == appearance.hairColorId }?.name ?: "Castanho"

        val eyes = AppearanceOptions.eyeStyles
            .firstOrNull { it.id == appearance.eyeId }?.name ?: "Normal"

        val outfit = AppearanceOptions.outfits
            .firstOrNull { it.id == appearance.outfitId }?.name ?: "Aventureiro"

        return """
            Create an original fantasy RPG player character.

            CHARACTER NAME: $characterName

            APPEARANCE:
            - Skin tone: $skin
            - Face: $face
            - Hairstyle: $hair
            - Hair color: $hairColor
            - Eyes: $eyes
            - Clothing: $outfit

            VISUAL STYLE:
            - Detailed high-quality pixel art.
            - Fantasy RPG aesthetic.
            - Clearly readable character silhouette.
            - Consistent proportions and recognizable identity.
            - Carefully defined pixel details and shading.
            - Transparent background.
            
            IMPORTANT:
            - Respect all selected appearance characteristics.
            - Do not randomly change the character's appearance.
            - Create an original character, not an existing copyrighted character.
            - The same character identity must be preserved in future poses,
              animations and directional sprites.
        """.trimIndent()
    }
}
