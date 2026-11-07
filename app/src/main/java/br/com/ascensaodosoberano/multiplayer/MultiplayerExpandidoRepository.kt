package br.com.ascensaodosoberano.multiplayer

import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.tasks.await

/** Todas as operações competitivas e recompensas são validadas por Cloud Functions. */
class MultiplayerExpandidoRepository(
    private val functions: FirebaseFunctions = FirebaseFunctions.getInstance("southamerica-east1")
) {
    suspend fun chamar(acao: String, extras: Map<String, Any?> = emptyMap()): Map<*, *> {
        val dados = mutableMapOf<String, Any?>("acao" to acao)
        dados.putAll(extras)
        val resposta = functions.getHttpsCallable("multiplayerExpandido").call(dados).await()
        return resposta.getData() as? Map<*, *> ?: emptyMap<Any, Any>()
    }
}
