package br.com.ascensaodosoberano.world

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.Normalizer

/** Carrega o cenário global do bioma; o Worker reutiliza o arquivo existente no R2. */
object WorldSceneImageApi {
    private const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"
    private val validSceneIds = setOf("floresta", "sombras", "neve", "deserto", "mar", "ruinas", "imperio", "central")

    fun sceneIdForContext(biome: String, region: String = ""): String {
        fun normalize(value: String): String = Normalizer.normalize(value, Normalizer.Form.NFD)
            .replace("\\p{Mn}+".toRegex(), "")
            .lowercase()
        val b = normalize(biome)
        val r = normalize(region)
        val source = if (b.isNotBlank()) b else r
        val combined = "$source $r"
        return when {
            listOf("floresta", "forest", "mata", "bosque").any(source::contains) -> "floresta"
            listOf("neve", "gelid", "gelo", "glacial", "montanha", "snow").any(source::contains) -> "neve"
            listOf("deserto", "duna", "areia", "desert").any(source::contains) -> "deserto"
            listOf("mar", "costa", "ilha", "oceano", "praia", "sea", "ocean").any(source::contains) -> "mar"
            listOf("ruina", "templo", "masmorra", "catacumba", "ruins").any(source::contains) -> "ruinas"
            listOf("imperio", "imperial").any(source::contains) -> "imperio"
            listOf("sombra", "abismo", "terras mortas", "nhar-zul", "dark valley").any(source::contains) -> "sombras"
            listOf("central", "planicie", "pradaria", "wilderness").any(source::contains) -> "central"
            listOf("floresta", "forest", "mata", "bosque").any(combined::contains) -> "floresta"
            listOf("neve", "gelid", "gelo", "glacial", "montanha", "snow").any(combined::contains) -> "neve"
            listOf("deserto", "duna", "areia", "desert").any(combined::contains) -> "deserto"
            listOf("mar", "costa", "ilha", "oceano", "praia", "sea", "ocean").any(combined::contains) -> "mar"
            listOf("ruina", "templo", "masmorra", "catacumba", "ruins").any(combined::contains) -> "ruinas"
            listOf("imperio", "imperial").any(combined::contains) -> "imperio"
            listOf("sombra", "abismo", "terras mortas", "nhar-zul", "dark valley").any(combined::contains) -> "sombras"
            listOf("central", "planicie", "pradaria", "wilderness").any(combined::contains) -> "central"
            else -> "floresta"
        }
    }

    suspend fun gerarOuRecuperar(sceneId: String): String = withContext(Dispatchers.IO) {
        require(sceneId in validSceneIds) { "Identificador de cenário inválido." }
        val user = FirebaseAuth.getInstance().currentUser
            ?: throw IllegalStateException("Entre em uma conta válida para carregar o cenário.")
        val token = user.getIdToken(false).await().token
            ?: throw IllegalStateException("Não foi possível validar sua sessão.")
        val connection = URL("$BASE_URL/api/scenes/generate").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 20_000
            connection.readTimeout = 130_000
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Accept", "application/json")
            val body = JSONObject().put("sceneId", sceneId).toString()
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val responseText = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            val json = runCatching { JSONObject(responseText) }.getOrNull()
            if (status !in 200..299) {
                val message = json?.optString("message")?.takeIf { it.isNotBlank() }
                    ?: when (status) {
                        401 -> "Sua sessão expirou. Entre novamente."
                        409 -> "Este cenário já está sendo criado por outro jogador. Tente novamente em instantes."
                        429 -> "O limite mensal compartilhado de R$ 48,00 foi atingido."
                        else -> "Não foi possível carregar o cenário oficial (HTTP $status)."
                    }
                throw IllegalStateException(message)
            }
            val imageUrl = json?.optString("imageUrl").orEmpty()
            require(imageUrl.startsWith("https://")) { "O servidor não retornou uma URL segura para o cenário." }
            imageUrl
        } finally {
            connection.disconnect()
        }
    }
}
