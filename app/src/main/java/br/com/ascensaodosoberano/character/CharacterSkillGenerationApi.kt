package br.com.ascensaodosoberano.character

import br.com.ascensaodosoberano.powers.AwakenedPower
import br.com.ascensaodosoberano.powers.PowerOrigin
import br.com.ascensaodosoberano.powers.PowerStatus
import br.com.ascensaodosoberano.powers.PowerType
import com.google.firebase.auth.FirebaseUser
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/**
 * Gera as habilidades iniciais a partir do conceito real do jogador.
 * A chave da OpenAI permanece exclusivamente no Cloudflare Worker.
 */
object CharacterSkillGenerationApi {
    private const val ENDPOINT =
        "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev/api/characters/skills/generate"

    suspend fun generate(profile: CharacterProfile, user: FirebaseUser): CharacterProfile =
        withContext(Dispatchers.IO) {
            // Usa exatamente o usuário autenticado pelo fluxo de criação.
            // Não consulta FirebaseAuth.currentUser novamente, evitando perder a sessão
            // entre a confirmação do login e a chamada da geração.
            val token = user.getIdToken(true).await().token
                ?: throw IllegalStateException("Não foi possível validar sua sessão.")

            val affinities = JSONObject().apply {
                profile.characterClass.affinities.forEach { (domain, affinity) ->
                    put(domain.name, affinity.name)
                }
                SkillDomain.values().forEach { domain ->
                    if (!has(domain.name)) put(domain.name, Affinity.MEDIUM.name)
                }
            }
            val attributes = JSONObject().apply {
                put("strength", profile.attributes.strength)
                put("intelligence", profile.attributes.intelligence)
                put("agility", profile.attributes.agility)
                put("vitality", profile.attributes.vitality)
                put("spirit", profile.attributes.spirit)
            }
            val payload = JSONObject().apply {
                put("characterName", profile.name.take(60))
                put("className", profile.characterClass.name.take(80))
                put("classDescription", profile.characterClass.description.take(800))
                put("isCustom", profile.characterClass.isCustom)
                put("affinities", affinities)
                put("attributes", attributes)
            }

            val connection = (URL(ENDPOINT).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 20_000
                readTimeout = 60_000
                doOutput = true
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                setRequestProperty("Accept", "application/json")
            }

            try {
                connection.outputStream.use {
                    it.write(payload.toString().toByteArray(Charsets.UTF_8))
                }
                val status = connection.responseCode
                val stream = if (status in 200..299) connection.inputStream else connection.errorStream
                val raw = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
                val response = runCatching { JSONObject(raw) }.getOrNull()
                    ?: throw IllegalStateException("O servidor retornou uma resposta inválida.")

                if (status !in 200..299) {
                    val message = response.optString("message").takeIf { it.isNotBlank() }
                        ?: when (status) {
                            401 -> "Sua sessão expirou. Entre novamente."
                            429 -> "O limite mensal de IA para personagens foi atingido."
                            else -> "Não foi possível criar as habilidades (HTTP $status)."
                        }
                    throw IllegalStateException(message)
                }

                val affinitiesJson = response.getJSONObject("affinities")
                val updatedAffinities = SkillDomain.values().associateWith { domain ->
                    runCatching {
                        Affinity.valueOf(affinitiesJson.getString(domain.name))
                    }.getOrElse {
                        throw IllegalStateException("A IA retornou uma afinidade inválida.")
                    }
                }

                val powersJson = response.getJSONArray("powers")
                require(powersJson.length() == 4) {
                    "A IA precisa criar exatamente quatro habilidades iniciais."
                }
                val powers = (0 until powersJson.length()).map { index ->
                    val item = powersJson.getJSONObject(index)
                    val type = runCatching {
                        PowerType.valueOf(item.getString("type"))
                    }.getOrElse {
                        throw IllegalStateException("A IA retornou um tipo de habilidade inválido.")
                    }
                    AwakenedPower(
                        id = UUID.randomUUID().toString(),
                        name = item.getString("name"),
                        description = item.getString("description"),
                        type = type,
                        origin = PowerOrigin.DISCOVERY,
                        status = PowerStatus.AWAKENED,
                        level = 1,
                        experience = 0,
                        manaCost = item.getInt("manaCost").coerceIn(0, 18),
                        baseDamage = item.getInt("baseDamage").coerceIn(0, 24),
                        cooldown = item.getInt("cooldown").coerceIn(0, 4),
                        effects = item.getJSONArray("effects").let { array ->
                            (0 until array.length()).map { array.getString(it) }
                        },
                        limitations = item.getJSONArray("limitations").let { array ->
                            (0 until array.length()).map { array.getString(it) }
                        }
                    )
                }

                profile.copy(
                    characterClass = profile.characterClass.copy(
                        description = response.getString("classDescription"),
                        affinities = updatedAffinities
                    ),
                    powerProfile = profile.powerProfile.copy(
                        powers = profile.powerProfile.powers + powers
                    ),
                    skillGenerationPending = false
                )
            } finally {
                connection.disconnect()
            }
        }
}
