package br.com.ascensaodosoberano.character

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** Envia somente a solicitação autenticada. A chave OpenAI permanece no Worker. */
class CloudflareCharacterVisualGenerationService(
    private val auth: FirebaseAuth = FirebaseAuth.getInstance(),
    private val endpoint: String = "$WORKER_BASE_URL/api/characters/visual/generate"
) : CharacterVisualGenerationService {

    override suspend fun generate(
        generation: CharacterAIGeneration
    ): CharacterAIGeneration = withContext(Dispatchers.IO) {
        try {
            val user = auth.currentUser
                ?: throw IllegalStateException("Entre na sua conta para gerar a imagem.")
            val token = user.getIdToken(false).await().token
                ?: throw IllegalStateException("Não foi possível validar sua sessão.")

            val body = JSONObject()
                .put("characterId", generation.characterId)
                .put("generationId", generation.generationId)
                .put("prompt", generation.prompt)
                .toString()

            val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 20_000
                readTimeout = 120_000
                doOutput = true
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
            }

            try {
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                val statusCode = connection.responseCode
                val responseStream = if (statusCode in 200..299) {
                    connection.inputStream
                } else {
                    connection.errorStream
                }
                val responseText = responseStream?.bufferedReader()?.use { it.readText() }.orEmpty()
                val response = runCatching { JSONObject(responseText) }.getOrNull()

                if (statusCode !in 200..299) {
                    val message = response?.optString("message")
                        ?.takeIf { it.isNotBlank() }
                        ?: when (statusCode) {
                            401 -> "Sua sessão expirou. Entre novamente."
                            429 -> "O orçamento mensal de imagens dos personagens foi atingido."
                            else -> "Não foi possível gerar a imagem (código $statusCode)."
                        }
                    return@withContext generation.copy(
                        status = GenerationStatus.FAILED,
                        errorMessage = message
                    )
                }

                val imageUrl = response?.optString("imageUrl").orEmpty()
                val imagePath = response?.optString("objectKey").orEmpty()
                if (imageUrl.isBlank() || imagePath.isBlank()) {
                    return@withContext generation.copy(
                        status = GenerationStatus.FAILED,
                        errorMessage = "O servidor não retornou o endereço da imagem."
                    )
                }

                generation.copy(
                    status = GenerationStatus.COMPLETED,
                    imagePath = imagePath,
                    imageUrl = imageUrl,
                    errorMessage = ""
                )
            } finally {
                connection.disconnect()
            }
        } catch (error: Exception) {
            generation.copy(
                status = GenerationStatus.FAILED,
                errorMessage = error.localizedMessage
                    ?: "Falha ao conectar ao serviço de geração visual."
            )
        }
    }

    companion object {
        const val WORKER_BASE_URL =
            "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"
    }
}
