
package br.com.ascensaodosoberano.character

enum class GenerationStatus {
    NOT_STARTED,
    PENDING,
    COMPLETED,
    FAILED
}

data class CharacterAIGeneration(
    val characterId: String,
    val generationId: String = "",
    val prompt: String = "",
    val status: GenerationStatus = GenerationStatus.NOT_STARTED,
    val imagePath: String = "",
    val imageUrl: String = "",
    val visualVersion: Int = 1,
    val errorMessage: String = ""
)
