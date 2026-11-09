package br.com.ascensaodosoberano.world

import kotlin.random.Random

/**
 * Núcleo local de decisão dos aventureiros autônomos.
 *
 * Este motor não chama serviços externos: recebe o estado do aventureiro e do
 * mundo e devolve uma decisão reproduzível. A camada de jogo é responsável por
 * executar a ação, persistir o novo estado e registrar os resultados.
 */
enum class AdventurerTemperament {
    CORAJOSO, PRUDENTE, AMBICIOSO, CURIOSO, SOCIAVEL, SOLITARIO, LEAL
}

enum class AdventurerRole {
    GUERREIRO, CAVALEIRO, ARQUEIRO, ASSASSINO, MAGO, CURANDEIRO, EXPLORADOR, ARTESAO
}

enum class AdventurerLifeState {
    OCIOSO, VIAJANDO, EXPLORANDO, EM_COMBATE, DESCANSANDO, EM_MISSAO, RETIRANDO
}

enum class AdventurerActionType {
    DESCANSAR,
    PROCURAR_ABRIGO,
    ACEITAR_MISSAO,
    CONTINUAR_MISSAO,
    EXPLORAR,
    COLETAR_RECURSOS,
    VIAJAR,
    AJUDAR_AVENTUREIRO,
    FORMAR_GRUPO,
    PROCURAR_COMPANHEIROS,
    RETIRAR_SE,
    PROCURAR_CIDADE,
    TREINAR,
    NEGOCIAR,
    AGUARDAR
}

enum class AdventurerMemoryType {
    VITORIA, DERROTA, FUGA, AJUDA_RECEBIDA, AJUDA_PRESTADA,
    TRAICAO, TESOURO_ENCONTRADO, CHEFE_DERROTADO, MISSAO_CONCLUIDA,
    MISSAO_FALHADA, AMIZADE_FORMADA, RIVALIDADE_FORMADA
}

data class AdventurerPersonality(
    val temperament: AdventurerTemperament,
    val courage: Int = 50,
    val ambition: Int = 50,
    val curiosity: Int = 50,
    val sociability: Int = 50,
    val loyalty: Int = 50,
    val caution: Int = 50
) {
    fun normalized(): AdventurerPersonality = copy(
        courage = courage.coerceIn(0, 100),
        ambition = ambition.coerceIn(0, 100),
        curiosity = curiosity.coerceIn(0, 100),
        sociability = sociability.coerceIn(0, 100),
        loyalty = loyalty.coerceIn(0, 100),
        caution = caution.coerceIn(0, 100)
    )
}

data class AdventurerMemory(
    val id: String,
    val type: AdventurerMemoryType,
    val description: String,
    val relatedCharacterId: String? = null,
    val worldPointId: String? = null,
    val createdAtEpochMillis: Long = 0L,
    val emotionalWeight: Int = 50
)

data class AdventurerRelationship(
    val characterId: String,
    val affinity: Int = 0,
    val trust: Int = 0,
    val rivalry: Int = 0,
    val sharedVictories: Int = 0,
    val sharedDefeats: Int = 0
) {
    fun normalized(): AdventurerRelationship = copy(
        affinity = affinity.coerceIn(-100, 100),
        trust = trust.coerceIn(-100, 100),
        rivalry = rivalry.coerceIn(0, 100),
        sharedVictories = sharedVictories.coerceAtLeast(0),
        sharedDefeats = sharedDefeats.coerceAtLeast(0)
    )
}

