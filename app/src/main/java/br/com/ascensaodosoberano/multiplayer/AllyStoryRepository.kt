package br.com.ascensaodosoberano.multiplayer

import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import kotlinx.coroutines.tasks.await

data class AllyStorySnapshot(
    val groupId: String = "",
    val chapterTitle: String = "A jornada começa",
    val narrativeText: String = "O grupo está reunido. A aventura compartilhada está prestes a começar.",
    val imageUrl: String = "",
    val eventType: String = "NARRATIVE",
    val choices: List<String> = emptyList(),
    val revision: Long = 0L,
    val updatedByUid: String = ""
)

data class AllyStoryVote(
    val uid: String = "",
    val playerName: String = "Aventureiro",
    val choice: String = ""
)

/**
 * Estado narrativo compartilhado do grupo.
 * O líder publica os acontecimentos; todos os integrantes observam a mesma revisão
 * em tempo real. Cada jogador registra sua escolha em um documento próprio.
 */
class AllyStoryRepository(
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance()
) {
    private val stories = db.collection("allyStories")
    private val groups = db.collection("allyGroups")

    fun observarHistoria(groupId: String, callback: (AllyStorySnapshot?) -> Unit): ListenerRegistration {
        return stories.document(groupId).addSnapshotListener { snap, error ->
            if (error != null || snap == null || !snap.exists()) {
                callback(null)
                return@addSnapshotListener
            }
            callback(
                AllyStorySnapshot(
                    groupId = groupId,
                    chapterTitle = snap.getString("chapterTitle") ?: "A jornada continua",
                    narrativeText = snap.getString("narrativeText") ?: "",
                    imageUrl = snap.getString("imageUrl") ?: "",
                    eventType = snap.getString("eventType") ?: "NARRATIVE",
                    choices = (snap.get("choices") as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
                    revision = snap.getLong("revision") ?: 0L,
                    updatedByUid = snap.getString("updatedByUid") ?: ""
                )
            )
        }
    }

    suspend fun publicarAcontecimento(
        groupId: String,
        leaderUid: String,
        chapterTitle: String,
        narrativeText: String,
        imageUrl: String = "",
        eventType: String = "NARRATIVE",
        choices: List<String> = emptyList()
    ) {
        require(groupId.isNotBlank() && leaderUid.isNotBlank())
        require(chapterTitle.length in 1..120)
        require(narrativeText.length in 1..5000)
        require(imageUrl.length <= 2048)
        require(choices.size <= 6 && choices.all { it.length in 1..100 })
        val groupRef = groups.document(groupId)
        val storyRef = stories.document(groupId)
        db.runTransaction { tx ->
            val group = tx.get(groupRef)
            require(group.exists() && group.getString("leaderUid") == leaderUid) {
                "Somente o líder do grupo pode avançar a narrativa compartilhada."
            }
            val previous = tx.get(storyRef)
            val revision = (previous.getLong("revision") ?: 0L) + 1L
            tx.set(storyRef, mapOf(
                "groupId" to groupId,
                "chapterTitle" to chapterTitle,
                "narrativeText" to narrativeText,
                "imageUrl" to imageUrl,
                "eventType" to eventType,
                "choices" to choices,
                "revision" to revision,
                "updatedByUid" to leaderUid,
                "updatedAt" to FieldValue.serverTimestamp()
            ))
            null
        }.await()
    }

    suspend fun registrarEscolha(
        groupId: String,
        uid: String,
        playerName: String,
        choice: String,
        storyRevision: Long
    ) {
        require(groupId.isNotBlank() && uid.isNotBlank())
        require(choice.length in 1..100 && playerName.length in 1..40)
        val voteRef = stories.document(groupId).collection("votes").document(uid)
        db.runTransaction { tx ->
            val story = tx.get(stories.document(groupId))
            require(story.exists()) { "A história compartilhada ainda não começou." }
            require((story.getLong("revision") ?: 0L) == storyRevision) {
                "A história mudou. Atualize a tela antes de escolher."
            }
            val allowed = (story.get("choices") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
            require(choice in allowed) { "Essa escolha não está disponível nesta cena." }
            tx.set(voteRef, mapOf(
                "uid" to uid,
                "playerName" to playerName,
                "choice" to choice,
                "storyRevision" to storyRevision,
                "updatedAt" to FieldValue.serverTimestamp()
            ))
            null
        }.await()
    }

    fun observarEscolhas(groupId: String, callback: (List<AllyStoryVote>) -> Unit): ListenerRegistration {
        return stories.document(groupId).collection("votes")
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    callback(emptyList())
                    return@addSnapshotListener
                }
                callback(snapshot?.documents.orEmpty().map { doc ->
                    AllyStoryVote(
                        uid = doc.getString("uid") ?: doc.id,
                        playerName = doc.getString("playerName") ?: "Aventureiro",
                        choice = doc.getString("choice") ?: ""
                    )
                })
            }
    }
}
