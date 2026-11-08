package br.com.ascensaodosoberano.multiplayer

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** Transporte autenticado único para operações multiplayer hospedadas na Cloudflare. */
internal object WorkerMultiplayerHttp {
    private const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"

    suspend fun post(path: String, payload: Map<String, Any?>): Map<*, *> {
        val user = FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Entre na sua conta para continuar.")
        val token = user.getIdToken(true).await().token
            ?: throw IllegalStateException("Não foi possível validar sua sessão.")
        val body = JSONObject()
        payload.forEach { (key, value) -> body.put(key, value ?: JSONObject.NULL) }

        return withContext(Dispatchers.IO) {
            val connection = (URL(BASE_URL + path).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 15000
                readTimeout = 30000
                doOutput = true
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                setRequestProperty("Accept", "application/json")
            }
            try {
                connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
                val status = connection.responseCode
                val stream = if (status in 200..299) connection.inputStream else connection.errorStream
                val raw = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
                val json = if (raw.isBlank()) JSONObject() else JSONObject(raw)
                if (status !in 200..299) {
                    val code = json.optString("error", "MULTIPLAYER_REQUEST_FAILED")
                    throw IllegalStateException(errorMessage(code))
                }
                objectToMap(json)
            } finally {
                connection.disconnect()
            }
        }
    }

    private fun errorMessage(code: String): String = when (code) {
        "UNAUTHORIZED" -> "Sua sessão expirou. Entre novamente."
        "TRADE_SERVER_UNAVAILABLE", "GUILD_SERVER_UNAVAILABLE", "MULTIPLAYER_SERVER_UNAVAILABLE" ->
            "Servidor temporariamente indisponível. Tente novamente."
        "CHARACTER_NOT_FOUND" -> "Crie um personagem antes de continuar."
        "INVALID_RECIPIENT" -> "O jogador escolhido não é válido."
        "NOT_A_PARTICIPANT" -> "Você não participa dessa troca."
        "TRADE_NOT_PENDING" -> "Essa troca não está mais pendente."
        "EMPTY_TRADE" -> "A troca precisa conter pelo menos um objeto."
        "ALREADY_IN_GUILD" -> "Você já pertence a uma guilda."
        "GUILD_FULL" -> "Essa guilda já atingiu o limite de membros."
        "GUILD_NOT_FOUND" -> "Guilda não encontrada."
        "INVALID_GUILD_CODE" -> "Código de guilda inválido."
        "INVALID_GUILD_NAME" -> "O nome da guilda deve ter de 3 a 24 caracteres."
        "XP_NAO_NEGOCIAVEL" -> "Experiência não pode ser negociada."
        "EQUIPAMENTO_EQUIPADO" -> "Retire o equipamento antes de negociá-lo."
        else -> "Não foi possível concluir a operação ($code)."
    }

    private fun objectToMap(json: JSONObject): Map<String, Any?> {
        val result = linkedMapOf<String, Any?>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            result[key] = jsonValue(json.opt(key))
        }
        return result
    }

    private fun jsonValue(value: Any?): Any? = when (value) {
        JSONObject.NULL -> null
        is JSONObject -> objectToMap(value)
        is JSONArray -> (0 until value.length()).map { jsonValue(value.opt(it)) }
        else -> value
    }
}
