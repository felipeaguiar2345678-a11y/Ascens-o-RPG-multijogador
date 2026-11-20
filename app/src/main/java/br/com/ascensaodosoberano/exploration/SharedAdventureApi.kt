package br.com.ascensaodosoberano.exploration

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** Cliente autenticado da aventura cooperativa. O servidor decide a escolha e publica a cena. */
object SharedAdventureApi {
    private const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"

    /**
     * Retorna true quando a nova cena já foi publicada; false enquanto outra requisição
     * ainda está gerando ou recuperando a mesma cena. Repetir a chamada não gera IA duplicada.
     */
    suspend fun advance(groupId: String, revision: Long): Boolean = withContext(Dispatchers.IO) {
        require(groupId.isNotBlank() && revision > 0L) {
            "O grupo ou a revisão da aventura é inválida."
        }
        val user = FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Entre em uma conta para continuar a aventura do grupo.")
        val token = user.getIdToken(false).await().token
            ?: throw IllegalStateException("Não foi possível validar sua sessão.")
        val payload = JSONObject().apply {
            put("groupId", groupId)
            put("revision", revision)
        }

        var connection: HttpURLConnection? = null
        try {
            connection = URL("$BASE_URL/api/adventure/shared-turn")
                .openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.connectTimeout = 20000
            connection.readTimeout = 60000
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Accept", "application/json")
            connection.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }

            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val responseText = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            val response = runCatching { JSONObject(responseText) }.getOrNull()
                ?: throw IllegalStateException("O servidor retornou uma resposta inválida.")
            if (status == 202) return@withContext false
            if (status == 503 && response.optString("error") == "SHARED_ADVENTURE_PUBLISH_PENDING") {
                return@withContext false
            }
            if (status !in 200..299) {
                throw IllegalStateException(
                    response.optString("message").ifBlank {
                        "Não foi possível avançar a aventura compartilhada (HTTP $status)."
                    }
                )
            }
            response.optString("status") == "PUBLISHED"
        } finally {
            connection?.disconnect()
        }
    }
}
