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
    val updatedByUid: String = "",
    val resolvedChoice: String = "",
    val resolutionType: String = "PENDENTE",
    val voteCounts: Map<String, Int> = emptyMap(),
    val resolvedRevision: Long = -1L
)

data class AllyStoryVote(
    val uid: String = "",
    val playerName: String = "Aventureiro",
    val choice: String = "",
    val storyRevision: Long = 0L
)

data class AllyStoryVoteResolution(
    val choice: String,
    val voteCounts: Map<String, Int>,
    val tied: Boolean,
    val totalVotes: Int
)

/**
 * Resolve uma votação somente quando todos os integrantes votaram na revisão atual.
 * Empates usam um sorteio pseudoaleatório estável por revisão e conjunto de votos,
 * para que todos os celulares cheguem ao mesmo resultado sem depender de relógio local.
 */
internal object AllyStoryVoteRules {
    fun resolve(
        groupMemberUids: List<String>,
        votes: List<AllyStoryVote>,
        availableChoices: List<String>,
        storyRevision: Long
    ): AllyStoryVoteResolution? {
        if (groupMemberUids.isEmpty() || groupMemberUids.size > AllyRepository.MAX_MEMBERS) return null
        if (groupMemberUids.any { it.isBlank() } || groupMemberUids.distinct().size != groupMemberUids.size) return null
        if (availableChoices.isEmpty() || availableChoices.any { it.isBlank() }) return null

        val members = groupMemberUids.toSet()
        val validVotes = votes
            .filter { it.uid in members && it.storyRevision == storyRevision && it.choice in availableChoices }
            .distinctBy { it.uid }
        if (validVotes.size != groupMemberUids.size) return null

        val counts = availableChoices.distinct().associateWith { choice ->
            validVotes.count { it.choice == choice }
        }
        val highest = counts.values.maxOrNull() ?: return null
        val finalists = counts.filterValues { it == highest }.keys.sorted()
        val selected = if (finalists.size == 1) {
            finalists.single()
        } else {
            val voteKey = validVotes.sortedBy { it.uid }
                .joinToString("|") { "${it.uid}=${it.choice}" }
            val seed = "$storyRevision|${groupMemberUids.sorted().joinToString("|")}|$voteKey"
            finalists[Math.floorMod(seed.hashCode(), finalists.size)]
        }
        return AllyStoryVoteResolution(
            choice = selected,
            voteCounts = counts,
            tied = finalists.size > 1,
            totalVotes = validVotes.size
        )
    }
}

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
                    updatedByUid = snap.getString("updatedByUid") ?: "",
                    resolvedChoice = snap.getString("resolvedChoice") ?: "",
                    resolutionType = snap.getString("resolutionType") ?: "PENDENTE",
                    voteCounts = (snap.get("voteCounts") as? Map<*, *>)
                        ?.mapNotNull { (key, value) ->
                            val choice = key as? String
                            val count = (value as? Number)?.toInt()
                            if (choice != null && count != null) choice to count else null
                        }?.toMap() ?: emptyMap(),
                    resolvedRevision = snap.getLong("resolvedRevision") ?: -1L
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
                "resolvedChoice" to "",
                "resolutionType" to "PENDENTE",
                "voteCounts" to emptyMap<String, Int>(),
                "resolvedRevision" to -1L,
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


    /**
     * O líder tenta concluir a votação. A transação relê grupo, cena e todos os votos,
     * garantindo que apenas uma resolução da revisão atual seja gravada.
     */
    suspend fun tentarResolverVotacao(
        groupId: String,
        leaderUid: String,
        groupMemberUids: List<String>,
        storyRevision: Long
    ): AllyStoryVoteResolution? {
        require(groupId.isNotBlank() && leaderUid.isNotBlank())
        return db.runTransaction { tx ->
            val groupRef = groups.document(groupId)
            val storyRef = stories.document(groupId)
            val group = tx.get(groupRef)
            val story = tx.get(storyRef)
            require(group.exists() && group.getString("leaderUid") == leaderUid) {
                "Somente o líder pode concluir a votação."
            }
            val actualMembers = (group.get("members") as? List<*>)
                ?.filterIsInstance<String>().orEmpty()
            require(actualMembers.toSet() == groupMemberUids.toSet()) {
                "A composição do grupo mudou. Atualize a votação."
            }
            if (!story.exists() || (story.getLong("revision") ?: 0L) != storyRevision) {
                return@runTransaction null
            }
            if ((story.getLong("resolvedRevision") ?: -1L) == storyRevision) {
                return@runTransaction null
            }
            val choices = (story.get("choices") as? List<*>)
                ?.filterIsInstance<String>().orEmpty()
            if (choices.isEmpty()) return@runTransaction null

            val voteRefs = actualMembers.map { stories.document(groupId).collection("votes").document(it) }
            val voteDocs = voteRefs.map { tx.get(it) }
            val votes = voteDocs.mapNotNull { vote ->
                if (!vote.exists()) null else AllyStoryVote(
                    uid = vote.getString("uid") ?: vote.id,
                    playerName = vote.getString("playerName") ?: "Aventureiro",
                    choice = vote.getString("choice") ?: "",
                    storyRevision = vote.getLong("storyRevision") ?: 0L
                )
            }
            val result = AllyStoryVoteRules.resolve(
                groupMemberUids = actualMembers,
                votes = votes,
                availableChoices = choices,
                storyRevision = storyRevision
            ) ?: return@runTransaction null

            val resolutionType = when {
                result.tied -> "EMPATE"
                result.voteCounts[result.choice] == actualMembers.size -> "UNANIMIDADE"
                else -> "MAIORIA"
            }
            tx.update(storyRef, mapOf(
                "resolvedChoice" to result.choice,
                "resolutionType" to resolutionType,
                "voteCounts" to result.voteCounts,
                "resolvedRevision" to storyRevision,
                "resolvedAt" to FieldValue.serverTimestamp()
            ))
            result
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
                        choice = doc.getString("choice") ?: "",
                        storyRevision = doc.getLong("storyRevision") ?: 0L
                    )
                })
            }
    }
}
