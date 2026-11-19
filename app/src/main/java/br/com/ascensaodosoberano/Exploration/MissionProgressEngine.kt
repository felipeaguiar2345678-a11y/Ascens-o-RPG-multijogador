package br.com.ascensaodosoberano.exploration

/**
 * Motor determinístico de objetivos. Não chama IA, não inventa acontecimentos e
 * não entrega recompensas. O chamador deve emitir eventos somente após o sistema
 * de jogo correspondente confirmar o acontecimento.
 */
enum class MissionEventType {
    CREATURE_DEFEATED, MATERIAL_OBTAINED, LOCATION_DISCOVERED, EVIDENCE_FOUND,
    ESCORT_STEP_COMPLETED, PROTECTED_TARGET_SURVIVED, TRACKING_CLUE_FOUND,
    CORRUPTION_SOURCE_CLEARED, RAID_STEP_COMPLETED, REGIONAL_BOSS_DEFEATED
}

data class MissionEvent(
    val type: MissionEventType,
    val amount: Int = 1,
    val creatureId: String? = null,
    val creatureName: String? = null,
    val creatureRank: String? = null,
    val regionId: String? = null,
    val locationId: String? = null,
    val itemId: String? = null,
    val itemName: String? = null,
    val targetId: String? = null,
    val isBoss: Boolean = false,
    /** Identificador estável do acontecimento confirmado pelo jogo. */
    val eventId: String? = null
)

data class MissionProgress(
    val counters: Map<String, Int> = emptyMap(),
    val completed: Boolean = false,
    val completedStages: Set<String> = emptySet(),
    /** IDs já contabilizados para impedir que uma repetição de salvamento conte de novo. */
    val processedEventIds: Set<String> = emptySet()
)

data class MissionProgressResult(
    val progress: MissionProgress,
    val accepted: Boolean,
    val newlyCompleted: Boolean,
    val reason: String? = null
)

object MissionProgressEngine {
    private val quantityRegex = Regex("(?i)(?:derrote|elimine|recolha|obtenha|encontre|recupere|descubra|purifique)\\s+(\\d+)")
    private val rankOrder = listOf("E", "D", "C", "B", "A", "S", "SS", "SSS", "WORLD")
    private val raidStages = setOf("entrada", "grupos", "nucleo", "guardiao")

