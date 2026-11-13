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
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Entre na sua conta para aceitar missões.")
        val characterRef = db.collection("characters").document(characterId)
        val missionRef = characterRef.collection("guildContracts").document(mission.id)
        // Firestore Android não permite ler Query dentro de transação.
        // Consulta contratos ativos antes da transação; a transação valida
        // propriedade, rank e uso do contrato específico.
        val active = characterRef.collection("guildContracts")
            .whereEqualTo("status", "ACCEPTED").get().await()
        require(active.isEmpty) {
            "Você já possui uma missão ativa. Conclua ou abandone antes de aceitar outra."
        }
        db.runTransaction { tx ->
            val character = tx.get(characterRef)
            require(character.exists() && character.getString("ownerUid") == uid) {
                "Este personagem não pertence à sua conta."
            }
            val rank = GuildRank.parse(character.getString("guildRank"))
            require(rank.canAccept(GuildRank.parse(mission.rank))) {
                "Seu rank atual não permite aceitar esta missão."
            }
            require(!tx.get(missionRef).exists()) {
                "Esta missão já foi utilizada e não pode ser aceita novamente."
            }
            tx.set(missionRef, mapOf(
                "contractId" to mission.id,
                "characterId" to characterId,
                "ownerUid" to uid,
                "title" to mission.title,
                "rank" to mission.rank,
                "ecosystemId" to mission.regionId,
                "biome" to mission.regionName,
                "region" to mission.regionName,
                "location" to mission.destinationName,
                "kind" to mission.type,
                "objective" to mission.objective,
                "threat" to "Ameaça compatível com rank ${mission.rank}",
                "rewardPreview" to "${mission.rewardGold} ouro · ${mission.rewardXp} XP",
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
