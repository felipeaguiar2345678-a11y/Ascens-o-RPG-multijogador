package br.com.ascensaodosoberano.guild

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import br.com.ascensaodosoberano.world.WorldApi
import kotlinx.coroutines.tasks.await

/**
 * Persistência dos contratos aceitos.
 *
 * O cliente só pode aceitar ou abandonar contratos. Conclusão, pagamento,
 * XP e promoção de rank devem ser gravados por uma função confiável do servidor.
 */
class GuildContractRepository(
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance()
) {
    suspend fun accept(characterId: String, contract: GuildContract) {
        require(characterId.isNotBlank()) { "Personagem inválido." }
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Entre na sua conta para aceitar contratos.")

        val characterRef = db.collection("characters").document(characterId)
        val contractRef = characterRef.collection("guildContracts").document(contract.id)

        db.runTransaction { tx ->
            val character = tx.get(characterRef)
            require(character.exists() && character.getString("ownerUid") == uid) {
                "Este personagem não pertence à sua conta."
            }
            val currentRank = GuildRank.parse(character.getString("guildRank"))
            require(currentRank.canAccept(contract.rank)) {
                "Seu rank atual não permite aceitar este contrato."
            }
            val existing = tx.get(contractRef)
            require(!existing.exists()) {
                "Este contrato já foi utilizado. Contratos abandonados não podem ser aceitos novamente."
            }
            tx.set(contractRef, mapOf(
                "contractId" to contract.id,
                "characterId" to characterId,
                "ownerUid" to uid,
                "title" to contract.title,
                "rank" to contract.rank.label,
                "ecosystemId" to contract.region.ecosystemId,
                "biome" to contract.region.biome,
                "region" to contract.region.label,
                "location" to contract.location,
                "kind" to contract.kind.name,
                "objective" to contract.objective,
                "threat" to contract.threat,
                "rewardPreview" to contract.reward,
                "status" to "ACCEPTED",
                "acceptedAt" to FieldValue.serverTimestamp(),
                "updatedAt" to FieldValue.serverTimestamp()
            ))
            true
        }.await()
    }

    /** Persiste a missão da guilda no mesmo registro protegido dos contratos. */
    suspend fun acceptMission(characterId: String, mission: br.com.ascensaodosoberano.exploration.GuildMission) {
        require(characterId.isNotBlank()) { "Personagem inválido." }
        WorldApi.aceitarMissao(characterId, mission)
    }
    suspend fun listActive(characterId: String): List<Map<String, Any?>> {
        require(characterId.isNotBlank()) { "Personagem inválido." }
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Entre na sua conta.")
        val character = db.collection("characters").document(characterId).get().await()
        require(character.exists() && character.getString("ownerUid") == uid) {
            "Este personagem não pertence à sua conta."
        }
        val active = db.collection("characters").document(characterId)
            .collection("guildContracts")
            .whereEqualTo("ownerUid", uid)
            .whereEqualTo("status", "ACCEPTED")
            .get().await().documents.map { it.data.orEmpty() }
        if (active.size == 1) {
            val missionId = active.first()["contractId"] as? String
            if (!missionId.isNullOrBlank()) runCatching { WorldApi.sincronizarMissaoAtiva(characterId, missionId) }
        }
        return active
    }

    /**
     * Marca uma missão como falha após a derrota definitiva do personagem.
     * O status deixa de ser ACCEPTED, liberando a aceitação de outra missão.
     */
    suspend fun failMission(characterId: String, missionId: String) {
        require(characterId.isNotBlank() && missionId.isNotBlank()) { "Missão inválida." }
        WorldApi.atualizarStatusMissao(characterId, missionId, "FAILED")
    }
    suspend fun abandon(characterId: String, contractId: String) {
        require(characterId.isNotBlank() && contractId.isNotBlank()) { "Contrato inválido." }
        WorldApi.atualizarStatusMissao(characterId, contractId, "ABANDONED")
    }
}
