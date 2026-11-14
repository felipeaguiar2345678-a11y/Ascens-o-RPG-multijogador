package br.com.ascensaodosoberano.character

/** Orquestra geração, registro e atualização do perfil sem gerar novamente no login. */
class CharacterVisualGenerationRunner(
    private val service: CharacterVisualGenerationService = CloudflareCharacterVisualGenerationService(),
    private val generationRepository: CharacterAIGenerationRepository = CharacterAIGenerationRepository(),
    private val profileRepository: CharacterProfileRepository = CharacterProfileRepository(),
    private val classVisualRepository: CharacterClassVisualRepository = CharacterClassVisualRepository()
) {
    suspend fun generate(profile: CharacterProfile): CharacterProfile {
        val previous = generationRepository.get(profile.id)
        if (previous?.status == GenerationStatus.COMPLETED && previous.imageUrl.isNotBlank()) {
            val restored = profile.withGeneratedImage(previous)
            profileRepository.save(restored)
            return restored
        }
        if (profile.appearance.generatedImageUrl.isNotBlank()) return profile

        // Reutiliza a arte compartilhada antes de chamar o provedor de imagens.
        val shared = classVisualRepository.get(profile.characterClass, profile.appearance)
        if (shared != null) {
            val reused = CharacterAIGeneration(
                characterId = profile.id,
                generationId = "class_${shared.classKey.take(48)}",
                status = GenerationStatus.COMPLETED,
                imagePath = shared.imagePath,
                imageUrl = shared.imageUrl,
                visualVersion = shared.visualVersion
            )
            generationRepository.save(reused)
            val restored = profile.withGeneratedImage(reused)
            profileRepository.save(restored)
            return restored
        }

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

        // Guarda a primeira arte gerada para que os próximos jogadores reutilizem.
        runCatching {
            classVisualRepository.save(
                profile.characterClass,
                profile.appearance,
                ClassVisualAsset(
                    classKey = classVisualRepository.keyFor(profile.characterClass, profile.appearance),
                    className = profile.characterClass.name,
                    imageUrl = result.imageUrl,
                    imagePath = result.imagePath,
                    visualVersion = result.visualVersion
                )
            )
        }

        val updated = profile.withGeneratedImage(result)
        profileRepository.save(updated)
        return updated
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
