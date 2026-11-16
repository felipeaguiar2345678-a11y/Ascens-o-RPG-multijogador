package br.com.ascensaodosoberano.world

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

object WorldSceneImageApi {
    private const val BASE_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev"
    fun sceneIdFor(biome: String): String {
        val value = biome.lowercase()
        return when {
            listOf("nevada","gélida","gelida","gelo","montanha").any(value::contains) -> "neve"
            listOf("deserto","duna","areia").any(value::contains) -> "deserto"
            listOf("mar","costa","ilha","oceano").any(value::contains) -> "mar"
            listOf("ruína","ruina","antiga","masmorra","catacumba").any(value::contains) -> "ruinas"
            listOf("império","imperio","fronteiras imperiais","campos imperiais").any(value::contains) -> "imperio"
            listOf("região central","terras selvagens centrais","central_wilds").any(value::contains) -> "central"
            listOf("terras das sombras","vale do abismo","terras mortas","nhar-zul").any(value::contains) -> "sombras"
            else -> "floresta"
        }
    }
    suspend fun gerarOuRecuperar(biome: String): String = withContext(Dispatchers.IO) {
        val user = FirebaseAuth.getInstance().currentUser ?: error("Entre em uma conta para carregar o cenário.")
        val token = user.getIdToken(false).await().token ?: error("Sessão inválida.")
        val body = JSONObject().put("sceneId", sceneIdFor(biome)).toString()
        val connection = URL("$BASE_URL/api/scenes/image").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 20000
            connection.readTimeout = 130000
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            val json = runCatching { JSONObject(text) }.getOrNull()
            if (status !in 200..299) error(json?.optString("message")?.takeIf { it.isNotBlank() } ?: "Não foi possível gerar o cenário (HTTP $status).")
            json?.optString("imageUrl")?.takeIf { it.startsWith("https://") } ?: error("O servidor não retornou a arte do cenário.")
        } finally { connection.disconnect() }
    }
}
