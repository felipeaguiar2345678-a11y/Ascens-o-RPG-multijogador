
package br.com.ascensaodosoberano.world

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class CreatureApiResult(
    val statusCode: Int,
    val body: JSONObject
) {
    val success: Boolean
        get() = statusCode in 200..299

    fun getCreature(): CriaturaGerada? {
        if (!success) return null

        return try {
            CreatureJsonParser.parse(body)
        } catch (e: Exception) {
            null
        }
    }
}


internal fun validateCreatureForEncounter(
    creature: CriaturaGerada,
    expectedEcosystemId: String,
    expectedBoss: Boolean
) {
    require(creature.ecosystemId == expectedEcosystemId) {
        "A criatura pertence a outro ecossistema."
    }
    require(creature.bioma.isNotBlank()) {
        "A criatura retornou um bioma vazio."
    }
    // Rank, raridade e nome do bioma são livres. O ecossistema é o vínculo
    // regional; o tipo de encontro e os dados básicos são as validações técnicas.
    require(creature.rank.isNotBlank()) {
        "A criatura retornou um rank vazio."
    }
    require(creature.raridade.isNotBlank()) {
        "A criatura retornou uma raridade vazia."
    }
    require(creature.chefe == expectedBoss) {
        "O tipo de encontro retornado não corresponde ao solicitado."
    }
    require(creature.nivel > 0 && creature.vidaMaxima > 0 && creature.ataques.isNotEmpty()) {
        "A criatura precisa possuir atributos básicos e ao menos um ataque."
    }
}

object CreatureApi {

    private const val BASE_URL =
        "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"

    suspend fun checkHealth(): CreatureApiResult {
        return request("/health", "GET")
    }

    suspend fun requestCreature(
        ecosystemId: String,
        biome: String,
        rank: String,
        danger: Int,
        isBoss: Boolean,
        bossChance: Double,
        creatureHint: String = ""
    ): CreatureApiResult {

        val usuario = FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException(
                "O jogador precisa estar autenticado."
            )

        val token = usuario.getIdToken(false).await().token
            ?: throw IllegalStateException(
                "Não foi possível obter o token Firebase."
            )

        val payload = JSONObject().apply {
            put("ecosystemId", ecosystemId)
            put("biome", biome)
            put("rank", rank)
            put("danger", danger)
            put("isBoss", isBoss)
            put("bossChance", bossChance)
            put("creatureHint", creatureHint.trim().take(240))
        }

        return request(
            "/api/creatures/generate",
            "POST",
            payload.toString(),
            token
        )
    }

    suspend fun gerarERegistrarCriatura(
    ecosystemId: String,
    biome: String,
    rank: String,
    danger: Int,
    isBoss: Boolean,
    bossChance: Double,
    creatureHint: String = ""
): CriaturaGerada {

        val resposta = requestCreature(
    ecosystemId,
    biome,
    rank,
    danger,
    isBoss,
    bossChance,
    creatureHint
)

        if (!resposta.success) {
            val mensagem = resposta.body.optString(
                "message", "Não foi possível gerar a criatura agora."
            )
            val detalhes = resposta.body.optJSONArray("validationIssues")
                ?.let { issues ->
                    (0 until issues.length())
                        .mapNotNull { index ->
                            issues.optString(index).takeIf { it.isNotBlank() }
                        }
                        .joinToString("; ")
                }
                .orEmpty()

            val diagnostico = if (detalhes.isNotBlank()) {
                "$mensagem Motivos: $detalhes"
            } else {
                mensagem
            }

            throw IllegalStateException(
                "$diagnostico (HTTP ${resposta.statusCode})"
            )
        }

        val criaturaRecebida = resposta.getCreature()
            ?: throw IllegalStateException(
                "A API retornou dados inválidos para a criatura."
            )

        validateCreatureForEncounter(criaturaRecebida, ecosystemId, isBoss)
        val raridadeNormalizada = when (
            criaturaRecebida.raridade.trim().uppercase()
        ) {
            "COMMON" -> "COMUM"
            "UNCOMMON" -> "INCOMUM"
            "RARE" -> "RARO"
            "EPIC" -> "ÉPICO"
            "LEGENDARY" -> "LENDÁRIO"
            "MYTHIC" -> "MÍTICO"
            "WORLD" -> "MUNDO"
            else -> criaturaRecebida.raridade.trim().uppercase()
        }

        return RepositorioCriaturas.registrarCriaturaGlobal(
            criaturaRecebida.copy(
                raridade = raridadeNormalizada
            )
        )
    }

    private suspend fun request(
        path: String,
        method: String,
        body: String? = null,
        authToken: String? = null
    ): CreatureApiResult = withContext(Dispatchers.IO) {

        var connection: HttpURLConnection? = null

        try {
            connection = URL(BASE_URL + path)
                .openConnection() as HttpURLConnection

            connection.requestMethod = method
            connection.connectTimeout = 20000
            // O Worker pode aguardar até 45 segundos pela geração da criatura.
            connection.readTimeout = 60000

            connection.setRequestProperty(
                "Accept",
                "application/json"
            )

            if (authToken != null) {
                connection.setRequestProperty(
                    "Authorization",
                    "Bearer $authToken"
                )
            }

            if (body != null) {
                connection.doOutput = true

                connection.setRequestProperty(
                    "Content-Type",
                    "application/json; charset=utf-8"
                )

                connection.outputStream.use {
                    it.write(body.toByteArray(Charsets.UTF_8))
                }
            }

            val status = connection.responseCode

            val stream = if (status in 200..299) {
                connection.inputStream
            } else {
                connection.errorStream
            }

            val responseText = stream
                ?.bufferedReader(Charsets.UTF_8)
                ?.use { it.readText() }
                ?: "{}"

            CreatureApiResult(
                status,
                JSONObject(responseText)
            )

        } catch (e: Exception) {
            CreatureApiResult(
                0,
                JSONObject().apply {
                    put("error", "NETWORK_ERROR")
                    put(
                        "message",
                        e.message ?: "Falha na comunicação com a API."
                    )
                }
            )
        } finally {
            connection?.disconnect()
        }
    }
}
