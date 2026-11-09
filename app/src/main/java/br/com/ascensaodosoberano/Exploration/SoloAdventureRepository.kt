package br.com.ascensaodosoberano.exploration

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await

data class AdventureSessionSnapshot(
    val history: List<AdventureMessage> = emptyList(),
    val chapterTitle: String = "",
    val narrative: String = "",
    val choices: List<String> = emptyList()
)

/**
 * Persiste a continuidade da aventura separada da ficha do personagem.
 * Cada jogador só acessa a sessão do próprio personagem.
 */
class SoloAdventureRepository(
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance(),
    private val auth: FirebaseAuth = FirebaseAuth.getInstance()
) {
    suspend fun load(characterId: String): AdventureSessionSnapshot? {
        require(characterId.isNotBlank())
        val uid = auth.currentUser?.uid
            ?: throw IllegalStateException("Entre na conta para recuperar sua aventura.")
        val snapshot = db.collection("users").document(uid)
            .collection("adventureSessions").document(characterId)
            .get().await()
        if (!snapshot.exists()) return null

        val history = (snapshot.get("history") as? List<*>)
            .orEmpty()
            .mapNotNull { raw ->
                val item = raw as? Map<*, *> ?: return@mapNotNull null
                val role = item["role"] as? String ?: return@mapNotNull null
                val text = item["text"] as? String ?: return@mapNotNull null
                if (role !in setOf("player", "assistant") || text.isBlank()) null
                else AdventureMessage(role, text.take(1600))
            }.takeLast(MAX_MESSAGES)

        val choices = (snapshot.get("choices") as? List<*>)
            .orEmpty().filterIsInstance<String>().take(4)

        return AdventureSessionSnapshot(
            history = history,
            chapterTitle = snapshot.getString("chapterTitle").orEmpty().take(100),
            narrative = snapshot.getString("narrative").orEmpty().take(3000),
            choices = choices
        )
    }

    suspend fun save(
        characterId: String,
        snapshot: AdventureSessionSnapshot
    ) {
        require(characterId.isNotBlank())
        require(snapshot.chapterTitle.length <= 100)
        require(snapshot.narrative.length <= 3000)
        require(snapshot.choices.size <= 4 && snapshot.choices.all { it.length in 1..180 })
        val uid = auth.currentUser?.uid
            ?: throw IllegalStateException("Entre na conta para salvar sua aventura.")

        val history = snapshot.history.takeLast(MAX_MESSAGES).map { item ->
            mapOf("role" to item.role, "text" to item.text.take(1600))
        }
        require(history.all {
            it["role"] in listOf("player", "assistant") &&
                (it["text"] as String).isNotBlank()
        })

        db.collection("users").document(uid)
            .collection("adventureSessions").document(characterId)
            .set(
                mapOf(
                    "ownerUid" to uid,
                    "characterId" to characterId,
                    "history" to history,
                    "chapterTitle" to snapshot.chapterTitle,
                    "narrative" to snapshot.narrative,
                    "choices" to snapshot.choices,
                    "updatedAt" to FieldValue.serverTimestamp()
                )
            ).await()
    }

    companion object {
        const val MAX_MESSAGES = 24
    }
}