    fun apply(mission: GuildMission, current: MissionProgress, event: MissionEvent): MissionProgressResult {
        if (current.completed) return rejected(current, "Missão já concluída.")
        val eventId = event.eventId?.trim()?.takeIf { it.isNotEmpty() }
        if (eventId != null && eventId in current.processedEventIds) {
            return rejected(current, "Este acontecimento já foi contabilizado.")
        }
        if (event.amount !in 1..1000) return rejected(current, "Quantidade do evento inválida.")
        if (event.regionId != mission.regionId) return rejected(current, "Evento sem confirmação da região correta.")
        if (event.locationId != mission.destinationId) return rejected(current, "Evento sem confirmação do destino correto.")

        val kind = normalize(mission.type)
        val objective = normalize(mission.objective)
        val nextCounters = current.counters.toMutableMap()
        val nextStages = current.completedStages.toMutableSet()
        val required = quantityRegex.find(mission.objective)?.groupValues?.getOrNull(1)?.toIntOrNull() ?: 1
        val requiresEvidence = objective.contains("prova") || objective.contains("evidencia")
        val requiresCreature = objective.contains("supere uma criatura") || objective.contains("criatura de rank compativel")
        val requiresBoss = objective.contains("guardiao") || objective.contains("chefe regional") ||
            objective.contains("chefe world") || objective.contains("chefe de alto rank")
        val requiresArtifact = objective.contains("artefato raro") || objective.contains("reliquia unica") ||
            objective.contains("suprimentos roubados") || objective.contains("selo imperial")
        val requiresSample = objective.contains("amostra unica")
        val artifactTokens = targetTokens(mission.objective.substringAfter("recupere", mission.objective))

        fun add(key: String, amount: Int = event.amount) {
            nextCounters[key] = ((nextCounters[key] ?: 0) + amount).coerceAtMost(100_000)
        }
        fun stage(key: String, counterKey: String = key): Boolean {
            if (key in nextStages) return false
            nextStages += key
            add(counterKey, 1)
            return true
        }

        val accepted = when {
            event.type == MissionEventType.EVIDENCE_FOUND && requiresEvidence &&
                !kind.contains("investiga") && !(kind.contains("cacada") || kind.contains("caca")) -> {
                if (event.targetId.isNullOrBlank()) return rejected(current, "Evidência sem identificação.")
                stage("evidencia-extra:${event.targetId}", "extraEvidence")
            }
            event.type == MissionEventType.CREATURE_DEFEATED && requiresCreature &&
                !(kind.contains("cacada") || kind.contains("caca")) -> {
                val actualRank = event.creatureRank?.uppercase()
                    ?: return rejected(current, "Rank da criatura não informado.")
                val rankLimit = rankOrder.indexOf(mission.rank.uppercase())
                val actual = rankOrder.indexOf(actualRank)
                if (rankLimit < 0 || actual < 0 || actual > rankLimit) return rejected(current, "Criatura incompatível com a condição adicional.")
                stage("criatura-extra:${event.creatureId ?: event.targetId ?: "criatura"}", "extraCreature")
            }
            event.type == MissionEventType.REGIONAL_BOSS_DEFEATED && requiresBoss &&
                !kind.contains("raid") && !kind.contains("masmorra") && !kind.contains("chefe") -> {
                if (!event.isBoss) return rejected(current, "O alvo não foi confirmado como chefe.")
                val actualRank = event.creatureRank?.uppercase()
                    ?: return rejected(current, "Rank do chefe não informado.")
                val rankLimit = rankOrder.indexOf(mission.rank.uppercase())
                val actual = rankOrder.indexOf(actualRank)
                val worldBoss = objective.contains("chefe world")
                val highRankBoss = objective.contains("chefe de alto rank")
                val minimumHighRank = rankOrder.indexOf("S")
                if (rankLimit < 0 || actual < 0 ||
                    (worldBoss && actualRank != "WORLD") ||
                    (!worldBoss && (actual > rankLimit || (highRankBoss && actual < minimumHighRank)))) {
                    return rejected(current, "Chefe incompatível com a condição adicional.")
                }
                stage("boss:${event.creatureId ?: event.targetId ?: "regional"}")
            }
            event.type == MissionEventType.MATERIAL_OBTAINED &&
                ((requiresArtifact && (event.targetId == "artifact" || !kind.contains("coleta"))) ||
                    (requiresSample && event.targetId == "sample")) -> {
                if (event.itemId.isNullOrBlank()) return rejected(current, "Item especial sem identificação.")
                val received = normalize(listOfNotNull(event.itemName, event.itemId).joinToString(" "))
                if (event.targetId == "sample") {
                    stage("amostra:${event.itemId}", "sample")
                } else {
                    if (artifactTokens.isNotEmpty() && artifactTokens.none { received.contains(it) }) return rejected(current, "O item não corresponde ao artefato exigido.")
                    stage("artefato:${event.itemId}", "artifact")
                }
            }
            kind.contains("raid") || kind.contains("masmorra") -> {
                when {
                    event.type == MissionEventType.CREATURE_DEFEATED && !event.isBoss -> {
                        val actualRank = event.creatureRank?.uppercase() ?: return rejected(current, "Rank do inimigo da raid não informado.")
                        val rankLimit = rankOrder.indexOf(mission.rank.uppercase())
                        val actual = rankOrder.indexOf(actualRank)
                        if (rankLimit < 0 || actual < 0 || actual > rankLimit) return rejected(current, "Inimigo incompatível com o rank da raid.")
                        add("raidKills", 1)
                        if ((nextCounters["raidKills"] ?: 0) >= 3) stage("grupos", "raidStages")
                        true
                    }
                    event.type == MissionEventType.RAID_STEP_COMPLETED -> {
                        val step = normalize(event.targetId.orEmpty())
                        val canonical = when {
                            step.contains("entrada") -> "entrada"
                            step.contains("grupo") || step.contains("onda") -> "grupos"
                            step.contains("nucleo") || step.contains("core") -> "nucleo"
                            step.contains("guardiao") || step.contains("chefe") || step.contains("boss") ->
                                return rejected(current, "O guardião só conta após uma vitória real contra o chefe.")
                            else -> return rejected(current, "Etapa da raid desconhecida.")
                        }
                        stage(canonical)
                    }
                    event.type == MissionEventType.REGIONAL_BOSS_DEFEATED && event.isBoss -> {
                        val actualRank = event.creatureRank?.uppercase()
                            ?: return rejected(current, "Rank do guardião não informado.")
                        val rankLimit = rankOrder.indexOf(mission.rank.uppercase())
                        val actual = rankOrder.indexOf(actualRank)
                        if (rankLimit < 0 || actual < 0 || actual > rankLimit) {
                            return rejected(current, "Guardião incompatível com o rank da raid.")
                        }
                        stage("guardiao")
                    }
                    else -> return rejected(current, "A raid exige confirmação de cada etapa e do guardião.")
                }
            }
            (kind.contains("cacada") || kind.contains("caca")) && event.type == MissionEventType.EVIDENCE_FOUND -> {
                if (event.targetId.isNullOrBlank() || !requiresEvidence) return rejected(current, "Prova não faz parte deste contrato ou está sem identificação.")
                stage("prova:${event.targetId}", "evidence")
            }
            kind.contains("cacada") || kind.contains("caca") -> {
                if (event.type != MissionEventType.CREATURE_DEFEATED) return rejected(current, "A missão exige derrotar criaturas.")
                val requiredRank = mission.rank.uppercase()
                val actualRank = event.creatureRank?.uppercase() ?: return rejected(current, "Rank da criatura não informado.")
                val rankLimit = rankOrder.indexOf(requiredRank)
                val actual = rankOrder.indexOf(actualRank)
                if (rankLimit < 0 || actual < 0 || actual > rankLimit) return rejected(current, "Criatura incompatível com o rank da missão.")
                val target = targetTokens(mission.title)
                val creature = normalize(event.creatureName.orEmpty())
                if (target.isNotEmpty() && target.none { creature.contains(it) }) return rejected(current, "Criatura não corresponde ao alvo do contrato.")
                add("kills", 1)
                true
            }
            kind.contains("coleta") -> {
                if (event.type != MissionEventType.MATERIAL_OBTAINED) return rejected(current, "A missão exige obter materiais.")
                if (event.itemId.isNullOrBlank()) return rejected(current, "Material sem identificação.")
                val expectedMaterial = Regex("(?i)\\b(?:unidades?\\s+de|quantidade\\s+de|obtenha\\s+\\d+\\s+)\\s*([^.;]+)")
                    .find(mission.objective)?.groupValues?.getOrNull(1)?.trim().orEmpty()
                    .ifBlank { mission.title.substringAfter(":", mission.title).trim() }
                val receivedMaterial = normalize(listOfNotNull(event.itemName, event.itemId).joinToString(" "))
                val expectedTokens = targetTokens(expectedMaterial)
                if (expectedTokens.isNotEmpty() && expectedTokens.none { receivedMaterial.contains(it) }) {
                    return rejected(current, "O material obtido não corresponde ao solicitado.")
                }
                add("materials")
                true
            }
            kind.contains("explora") -> {
                if (event.type != MissionEventType.LOCATION_DISCOVERED) return rejected(current, "A missão exige descobrir locais.")
                if (event.targetId.isNullOrBlank()) return rejected(current, "Local descoberto sem identificação.")
                stage("local:${event.targetId}", "locations")
            }
            kind.contains("investiga") -> {
                if (event.type != MissionEventType.EVIDENCE_FOUND) return rejected(current, "A missão exige encontrar evidências.")
                if (event.targetId.isNullOrBlank()) return rejected(current, "Evidência sem identificação.")
                stage("evidencia:${event.targetId}", "evidence")
            }
            kind.contains("escolta") -> {
                if (event.type != MissionEventType.ESCORT_STEP_COMPLETED) return rejected(current, "A missão exige avançar a escolta.")
                if (event.targetId.isNullOrBlank()) return rejected(current, "Etapa de escolta sem identificação.")
                stage("escolta:${event.targetId}", "escort")
            }
            kind.contains("protec") || kind.contains("defesa") -> {
                if (event.type != MissionEventType.PROTECTED_TARGET_SURVIVED) return rejected(current, "O alvo protegido precisa sobreviver.")
                if (event.targetId.isNullOrBlank()) return rejected(current, "Alvo protegido sem identificação.")
                stage("protecao:${event.targetId}", "protection")
            }
            kind.contains("rastrea") -> {
                if (event.type != MissionEventType.TRACKING_CLUE_FOUND) return rejected(current, "A missão exige pistas de rastreamento.")
                if (event.targetId.isNullOrBlank()) return rejected(current, "Pista sem identificação.")
                stage("pista:${event.targetId}", "tracking")
            }
            kind.contains("purifica") -> {
                if (event.type != MissionEventType.CORRUPTION_SOURCE_CLEARED) return rejected(current, "A missão exige purificar focos de corrupção.")
                if (event.targetId.isNullOrBlank()) return rejected(current, "Foco de corrupção sem identificação.")
                stage("foco:${event.targetId}", "purification")
            }
            kind.contains("chefe") -> {
                if (event.type != MissionEventType.REGIONAL_BOSS_DEFEATED || !event.isBoss) return rejected(current, "A missão exige derrotar o chefe indicado.")
                val requiredRank = mission.rank.uppercase()
                val actualRank = event.creatureRank?.uppercase() ?: return rejected(current, "Rank do chefe não informado.")
                val rankLimit = rankOrder.indexOf(requiredRank)
                val actual = rankOrder.indexOf(actualRank)
                if (rankLimit < 0 || actual < 0 || actual > rankLimit) return rejected(current, "Chefe incompatível com o rank da missão.")
                stage("boss:${event.creatureId ?: event.targetId ?: "regional"}")
            }
            else -> return rejected(current, "Tipo de missão ainda não possui regra configurada.")
        }
        if (!accepted) return rejected(current, "Esta etapa já foi registrada.")

        // Contratos combinados precisam cumprir cada parte descrita no tipo/objetivo.
        val primaryComplete = when {
            kind.contains("raid") || kind.contains("masmorra") ->
                raidStages.all { it in nextStages }
            kind.contains("cacada") || kind.contains("caca") ->
                (nextCounters["kills"] ?: 0) >= required &&
                    (!objective.contains("provas") || (nextCounters["evidence"] ?: 0) >= 1)
            kind.contains("coleta") -> (nextCounters["materials"] ?: 0) >= required
            kind.contains("explora") -> (nextCounters["locations"] ?: 0) >= required
            kind.contains("investiga") -> (nextCounters["evidence"] ?: 0) >= required
            kind.contains("escolta") -> (nextCounters["escort"] ?: 0) >= required
            kind.contains("protec") || kind.contains("defesa") -> (nextCounters["protection"] ?: 0) >= required
            kind.contains("rastrea") -> (nextCounters["tracking"] ?: 0) >= required
            kind.contains("purifica") -> (nextCounters["purification"] ?: 0) >= required
            kind.contains("chefe") -> nextStages.any { it.startsWith("boss:") }
            else -> false
        }
        val bossComplete = nextStages.any { it.startsWith("boss:") || it == "guardiao" }
        val extrasComplete =
            (!requiresEvidence || (nextCounters["evidence"] ?: 0) + (nextCounters["extraEvidence"] ?: 0) >= 1) &&
            (!requiresCreature || ((nextCounters["extraCreature"] ?: 0) + (if (kind.contains("cacada") || kind.contains("caca")) (nextCounters["kills"] ?: 0) else 0)) >= 1) &&
            (!requiresBoss || bossComplete) &&
            (!requiresArtifact || (nextCounters["artifact"] ?: 0) >= 1) &&
            (!requiresSample || (nextCounters["sample"] ?: 0) >= 1)
        val nowComplete = primaryComplete && extrasComplete
        val processedIds = if (eventId == null) current.processedEventIds
            else (current.processedEventIds + eventId).toList().takeLast(1000).toSet()
        val completed = MissionProgress(
            counters = nextCounters,
            completed = nowComplete,
            completedStages = nextStages,
            processedEventIds = processedIds
        )
        return MissionProgressResult(completed, true, nowComplete && !current.completed)
    }

