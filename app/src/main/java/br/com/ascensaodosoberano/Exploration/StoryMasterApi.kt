package br.com.ascensaodosoberano.exploration

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class StoryScene(
    val chapterTitle: String,
    val sceneTitle: String,
    val narrativeText: String,
    val choices: List<String>,
    val eventType: String,
    val questTitle: String,
    val questObjective: String,
    val questLocationHint: String,
    val encounterHint: String,
    val memorySummary: String
)

object StoryMasterApi {
    private const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"

    suspend fun advance(
        characterName: String,
        level: Int,
        location: String,
        region: String,
        action: String,
        memorySummary: String,
        previousScene: String,
        party: List<String> = emptyList(),
        campaignId: String = ""
    ): StoryScene = withContext(Dispatchers.IO) {
        val user = FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Entre em uma conta para usar o Mestre de História.")
        val token = user.getIdToken(false).await().token
            ?: throw IllegalStateException("Não foi possível validar sua sessão.")
        val payload = JSONObject().apply {
            put("characterName", characterName.take(60))
            put("level", level.coerceIn(1, 10000))
            put("location", location.take(100))
            put("region", region.take(100))
            put("action", action.take(600))
            put("memorySummary", memorySummary.take(1200))
            put("previousScene", previousScene.take(2500))
            put("party", JSONArray(party.take(3).map { it.take(60) }))
            put("campaignId", campaignId.take(80))
        }
        val connection = URL("$BASE_URL/api/story/advance").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 20000
            connection.readTimeout = 60000
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Accept", "application/json")
            connection.doOutput = true
            connection.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val raw = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            val json = JSONObject(raw.ifBlank { "{}" })
            if (status !in 200..299) {
                throw IllegalStateException(json.optString("message", "O Mestre de História falhou (HTTP $status)."))
            }
            val choicesJson = json.optJSONArray("choices") ?: JSONArray()
            val choices = buildList {
                for (index in 0 until choicesJson.length()) {
                    val choice = choicesJson.optString(index)
                    if (choice.isNotBlank()) add(choice)
                }
            }
            require(choices.size in 2..4) { "A história retornou escolhas inválidas." }
            StoryScene(
                chapterTitle = json.getString("chapterTitle"),
                sceneTitle = json.getString("sceneTitle"),
                narrativeText = json.getString("narrativeText"),
                choices = choices,
                eventType = json.optString("eventType", "NARRATIVE"),
                questTitle = json.optString("questTitle"),
                questObjective = json.optString("questObjective"),
                questLocationHint = json.optString("questLocationHint"),
                encounterHint = json.optString("encounterHint", "NONE"),
                memorySummary = json.optString("memorySummary")
            )
        } finally {
            connection.disconnect()
        }
    }
}
