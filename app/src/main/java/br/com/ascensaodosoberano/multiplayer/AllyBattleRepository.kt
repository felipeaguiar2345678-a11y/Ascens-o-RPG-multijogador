package br.com.ascensaodosoberano.multiplayer

import br.com.ascensaodosoberano.combat.CombatPhase
import br.com.ascensaodosoberano.combat.CombatState
import br.com.ascensaodosoberano.combat.Combatant
import br.com.ascensaodosoberano.combat.CombatSystem
import br.com.ascensaodosoberano.world.AtaqueCriatura
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import kotlinx.coroutines.tasks.await
import kotlin.math.sqrt
import java.util.UUID

data class AllyBattleMember(
    val uid: String,
    val name: String,
    val hero: Combatant,
    val damageDealt: Int = 0,
    val role: String = when {
        hero.defense >= hero.attack && hero.defense > hero.magicPower -> "GUARDIÃO"
        hero.magicPower >= hero.attack -> "MAGO"
        else -> "ATACANTE"
    },
    val specialCharge: Int = 0,
    val specialUsed: Boolean = false,
    val skillCooldowns: Map<String, Int> = emptyMap(),
    val playerStun: Int = 0,
    val chargingSkill: AtaqueCriatura? = null,
    val chargeTurns: Int = 0,
    val chargeBreak: Int = 0,
    val chargeBreakMax: Int = 0
)

data class AllyBattleSnapshot(
    val id: String,
    val groupId: String,
    val worldPointId: String,
    val creatureId: String,
    val members: List<AllyBattleMember>,
    val activePlayerUid: String,
    val state: CombatState,
    val status: String,
    val revision: Long,
    val claimedUids: List<String> = emptyList()
)


/** Regras puras para validar presença recente e proximidade de aliados. */
internal object AllyBattleEligibility {
    const val PRESENCE_MAX_AGE_MS = 30_000L

    fun isFresh(online: Boolean, updatedAtMillis: Long, nowMillis: Long): Boolean =
        online && updatedAtMillis > 0L && nowMillis >= updatedAtMillis &&
            nowMillis - updatedAtMillis <= PRESENCE_MAX_AGE_MS

    fun isNearby(x: Float, y: Float, otherX: Float, otherY: Float): Boolean {
        val dx = x - otherX
        val dy = y - otherY
        return sqrt(dx * dx + dy * dy) <= AllyBattleRepository.DISTANCIA_ENTRADA
    }
}