    private fun targetTokens(title: String): List<String> {
        val ignored = setOf(
            "cacada", "caca", "ameaca", "regional", "contrato", "missao",
            "derrote", "elimine", "afaste", "enfrente", "enfrentar",
            "recolher", "recolha", "obter", "obtenha", "entregar", "recuperar", "recupere", "encontrar", "encontre",
            "criatura", "criaturas", "monstro", "monstros", "fera", "feras",
            "selvagem", "selvagens", "agressivo", "agressivos", "errante", "errantes",
            "da", "das", "de", "do", "dos", "na", "nas", "no", "nos", "e"
        )
        return normalize(title.substringAfter(":", title))
            .split(" ")
            .map { token ->
                when {
                    token.endsWith("oes") && token.length > 5 -> token.dropLast(3) + "ao"
                    token.endsWith("ais") && token.length > 4 -> token.dropLast(3) + "al"
                    token.endsWith("is") && token.length > 4 -> token.dropLast(2) + "il"
                    token.endsWith("s") && token.length > 4 -> token.dropLast(1)
                    else -> token
                }
            }
            .filter { it.length >= 4 && it !in ignored }
            .distinct()
    }

    private fun normalize(value: String): String = java.text.Normalizer.normalize(
        value.lowercase().replace('ç', 'c'), java.text.Normalizer.Form.NFD
    ).replace(Regex("\\p{Mn}+"), "").replace(Regex("[^a-z0-9 ]"), " ").replace(Regex("\\s+"), " ").trim()

    private fun rejected(progress: MissionProgress, reason: String) =
        MissionProgressResult(progress, false, false, reason)
}