data class AutonomousAdventurer(
    val id: String,
    val displayName: String,
    val role: AdventurerRole,
    val level: Int = 1,
    val experience: Long = 0L,
    val health: Int = 100,
    val maxHealth: Int = 100,
    val stamina: Int = 100,
    val maxStamina: Int = 100,
    val mana: Int = 0,
    val maxMana: Int = 0,
    val gold: Long = 0L,
    val worldPointId: String,
    val personality: AdventurerPersonality,
    val lifeState: AdventurerLifeState = AdventurerLifeState.OCIOSO,
    val currentMissionId: String? = null,
    val currentGoal: String? = null,
    val partyId: String? = null,
    val memories: List<AdventurerMemory> = emptyList(),
    val relationships: List<AdventurerRelationship> = emptyList(),
    val lastDecisionAtEpochMillis: Long = 0L,
    val decisionCooldownUntilEpochMillis: Long = 0L
) {
    fun normalized(): AutonomousAdventurer = copy(
        level = level.coerceAtLeast(1),
        experience = experience.coerceAtLeast(0L),
        health = health.coerceIn(0, maxHealth.coerceAtLeast(1)),
        maxHealth = maxHealth.coerceAtLeast(1),
        stamina = stamina.coerceIn(0, maxStamina.coerceAtLeast(1)),
        maxStamina = maxStamina.coerceAtLeast(1),
        mana = mana.coerceIn(0, maxMana.coerceAtLeast(0)),
        maxMana = maxMana.coerceAtLeast(0),
        gold = gold.coerceAtLeast(0L),
        personality = personality.normalized(),
        memories = memories.takeLast(MAX_MEMORIES),
        relationships = relationships.map { it.normalized() }.distinctBy { it.characterId }
    )

    companion object {
        const val MAX_MEMORIES = 40
    }
}

data class AdventurerMissionOffer(
    val id: String,
    val recommendedLevel: Int,
    val danger: Int,
    val rewardGold: Long = 0L,
    val rewardExperience: Long = 0L,
    val targetWorldPointId: String,
    val requiresParty: Boolean = false,
    val isBossMission: Boolean = false
)

data class AdventurerWorldSnapshot(
    val worldPointId: String,
    val regionId: String,
    val danger: Int = 0,
    val isSettlement: Boolean = false,
    val isSafeZone: Boolean = false,
    val hasShelter: Boolean = false,
    val hasResourceNodes: Boolean = false,
    val hasTraining: Boolean = false,
    val nearbyThreat: Boolean = false,
    val nearbyWoundedAdventurerId: String? = null,
    val availableMissionOffers: List<AdventurerMissionOffer> = emptyList(),
    val knownTravelDestinations: List<String> = emptyList(),
    val nearbyAdventurerIds: List<String> = emptyList(),
    val currentEpochMillis: Long = 0L
)

data class AdventurerDecision(
    val action: AdventurerActionType,
    val priority: Int,
    val reason: String,
    val targetId: String? = null,
    val destinationWorldPointId: String? = null,
    val missionId: String? = null,
    val cooldownMillis: Long = 30_000L
)

object AutonomousAdventurerAI {
    private const val CRITICAL_HEALTH_PERCENT = 20
    private const val LOW_STAMINA_PERCENT = 18
    private const val LOW_HEALTH_PERCENT = 45

