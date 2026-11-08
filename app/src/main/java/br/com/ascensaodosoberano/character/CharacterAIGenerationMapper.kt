
package br.com.ascensaodosoberano.character

object CharacterAIGenerationMapper {

    fun toMap(
        generation: CharacterAIGeneration
    ): Map<String, Any> {

        return mapOf(
            "characterId" to generation.characterId,
            "generationId" to generation.generationId,
            "prompt" to generation.prompt,
            "status" to generation.status.name,
            "imagePath" to generation.imagePath,
            "imageUrl" to generation.imageUrl,
            "visualVersion" to generation.visualVersion,
            "errorMessage" to generation.errorMessage
        )
    }

          
    fun fromMap(data: Map<String, Any?>): CharacterAIGeneration {
        val status = runCatching {
            GenerationStatus.valueOf(data["status"] as? String ?: "NOT_STARTED")
        }.getOrDefault(GenerationStatus.NOT_STARTED)

        return CharacterAIGeneration(
            characterId = data["characterId"] as? String ?: "",
            generationId = data["generationId"] as? String ?: "",
            prompt = data["prompt"] as? String ?: "",
            status = status,
            imagePath = data["imagePath"] as? String ?: "",
            imageUrl = data["imageUrl"] as? String ?: "",
            visualVersion = (data["visualVersion"] as? Number)?.toInt() ?: 1,
            errorMessage = data["errorMessage"] as? String ?: ""
        )
    }

}
