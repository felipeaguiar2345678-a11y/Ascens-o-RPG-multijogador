package br.com.ascensaodosoberano.guild

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
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
            require(!existing.exists() || existing.getString("status") == "ABANDONED") {
                "Este contrato já foi aceito ou concluído."
            }
            tx.set(contractRef, mapOf(
                "contractId" to contract.id,
                "characterId" to characterId,
                "ownerUid" to uid,
                "title" to contract.title,
                "rank" to contract.rank.label,
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

    suspend fun listActive(characterId: String): List<Map<String, Any?>> {
        require(characterId.isNotBlank()) { "Personagem inválido." }
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Entre na sua conta.")
        val character = db.collection("characters").document(characterId).get().await()
        require(character.exists() && character.getString("ownerUid") == uid) {
            "Este personagem não pertence à sua conta."
        }
        return db.collection("characters").document(characterId)
            .collection("guildContracts")
            .whereEqualTo("status", "ACCEPTED")
            .get().await().documents.map { it.data.orEmpty() }
    }

    suspend fun abandon(characterId: String, contractId: String) {
        require(characterId.isNotBlank() && contractId.isNotBlank()) {
            "Contrato inválido."
        }
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Entre na sua conta.")
        val ref = db.collection("characters").document(characterId)
            .collection("guildContracts").document(contractId)
        db.runTransaction { tx ->
            val contract = tx.get(ref)
            require(contract.exists() && contract.getString("ownerUid") == uid) {
                "Contrato não encontrado."
            }
            require(contract.getString("status") == "ACCEPTED") {
                "Somente contratos ativos podem ser abandonados."
            }
            tx.update(ref, mapOf(
                "status" to "ABANDONED",
                "abandonedAt" to FieldValue.serverTimestamp(),
                "updatedAt" to FieldValue.serverTimestamp()
            ))
            true
        }.await()
    }
}
