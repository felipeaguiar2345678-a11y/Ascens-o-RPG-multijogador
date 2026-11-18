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
    val targetId: String? = null,
    val isBoss: Boolean = false
)

data class MissionProgress(
    val counters: Map<String, Int> = emptyMap(),
    val completed: Boolean = false,
    val completedStages: Set<String> = emptySet()
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
        if (event.amount !in 1..1000) return rejected(current, "Quantidade do evento inválida.")
        if (event.regionId != mission.regionId) return rejected(current, "Evento sem confirmação da região correta.")
        if (event.locationId != mission.destinationId) return rejected(current, "Evento sem confirmação do destino correto.")

        val kind = normalize(mission.type)
        val objective = normalize(mission.objective)
        val nextCounters = current.counters.toMutableMap()
        val nextStages = current.completedStages.toMutableSet()
        val required = quantityRegex.find(mission.objective)?.groupValues?.getOrNull(1)?.toIntOrNull() ?: 1

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
            kind.contains("raid") || kind.contains("masmorra") -> {
                when {
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
                        stage("guardiao")
                    }
                    else -> return rejected(current, "A raid exige confirmação de cada etapa e do guardião.")
                }
            }
            (kind.contains("cacada") || kind.contains("caca")) && event.type == MissionEventType.EVIDENCE_FOUND -> {
                if (event.targetId.isNullOrBlank() || !objective.contains("provas")) return rejected(current, "Prova não faz parte deste contrato ou está sem identificação.")
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
                add("kills")
                true
            }
            kind.contains("coleta") -> {
                if (event.type != MissionEventType.MATERIAL_OBTAINED) return rejected(current, "A missão exige obter materiais.")
                if (event.itemId.isNullOrBlank()) return rejected(current, "Material sem identificação.")
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
            kind.contains("chefe") || mission.special -> {
                if (event.type != MissionEventType.REGIONAL_BOSS_DEFEATED || !event.isBoss) return rejected(current, "A missão exige derrotar o chefe indicado.")
                stage("boss:${event.creatureId ?: event.targetId ?: "regional"}")
            }
            else -> return rejected(current, "Tipo de missão ainda não possui regra configurada.")
        }
        if (!accepted) return rejected(current, "Esta etapa já foi registrada.")

        // Contratos combinados precisam cumprir cada parte descrita no tipo/objetivo.
        val nowComplete = when {
            kind.contains("raid") || kind.contains("masmorra") ->
                raidStages.all { it in nextStages }
            mission.special -> nextStages.any { it.startsWith("boss:") || it == "guardiao" }
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
            else -> false
        }
        // Tipos compostos não podem concluir ao cumprir somente a primeira parte.
        val compositeRequirements = listOf(
            "coleta" to ("materials" to MissionEventType.MATERIAL_OBTAINED),
            "investiga" to ("evidence" to MissionEventType.EVIDENCE_FOUND),
            "escolta" to ("escort" to MissionEventType.ESCORT_STEP_COMPLETED),
            "protec" to ("protection" to MissionEventType.PROTECTED_TARGET_SURVIVED)
        )
        val completed = if (nowComplete) MissionProgress(nextCounters, true, nextStages) else MissionProgress(nextCounters, false, nextStages)
        return MissionProgressResult(completed, true, nowComplete && !current.completed)
    }

    private fun targetTokens(title: String): List<String> {
        val target = normalize(title.substringAfter(":", title))
        return listOf("rato", "javali", "goblin", "esqueleto", "lobo", "urso", "aranha", "serpente", "bandido")
            .filter { target.contains(it) }
    }

    private fun normalize(value: String): String = java.text.Normalizer.normalize(
        value.lowercase().replace('ç', 'c'), java.text.Normalizer.Form.NFD
    ).replace(Regex("\\p{Mn}+"), "").replace(Regex("[^a-z0-9 ]"), " ").replace(Regex("\\s+"), " ").trim()

    private fun rejected(progress: MissionProgress, reason: String) =
        MissionProgressResult(progress, false, false, reason)
}
