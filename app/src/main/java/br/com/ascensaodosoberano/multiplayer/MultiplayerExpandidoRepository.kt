package br.com.ascensaodosoberano.multiplayer

/** Operações competitivas e recompensas são validadas no servidor Cloudflare. */
class MultiplayerExpandidoRepository {
    suspend fun chamar(acao: String, extras: Map<String, Any?> = emptyMap()): Map<*, *> {
        val dados = mutableMapOf<String, Any?>("acao" to acao)
        dados.putAll(extras)
        return WorkerMultiplayerApi.post("/api/multiplayer/expanded", dados)
    }
}
