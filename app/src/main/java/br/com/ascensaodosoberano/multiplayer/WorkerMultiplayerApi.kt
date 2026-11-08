package br.com.ascensaodosoberano.multiplayer

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** Cliente autenticado para as operações de servidor hospedadas no Worker. */
object WorkerMultiplayerApi {
    private const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"

    suspend fun post(path: String, dados: Map<String, Any?>): Map<*, *> {
        require(path.startsWith("/api/") && !path.contains("..")) {
            "Endereço de serviço inválido."
        }
        val user = FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Entre na sua conta para continuar.")
        val token = user.getIdToken(false).await().token
            ?: throw IllegalStateException("Não foi possível validar sua sessão.")

        return withContext(Dispatchers.IO) {
            val connection = URL(BASE_URL + path).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "POST"
                connection.doOutput = true
                connection.connectTimeout = 15000
                connection.readTimeout = 60000
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                val payload = JSONObject(dados).toString()
                connection.outputStream.use { it.write(payload.toByteArray(Charsets.UTF_8)) }

                val status = connection.responseCode
                val stream = if (status in 200..299) connection.inputStream else connection.errorStream
                val raw = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
                val json = runCatching { JSONObject(raw) }.getOrElse { JSONObject() }
                if (status !in 200..299) {
                    val code = json.optString("error", "SERVER_ERROR")
                    val message = when (code) {
                        "UNAUTHORIZED" -> "Sua sessão expirou. Entre novamente."
                        "ALREADY_IN_GUILD" -> "Você já pertence a uma guilda."
                        "NOT_IN_GUILD" -> "Você não pertence a uma guilda."
                        "INVALID_GUILD_NAME" -> "O nome da guilda deve ter de 3 a 24 caracteres."
                        "INVALID_GUILD_CODE" -> "O código da guilda é inválido."
                        "GUILD_NOT_FOUND" -> "Não encontramos essa guilda."
                        "GUILD_FULL" -> "Essa guilda já atingiu o limite de membros."
                        "GUILD_SERVER_UNAVAILABLE" -> "O servidor de guildas está temporariamente indisponível."
                        else -> "O servidor recusou a operação ($code)."
                    }
                    throw IllegalStateException(message)
                }
                json.toMapDeep()
            } finally {
                connection.disconnect()
            }
        }
    }

    private fun JSONObject.toMapDeep(): Map<String, Any?> = buildMap {
        val keys = keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = get(key)
            put(key, when (value) {
                JSONObject.NULL -> null
                is JSONObject -> value.toMapDeep()
                is JSONArray -> value.toListDeep()
                else -> value
            })
        }
    }

    private fun JSONArray.toListDeep(): List<Any?> = (0 until length()).map { index ->
        when (val value = get(index)) {
            JSONObject.NULL -> null
            is JSONObject -> value.toMapDeep()
            is JSONArray -> value.toListDeep()
            else -> value
        }
    }
}
