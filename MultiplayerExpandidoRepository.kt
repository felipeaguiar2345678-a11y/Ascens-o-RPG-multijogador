package br.com.ascensaodosoberano.multiplayer

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL

/**
 * Cliente do multiplayer expandido via Cloudflare Worker.
 * Nenhuma recompensa ou resultado é calculado pelo aplicativo.
 */
class MultiplayerExpandidoRepository {
    suspend fun chamar(acao: String, extras: Map<String, Any?> = emptyMap()): Map<*, *> {
        val user = FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Entre na sua conta para usar o multiplayer.")
        val token = user.getIdToken(true).await().token
            ?: throw IllegalStateException("Não foi possível validar sua sessão.")

        val payload = JSONObject().put("acao", acao)
        extras.forEach { (key, value) -> payload.put(key, value ?: JSONObject.NULL) }

        return withContext(Dispatchers.IO) {
            val connection = (URL("$BASE_URL/api/multiplayer/expanded").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 15000
                readTimeout = 30000
                doOutput = true
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                setRequestProperty("Accept", "application/json")
            }
            try {
                connection.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
                val status = connection.responseCode
                val stream = if (status in 200..299) connection.inputStream else connection.errorStream
                val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
                val result = if (text.isBlank()) JSONObject() else JSONObject(text)
                if (status !in 200..299) {
                    val code = result.optString("error", "MULTIPLAYER_REQUEST_FAILED")
                    throw IllegalStateException(mensagemErro(code))
                }
                jsonObjectToMap(result)
            } finally {
                connection.disconnect()
            }
        }
    }

    private fun mensagemErro(code: String): String = when (code) {
        "UNAUTHORIZED" -> "Sua sessão expirou. Entre novamente."
        "BESTIARY_EMPTY" -> "Ainda não existem criaturas cadastradas para formar uma masmorra."
        "CHARACTER_NOT_FOUND" -> "Crie um personagem antes de participar."
        "DUNGEON_FULL" -> "A expedição já está cheia."
        "DUNGEON_NOT_OPEN" -> "Essa expedição já começou ou foi encerrada."
        "ALREADY_IN_DUNGEON" -> "Você já está em uma expedição."
        "NO_BOSS_FOR_ECOSYSTEM" -> "Ainda não existe chefe cadastrado neste ecossistema."
        "NOT_YOUR_TURN" -> "Ainda não é seu turno."
        "EVENT_REQUIREMENTS_NOT_MET" -> "Você ainda não cumpriu os objetivos desta temporada."
        "ALREADY_CLAIMED" -> "Você já recebeu essa recompensa."
        "MULTIPLAYER_SERVER_UNAVAILABLE" -> "Servidor multiplayer temporariamente indisponível. Tente novamente."
        else -> "Não foi possível concluir a ação ($code)."
    }

    private fun jsonObjectToMap(json: JSONObject): Map<String, Any?> {
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
        is JSONObject -> jsonObjectToMap(value)
        is JSONArray -> (0 until value.length()).map { jsonValue(value.opt(it)) }
        else -> value
    }

    private companion object {
        const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"
    }
}
