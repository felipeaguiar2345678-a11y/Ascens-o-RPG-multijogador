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
        if (previous?.status == GenerationStatus.COMPLETED &&
            previous.imageUrl.isNotBlank() && CharacterVisualVersionPolicy.isCompatible(previous.visualVersion)
        ) {
            val restored = profile.withGeneratedImage(previous)
            persistirVisualOuFalhar(profile, previous)
            return restored
        }
        if (profile.appearance.generatedImageUrl.isNotBlank() &&
            CharacterVisualVersionPolicy.isCompatible(profile.appearance.visualVersion)
        ) return profile

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
            persistirVisualOuFalhar(profile, reused)
            return restored
        }

        val request = CharacterAIGenerationFactory.prepare(
            characterId = profile.id,
            profile = profile
        ).copy(status = GenerationStatus.PENDING)
        generationRepository.save(request)
        val result = service.generate(request)

        if (result.status != GenerationStatus.COMPLETED || result.imageUrl.isBlank()) {
            generationRepository.save(result)
            throw CharacterVisualGenerationException(
                result.errorMessage.ifBlank { "A imagem não foi gerada." }
            )
        }
        if (!CharacterVisualVersionPolicy.isCompatible(result.visualVersion)) {
            throw CharacterVisualGenerationException(
                "A arte foi gerada em um formato antigo e incompatível. Nenhuma imagem foi aplicada ao personagem."
            )
        }
        generationRepository.save(result)

        val updated = profile.withGeneratedImage(result)
        persistirVisualOuFalhar(profile, result)

        // Só publica no catálogo compartilhado depois de confirmar que a aparência
        // original ainda é a mesma no servidor.
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
        return updated
    }

    private suspend fun persistirVisualOuFalhar(
        original: CharacterProfile,
        generation: CharacterAIGeneration?
    ) {
        val resultado = generation
            ?: throw CharacterVisualGenerationException("Resultado visual ausente.")
        val salvo = profileRepository.saveGeneratedVisual(original, resultado)
        if (!salvo) {
            throw CharacterVisualGenerationException(
                "A aparência do personagem mudou ou outra imagem foi aplicada em outro aparelho. " +
                    "A geração antiga não foi gravada; atualize a ficha antes de tentar novamente."
            )
        }
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
