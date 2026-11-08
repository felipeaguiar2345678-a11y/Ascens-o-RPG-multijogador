package br.com.ascensaodosoberano.multiplayer

import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.FieldValue
import kotlinx.coroutines.tasks.await

/**
 * Presença pública dos jogadores no mundo.
 * Cada jogador só pode escrever o próprio documento; jogadores autenticados
 * podem observar quem está na mesma área.
 */
data class JogadorOnline(
    val uid: String = "",
    val nome: String = "Aventureiro",
    val nivel: Int = 1,
    val worldPointId: String = "clareira_inicial",
    val x: Float = 0.5f,
    val y: Float = 0.5f,
    val vida: Int = 0,
    val vidaMaxima: Int = 0,
    val ataque: Int = 0,
    val defesa: Int = 0,
    val mana: Int = 0,
    val manaMaxima: Int = 0,
    val agilidade: Int = 0,
    val poderMagico: Int = 0,
    val imagemPersonagemUrl: String = "",
    val ultimaAtualizacao: Long = 0L
)

class PresenceRepository(
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance()
) {
    private val collection = db.collection("worldPresence")

    suspend fun publicar(
        uid: String,
        nome: String,
        nivel: Int,
        worldPointId: String,
        x: Float,
        y: Float,
        vida: Int = 0,
        vidaMaxima: Int = 0,
        ataque: Int = 0,
        defesa: Int = 0,
        mana: Int = 0,
        manaMaxima: Int = 0,
        agilidade: Int = 0,
        poderMagico: Int = 0,
        imagemPersonagemUrl: String = ""
    ) {
        require(uid.isNotBlank()) { "UID inválido." }
        require(worldPointId.isNotBlank()) { "Área do mundo inválida." }

        collection.document(uid).set(
            mapOf(
                "uid" to uid,
                "nome" to nome,
                "nivel" to nivel.coerceAtLeast(1),
                "worldPointId" to worldPointId,
                "x" to x.coerceIn(0f, 1f),
                "y" to y.coerceIn(0f, 1f),
                "vida" to vida.coerceAtLeast(0),
                "vidaMaxima" to vidaMaxima.coerceAtLeast(0),
                "ataque" to ataque.coerceAtLeast(0),
                "defesa" to defesa.coerceAtLeast(0),
                "mana" to mana.coerceAtLeast(0),
                "manaMaxima" to manaMaxima.coerceAtLeast(0),
                "agilidade" to agilidade.coerceAtLeast(0),
                "poderMagico" to poderMagico.coerceAtLeast(0),
                "imagemPersonagemUrl" to imagemPersonagemUrl.takeIf { it.startsWith("https://") || it.startsWith("http://") }.orEmpty(),
                "ultimaAtualizacao" to FieldValue.serverTimestamp(),
                "online" to true
            )
        ).await()
    }

    fun observarJogadoresNaArea(
        worldPointId: String,
        uidAtual: String,
        aoAtualizar: (List<JogadorOnline>) -> Unit,
        aoFalhar: (Exception) -> Unit = {}
    ): ListenerRegistration {
        return collection
            .whereEqualTo("worldPointId", worldPointId)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    aoFalhar(error)
                    return@addSnapshotListener
                }

                val agora = System.currentTimeMillis()
                val jogadores = snapshot?.documents.orEmpty().mapNotNull { doc ->
                    if (doc.getBoolean("online") != true) return@mapNotNull null
                    val uid = doc.getString("uid") ?: return@mapNotNull null
                    if (uid == uidAtual) return@mapNotNull null

                    val atualizado = doc.getTimestamp("ultimaAtualizacao")
                        ?.toDate()?.time ?: 0L
                    if (atualizado == 0L || agora - atualizado > 30_000L) {
                        return@mapNotNull null
                    }

                    JogadorOnline(
                        uid = uid,
                        nome = doc.getString("nome") ?: "Aventureiro",
                        nivel = (doc.getLong("nivel") ?: 1L).toInt(),
                        worldPointId = doc.getString("worldPointId") ?: worldPointId,
                        x = (doc.getDouble("x") ?: 0.5).toFloat(),
                        y = (doc.getDouble("y") ?: 0.5).toFloat(),
                        vida = (doc.getLong("vida") ?: 0L).toInt(),
                        vidaMaxima = (doc.getLong("vidaMaxima") ?: 0L).toInt(),
                        ataque = (doc.getLong("ataque") ?: 0L).toInt(),
                        defesa = (doc.getLong("defesa") ?: 0L).toInt(),
                        mana = (doc.getLong("mana") ?: 0L).toInt(),
                        manaMaxima = (doc.getLong("manaMaxima") ?: 0L).toInt(),
                        agilidade = (doc.getLong("agilidade") ?: 0L).toInt(),
                        poderMagico = (doc.getLong("poderMagico") ?: 0L).toInt(),
                        imagemPersonagemUrl = doc.getString("imagemPersonagemUrl") ?: "",
                        ultimaAtualizacao = atualizado
                    )
                }
                aoAtualizar(jogadores)
            }
    }

    fun observarPresencasDosJogadores(
        uids: List<String>,
        aoAtualizar: (List<JogadorOnline>) -> Unit
    ): ListenerRegistration? {
        val validos = uids.filter { it.isNotBlank() }.distinct().take(10)
        if (validos.isEmpty()) return null
        return collection.whereIn("uid", validos)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    aoAtualizar(emptyList())
                    return@addSnapshotListener
                }
                val agora = System.currentTimeMillis()
                aoAtualizar(snapshot?.documents.orEmpty().mapNotNull { doc ->
                    if (doc.getBoolean("online") != true) return@mapNotNull null
                    val atualizado = doc.getTimestamp("ultimaAtualizacao")?.toDate()?.time ?: 0L
                    if (atualizado == 0L || agora - atualizado > 30_000L) return@mapNotNull null
                    val uid = doc.getString("uid") ?: return@mapNotNull null
                    JogadorOnline(
                        uid = uid,
                        nome = doc.getString("nome") ?: "Aventureiro",
                        nivel = (doc.getLong("nivel") ?: 1L).toInt(),
                        worldPointId = doc.getString("worldPointId") ?: "",
                        x = (doc.getDouble("x") ?: 0.5).toFloat(),
                        y = (doc.getDouble("y") ?: 0.5).toFloat(),
                        vida = (doc.getLong("vida") ?: 0L).toInt(),
                        vidaMaxima = (doc.getLong("vidaMaxima") ?: 0L).toInt(),
                        ataque = (doc.getLong("ataque") ?: 0L).toInt(),
                        defesa = (doc.getLong("defesa") ?: 0L).toInt(),
                        mana = (doc.getLong("mana") ?: 0L).toInt(),
                        manaMaxima = (doc.getLong("manaMaxima") ?: 0L).toInt(),
                        agilidade = (doc.getLong("agilidade") ?: 0L).toInt(),
                        poderMagico = (doc.getLong("poderMagico") ?: 0L).toInt(),
                        imagemPersonagemUrl = doc.getString("imagemPersonagemUrl") ?: "",
                        ultimaAtualizacao = atualizado
                    )
                })
            }
    }

    suspend fun sair(uid: String) {
        if (uid.isNotBlank()) {
            collection.document(uid).delete().await()
        }
    }
}
