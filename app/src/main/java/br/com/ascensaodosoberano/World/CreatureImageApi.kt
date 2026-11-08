package br.com.ascensaodosoberano.world

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class CreatureImageResult(
    val imageId: String,
    val imageUrl: String,
    val objectKey: String,
    val sizeBytes: Long,
    val actualCostBRL: Double
)

/** Solicita a arte ao Worker; a chave OpenAI nunca fica no aplicativo. */
object CreatureImageApi {
    private const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"

    suspend fun gerarImagemOficial(
        creatureId: String
    ): CreatureImageResult = withContext(Dispatchers.IO) {
        require(creatureId.matches(Regex("[A-Za-z0-9_-]{1,100}"))) { "Identificador de criatura inválido." }
        val user = FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Entre em uma conta para gerar a imagem.")
        val token = user.getIdToken(true).await().token
            ?: throw IllegalStateException("Não foi possível validar sua sessão.")
        val body = JSONObject().put("creatureId", creatureId).toString()
        val connection = URL("$BASE_URL/api/creatures/image").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 20_000
            connection.readTimeout = 130_000
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Accept", "application/json")
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val responseText = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            val response = runCatching { JSONObject(responseText) }.getOrNull()
            if (status !in 200..299) {
                val message = response?.optString("message")?.takeIf { it.isNotBlank() }
                    ?: "Não foi possível gerar a imagem da criatura (HTTP $status)."
                throw IllegalStateException(message)
            }
            val json = response ?: throw IllegalStateException(
                "O servidor retornou uma resposta inválida."
            )
            val imageId = json.optString("imageId", creatureId)
            val imageUrl = json.optString("imageUrl")
            val objectKey = json.optString("objectKey")
            require(imageId.isNotBlank() && imageUrl.isNotBlank() && objectKey.isNotBlank()) {
                "O servidor não retornou os dados completos da imagem."
            }
            CreatureImageResult(imageId, imageUrl, objectKey,
                json.optLong("sizeBytes"), json.optDouble("actualBRL", 0.0))
        } finally {
            connection.disconnect()
        }
    }
}
