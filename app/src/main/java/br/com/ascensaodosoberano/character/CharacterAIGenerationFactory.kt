
package br.com.ascensaodosoberano.character

import java.util.UUID

object CharacterAIGenerationFactory {

    fun prepare(
        characterId: String,
        profile: CharacterProfile
    ): CharacterAIGeneration {

        val prompt = CharacterAIPrompt.generate(
            characterName = profile.name,
            appearance = profile.appearance,
            characterClass = profile.characterClass
        )

        return CharacterAIGeneration(
            characterId = characterId,
            generationId = UUID.randomUUID().toString(),
            prompt = prompt,
            status = GenerationStatus.NOT_STARTED,
            visualVersion = 1
        )
    }
}
