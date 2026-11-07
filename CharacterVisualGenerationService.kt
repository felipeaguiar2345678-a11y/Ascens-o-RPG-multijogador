
package br.com.ascensaodosoberano.character

interface CharacterVisualGenerationService {

    suspend fun generate(
        generation: CharacterAIGeneration
    ): CharacterAIGeneration
}
