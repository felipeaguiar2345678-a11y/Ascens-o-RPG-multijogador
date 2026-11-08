package br.com.ascensaodosoberano.world

import com.google.firebase.auth.FirebaseAuth
import br.com.ascensaodosoberano.multiplayer.JogadorOnline
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL


data class CreatureGlobalStats(
    val creatureId: String = "",
    val encounterToken: String = "",
    val totalPlayersEncountered: Int = 0,
    val firstDiscovererUid: String = "",
    val firstDiscovererName: String = "",
    val firstDiscoveryAt: Long = 0L,
    val totalDefeats: Int = 0,
    val firstDefeaterUid: String = "",
    val firstDefeaterName: String = "",
    val firstDefeatAt: Long = 0L,
    val highestDamage: Int = 0,
    val highestDamageUid: String = "",
    val highestDamageName: String = "",
    val mostDefeatsUid: String = "",
    val mostDefeatsName: String = "",
    val mostDefeatsCount: Int = 0
)

/** Cliente autenticado para o estado mundial persistente do Worker. */
object WorldApi {
    private const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"

    suspend fun getWorldState(): JSONObject = request("/api/world/state", null)

    suspend fun buscarHabitantes(settlementId: String): JSONObject {
        val encoded = java.net.URLEncoder.encode(settlementId, "UTF-8")
        return request("/api/world/npcs?settlementId=$encoded", null)
    }

    suspend fun conversarComHabitante(npcId: String): JSONObject {
        return request("/api/world/npcs/interact", JSONObject().apply {
            put("npcId", npcId)
            put("action", "CONVERSAR")
        })
    }

    suspend fun agirComPedidoHabitante(
        npcId: String,
        problemId: String,
        action: String
    ): JSONObject {
        require(action == "ACEITAR_PEDIDO" || action == "AJUDAR_HABITANTE")
        return request("/api/world/npcs/interact", JSONObject().apply {
            put("npcId", npcId)
            put("problemId", problemId)
            put("action", action)
        })
    }

    suspend fun getCreaturePlacements(ecosystemId: String): JSONObject {
        val encoded = java.net.URLEncoder.encode(ecosystemId, "UTF-8")
        return request("/api/world/creatures/placements?ecosystemId=$encoded", null)
    }

    suspend fun salvarPosicaoPersonagem(
        characterId: String,
        x: Float,
        y: Float,
        worldPointId: String
    ) {
        require(characterId.isNotBlank()) { "Personagem inválido." }
        request("/api/characters/position", JSONObject().apply {
            put("characterId", characterId)
            put("x", x.coerceIn(-100f, 100f))
            put("y", y.coerceIn(-100f, 100f))
            put("worldPointId", worldPointId)
        })
    }

    suspend fun publicarPresenca(
        nome: String,
        nivel: Int,
        worldPointId: String,
        x: Float,
        y: Float,
        vida: Int,
        vidaMaxima: Int,
        ataque: Int,
        defesa: Int,
        mana: Int,
        manaMaxima: Int,
        agilidade: Int,
        poderMagico: Int,
        imagemPersonagemUrl: String
    ): JogadorOnline {
        val response = request("/api/world/presence", JSONObject().apply {
            put("nome", nome)
            put("nivel", nivel)
            put("worldPointId", worldPointId)
            put("x", x)
            put("y", y)
            put("vida", vida)
            put("vidaMaxima", vidaMaxima)
            put("ataque", ataque)
            put("defesa", defesa)
            put("mana", mana)
            put("manaMaxima", manaMaxima)
            put("agilidade", agilidade)
            put("poderMagico", poderMagico)
            put("imagemPersonagemUrl", imagemPersonagemUrl)
        })
        val presence = response.optJSONObject("presence")
            ?: throw IllegalStateException("O servidor não retornou a posição oficial do jogador.")
        return presence.toJogadorOnline()
    }

    suspend fun buscarPresencas(worldPointId: String): List<JogadorOnline> {
        val encoded = java.net.URLEncoder.encode(worldPointId, "UTF-8")
        val response = request("/api/world/presence?worldPointId=$encoded", null)
        val players = response.optJSONArray("players") ?: return emptyList()
        return buildList {
            for (index in 0 until players.length()) {
                val item = players.optJSONObject(index) ?: continue
                add(item.toJogadorOnline())
            }
        }
    }

