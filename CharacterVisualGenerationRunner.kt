package br.com.ascensaodosoberano.character

/** Orquestra geração, registro e atualização do perfil sem gerar novamente no login. */
class CharacterVisualGenerationRunner(
    private val service: CharacterVisualGenerationService =
        CloudflareCharacterVisualGenerationService(),
    private val generationRepository: CharacterAIGenerationRepository =
        CharacterAIGenerationRepository(),
    private val profileRepository: CharacterProfileRepository =
        CharacterProfileRepository()
) {

    suspend fun generate(profile: CharacterProfile): CharacterProfile {
        // Uma imagem concluída nunca é cobrada novamente ao abrir o jogo.
        val previous = generationRepository.get(profile.id)
        if (previous?.status == GenerationStatus.COMPLETED && previous.imageUrl.isNotBlank()) {
            val restoredProfile = profile.withGeneratedImage(previous)
            profileRepository.save(restoredProfile)
            return restoredProfile
        }
        if (profile.appearance.generatedImageUrl.isNotBlank()) return profile

        val request = CharacterAIGenerationFactory.prepare(
            characterId = profile.id,
            profile = profile
        ).copy(status = GenerationStatus.PENDING)

        generationRepository.save(request)
        val result = service.generate(request)
        generationRepository.save(result)

        if (result.status != GenerationStatus.COMPLETED || result.imageUrl.isBlank()) {
            throw CharacterVisualGenerationException(
                result.errorMessage.ifBlank { "A imagem não foi gerada." }
            )
        }

        val updatedProfile = profile.withGeneratedImage(result)
        profileRepository.save(updatedProfile)
        return updatedProfile
    }

    private fun CharacterProfile.withGeneratedImage(
        generation: CharacterAIGeneration
    ): CharacterProfile = copy(
        appearance = appearance.copy(
            generatedImagePath = generation.imagePath,
            generatedImageUrl = generation.imageUrl,
            generationId = generation.generationId,
            visualVersion = generation.visualVersion
        )
    )
}

class CharacterVisualGenerationException(message: String) : Exception(message)
