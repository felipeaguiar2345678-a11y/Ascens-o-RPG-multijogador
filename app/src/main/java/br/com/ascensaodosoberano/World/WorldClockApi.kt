package br.com.ascensaodosoberano.world

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** Obtém o instante UTC do Worker, para que todos os clientes calculem a mesma fase. */
object WorldClockApi {
    private const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"

    suspend fun getServerEpochMillis(): Long {
        val user = FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Entre na sua conta para sincronizar o mundo.")
        val token = user.getIdToken(false).await().token
            ?: throw IllegalStateException("Não foi possível validar a sessão.")
        return withContext(Dispatchers.IO) {
            val connection = (URL("$BASE_URL/api/world/clock").openConnection() as HttpURLConnection)
            try {
                connection.requestMethod = "GET"
                connection.connectTimeout = 10000
                connection.readTimeout = 10000
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.setRequestProperty("Accept", "application/json")
                val status = connection.responseCode
                val stream = if (status in 200..299) connection.inputStream else connection.errorStream
                val body = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
                if (status !in 200..299) {
                    throw IllegalStateException(JSONObject(body).optString("message", "Falha ao sincronizar o relógio mundial."))
                }
                JSONObject(body).getLong("serverEpochMillis")
            } finally {
                connection.disconnect()
            }
        }
    }
}
