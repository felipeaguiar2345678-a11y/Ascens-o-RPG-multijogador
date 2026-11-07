package br.com.ascensaodosoberano.character

object AppearanceEditor {

    fun changeSkin(
        appearance: CharacterAppearance,
        optionId: String
    ) = appearance.copy(skinId = optionId)

    fun changeFace(
        appearance: CharacterAppearance,
        optionId: String
    ) = appearance.copy(faceId = optionId)

    fun changeHair(
        appearance: CharacterAppearance,
        optionId: String
    ) = appearance.copy(hairId = optionId)

    fun changeHairColor(
        appearance: CharacterAppearance,
        optionId: String
    ) = appearance.copy(hairColorId = optionId)

    fun changeEyes(
        appearance: CharacterAppearance,
        optionId: String
    ) = appearance.copy(eyeId = optionId)

    fun changeOutfit(
        appearance: CharacterAppearance,
        optionId: String
    ) = appearance.copy(outfitId = optionId)

    fun randomize(
        appearance: CharacterAppearance
    ): CharacterAppearance {
        return appearance.copy(
            skinId = AppearanceOptions.skinTones.random().id,
            faceId = AppearanceOptions.faces.random().id,
            hairId = AppearanceOptions.hairstyles.random().id,
            hairColorId = AppearanceOptions.hairColors.random().id,
            eyeId = AppearanceOptions.eyeStyles.random().id,
            outfitId = AppearanceOptions.outfits.random().id
        )
    }
}