package br.com.ascensaodosoberano.multiplayer

import androidx.compose.runtime.Stable
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import br.com.ascensaodosoberano.world.WorldApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

/**
 * Presença pública dos jogadores.
 * Posição e validação de movimento vêm do Durable Object global.
 * O A presença validada pelo servidor também é espelhada no Firestore para as regras e consultas transacionais dos grupos.
 */
@Stable
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
    ): JogadorOnline {
        require(uid.isNotBlank()) { "UID inválido." }
        require(worldPointId.isNotBlank()) { "Área do mundo inválida." }
        val presenca = WorldApi.publicarPresenca(
            nome = nome,
            nivel = nivel,
            worldPointId = worldPointId,
            x = x,
            y = y,
            vida = vida,
            vidaMaxima = vidaMaxima,
            ataque = ataque,
            defesa = defesa,
            mana = mana,
            manaMaxima = manaMaxima,
            agilidade = agilidade,
            poderMagico = poderMagico,
            imagemPersonagemUrl = imagemPersonagemUrl
        )

        // Espelha no Firestore a posição já validada pelo Durable Object.
        // Grupos e batalhas cooperativas ainda usam esta coleção para validar
        // proximidade e presença recente dos integrantes.
        val dadosLegados = mutableMapOf<String, Any>(
            "uid" to presenca.uid,
            "nome" to presenca.nome,
            "nivel" to presenca.nivel,
            "worldPointId" to presenca.worldPointId,
            "x" to presenca.x.toDouble(),
            "y" to presenca.y.toDouble(),
            "vida" to presenca.vida,
            "vidaMaxima" to presenca.vidaMaxima,
            "ataque" to presenca.ataque,
            "defesa" to presenca.defesa,
            "mana" to presenca.mana,
            "manaMaxima" to presenca.manaMaxima,
            "agilidade" to presenca.agilidade,
            "poderMagico" to presenca.poderMagico,
            "ultimaAtualizacao" to FieldValue.serverTimestamp(),
            "online" to true
        )
        if (presenca.imagemPersonagemUrl.isNotBlank()) {
            dadosLegados["imagemPersonagemUrl"] = presenca.imagemPersonagemUrl
        }
        collection.document(uid).set(dadosLegados).await()
        return presenca
    }

    fun observarJogadoresNaArea(
        worldPointId: String,
        uidAtual: String,
        aoAtualizar: (List<JogadorOnline>) -> Unit,
        aoFalhar: (Exception) -> Unit = {}
    ): ListenerRegistration {
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        val job: Job = scope.launch {
            while (isActive) {
                try {
                    val jogadores = WorldApi.buscarPresencas(worldPointId)
                        .filter { it.uid != uidAtual }
                    aoAtualizar(jogadores)
                } catch (erro: Exception) {
                    aoFalhar(erro)
                }
                delay(3_000L)
            }
        }
        return object : ListenerRegistration {
            override fun remove() {
                job.cancel()
                scope.coroutineContext[Job]?.cancel()
            }
        }
    }

    /**
     * Consulta legada por UID para sistemas de grupo que ainda usam Firestore.
     * A presença principal do mapa não depende deste método.
     */
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
