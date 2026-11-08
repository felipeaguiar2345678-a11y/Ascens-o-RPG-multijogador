package br.com.ascensaodosoberano.multiplayer

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** A oferta não possui campos para XP nem para pets eclodidos. */
data class OfertaTroca(
    val itens: List<Map<String, Any>> = emptyList(),
    val ovos: List<String> = emptyList(),
    val equipamentos: List<String> = emptyList()
)

data class TrocaSnapshot(
    val id: String,
    val remetenteUid: String,
    val destinatarioUid: String,
    val status: String,
    val ofertas: Map<String, Any>,
    val aceitoPor: List<String>
)

class TradeRepository(
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance(),
    private val auth: FirebaseAuth = FirebaseAuth.getInstance()
) {
    companion object {
        private const val WORKER_URL = "https://ascensao-soberano-api.felipeaguiar2345678.workers.dev/api/trades"
    }

    private suspend fun chamar(dados: Map<String, Any?>): Map<*, *> {
        val user = auth.currentUser
            ?: throw IllegalStateException("Entre na sua conta para negociar.")
        val token = user.getIdToken(false).await().token
            ?: throw IllegalStateException("Não foi possível validar sua sessão.")

        return withContext(Dispatchers.IO) {
            val connection = URL(WORKER_URL).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "POST"
                connection.doOutput = true
                connection.connectTimeout = 15000
                connection.readTimeout = 30000
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                val payload = JSONObject(dados).toString()
                connection.outputStream.use { output ->
                    output.write(payload.toByteArray(Charsets.UTF_8))
                }
                val statusCode = connection.responseCode
                val stream = if (statusCode in 200..299) connection.inputStream else connection.errorStream
                val responseText = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
                val response = runCatching { JSONObject(responseText) }.getOrElse { JSONObject() }
                if (statusCode !in 200..299) {
                    val code = response.optString("error", "TRADE_SERVER_ERROR")
                    val message = when (code) {
                        "TRADE_SERVER_UNAVAILABLE", "FIREBASE_ADMIN_NOT_READY" ->
                            "O serviço seguro de trocas ainda não está configurado. Tente novamente mais tarde."
                        "ITEM_NAO_PERTENCE_AO_JOGADOR" -> "Um dos itens não está mais no seu inventário."
                        "XP_NAO_NEGOCIAVEL" -> "Experiência não pode ser negociada."
                        "OVO_NAO_PERTENCE_AO_JOGADOR" -> "Um dos ovos não está mais no seu inventário."
                        "EQUIPAMENTO_NAO_PERTENCE_AO_JOGADOR" -> "Um dos equipamentos não está mais no seu inventário."
                        "TRADE_NOT_PENDING" -> "Essa troca não está mais disponível."
                        "NOT_A_PARTICIPANT" -> "Você não participa dessa troca."
                        else -> "O servidor recusou a operação de troca ($code)."
                    }
                    throw IllegalStateException(message)
                }
                buildMap<String, Any?> {
                    val keys = response.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        put(key, response.opt(key))
                    }
                }
            } finally {
                connection.disconnect()
            }
        }
    }

    suspend fun criarTroca(destinatarioUid: String): String {
        require(destinatarioUid.isNotBlank() && destinatarioUid != auth.currentUser?.uid) {
            "Escolha outro jogador para negociar."
        }
        val result = chamar(mapOf("acao" to "criar", "destinatarioUid" to destinatarioUid))
        return result["trocaId"]?.toString()
            ?: error("O servidor não retornou o identificador da troca.")
    }

    suspend fun enviarOferta(trocaId: String, oferta: OfertaTroca) {
        chamar(mapOf("acao" to "ofertar", "trocaId" to trocaId, "oferta" to mapOf(
            "itens" to oferta.itens,
            "ovos" to oferta.ovos,
            "equipamentos" to oferta.equipamentos
        )))
    }

    suspend fun aceitar(trocaId: String) {
        chamar(mapOf("acao" to "aceitar", "trocaId" to trocaId))
    }

    suspend fun cancelar(trocaId: String) {
        chamar(mapOf("acao" to "cancelar", "trocaId" to trocaId))
    }

    fun observarMinhasTrocas(uid: String, callback: (List<TrocaSnapshot>) -> Unit): ListenerRegistration {
        val resultados = mutableMapOf<String, TrocaSnapshot>()
        fun emitir() = callback(resultados.values.sortedByDescending { it.id })
        fun converter(s: com.google.firebase.firestore.QuerySnapshot) {
            s.documents.forEach { doc ->
                resultados[doc.id] = TrocaSnapshot(
                    id = doc.id,
                    remetenteUid = doc.getString("remetenteUid") ?: "",
                    destinatarioUid = doc.getString("destinatarioUid") ?: "",
                    status = doc.getString("status") ?: "PENDENTE",
                    ofertas = (doc.get("ofertas") as? Map<*, *>)
                        ?.mapNotNull { (key, value) ->
                            val field = key as? String
                            if (field != null && value != null) field to value else null
                        }
                        ?.toMap()
                        ?: emptyMap(),
                    aceitoPor = (doc.get("aceitoPor") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                )
            }
            emitir()
        }
        val a = db.collection("trades").whereEqualTo("remetenteUid", uid).addSnapshotListener { s, e -> if (e == null && s != null) converter(s) }
        val b = db.collection("trades").whereEqualTo("destinatarioUid", uid).addSnapshotListener { s, e -> if (e == null && s != null) converter(s) }
        return object : ListenerRegistration {
            override fun remove() { a.remove(); b.remove() }
        }
    }
}
