package br.com.ascensaodosoberano.exploration

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class AdventureMessage(
    val role: String,
    val text: String
)

data class AdventureTurn(
    val chapterTitle: String,
    val narrative: String,
    val choices: List<String>,
    val encounter: Boolean,
    val creatureHint: String,
    val bossEncounter: Boolean,
    val costBRL: Double,
    val missionObjectiveCompleted: Boolean = false,
    val missionCompletionMessage: String = "",
    val missionRewardGold: Long = 0L,
    val missionRewardXp: Int = 0
)

/** Cliente autenticado da aventura solo. A chave do provedor permanece no Worker. */
object SoloAdventureApi {
    private const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"

    suspend fun nextTurn(
        characterName: String,
        level: Int,
        location: String,
        ecosystemId: String,
        biome: String,
        action: String,
        history: List<AdventureMessage>,
        characterId: String,
        missionId: String? = null,
        missionObjective: String? = null,
        missionRank: String? = null,
        missionRarity: String? = null
    ): AdventureTurn = withContext(Dispatchers.IO) {
        require(characterName.isNotBlank() && location.isNotBlank() &&
            ecosystemId.isNotBlank() && biome.isNotBlank()) {
            "Os dados do personagem ou da região estão incompletos."
        }
        require(action.length <= 700 && history.size <= 8) {
            "A ação ou o histórico ultrapassa o limite permitido."
        }

        val user = FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Entre em uma conta para iniciar a aventura por IA.")
        val token = user.getIdToken(false).await().token
            ?: throw IllegalStateException("Não foi possível validar sua sessão.")

        val historyJson = JSONArray().apply {
            history.takeLast(8).forEach { item ->
                put(JSONObject().apply {
                    put("role", item.role)
                    put("text", item.text.take(1600))
                })
            }
        }
        val payload = JSONObject().apply {
            put("characterName", characterName.take(60))
            put("level", level.coerceIn(1, 10000))
            put("location", location.take(100))
            put("ecosystemId", ecosystemId.take(100))
            put("biome", biome.take(100))
            put("action", action.take(700))
            put("history", historyJson)
            put("missionObjective", missionObjective?.take(300).orEmpty())
            put("missionRank", missionRank?.take(8).orEmpty())
            put("missionRarity", missionRarity?.take(20).orEmpty())
            put("characterId", characterId.take(128))
            put("missionId", missionId?.take(128).orEmpty())
        }

        var connection: HttpURLConnection? = null
        try {
            connection = URL("$BASE_URL/api/adventure/turn")
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
            val json = runCatching { JSONObject(responseText) }.getOrNull()
                ?: throw IllegalStateException("O servidor retornou uma resposta inválida.")
            if (status !in 200..299) {
                val message = json.optString("message").ifBlank {
                    "Não foi possível continuar a aventura (HTTP $status)."
                }
                throw IllegalStateException(message)
            }

            val choicesArray = json.optJSONArray("choices")
                ?: throw IllegalStateException("O narrador não retornou as quatro escolhas.")
            val choices = (0 until choicesArray.length()).map { choicesArray.optString(it) }
            require(choices.size == 4 && choices.all { it.isNotBlank() }) {
                "O narrador retornou escolhas incompletas."
            }
            val missionReward = json.optJSONObject("missionReward")
            AdventureTurn(
                chapterTitle = json.optString("chapterTitle"),
                narrative = json.optString("narrative"),
                choices = choices,
                encounter = json.optBoolean("encounter"),
                creatureHint = json.optString("creatureHint"),
                bossEncounter = json.optBoolean("bossEncounter"),
                costBRL = json.optDouble("costBRL", 0.0),
                missionObjectiveCompleted = json.optBoolean("missionObjectiveCompleted", false),
                missionCompletionMessage = json.optString("missionCompletionMessage"),
                missionRewardGold = missionReward?.optLong("gold", 0L) ?: 0L,
                missionRewardXp = missionReward?.optInt("xp", 0) ?: 0
            )
        } finally {
            connection?.disconnect()
        }
    }
}
