
package br.com.ascensaodosoberano.character

class CharacterVisualGenerationController(
    private val service: CharacterVisualGenerationService
) {

    suspend fun generateFor(
        characterId: String,
        profile: CharacterProfile
    ): CharacterAIGeneration {

        val request = CharacterAIGenerationFactory.prepare(
            characterId = characterId,
            profile = profile
        )

        return service.generate(request)
    }
}
