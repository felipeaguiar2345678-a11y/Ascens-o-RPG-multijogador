package br.com.ascensaodosoberano.multiplayer

import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.tasks.await

/** Guilda é uma estrutura social permanente, independente do grupo temporário Ally. */
data class GuildaSnapshot(
    val id: String,
    val nome: String,
    val codigoConvite: String,
    val liderUid: String,
    val membros: List<String>,
    val nomesMembros: Map<String, String>,
    val nivelAcampamento: Int = 1,
    val experienciaAcampamento: Int = 0
)

class GuildRepository(
    private val functions: FirebaseFunctions = FirebaseFunctions.getInstance("southamerica-east1"),
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance()
) {
    private suspend fun chamar(acao: String, extras: Map<String, Any> = emptyMap()): Map<*, *> {
        val dados = mutableMapOf<String, Any>("acao" to acao)
        dados.putAll(extras)
        val result = functions.getHttpsCallable("gerenciarGuilda").call(dados).await()
        return result.data as? Map<*, *> ?: emptyMap<Any, Any>()
    }

    suspend fun criar(nome: String, uid: String, nomeJogador: String): String {
        require(nome.trim().length in 3..24) { "O nome da guilda deve ter de 3 a 24 caracteres." }
        val result = chamar("criar", mapOf(
            "nome" to nome.trim(), "nomeJogador" to nomeJogador.take(32)
        ))
        return result["guildaId"]?.toString() ?: error("O servidor não retornou a guilda criada.")
    }

    suspend fun entrar(codigo: String, nomeJogador: String) {
        require(codigo.trim().length == 6) { "O código da guilda deve ter 6 caracteres." }
        chamar("entrar", mapOf("codigo" to codigo.trim().uppercase(), "nomeJogador" to nomeJogador.take(32)))
    }

    suspend fun sair() { chamar("sair") }

    /** Observa a associação privada e, em seguida, a guilda correspondente. */
    fun observarMinhaGuilda(uid: String, callback: (GuildaSnapshot?) -> Unit): ListenerRegistration {
        var guildListener: ListenerRegistration? = null
        val membershipListener = db.collection("guildMembership").document(uid)
            .addSnapshotListener { membership, error ->
                guildListener?.remove()
                guildListener = null
                if (error != null || membership == null || !membership.exists()) {
                    callback(null)
                    return@addSnapshotListener
                }
                val guildId = membership.getString("guildId") ?: run {
                    callback(null); return@addSnapshotListener
                }
                guildListener = db.collection("guilds").document(guildId)
                    .addSnapshotListener { guild, guildError ->
                        if (guildError != null || guild == null || !guild.exists()) {
                            callback(null); return@addSnapshotListener
                        }
                        val names = (guild.get("memberNames") as? Map<*, *>)
                            ?.mapNotNull { (key, value) ->
                                if (key is String && value is String) key to value else null
                            }?.toMap() ?: emptyMap()
                        callback(GuildaSnapshot(
                            id = guild.id,
                            nome = guild.getString("name") ?: "Guilda",
                            codigoConvite = guild.getString("inviteCode") ?: "------",
                            liderUid = guild.getString("leaderUid") ?: "",
                            membros = (guild.get("members") as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
                            nomesMembros = names,
                            nivelAcampamento = (guild.getLong("campLevel") ?: 1L).toInt(),
                            experienciaAcampamento = (guild.getLong("campExperience") ?: 0L).toInt()
                        ))
                    }
            }
        return object : ListenerRegistration {
            override fun remove() { membershipListener.remove(); guildListener?.remove() }
        }
    }
}
