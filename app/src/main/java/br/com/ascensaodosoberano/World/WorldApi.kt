package br.com.ascensaodosoberano.world

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** Cliente autenticado para o estado mundial persistente do Worker. */
object WorldApi {
    private const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"

    suspend fun getWorldState(): JSONObject = request("/api/world/state", null)

    suspend fun registerCreature(creature: CriaturaGerada): Boolean {
        val body = JSONObject().apply {
            put("id", creature.id)
            put("ecosystemId", creature.ecosystemId)
            put("danger", creature.perigo)
            put("rank", creature.rank)
        }
        val response = request("/api/world/creatures/register", body)
        return response.optBoolean("registered", false)
    }

    private suspend fun request(path: String, body: JSONObject?): JSONObject {
        val user = FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Entre na sua conta para sincronizar o mundo.")
        val token = user.getIdToken(false).await().token
            ?: throw IllegalStateException("Não foi possível validar a sessão.")
        return withContext(Dispatchers.IO) {
            val connection = URL(BASE_URL + path).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = if (body == null) "GET" else "POST"
                connection.connectTimeout = 12000
                connection.readTimeout = 20000
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.setRequestProperty("Accept", "application/json")
                if (body != null) {
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                    connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
                }
                val status = connection.responseCode
                val stream = if (status in 200..299) connection.inputStream else connection.errorStream
                val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
                if (status !in 200..299) {
                    throw IllegalStateException(JSONObject(text).optString("message", "Falha ao sincronizar o mundo (HTTP $status)."))
                }
                JSONObject(text)
            } finally {
                connection.disconnect()
            }
        }
    }
}
