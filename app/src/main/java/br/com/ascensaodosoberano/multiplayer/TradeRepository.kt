package br.com.ascensaodosoberano.multiplayer

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.tasks.await

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
    private val functions: FirebaseFunctions = FirebaseFunctions.getInstance("southamerica-east1"),
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance(),
    private val auth: FirebaseAuth = FirebaseAuth.getInstance()
) {
    private suspend fun chamar(dados: Map<String, Any?>): Map<*, *> {
        check(auth.currentUser != null) { "Entre na sua conta para negociar." }
        val result = functions.getHttpsCallable("gerenciarTroca").call(dados).await()
        return result.getData() as? Map<*, *> ?: emptyMap<Any, Any>()
    }

    suspend fun criarTroca(destinatarioUid: String): String {
        require(destinatarioUid.isNotBlank() && destinatarioUid != auth.currentUser?.uid) {
            "Escolha outro jogador para negociar."
        }
        val result = chamar(mapOf("acao" to "criar", "destinatarioUid" to destinatarioUid))
        return result["trocaId"]?.toString() ?: error("O servidor não retornou o identificador da troca.")
    }

    suspend fun enviarOferta(trocaId: String, oferta: OfertaTroca) {
        chamar(mapOf("acao" to "ofertar", "trocaId" to trocaId, "oferta" to mapOf(
            "itens" to oferta.itens, "ovos" to oferta.ovos, "equipamentos" to oferta.equipamentos
        )))
    }

    suspend fun aceitar(trocaId: String) { chamar(mapOf("acao" to "aceitar", "trocaId" to trocaId)) }
    suspend fun cancelar(trocaId: String) { chamar(mapOf("acao" to "cancelar", "trocaId" to trocaId)) }

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
