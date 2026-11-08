package br.com.ascensaodosoberano.multiplayer

import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import kotlinx.coroutines.tasks.await
import java.util.UUID

/** Grupo cooperativo do mundo aberto. Campanhas usam coleções separadas. */
data class AllyGroup(
    val id: String = "",
    val leaderUid: String = "",
    val members: List<String> = emptyList(),
    val memberNames: Map<String, String> = emptyMap(),
    val activeBattleId: String = "",
    val inviteCode: String = "",
    val createdAt: Long = 0L
)

data class AllyInvite(
    val id: String = "",
    val groupId: String = "",
    val senderUid: String = "",
    val senderName: String = "Aventureiro",
    val receiverUid: String = "",
    val status: String = "PENDING",
    val createdAt: Long = 0L
)

class AllyRepository(
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance()
) {
    companion object {
        const val MAX_MEMBERS = 3
    }

    private val groups = db.collection("allyGroups")
    private val invites = db.collection("allyInvites")
    private val memberships = db.collection("allyMembership")
    private val battles = db.collection("allyBattles")

    /** Cria um mundo cooperativo e emite um código curto para os outros jogadores. */
    suspend fun criarMundo(uid: String, nome: String): String {
        require(uid.isNotBlank() && nome.isNotBlank())
        val groupRef = groups.document(uid)
        val membershipRef = memberships.document(uid)
        val inviteCode = (100000..999999).random().toString()
        val codeRef = db.collection("allyGroupCodes").document(inviteCode)
        db.runTransaction { tx ->
            require(!tx.get(membershipRef).exists()) { "Você já está em um mundo multiplayer." }
            require(!tx.get(groupRef).exists()) { "Seu mundo já existe. Entre nele pelo grupo atual." }
            tx.set(groupRef, mapOf(
                "leaderUid" to uid,
                "members" to listOf(uid),
                "memberNames" to mapOf(uid to nome.take(40)),
                "inviteCode" to inviteCode,
                "activeBattleId" to "",
                "createdAt" to FieldValue.serverTimestamp(),
                "updatedAt" to FieldValue.serverTimestamp()
            ))
            tx.set(membershipRef, mapOf("groupId" to uid))
            tx.set(codeRef, mapOf(
                "groupId" to uid,
                "ownerUid" to uid,
                "active" to true,
                "createdAt" to FieldValue.serverTimestamp()
            ))
            inviteCode
        }.await()
        return inviteCode
    }

    /** Entra em um mundo usando o código compartilhado pelo líder. */
    suspend fun entrarPorCodigo(uid: String, nome: String, codigo: String): String {
        require(uid.isNotBlank() && nome.isNotBlank())
        val normalized = codigo.filter(Char::isDigit)
        require(normalized.length == 6) { "O código do mundo deve ter 6 números." }
        val codeRef = db.collection("allyGroupCodes").document(normalized)
        val groupId = db.runTransaction { tx ->
            val codeSnap = tx.get(codeRef)
            require(codeSnap.exists() && codeSnap.getBoolean("active") == true) { "Código inválido ou expirado." }
            val targetGroupId = codeSnap.getString("groupId") ?: error("Código sem mundo associado.")
            val groupRef = groups.document(targetGroupId)
            val membershipRef = memberships.document(uid)
            val membershipSnap = tx.get(membershipRef)
            val groupSnap = tx.get(groupRef)
            require(!membershipSnap.exists()) { "Você já está em outro mundo multiplayer." }
            require(groupSnap.exists()) { "Esse mundo não está mais disponível." }
            val members = (groupSnap.get("members") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
            require(uid !in members) { "Você já está nesse mundo." }
            require(members.size < MAX_MEMBERS) { "Esse mundo já está cheio (3 jogadores)." }
            val names = (groupSnap.get("memberNames") as? Map<*, *>)?.entries
                ?.mapNotNull { (key, value) -> if (key is String && value is String) key to value else null }
                ?.toMap()?.toMutableMap() ?: mutableMapOf()
            names[uid] = nome.take(40)
            tx.update(groupRef, mapOf(
                "members" to (members + uid),
                "memberNames" to names,
                "lastJoinCode" to normalized,
                "updatedAt" to FieldValue.serverTimestamp()
            ))
            tx.set(membershipRef, mapOf("groupId" to targetGroupId))
            targetGroupId
        }.await()
        return groupId
    }

    /** Cria o grupo do líder se necessário e envia convite para o jogador selecionado. */
    suspend fun enviarConvite(
        senderUid: String,
        senderName: String,
        receiverUid: String
    ): String {
        require(senderUid.isNotBlank() && receiverUid.isNotBlank())
        require(senderUid != receiverUid) { "Você não pode convidar a si mesmo." }

        val senderMembershipRef = memberships.document(senderUid)
        val inviteRef = invites.document(UUID.randomUUID().toString())

        db.runTransaction { tx ->
            val membershipSnap = tx.get(senderMembershipRef)
            val groupId = membershipSnap.getString("groupId") ?: senderUid
            val receiverMembershipRef = memberships.document(receiverUid)
            val receiverMembership = tx.get(receiverMembershipRef)
            require(!receiverMembership.exists()) { "Você já faz parte de outro grupo." }
            val groupRef = groups.document(groupId)
            val groupSnap = tx.get(groupRef)
            if (!groupSnap.exists()) {
                require(groupId == senderUid) { "Seu grupo não está mais disponível." }
                tx.set(groupRef, mapOf(
                    "leaderUid" to senderUid,
                    "members" to listOf(senderUid),
                    "memberNames" to mapOf(senderUid to senderName),
                    "createdAt" to FieldValue.serverTimestamp(),
                    "updatedAt" to FieldValue.serverTimestamp()
                ))
                tx.set(senderMembershipRef, mapOf("groupId" to groupId))
            } else {
                val leader = groupSnap.getString("leaderUid")
                val members = groupSnap.get("members") as? List<*> ?: emptyList<Any>()
                require(leader == senderUid) { "Somente o líder pode convidar jogadores." }
                require(receiverUid !in members) { "Esse jogador já está no grupo." }
                require(members.size < MAX_MEMBERS) { "O mundo já está completo (3 jogadores)." }
            }
            tx.set(inviteRef, mapOf(
                "groupId" to groupId,
                "senderUid" to senderUid,
                "senderName" to senderName,
                "receiverUid" to receiverUid,
                "status" to "PENDING",
                "createdAt" to FieldValue.serverTimestamp()
            ))
            null
        }.await()

        return inviteRef.id
    }

    suspend fun aceitarConvite(inviteId: String, receiverUid: String, receiverName: String) {
        val inviteRef = invites.document(inviteId)

        db.runTransaction { tx ->
            val inviteSnap = tx.get(inviteRef)
            require(inviteSnap.exists()) { "Convite não encontrado." }
            require(inviteSnap.getString("receiverUid") == receiverUid) { "Esse convite não pertence a você." }
            require(inviteSnap.getString("status") == "PENDING") { "Esse convite não está mais disponível." }

            val groupId = inviteSnap.getString("groupId") ?: error("Grupo inválido.")
            val receiverMembershipRef = memberships.document(receiverUid)
            val receiverMembership = tx.get(receiverMembershipRef)
            require(!receiverMembership.exists()) { "Você já faz parte de outro grupo." }
            val groupRef = groups.document(groupId)
            val groupSnap = tx.get(groupRef)
            require(groupSnap.exists()) { "O grupo não existe mais." }
            val members = (groupSnap.get("members") as? List<*>)
                ?.filterIsInstance<String>() ?: emptyList()
            require(receiverUid !in members) { "Você já está nesse grupo." }
            require(members.size < MAX_MEMBERS) { "O grupo já está completo." }

            val names = (groupSnap.get("memberNames") as? Map<*, *>)
                ?.entries?.mapNotNull { (key, value) ->
                    if (key is String && value is String) key to value else null
                }?.toMap()?.toMutableMap() ?: mutableMapOf()
            names[receiverUid] = receiverName

            tx.update(groupRef, mapOf(
                "members" to members + receiverUid,
                "memberNames" to names,
                "lastInviteId" to inviteId,
                "updatedAt" to FieldValue.serverTimestamp()
            ))
            tx.set(receiverMembershipRef, mapOf("groupId" to groupId))
            tx.update(inviteRef, mapOf(
                "status" to "ACCEPTED",
                "answeredAt" to FieldValue.serverTimestamp()
            ))
            null
        }.await()
    }

    suspend fun recusarConvite(inviteId: String, receiverUid: String) {
        val ref = invites.document(inviteId)
        db.runTransaction { tx ->
            val snap = tx.get(ref)
            require(snap.exists() && snap.getString("receiverUid") == receiverUid)
            require(snap.getString("status") == "PENDING")
            tx.update(ref, mapOf(
                "status" to "DECLINED",
                "answeredAt" to FieldValue.serverTimestamp()
            ))
            null
        }.await()
    }

    suspend fun removerMembro(leaderUid: String, memberUid: String) {
        require(leaderUid != memberUid) { "O líder não pode remover a si mesmo." }
        val ref = groups.document(leaderUid)
        db.runTransaction { tx ->
            val snap = tx.get(ref)
            require(snap.exists() && snap.getString("leaderUid") == leaderUid)
            val activeBattleId = snap.getString("activeBattleId")
            if (!activeBattleId.isNullOrBlank()) {
                val battle = tx.get(battles.document(activeBattleId))
                require(!battle.exists() || battle.getString("status") != "ACTIVE") {
                    "Finalize o combate do grupo antes de remover alguém."
                }
                if (battle.exists() && battle.getString("status") == "FINISHED") {
                    val participants = (battle.get("participantUids") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                    val claimed = (battle.get("claimedUids") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                    require(claimed.containsAll(participants)) { "Todos os participantes precisam retirar suas recompensas antes de alterar o grupo." }
                }
            }
            val members = (snap.get("members") as? List<*>)
                ?.filterIsInstance<String>() ?: emptyList()
            require(memberUid in members) { "Jogador não está no grupo." }
            val names = (snap.get("memberNames") as? Map<*, *>)
                ?.filterKeys { it is String }
                ?.mapKeys { it.key as String }
                ?.toMutableMap() ?: mutableMapOf()
            names.remove(memberUid)
            tx.update(ref, mapOf(
                "members" to members.filterNot { it == memberUid },
                "memberNames" to names,
                "updatedAt" to FieldValue.serverTimestamp()
            ))
            tx.delete(memberships.document(memberUid))
            null
        }.await()
    }

    /** O líder que sai encerra o grupo; os demais podem sair individualmente. */
    suspend fun sairDoGrupo(groupId: String, uid: String) {
        val ref = groups.document(groupId)
        db.runTransaction { tx ->
            val snap = tx.get(ref)
            if (!snap.exists()) return@runTransaction null
            val leader = snap.getString("leaderUid") ?: return@runTransaction null
            val activeBattleId = snap.getString("activeBattleId")
            if (!activeBattleId.isNullOrBlank()) {
                val battle = tx.get(battles.document(activeBattleId))
                require(!battle.exists() || battle.getString("status") != "ACTIVE") {
                    "Finalize o combate do grupo antes de sair."
                }
                if (battle.exists() && battle.getString("status") == "FINISHED") {
                    val participants = (battle.get("participantUids") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                    val claimed = (battle.get("claimedUids") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                    require(claimed.containsAll(participants)) { "Todos os participantes precisam retirar suas recompensas antes de alterar o grupo." }
                }
            }
            val members = (snap.get("members") as? List<*>)
                ?.filterIsInstance<String>() ?: emptyList()
            require(uid in members) { "Você não faz parte desse grupo." }
            if (uid == leader) {
                members.forEach { member -> tx.delete(memberships.document(member)) }
                tx.delete(ref)
            } else {
                val names = (snap.get("memberNames") as? Map<*, *>)
                    ?.filterKeys { it is String }
                    ?.mapKeys { it.key as String }
                    ?.toMutableMap() ?: mutableMapOf()
                names.remove(uid)
                tx.update(ref, mapOf(
                    "members" to members.filterNot { it == uid },
                    "memberNames" to names,
                    "updatedAt" to FieldValue.serverTimestamp()
                ))
                tx.delete(memberships.document(uid))
            }
            null
        }.await()
    }


    suspend fun obterGrupoId(uid: String): String? {
        if (uid.isBlank()) return null
        return memberships.document(uid).get().await().getString("groupId")
    }

    fun observarGrupo(groupId: String, callback: (AllyGroup?) -> Unit): ListenerRegistration {
        return groups.document(groupId).addSnapshotListener { snap, error ->
            if (error != null || snap == null || !snap.exists()) {
                callback(null)
                return@addSnapshotListener
            }
            val names = (snap.get("memberNames") as? Map<*, *>)
                ?.entries?.mapNotNull { (k, v) ->
                    if (k is String && v is String) k to v else null
                }?.toMap() ?: emptyMap()
            callback(AllyGroup(
                id = snap.id,
                leaderUid = snap.getString("leaderUid") ?: "",
                members = (snap.get("members") as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
                memberNames = names,
                activeBattleId = snap.getString("activeBattleId") ?: "",
                inviteCode = snap.getString("inviteCode") ?: "",
                createdAt = snap.getTimestamp("createdAt")?.toDate()?.time ?: 0L
            ))
        }
    }

    fun observarConvites(uid: String, callback: (List<AllyInvite>) -> Unit): ListenerRegistration {
        return invites.whereEqualTo("receiverUid", uid)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    callback(emptyList())
                    return@addSnapshotListener
                }
                callback(snapshot?.documents.orEmpty()
                    .filter { it.getString("status") == "PENDING" }
                    .map { doc ->
                    AllyInvite(
                        id = doc.id,
                        groupId = doc.getString("groupId") ?: "",
                        senderUid = doc.getString("senderUid") ?: "",
                        senderName = doc.getString("senderName") ?: "Aventureiro",
                        receiverUid = doc.getString("receiverUid") ?: "",
                        status = doc.getString("status") ?: "PENDING",
                        createdAt = doc.getTimestamp("createdAt")?.toDate()?.time ?: 0L
                    )
                })
            }
    }
}
