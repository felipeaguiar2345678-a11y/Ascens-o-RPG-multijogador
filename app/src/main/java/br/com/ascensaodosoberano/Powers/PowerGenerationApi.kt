package br.com.ascensaodosoberano.powers

import br.com.ascensaodosoberano.character.CharacterAttributes
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

object PowerGenerationApi {
    private const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"

    suspend fun generate(
        characterId: String,
        characterName: String,
        level: Int,
        className: String,
        affinities: Map<String, String>,
        attributes: CharacterAttributes,
        maxMana: Int,
        desire: PowerDesire,
        observations: List<PowerObservation>
    ): AwakenedPower = withContext(Dispatchers.IO) {
        val user = FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Entre em uma conta para despertar um poder.")
        val token = user.getIdToken(false).await().token
            ?: throw IllegalStateException("Não foi possível validar sua sessão.")

        val payload = JSONObject().apply {
            put("characterId", characterId.take(128))
            put("characterName", characterName.take(60))
            put("level", level.coerceIn(1, 10000))
            put("className", className.take(80))
            put("affinities", JSONObject().apply {
                affinities.entries.take(12).forEach { (domain, affinity) ->
                    put(domain.take(40), affinity.take(20))
                }
            })
            put("attributes", JSONObject().apply {
                put("strength", attributes.strength.coerceIn(1, 10000))
                put("intelligence", attributes.intelligence.coerceIn(1, 10000))
                put("agility", attributes.agility.coerceIn(1, 10000))
                put("vitality", attributes.vitality.coerceIn(1, 10000))
                put("spirit", attributes.spirit.coerceIn(1, 10000))
            })
            put("maxMana", maxMana.coerceIn(1, 100000))
            put("desire", JSONObject().apply {
                put("id", desire.id.take(100))
                put("name", desire.name.take(100))
                put("description", desire.description.take(240))
                put("type", desire.desiredType.name)
                put("progress", desire.progress.coerceIn(0, 100))
            })
            put("observations", JSONArray().apply {
                observations.takeLast(20).forEach { item ->
                    put(JSONObject().apply {
                        put("action", item.action.take(180))
                        put("category", item.category.take(60))
                        put("intensity", item.intensity.coerceIn(1, 100))
                        put("tags", JSONArray().apply {
                            item.tags.take(12).forEach { tag -> put(tag.take(60)) }
                        })
                    })
                }
            })
        }

        var connection: HttpURLConnection? = null
        try {
            connection = URL("$BASE_URL/api/powers/generate").openConnection() as HttpURLConnection
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
                ?: throw IllegalStateException("A IA retornou uma resposta inválida.")
            if (status !in 200..299) {
                throw IllegalStateException(json.optString("message").ifBlank {
                    "Não foi possível despertar o poder (HTTP $status)."
                })
            }

            val stagesJson = json.optJSONArray("evolutionStages") ?: JSONArray()
            val stages = (0 until stagesJson.length()).mapNotNull { index ->
                val stage = stagesJson.optJSONObject(index) ?: return@mapNotNull null
                PowerEvolutionStage(
                    name = stage.optString("name"),
                    description = stage.optString("description"),
                    requiredLevel = stage.optInt("requiredLevel", level + 1)
                )
            }
            require(stages.size == 4) { "A IA não retornou os quatro estágios de evolução." }

            AwakenedPower(
                id = json.optString("id"),
                name = json.optString("name"),
                description = json.optString("description"),
                type = runCatching { PowerType.valueOf(json.optString("type").uppercase()) }
                    .getOrDefault(PowerType.UNKNOWN),
                origin = PowerOrigin.DISCOVERY,
                status = PowerStatus.AWAKENED,
                level = 1,
                experience = 0,
                manaCost = json.optInt("manaCost").coerceAtLeast(0),
                baseDamage = json.optInt("baseDamage").coerceAtLeast(0),
                cooldown = json.optInt("cooldown").coerceAtLeast(0),
                effects = json.optJSONArray("effects").toStringList(),
                limitations = json.optJSONArray("limitations").toStringList(),
                concept = json.optString("concept"),
                potential = json.optString("potential"),
                manifestation = json.optString("manifestation"),
                awakeningNarrative = json.optString("awakeningNarrative"),
                evolutionStages = stages,
                originDesireId = desire.id
            )
        } finally {
            connection?.disconnect()
        }
    }

    private fun JSONArray?.toStringList(): List<String> {
        if (this == null) return emptyList()
        return (0 until length()).map { optString(it) }.filter { it.isNotBlank() }
    }
}