    private fun JSONObject.toJogadorOnline() = JogadorOnline(
        uid = optString("uid"),
        nome = optString("nome", "Aventureiro"),
        nivel = optInt("nivel", 1),
        worldPointId = optString("worldPointId", "clareira_inicial"),
        x = optDouble("x", 0.5).toFloat(),
        y = optDouble("y", 0.5).toFloat(),
        vida = optInt("vida"),
        vidaMaxima = optInt("vidaMaxima"),
        ataque = optInt("ataque"),
        defesa = optInt("defesa"),
        mana = optInt("mana"),
        manaMaxima = optInt("manaMaxima"),
        agilidade = optInt("agilidade"),
        poderMagico = optInt("poderMagico"),
        imagemPersonagemUrl = optString("imagemPersonagemUrl"),
        ultimaAtualizacao = optLong("updatedAt")
    )

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


    suspend fun registrarEncontroGlobal(
        creatureId: String,
        playerName: String,
        gerarTokenSolo: Boolean = true
    ): CreatureGlobalStats {
        val response = request("/api/bestiary/encounter", JSONObject().apply {
            put("creatureId", creatureId)
            put("playerName", playerName)
            put("issueSoloToken", gerarTokenSolo)
        })
        return response.toCreatureGlobalStats(creatureId)
    }


    suspend fun buscarEstatisticasGlobaisEmLote(creatureIds: List<String>): Map<String, CreatureGlobalStats> {
        val ids = creatureIds.filter { it.isNotBlank() }.distinct().take(50)
        if (ids.isEmpty()) return emptyMap()
        val encodedIds = ids.joinToString(",") {
            java.net.URLEncoder.encode(it, "UTF-8")
        }
        val response = request("/api/bestiary/stats?ids=$encodedIds", null)
        val array = response.optJSONArray("stats") ?: return emptyMap()
        return buildMap {
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                val id = item.optString("creatureId")
                if (id.isNotBlank()) put(id, item.toCreatureGlobalStats(id))
            }
        }
    }

    suspend fun buscarEstatisticasGlobais(creatureId: String): CreatureGlobalStats {
        val response = request("/api/bestiary/stats?id=" + java.net.URLEncoder.encode(creatureId, "UTF-8"), null)
        return response.toCreatureGlobalStats(creatureId)
    }


    suspend fun registrarDerrotaSolo(encounterToken: String, damageDealt: Int): Boolean {
        val response = request("/api/bestiary/solo-defeat", JSONObject().apply {
            put("encounterToken", encounterToken)
            put("damageDealt", damageDealt.coerceAtLeast(0))
        })
        return response.optBoolean("registered", false) || response.optBoolean("duplicate", false)
    }

    suspend fun registrarDerrotaGlobal(battleId: String): Boolean {
        val response = request("/api/bestiary/defeat", JSONObject().apply {
            put("battleId", battleId)
        })
        return response.optBoolean("registered", false) || response.optBoolean("duplicate", false)
    }

    private fun JSONObject.toCreatureGlobalStats(creatureId: String) = CreatureGlobalStats(
        creatureId = optString("creatureId", creatureId),
        encounterToken = optString("encounterToken"),
        totalPlayersEncountered = optInt("totalPlayersEncountered"),
        firstDiscovererUid = optString("firstDiscovererUid"),
        firstDiscovererName = optString("firstDiscovererName"),
        firstDiscoveryAt = optLong("firstDiscoveryAt"),
        totalDefeats = optInt("totalDefeats"),
        firstDefeaterUid = optString("firstDefeaterUid"),
        firstDefeaterName = optString("firstDefeaterName"),
        firstDefeatAt = optLong("firstDefeatAt"),
        highestDamage = optInt("highestDamage"),
        highestDamageUid = optString("highestDamageUid"),
        highestDamageName = optString("highestDamageName"),
        mostDefeatsUid = optString("mostDefeatsUid"),
        mostDefeatsName = optString("mostDefeatsName"),
        mostDefeatsCount = optInt("mostDefeatsCount")
    )

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
