package br.com.ascensaodosoberano.companions

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class ResultadoArteVisualEquipamento(
    val visualId: String,
    val status: String,
    val visualFrenteCaminho: String = "",
    val visualCostasCaminho: String = "",
    val visualLadoEsquerdoCaminho: String = "",
    val visualLadoDireitoCaminho: String = "",
    val visualCamadaTraseiraCaminho: String = "",
    val visualCamadaDianteiraCaminho: String = "",
    val custoRealBRL: Double = 0.0,
    val geracaoAtivada: Boolean = false
)

/** Consulta o catálogo e só solicita geração se o servidor informar que ela está liberada. */
object EquipmentVisualApi {
    private const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"

    suspend fun solicitarGeracaoSeLiberada(visualId: String): ResultadoArteVisualEquipamento =
        withContext(Dispatchers.IO) {
            require(visualId.matches(Regex("equip_[a-f0-9]{64}"))) {
                "Identificador visual de equipamento inválido."
            }
            val user = FirebaseAuth.getInstance().currentUser
                ?: throw IllegalStateException("Entre em uma conta para solicitar a arte.")
            val token = user.getIdToken(false).await().token
                ?: throw IllegalStateException("Não foi possível validar sua sessão.")
            val body = JSONObject().put("visualId", visualId).toString()
            val connection = URL("$BASE_URL/api/equipment/image/generate").openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "POST"
                connection.connectTimeout = 15_000
                connection.readTimeout = 120_000
                connection.doOutput = true
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                connection.setRequestProperty("Accept", "application/json")
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                val statusCode = connection.responseCode
                val stream = if (statusCode in 200..299) connection.inputStream else connection.errorStream
                val responseText = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
                val json = runCatching { JSONObject(responseText) }.getOrNull()
                    ?: throw IllegalStateException("O servidor retornou uma resposta inválida.")
                if (statusCode !in 200..299) {
                    throw IllegalStateException(
                        json.optString("message").takeIf(String::isNotBlank)
                            ?: "Não foi possível solicitar a arte (HTTP $statusCode)."
                    )
                }
                ResultadoArteVisualEquipamento(
                    visualId = json.optString("visualId", visualId),
                    status = json.optString("status", "pending"),
                    visualFrenteCaminho = json.optString("visualFrenteCaminho"),
                    visualCostasCaminho = json.optString("visualCostasCaminho"),
                    visualLadoEsquerdoCaminho = json.optString("visualLadoEsquerdoCaminho"),
                    visualLadoDireitoCaminho = json.optString("visualLadoDireitoCaminho"),
                    visualCamadaTraseiraCaminho = json.optString("visualCamadaTraseiraCaminho"),
                    visualCamadaDianteiraCaminho = json.optString("visualCamadaDianteiraCaminho"),
                    custoRealBRL = json.optDouble("actualBRL", 0.0),
                    geracaoAtivada = json.optBoolean("generationEnabled", false)
                )
            } finally {
                connection.disconnect()
            }
        }

    suspend fun resolverArteOficial(visualId: String): ResultadoArteVisualEquipamento =
        withContext(Dispatchers.IO) {
            require(visualId.matches(Regex("equip_[a-f0-9]{64}"))) {
                "Identificador visual de equipamento inválido."
            }
            val user = FirebaseAuth.getInstance().currentUser
                ?: throw IllegalStateException("Entre em uma conta para consultar o catálogo visual.")
            val token = user.getIdToken(false).await().token
                ?: throw IllegalStateException("Não foi possível validar sua sessão.")
            val body = JSONObject().put("visualId", visualId).toString()
            val connection = URL("$BASE_URL/api/equipment/image").openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "POST"
                connection.connectTimeout = 15_000
                connection.readTimeout = 25_000
                connection.doOutput = true
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                connection.setRequestProperty("Accept", "application/json")
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                val statusCode = connection.responseCode
                val stream = if (statusCode in 200..299) connection.inputStream else connection.errorStream
                val responseText = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
                val json = runCatching { JSONObject(responseText) }.getOrNull()
                    ?: throw IllegalStateException("O servidor retornou uma resposta inválida.")
                if (statusCode !in 200..299) {
                    throw IllegalStateException(
                        json.optString("message").takeIf(String::isNotBlank)
                            ?: "Não foi possível consultar a arte do equipamento (HTTP $statusCode)."
                    )
                }
                ResultadoArteVisualEquipamento(
                    visualId = json.optString("visualId", visualId),
                    status = json.optString("status", "pending"),
                    visualFrenteCaminho = json.optString("visualFrenteCaminho"),
                    visualCostasCaminho = json.optString("visualCostasCaminho"),
                    visualLadoEsquerdoCaminho = json.optString("visualLadoEsquerdoCaminho"),
                    visualLadoDireitoCaminho = json.optString("visualLadoDireitoCaminho"),
                    visualCamadaTraseiraCaminho = json.optString("visualCamadaTraseiraCaminho"),
                    visualCamadaDianteiraCaminho = json.optString("visualCamadaDianteiraCaminho"),
                    custoRealBRL = json.optDouble("actualBRL", 0.0),
                    geracaoAtivada = json.optBoolean("generationEnabled", false)
                )
            } finally {
                connection.disconnect()
            }
        }
}