/** Uma única batalha compartilhada por todo o grupo Ally. */
class AllyBattleRepository(
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance()
) {
    private val groups = db.collection("allyGroups")
    private val battles = db.collection("allyBattles")
    private val presence = db.collection("worldPresence")

    companion object {
        const val DISTANCIA_ENTRADA = 0.08f
    }

    suspend fun iniciarBatalha(
        groupId: String,
        starterUid: String,
        worldPointId: String,
        creatureId: String,
        initialState: CombatState
    ): String {
        val groupRef = groups.document(groupId)
        val battleRef = battles.document(UUID.randomUUID().toString())

        db.runTransaction { tx ->
            val group = tx.get(groupRef)
            require(group.exists()) { "Grupo Ally não encontrado." }
            val memberUids = (group.get("members") as? List<*>)
                ?.filterIsInstance<String>() ?: emptyList()
            require(starterUid in memberUids) { "Você não faz parte desse grupo." }

            val currentBattleId = group.getString("activeBattleId")
            if (!currentBattleId.isNullOrBlank()) {
                val oldBattle = tx.get(battles.document(currentBattleId))
                require(!oldBattle.exists() || oldBattle.getString("status") != "ACTIVE") {
                    "Seu grupo já está em combate. Entre na batalha existente."
                }
                if (oldBattle.exists() && oldBattle.getString("status") == "FINISHED") {
                    val participants = (oldBattle.get("participantUids") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                    val claimed = (oldBattle.get("claimedUids") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                    require(claimed.containsAll(participants)) {
                        "Todos os participantes precisam retirar as recompensas antes de iniciar outra batalha."
                    }
                }
            }

            val presenceSnapshots = memberUids.associateWith { uid ->
                tx.get(presence.document(uid))
            }
            val starterPresence = presenceSnapshots[starterUid]
                ?: error("Sua presença no mundo ainda não foi publicada.")
            val now = System.currentTimeMillis()
            val starterUpdated = starterPresence.getTimestamp("ultimaAtualizacao")?.toDate()?.time ?: 0L
            require(AllyBattleEligibility.isFresh(
                starterPresence.getBoolean("online") == true,
                starterUpdated,
                now
            )) { "Sua presença no mundo está desatualizada. Aguarde a sincronização." }
            require(starterPresence.getString("worldPointId") == worldPointId) {
                "Você precisa estar na mesma área da criatura para iniciar o combate."
            }
            val starterX = starterPresence.getDouble("x")?.toFloat()
                ?: error("Posição do jogador indisponível.")
            val starterY = starterPresence.getDouble("y")?.toFloat()
                ?: error("Posição do jogador indisponível.")

            val battleMembers = memberUids.mapNotNull { uid ->
                val doc = presenceSnapshots[uid] ?: return@mapNotNull null
                val updated = doc.getTimestamp("ultimaAtualizacao")?.toDate()?.time ?: 0L
                val fresh = AllyBattleEligibility.isFresh(doc.getBoolean("online") == true, updated, now)
                val sameArea = doc.getString("worldPointId") == worldPointId
                val x = doc.getDouble("x")?.toFloat() ?: 0.5f
                val y = doc.getDouble("y")?.toFloat() ?: 0.5f
                val nearby = AllyBattleEligibility.isNearby(x, y, starterX, starterY)
                if (uid != starterUid && (!fresh || !sameArea || !nearby)) {
                    return@mapNotNull null
                }
                val hero = if (uid == starterUid) initialState.hero else Combatant(
                    name = doc.getString("nome") ?: "Aventureiro",
                    maxHp = (doc.getLong("vidaMaxima") ?: 1L).toInt().coerceAtLeast(1),
                    hp = (doc.getLong("vida") ?: 1L).toInt().coerceAtLeast(0),
                    attack = (doc.getLong("ataque") ?: 1L).toInt().coerceAtLeast(1),
                    defense = (doc.getLong("defesa") ?: 0L).toInt().coerceAtLeast(0),
                    mana = (doc.getLong("mana") ?: 0L).toInt().coerceAtLeast(0),
                    maxMana = (doc.getLong("manaMaxima") ?: 0L).toInt().coerceAtLeast(0),
                    level = (doc.getLong("nivel") ?: 1L).toInt().coerceAtLeast(1),
                    agility = (doc.getLong("agilidade") ?: 1L).toInt().coerceAtLeast(1),
                    magicPower = (doc.getLong("poderMagico") ?: 0L).toInt().coerceAtLeast(0)
                )
                AllyBattleMember(
                    uid = uid,
                    name = doc.getString("nome") ?: hero.name,
                    hero = hero
                )
            }.toMutableList()

            require(battleMembers.any { it.uid == starterUid }) {
                "Não foi possível incluir o líder no combate."
            }

            val first = battleMembers.first { it.uid == starterUid }
            val synchronizedState = initialState.copy(hero = first.hero)
            tx.set(battleRef, mapOf(
                "groupId" to groupId,
                "worldPointId" to worldPointId,
                "creatureId" to creatureId,
                "starterUid" to starterUid,
                "members" to battleMembers.map { it.toMap() },
                "participantUids" to battleMembers.map { it.uid },
                "activePlayerUid" to starterUid,
                "state" to synchronizedState.toMap(),
                "status" to "ACTIVE",
                "claimedUids" to emptyList<String>(),
                "revision" to 0L,
                "createdAt" to FieldValue.serverTimestamp(),
                "updatedAt" to FieldValue.serverTimestamp()
            ))
            tx.update(groupRef, mapOf(
                "activeBattleId" to battleRef.id,
                "updatedAt" to FieldValue.serverTimestamp()
            ))
            null
        }.await()

        return battleRef.id
    }

    /** Um aliado que chegou perto pode entrar na batalha que ainda está ativa. */
    suspend fun entrarNaBatalha(battleId: String, uid: String) {
        val battleRef = battles.document(battleId)
        db.runTransaction { tx ->
            val battle = tx.get(battleRef)
            require(battle.exists() && battle.getString("status") == "ACTIVE") { "Essa batalha já terminou." }
            val groupId = battle.getString("groupId") ?: error("Grupo inválido.")
            val group = tx.get(groups.document(groupId))
            val groupMembers = (group.get("members") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
            require(uid in groupMembers) { "Você não pertence a esse grupo." }
            val members = readMembers(battle.get("members"))
            require(members.none { it.uid == uid }) { "Você já está nessa batalha." }

            val playerPresence = tx.get(presence.document(uid))
            val updated = playerPresence.getTimestamp("ultimaAtualizacao")?.toDate()?.time ?: 0L
            require(AllyBattleEligibility.isFresh(playerPresence.getBoolean("online") == true, updated, System.currentTimeMillis())) {
                "Sua presença online está desatualizada. Aguarde a atualização do mundo."
            }
            val area = battle.getString("worldPointId") ?: ""
            require(playerPresence.getString("worldPointId") == area) { "Você precisa estar na mesma área." }
            val x = playerPresence.getDouble("x")?.toFloat() ?: 0.5f
            val y = playerPresence.getDouble("y")?.toFloat() ?: 0.5f
            val agora = System.currentTimeMillis()
            val perto = members.any { member ->
                val other = tx.get(presence.document(member.uid))
                val otherUpdated = other.getTimestamp("ultimaAtualizacao")?.toDate()?.time ?: 0L
                val otherOnline = AllyBattleEligibility.isFresh(other.getBoolean("online") == true, otherUpdated, agora)
                val sameArea = other.getString("worldPointId") == area
                val ox = other.getDouble("x")?.toFloat() ?: 0.5f
                val oy = other.getDouble("y")?.toFloat() ?: 0.5f
                otherOnline && sameArea && AllyBattleEligibility.isNearby(x, y, ox, oy)
            }
            require(perto) { "Chegue mais perto de um integrante em combate para entrar." }

            val hero = Combatant(
                name = playerPresence.getString("nome") ?: "Aventureiro",
                maxHp = (playerPresence.getLong("vidaMaxima") ?: 1L).toInt().coerceAtLeast(1),
                hp = (playerPresence.getLong("vida") ?: 1L).toInt().coerceAtLeast(0),
                attack = (playerPresence.getLong("ataque") ?: 1L).toInt().coerceAtLeast(1),
                defense = (playerPresence.getLong("defesa") ?: 0L).toInt().coerceAtLeast(0),
                mana = (playerPresence.getLong("mana") ?: 0L).toInt().coerceAtLeast(0),
                maxMana = (playerPresence.getLong("manaMaxima") ?: 0L).toInt().coerceAtLeast(0),
                level = (playerPresence.getLong("nivel") ?: 1L).toInt().coerceAtLeast(1),
                agility = (playerPresence.getLong("agilidade") ?: 1L).toInt().coerceAtLeast(1),
                magicPower = (playerPresence.getLong("poderMagico") ?: 0L).toInt().coerceAtLeast(0)
            )
            val name = playerPresence.getString("nome") ?: hero.name
            tx.update(battleRef, mapOf(
                "members" to (members + AllyBattleMember(uid, name, hero)).map { it.toMap() },
                "participantUids" to (members.map { it.uid } + uid),
                "revision" to ((battle.getLong("revision") ?: 0L) + 1L),
                "updatedAt" to FieldValue.serverTimestamp()
            ))
            null
        }.await()
    }

    suspend fun executarAcao(battleId: String, uid: String, acao: String) {
        atualizarBatalha(battleId, uid) { state, members ->
            when {
                acao == "ATACAR" -> CombatSystem.playerAttack(state)
                acao == "DEFENDER" -> CombatSystem.playerDefend(state)
                acao.startsWith("HABILIDADE:") ->
                    CombatSystem.playerUseSkill(state, acao.substringAfter(":"))
                acao == "INIMIGO" -> CombatSystem.enemyAttack(state)
                acao == "CONTINUAR_CARREGAMENTO" -> CombatSystem.playerContinueCharge(state)
                acao == "LIBERAR_CARREGAMENTO" -> CombatSystem.playerReleaseChargedSkill(state)
                acao == "ESPECIAL" -> CombatSystem.playerSpecial(state)
                acao == "COMBO" -> {
                    val aliadosVivos = members.filter { it.uid != uid && it.hero.isAlive }
                    require(aliadosVivos.isNotEmpty()) { "Combo exige pelo menos um aliado vivo." }
                    val funcoes = members.filter { it.hero.isAlive }.map { it.role }.distinct().size
                    val multiplicador = when {
                        funcoes >= 3 -> 1.65
                        funcoes == 2 -> 1.45
                        else -> 1.25
                    }
                    val ataqueCombinado = state.copy(
                        hero = state.hero.copy(attack = (state.hero.attack * multiplicador).toInt()),
                        log = state.log + "Combo de equipe! Funções cooperando: $funcoes."
                    )
                    val resultadoCombo = CombatSystem.playerAttack(ataqueCombinado)
                    resultadoCombo.copy(hero = resultadoCombo.hero.copy(attack = state.hero.attack))
                }
                acao == "REVIVER" -> {
                    val indice = members.indexOfFirst { it.uid != uid && !it.hero.isAlive }
                    require(indice >= 0) { "Nenhum aliado caído precisa ser reanimado." }
                    val caido = members[indice]
                    members[indice] = caido.copy(
                        hero = caido.hero.copy(hp = (caido.hero.maxHp * 0.35).toInt().coerceAtLeast(1))
                    )
                    state.copy(
                        phase = CombatPhase.ENEMY_TURN,
                        log = state.log + "${caido.name} foi reanimado por um aliado!"
                    )
                }
                else -> error("Ação de combate inválida.")
            }
        }
    }

    private suspend fun atualizarBatalha(
        battleId: String,
        uid: String,
        aplicar: (CombatState, MutableList<AllyBattleMember>) -> CombatState
    ) {
        val ref = battles.document(battleId)
        db.runTransaction { tx ->
            val doc = tx.get(ref)
            require(doc.exists() && doc.getString("status") == "ACTIVE") { "Essa batalha não está ativa." }
            require(doc.getString("activePlayerUid") == uid) { "Aguarde seu turno." }
            val members = readMembers(doc.get("members")).toMutableList()
            var state = stateFromMap(doc.get("state") as? Map<*, *> ?: error("Estado da batalha inválido."))
            val phaseEsperada = if (state.phase == CombatPhase.ENEMY_TURN) "INIMIGO" else "JOGADOR"
            if (phaseEsperada == "INIMIGO") require(state.phase == CombatPhase.ENEMY_TURN && state.hero.isAlive)
            else require(state.phase == CombatPhase.PLAYER_TURN)

            val oldEnemyHp = state.enemy.hp
            state = aplicar(state, members)
            val memberIndex = members.indexOfFirst { it.uid == uid }
            if (memberIndex >= 0) {
                val old = members[memberIndex]
                val damage = (oldEnemyHp - state.enemy.hp).coerceAtLeast(0)
                members[memberIndex] = old.copy(
                    hero = state.hero,
                    damageDealt = old.damageDealt + damage,
                    specialCharge = state.especialCarga,
                    specialUsed = state.especialUsado,
                    skillCooldowns = state.recargasJogador,
                    playerStun = state.turnosAtordoadoJogador,
                    chargingSkill = state.carregandoHabilidadeJogador,
                    chargeTurns = state.turnosRestantesCarregamentoJogador,
                    chargeBreak = state.quebraAtaqueCarregadoJogador,
                    chargeBreakMax = state.quebraAtaqueCarregadoMaximaJogador
                )
            }

            var nextUid = uid
            var status = "ACTIVE"
            if (state.phase == CombatPhase.VICTORY || state.phase == CombatPhase.ENEMY_ESCAPED) {
                status = "FINISHED"
            } else if (phaseEsperada == "INIMIGO") {
                val alive = members.filter { it.hero.isAlive }
                if (alive.isEmpty()) {
                    state = state.copy(phase = CombatPhase.DEFEAT)
                    status = "FINISHED"
                } else {
                    val currentIndex = members.indexOfFirst { it.uid == uid }
                    val ordered = (1..members.size).map { step -> members[(currentIndex + step) % members.size] }
                    val next = ordered.firstOrNull { it.hero.isAlive } ?: alive.first()
                    nextUid = next.uid
                    state = state.copy(
                        hero = next.hero,
                        especialCarga = next.specialCharge,
                        especialUsado = next.specialUsed,
                        recargasJogador = next.skillCooldowns,
                        turnosAtordoadoJogador = next.playerStun,
                        carregandoHabilidadeJogador = next.chargingSkill,
                        turnosRestantesCarregamentoJogador = next.chargeTurns,
                        quebraAtaqueCarregadoJogador = next.chargeBreak,
                        quebraAtaqueCarregadoMaximaJogador = next.chargeBreakMax,
                        phase = CombatPhase.PLAYER_TURN,
                        playerDefending = false,
                        defenseReduction = 0,
                        playerVulnerable = false,
                        pendingEffectsOnHero = emptyList(),
                        log = state.log + "Turno de ${next.name}."
                    )
                }
            } else if (state.phase == CombatPhase.DEFEAT) {
                status = "FINISHED"
            }

            tx.update(ref, mapOf(
                "members" to members.map { it.toMap() },
                "activePlayerUid" to nextUid,
                "state" to state.toMap(),
                "status" to status,
                "revision" to ((doc.getLong("revision") ?: 0L) + 1L),
                "updatedAt" to FieldValue.serverTimestamp()
            ))
            null
        }.await()
    }

    /**
     * Recupera uma batalha quando o dono do turno fica inativo por tempo prolongado.
     * O aliado que estiver conectado pode executar uma defesa automática e o turno do inimigo,
     * sem apagar o estado compartilhado nem conceder recompensas.
     */
    suspend fun recuperarTurnoInativo(
        battleId: String,
        uid: String
    ): Boolean {
        require(uid.isNotBlank()) { "Participante inválido." }
        val ref = battles.document(battleId)
        return db.runTransaction { tx ->
            val doc = tx.get(ref)
            if (!doc.exists() || doc.getString("status") != "ACTIVE") {
                return@runTransaction false
            }
            val participants = (doc.get("participantUids") as? List<*>)
                ?.filterIsInstance<String>() ?: emptyList()
            if (uid !in participants) return@runTransaction false

            val members = readMembers(doc.get("members")).toMutableList()
            val currentUid = doc.getString("activePlayerUid") ?: return@runTransaction false
            val currentIndex = members.indexOfFirst { it.uid == currentUid }
            if (currentIndex < 0) return@runTransaction false

            var state = stateFromMap(doc.get("state") as? Map<*, *>
                ?: return@runTransaction false)
            state = when (state.phase) {
                CombatPhase.PLAYER_TURN -> CombatSystem.playerDefend(state)
                CombatPhase.ENEMY_TURN -> state
                else -> return@runTransaction false
            }
            if (state.phase == CombatPhase.ENEMY_TURN) {
                state = CombatSystem.enemyAttack(state)
            }

            val current = members[currentIndex]
            members[currentIndex] = current.copy(
                hero = state.hero,
                specialCharge = state.especialCarga,
                specialUsed = state.especialUsado,
                skillCooldowns = state.recargasJogador,
                playerStun = state.turnosAtordoadoJogador,
                chargingSkill = state.carregandoHabilidadeJogador,
                chargeTurns = state.turnosRestantesCarregamentoJogador,
                chargeBreak = state.quebraAtaqueCarregadoJogador,
                chargeBreakMax = state.quebraAtaqueCarregadoMaximaJogador
            )

            // A queda do herói atual não encerra o grupo se ainda houver aliados vivos.
            val defeated = members.none { it.hero.isAlive }
            var nextUid = currentUid
            var status = "ACTIVE"
            if (defeated) {
                state = state.copy(phase = CombatPhase.DEFEAT)
                status = "FINISHED"
            } else {
                val ordered = (1..members.size).map { step ->
                    members[(currentIndex + step) % members.size]
                }
                val next = ordered.firstOrNull { it.hero.isAlive }
                    ?: members[currentIndex]
                nextUid = next.uid
                state = state.copy(
                    hero = next.hero,
                    especialCarga = next.specialCharge,
                    especialUsado = next.specialUsed,
                    recargasJogador = next.skillCooldowns,
                    turnosAtordoadoJogador = next.playerStun,
                    carregandoHabilidadeJogador = next.chargingSkill,
                    turnosRestantesCarregamentoJogador = next.chargeTurns,
                    quebraAtaqueCarregadoJogador = next.chargeBreak,
                    quebraAtaqueCarregadoMaximaJogador = next.chargeBreakMax,
                    phase = CombatPhase.PLAYER_TURN,
                    playerDefending = false,
                    defenseReduction = 0,
                    playerVulnerable = false,
                    pendingEffectsOnHero = emptyList(),
                    log = state.log + "O turno foi recuperado após inatividade. Vez de ${next.name}."
                )
            }

            tx.update(ref, mapOf(
                "members" to members.map { it.toMap() },
                "activePlayerUid" to nextUid,
                "state" to state.toMap(),
                "status" to status,
                "revision" to ((doc.getLong("revision") ?: 0L) + 1L),
                "updatedAt" to FieldValue.serverTimestamp()
            ))
            true
        }.await()
    }

    suspend fun obterBatalha(battleId: String): AllyBattleSnapshot? {
        val doc = battles.document(battleId).get().await()
        return snapshotFromDocument(doc)
    }

    fun observarBatalha(battleId: String, callback: (AllyBattleSnapshot?) -> Unit): ListenerRegistration {
        return battles.document(battleId).addSnapshotListener { doc, error ->
            if (error != null || doc == null) {
                callback(null)
                return@addSnapshotListener
            }
            callback(snapshotFromDocument(doc))
        }
    }

    private fun snapshotFromDocument(doc: DocumentSnapshot): AllyBattleSnapshot? {
        if (!doc.exists()) return null
        val stateMap = doc.get("state") as? Map<*, *> ?: return null
        return AllyBattleSnapshot(
            id = doc.id,
            groupId = doc.getString("groupId") ?: "",
            worldPointId = doc.getString("worldPointId") ?: "",
            creatureId = doc.getString("creatureId") ?: "",
            members = readMembers(doc.get("members")),
            activePlayerUid = doc.getString("activePlayerUid") ?: "",
            state = stateFromMap(stateMap),
            status = doc.getString("status") ?: "ACTIVE",
            revision = doc.getLong("revision") ?: 0L,
            claimedUids = (doc.get("claimedUids") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
        )
    }

    private fun readMembers(raw: Any?): List<AllyBattleMember> =
        (raw as? List<*>)?.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val uid = map["uid"] as? String ?: return@mapNotNull null
            val heroMap = map["hero"] as? Map<*, *> ?: return@mapNotNull null
            AllyBattleMember(
                uid = uid,
                name = map["name"] as? String ?: "Aventureiro",
                hero = combatantFromMap(heroMap),
                damageDealt = (map["damageDealt"] as? Number)?.toInt() ?: 0,
                role = map["role"] as? String ?: when {
                    combatantFromMap(heroMap).defense >= combatantFromMap(heroMap).attack && combatantFromMap(heroMap).defense > combatantFromMap(heroMap).magicPower -> "GUARDIÃO"
                    combatantFromMap(heroMap).magicPower >= combatantFromMap(heroMap).attack -> "MAGO"
                    else -> "ATACANTE"
                },
                specialCharge = (map["specialCharge"] as? Number)?.toInt() ?: 0,
                specialUsed = map["specialUsed"] as? Boolean ?: false,
                skillCooldowns = (map["skillCooldowns"] as? Map<*, *>)?.mapNotNull { (k, v) -> if (k is String && v is Number) k to v.toInt() else null }?.toMap() ?: emptyMap(),
                playerStun = (map["playerStun"] as? Number)?.toInt() ?: 0,
                chargingSkill = (map["chargingSkill"] as? Map<*, *>)?.takeIf { it.isNotEmpty() }?.let { attackFromMap(it) },
                chargeTurns = (map["chargeTurns"] as? Number)?.toInt() ?: 0,
                chargeBreak = (map["chargeBreak"] as? Number)?.toInt() ?: 0,
                chargeBreakMax = (map["chargeBreakMax"] as? Number)?.toInt() ?: 0
            )
        } ?: emptyList()

    private fun AllyBattleMember.toMap(): Map<String, Any> = mapOf(
        "uid" to uid,
        "name" to name,
        "hero" to hero.toMap(),
        "damageDealt" to damageDealt,
        "role" to role,
        "specialCharge" to specialCharge,
        "specialUsed" to specialUsed,
        "skillCooldowns" to skillCooldowns,
        "playerStun" to playerStun,
        "chargingSkill" to (chargingSkill?.toMap() ?: emptyMap<String, Any>()),
        "chargeTurns" to chargeTurns,
        "chargeBreak" to chargeBreak,
        "chargeBreakMax" to chargeBreakMax
    )

    private fun Combatant.toMap(): Map<String, Any> = mapOf(
        "name" to name, "maxHp" to maxHp, "hp" to hp, "attack" to attack,
        "defense" to defense, "mana" to mana, "maxMana" to maxMana,
        "rank" to rank, "level" to level, "danger" to danger,
        "xpReward" to xpReward, "isBoss" to isBoss, "agility" to agility,
        "magicPower" to magicPower, "attacks" to attacks.map { it.toMap() }
    )

    private fun combatantFromMap(map: Map<*, *>): Combatant = Combatant(
        name = map["name"] as? String ?: "Aventureiro",
        maxHp = (map["maxHp"] as? Number)?.toInt() ?: 1,
        hp = (map["hp"] as? Number)?.toInt() ?: 1,
        attack = (map["attack"] as? Number)?.toInt() ?: 1,
        defense = (map["defense"] as? Number)?.toInt() ?: 0,
        mana = (map["mana"] as? Number)?.toInt() ?: 0,
        maxMana = (map["maxMana"] as? Number)?.toInt() ?: 0,
        rank = map["rank"] as? String ?: "E",
        level = (map["level"] as? Number)?.toInt() ?: 1,
        danger = (map["danger"] as? Number)?.toInt() ?: 30,
        xpReward = (map["xpReward"] as? Number)?.toInt() ?: 0,
        isBoss = map["isBoss"] as? Boolean ?: false,
        agility = (map["agility"] as? Number)?.toInt() ?: 5,
        magicPower = (map["magicPower"] as? Number)?.toInt() ?: 0,
        attacks = (map["attacks"] as? List<*>)?.mapNotNull { it as? Map<*, *> }?.map { attackFromMap(it) } ?: emptyList()
    )

    private fun AtaqueCriatura.toMap(): Map<String, Any> = mapOf(
        "id" to id, "nome" to nome, "descricao" to descricao, "tipoDano" to tipoDano,
        "elemento" to elemento, "danoBase" to danoBase, "multiplicador" to multiplicador,
        "custoMana" to custoMana, "custoManaMinimo" to custoManaMinimo,
        "custoManaMaximo" to custoManaMaximo, "efeitos" to efeitos,
        "duracaoTurnos" to duracaoTurnos, "chanceAplicacao" to chanceAplicacao,
        "chanceUso" to chanceUso, "turnosCarregamento" to turnosCarregamento,
        "turnosRecarga" to turnosRecarga, "podeSerInterrompida" to podeSerInterrompida, "categoria" to categoria, "danoQuebra" to danoQuebra
    )

    private fun attackFromMap(map: Map<*, *>): AtaqueCriatura = AtaqueCriatura(
        id = map["id"] as? String ?: "", nome = map["nome"] as? String ?: "",
        descricao = map["descricao"] as? String ?: "", tipoDano = map["tipoDano"] as? String ?: "FISICO",
        elemento = map["elemento"] as? String ?: "NEUTRO", danoBase = (map["danoBase"] as? Number)?.toInt() ?: 0,
        multiplicador = (map["multiplicador"] as? Number)?.toFloat() ?: 1f,
        custoMana = (map["custoMana"] as? Number)?.toInt() ?: 0,
        custoManaMinimo = (map["custoManaMinimo"] as? Number)?.toInt() ?: 0,
        custoManaMaximo = (map["custoManaMaximo"] as? Number)?.toInt() ?: 0,
        efeitos = (map["efeitos"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
        duracaoTurnos = (map["duracaoTurnos"] as? Number)?.toInt() ?: 0,
        chanceAplicacao = (map["chanceAplicacao"] as? Number)?.toInt() ?: 100,
        chanceUso = (map["chanceUso"] as? Number)?.toInt() ?: 50,
        turnosCarregamento = (map["turnosCarregamento"] as? Number)?.toInt() ?: 0,
        turnosRecarga = (map["turnosRecarga"] as? Number)?.toInt() ?: 0,
        podeSerInterrompida = map["podeSerInterrompida"] as? Boolean ?: true,
        categoria = map["categoria"] as? String ?: "NORMAL",
        danoQuebra = (map["danoQuebra"] as? Number)?.toInt() ?: 0
    )

    private fun CombatState.toMap(): Map<String, Any> = mapOf(
        "hero" to hero.toMap(), "enemy" to enemy.toMap(), "phase" to phase.name,
        "turn" to turn, "log" to log, "enemyDefending" to enemyDefending,
        "playerDefending" to playerDefending, "defenseReduction" to defenseReduction,
        "playerContribution" to playerContribution, "xpGained" to xpGained,
        "playerVulnerable" to playerVulnerable, "enemyVulnerable" to enemyVulnerable,
        "pendingEffectsOnHero" to pendingEffectsOnHero,
        "carregandoHabilidadeJogador" to (carregandoHabilidadeJogador?.toMap() ?: emptyMap<String, Any>()),
        "turnosRestantesCarregamentoJogador" to turnosRestantesCarregamentoJogador,
        "carregandoHabilidadeInimigo" to (carregandoHabilidadeInimigo?.toMap() ?: emptyMap<String, Any>()),
        "turnosRestantesCarregamentoInimigo" to turnosRestantesCarregamentoInimigo,
        "custoManaHabilidadeInimigoCarregando" to custoManaHabilidadeInimigoCarregando,
        "danoHabilidadeInimigoCarregando" to danoHabilidadeInimigoCarregando,
        "quebraAtaqueCarregadoJogador" to quebraAtaqueCarregadoJogador,
        "quebraAtaqueCarregadoMaximaJogador" to quebraAtaqueCarregadoMaximaJogador,
        "quebraAtaqueCarregadoInimigo" to quebraAtaqueCarregadoInimigo,
        "quebraAtaqueCarregadoMaximaInimigo" to quebraAtaqueCarregadoMaximaInimigo,
        "turnosAtordoadoInimigo" to turnosAtordoadoInimigo,
        "recargasJogador" to recargasJogador,
        "recargasInimigo" to recargasInimigo,
        "especialCarga" to especialCarga, "especialUsado" to especialUsado,
        "turnosAtordoadoJogador" to turnosAtordoadoJogador,
        "efeitoVisualAtual" to efeitoVisualAtual
    )

    private fun stateFromMap(map: Map<*, *>): CombatState {
        val hero = combatantFromMap(map["hero"] as? Map<*, *> ?: emptyMap<Any, Any>())
        val enemy = combatantFromMap(map["enemy"] as? Map<*, *> ?: emptyMap<Any, Any>())
        fun attack(key: String): AtaqueCriatura? =
            (map[key] as? Map<*, *>)?.takeIf { it.isNotEmpty() }?.let { attackFromMap(it) }
        fun int(key: String, default: Int = 0) = (map[key] as? Number)?.toInt() ?: default
        fun bool(key: String) = map[key] as? Boolean ?: false
        fun intMap(key: String) = (map[key] as? Map<*, *>)?.entries?.mapNotNull { (k, v) ->
            if (k is String && v is Number) k to v.toInt() else null
        }?.toMap() ?: emptyMap()
        return CombatState(
            hero = hero, enemy = enemy,
            phase = runCatching { CombatPhase.valueOf(map["phase"] as? String ?: "PLAYER_TURN") }.getOrDefault(CombatPhase.PLAYER_TURN),
            turn = int("turn", 1), log = (map["log"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
            enemyDefending = bool("enemyDefending"), playerDefending = bool("playerDefending"),
            defenseReduction = int("defenseReduction"),
            playerContribution = (map["playerContribution"] as? Number)?.toFloat() ?: 1f,
            xpGained = int("xpGained"), playerVulnerable = bool("playerVulnerable"),
            enemyVulnerable = bool("enemyVulnerable"),
            pendingEffectsOnHero = (map["pendingEffectsOnHero"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
            carregandoHabilidadeJogador = attack("carregandoHabilidadeJogador"),
            turnosRestantesCarregamentoJogador = int("turnosRestantesCarregamentoJogador"),
            carregandoHabilidadeInimigo = attack("carregandoHabilidadeInimigo"),
            turnosRestantesCarregamentoInimigo = int("turnosRestantesCarregamentoInimigo"),
            custoManaHabilidadeInimigoCarregando = int("custoManaHabilidadeInimigoCarregando"),
            danoHabilidadeInimigoCarregando = int("danoHabilidadeInimigoCarregando"),
            quebraAtaqueCarregadoJogador = int("quebraAtaqueCarregadoJogador"),
            quebraAtaqueCarregadoMaximaJogador = int("quebraAtaqueCarregadoMaximaJogador"),
            quebraAtaqueCarregadoInimigo = int("quebraAtaqueCarregadoInimigo"),
            quebraAtaqueCarregadoMaximaInimigo = int("quebraAtaqueCarregadoMaximaInimigo"),
            turnosAtordoadoInimigo = int("turnosAtordoadoInimigo"),
            recargasJogador = intMap("recargasJogador"), recargasInimigo = intMap("recargasInimigo"),
            especialCarga = int("especialCarga"), especialUsado = bool("especialUsado"),
            turnosAtordoadoJogador = int("turnosAtordoadoJogador"),
            efeitoVisualAtual = map["efeitoVisualAtual"] as? String ?: ""
        )
    }
}