    /**
     * Avalia necessidades, personalidade, memória, relações e contexto local.
     * A função é pura: não altera o aventureiro nem executa ações no mundo.
     */
    fun decide(
        rawAdventurer: AutonomousAdventurer,
        world: AdventurerWorldSnapshot,
        random: Random = Random.Default
    ): AdventurerDecision {
        val adventurer = rawAdventurer.normalized()
        val personality = adventurer.personality
        val danger = world.danger.coerceIn(0, 100)
        val healthPercent = percent(adventurer.health, adventurer.maxHealth)
        val staminaPercent = percent(adventurer.stamina, adventurer.maxStamina)

        if (world.currentEpochMillis < adventurer.decisionCooldownUntilEpochMillis) {
            return decision(AdventurerActionType.AGUARDAR, 5, "Ainda está avaliando a situação.", cooldown = 10_000L)
        }

        // Sobrevivência sempre tem prioridade sobre ambição e exploração.
        if (healthPercent <= CRITICAL_HEALTH_PERCENT) {
            return when {
                world.isSafeZone -> decision(
                    AdventurerActionType.DESCANSAR, 100,
                    "Está gravemente ferido e precisa se recuperar.", cooldown = 90_000L
                )
                world.hasShelter -> decision(
                    AdventurerActionType.PROCURAR_ABRIGO, 100,
                    "Está ferido demais para continuar exposto.", cooldown = 60_000L
                )
                else -> decision(
                    AdventurerActionType.RETIRAR_SE, 100,
                    "A sobrevivência é mais importante que a missão.", cooldown = 45_000L
                )
            }
        }

        if (staminaPercent <= LOW_STAMINA_PERCENT && !world.nearbyThreat) {
            return decision(
                if (world.isSafeZone || world.hasShelter) AdventurerActionType.DESCANSAR
                else AdventurerActionType.PROCURAR_ABRIGO,
                90, "Precisa recuperar o fôlego antes de se arriscar.", cooldown = 75_000L
            )
        }

        // Um aventureiro prudente evita combates desnecessários; um corajoso
        // aceita riscos maiores, mas não ignora uma situação quase fatal.
        if (world.nearbyThreat && healthPercent < LOW_HEALTH_PERCENT) {
            val escapeScore = personality.caution + (100 - personality.courage) / 2
            if (random.nextInt(100) < escapeScore.coerceIn(10, 95)) {
                return decision(
                    AdventurerActionType.RETIRAR_SE, 85,
                    "Percebeu que o combate pode terminar em derrota.", cooldown = 40_000L
                )
            }
        }

        val woundedId = world.nearbyWoundedAdventurerId
        if (woundedId != null && personality.sociability >= 45) {
            val relationship = adventurer.relationships.firstOrNull { it.characterId == woundedId }
            val affinityBonus = relationship?.affinity?.coerceAtLeast(0) ?: 0
            val loyaltyBonus = if (personality.temperament == AdventurerTemperament.LEAL) 20 else 0
            val helpChance = (personality.sociability + affinityBonus / 2 + loyaltyBonus).coerceIn(0, 100)
            if (random.nextInt(100) < helpChance) {
                return decision(
                    AdventurerActionType.AJUDAR_AVENTUREIRO, 82,
                    "Decidiu ajudar um aventureiro ferido.", targetId = woundedId,
                    cooldown = 35_000L
                )
            }
        }

        if (adventurer.currentMissionId != null) {
            return decision(
                AdventurerActionType.CONTINUAR_MISSAO, 75,
                "Está comprometido com uma missão e pretende concluí-la.",
                missionId = adventurer.currentMissionId,
                cooldown = 25_000L
            )
        }

        val suitableMission = chooseMission(adventurer, world, random)
        if (suitableMission != null) {
            return decision(
                AdventurerActionType.ACEITAR_MISSAO, 70,
                missionReason(adventurer, suitableMission),
                missionId = suitableMission.id,
                destination = suitableMission.targetWorldPointId,
                cooldown = 45_000L
            )
        }

        if (world.isSettlement && world.hasTraining && personality.ambition >= 65) {
            return decision(
                AdventurerActionType.TREINAR, 55,
                "Quer aprimorar suas habilidades antes da próxima jornada.",
                cooldown = 120_000L
            )
        }

        if (world.hasResourceNodes && personality.ambition >= 35) {
            return decision(
                AdventurerActionType.COLETAR_RECURSOS, 48,
                "Identificou recursos que podem ser úteis ou valiosos.",
                cooldown = 60_000L
            )
        }

        if (world.isSettlement && world.nearbyAdventurerIds.isNotEmpty() &&
            personality.sociability >= 60 && adventurer.partyId == null
        ) {
            val candidate = chooseCompanion(adventurer, world.nearbyAdventurerIds)
            if (candidate != null) {
                return decision(
                    AdventurerActionType.PROCURAR_COMPANHEIROS, 45,
                    "Está procurando aliados para uma futura expedição.",
                    targetId = candidate,
                    cooldown = 90_000L
                )
            }
        }

        if (personality.curiosity >= 45 && world.knownTravelDestinations.isNotEmpty()) {
            val destination = world.knownTravelDestinations
                .filter { it != world.worldPointId }
                .randomOrNull(random)
            if (destination != null) {
                val riskTolerance = (personality.courage + personality.curiosity) / 2
                if (danger <= riskTolerance || world.isSafeZone) {
                    return decision(
                        AdventurerActionType.EXPLORAR, 40,
                        "A curiosidade o levou a investigar outra área.",
                        destination = destination,
                        cooldown = 90_000L
                    )
                }
            }
        }

        if (world.isSettlement && personality.ambition >= 40 && adventurer.gold > 0L) {
            return decision(
                AdventurerActionType.NEGOCIAR, 30,
                "Pretende negociar para melhorar seus recursos.",
                cooldown = 90_000L
            )
        }

        return if (world.isSettlement) {
            decision(AdventurerActionType.AGUARDAR, 15, "Está descansando e observando o movimento local.", cooldown = 60_000L)
        } else {
            decision(AdventurerActionType.VIAJAR, 20, "Está seguindo sua jornada pelo mundo.", cooldown = 45_000L)
        }
    }

