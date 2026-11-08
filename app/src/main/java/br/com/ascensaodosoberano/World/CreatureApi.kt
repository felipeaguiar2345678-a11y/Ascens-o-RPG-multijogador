
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
        bossChance: Double
    ): CreatureApiResult {

        val usuario = FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException(
                "O jogador precisa estar autenticado."
            )

        val token = usuario.getIdToken(true).await().token
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
    bossChance: Double
): CriaturaGerada {

        val resposta = requestCreature(
    ecosystemId,
    biome,
    rank,
    danger,
    isBoss,
    bossChance
)

        if (!resposta.success) {
            val mensagem = resposta.body.optString(
                "message", "Não foi possível gerar a criatura agora."
            )
            throw IllegalStateException(
                "$mensagem (HTTP ${resposta.statusCode})"
            )
        }

        val criaturaRecebida = resposta.getCreature()
            ?: throw IllegalStateException(
                "A API retornou dados inválidos para a criatura."
            )

        require(criaturaRecebida.ecosystemId == ecosystemId) {
            "A criatura pertence a outro ecossistema."
        }
        require(criaturaRecebida.bioma.equals(biome, ignoreCase = true)) {
            "A criatura não corresponde ao bioma solicitado."
        }

        val ranks = listOf("E", "D", "C", "B", "A", "S", "SS", "SSS")
        val rankGerado = ranks.indexOf(criaturaRecebida.rank.uppercase())
        val rankMaximo = ranks.indexOf(rank.uppercase())
        require(rankGerado >= 0 && rankMaximo >= 0 && rankGerado <= rankMaximo) {
            "O rank gerado ultrapassa o limite desta região."
        }
        require(criaturaRecebida.chefe == isBoss) {
            "O tipo de encontro retornado não corresponde ao solicitado."
        }
        require(criaturaRecebida.nivel > 0 && criaturaRecebida.vidaMaxima > 0) {
            "A criatura retornou atributos básicos inválidos."
        }
        require(criaturaRecebida.ataques.isNotEmpty()) {
            "A criatura precisa possuir ao menos um ataque."
        }
        require(criaturaRecebida.raridade.trim().uppercase() in setOf(
            "COMUM", "INCOMUM", "RARO", "ÉPICO", "LENDÁRIO", "MÍTICO", "MUNDO",
            "COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC", "WORLD"
        )) {
            "A criatura retornou uma raridade desconhecida."
        }
        if (isBoss) {
            require(criaturaRecebida.drops.any {
                it.tipo.equals("EQUIPAMENTO", ignoreCase = true) &&
                    it.garantido && it.chancePercentual >= 100f &&
                    !it.efeitoEspecial.isNullOrBlank()
            }) {
                "O chefe precisa possuir um equipamento garantido com efeito especial."
            }
        }

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
