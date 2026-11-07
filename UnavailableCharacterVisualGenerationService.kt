
package br.com.ascensaodosoberano.character

class UnavailableCharacterVisualGenerationService :
    CharacterVisualGenerationService {

    override suspend fun generate(
        generation: CharacterAIGeneration
    ): CharacterAIGeneration {

        return generation.copy(
            status = GenerationStatus.FAILED,
            errorMessage = "Serviço de geração visual ainda não configurado."
        )
    }
}