    private fun chooseMission(
        adventurer: AutonomousAdventurer,
        world: AdventurerWorldSnapshot,
        random: Random
    ): AdventurerMissionOffer? {
        val personality = adventurer.personality
        val riskTolerance = (
            personality.courage * 0.55f +
                personality.ambition * 0.25f +
                (100 - personality.caution) * 0.20f
            ).toInt().coerceIn(5, 100)

        val memoryPenalty = adventurer.memories
            .takeLast(8)
            .count { it.type == AdventurerMemoryType.DERROTA || it.type == AdventurerMemoryType.MISSAO_FALHADA } * 5

        val effectiveRisk = (riskTolerance - memoryPenalty).coerceAtLeast(5)

        val candidates = world.availableMissionOffers.filter { mission ->
            val levelGap = mission.recommendedLevel - adventurer.level
            val allowedLevelGap = if (personality.temperament == AdventurerTemperament.CORAJOSO) 4 else 2
            val canTakeRisk = mission.danger <= effectiveRisk
            val canHandleLevel = levelGap <= allowedLevelGap
            val canSoloBoss = !mission.isBossMission || adventurer.level >= mission.recommendedLevel
            val canParty = !mission.requiresParty || adventurer.partyId != null
            canTakeRisk && canHandleLevel && canSoloBoss && canParty
        }

        if (candidates.isEmpty()) return null

        val scored = candidates.map { mission ->
            val levelFit = 100 - kotlin.math.abs(mission.recommendedLevel - adventurer.level) * 12
            val rewardAppeal = (mission.rewardGold / 10L).coerceIn(0L, 30L).toInt()
            val ambitionBonus = personality.ambition / 5
            val curiosityBonus = if (mission.targetWorldPointId != world.worldPointId) personality.curiosity / 8 else 0
            val dangerPenalty = mission.danger / 4
            mission to (levelFit + rewardAppeal + ambitionBonus + curiosityBonus - dangerPenalty)
        }.sortedByDescending { it.second }

        val top = scored.take(minOf(3, scored.size))
        return top.randomOrNull(random)?.first
    }

    private fun chooseCompanion(
        adventurer: AutonomousAdventurer,
        candidates: List<String>
    ): String? {
        val known = adventurer.relationships
            .filter { it.trust >= 0 && it.rivalry < 70 }
            .map { it.characterId }
            .toSet()
        return candidates.firstOrNull { it in known } ?: candidates.firstOrNull()
    }

    private fun missionReason(
        adventurer: AutonomousAdventurer,
        mission: AdventurerMissionOffer
    ): String = when {
        mission.isBossMission -> "Acredita estar preparado para enfrentar um grande desafio."
        adventurer.personality.ambition >= 70 -> "Viu na missão uma oportunidade de crescer e conquistar recompensas."
        adventurer.personality.temperament == AdventurerTemperament.LEAL -> "Aceitou a missão porque deseja ajudar outras pessoas."
        else -> "Considerou a missão compatível com sua experiência e seus objetivos."
    }

    private fun percent(value: Int, maximum: Int): Int =
        ((value.coerceAtLeast(0).toFloat() / maximum.coerceAtLeast(1)) * 100f).toInt().coerceIn(0, 100)

    private fun decision(
        action: AdventurerActionType,
        priority: Int,
        reason: String,
        targetId: String? = null,
        destination: String? = null,
        missionId: String? = null,
        cooldown: Long
    ) = AdventurerDecision(
        action = action,
        priority = priority.coerceIn(0, 100),
        reason = reason,
        targetId = targetId,
        destinationWorldPointId = destination,
        missionId = missionId,
        cooldownMillis = cooldown.coerceAtLeast(1_000L)
    )
}
