package br.com.ascensaodosoberano.exploration

/**
 * Regras determinísticas de progresso das missões.
 * Não chama IA e não concede recompensas: apenas valida eventos reais do jogo
 * e produz o novo estado de progresso para persistência transacional.
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
    val completed: Boolean = false
)

data class MissionProgressResult(
    val progress: MissionProgress,
    val accepted: Boolean,
    val newlyCompleted: Boolean,
    val reason: String? = null
)

object MissionProgressEngine {
    private val quantityRegex = Regex("(?i)(?:derrote|elimine|recolha|obtenha|encontre|recupere)\\s+(\\d+)")
    private val rankOrder = listOf("E", "D", "C", "B", "A", "S", "SS", "SSS", "WORLD")

    fun apply(mission: GuildMission, current: MissionProgress, event: MissionEvent): MissionProgressResult {
        if (current.completed) return rejected(current, "Missão já concluída.")
        if (event.amount <= 0) return rejected(current, "Evento sem quantidade válida.")
        if (event.regionId != null && event.regionId != mission.regionId) {
            return rejected(current, "Evento ocorreu em outra região.")
        }
        if (event.locationId != null && event.locationId != mission.destinationId) {
            return rejected(current, "Evento ocorreu em outro local.")
        }

        val kind = mission.type.lowercase()
        val key = when {
            mission.special && event.type == MissionEventType.REGIONAL_BOSS_DEFEATED && event.isBoss -> "bosses"
            kind.contains("caçada") || kind.contains("caça") -> {
                if (event.type != MissionEventType.CREATURE_DEFEATED) return rejected(current, "A missão exige derrotar criaturas.")
                val requiredRank = mission.rank.uppercase()
                val actualRank = event.creatureRank?.uppercase() ?: return rejected(current, "Rank da criatura não informado.")
                if (rankOrder.indexOf(actualRank).let { it < 0 || it > rankOrder.indexOf(requiredRank) }) {
                    return rejected(current, "Criatura incompatível com o rank da missão.")
                }
                val titleTarget = mission.title.substringAfter(":", "").trim().lowercase()
                val target = when {
                    titleTarget.contains("rato") -> listOf("rato")
                    titleTarget.contains("javali") -> listOf("javali")
                    titleTarget.contains("goblin") -> listOf("goblin")
                    titleTarget.contains("esqueleto") -> listOf("esqueleto")
                    else -> emptyList()
                }
                if (target.isNotEmpty() && event.creatureName.orEmpty().lowercase().let { name -> target.none { token -> name.contains(token) } }) {
                    return rejected(current, "Criatura não corresponde ao alvo do contrato.")
                }
                "kills"
            }
            kind.contains("coleta") -> {
                if (event.type != MissionEventType.MATERIAL_OBTAINED) return rejected(current, "A missão exige obter materiais.")
                "materials"
            }
            kind.contains("explora") -> {
                if (event.type != MissionEventType.LOCATION_DISCOVERED) return rejected(current, "A missão exige descobrir locais.")
                "locations"
            }
            kind.contains("investiga") -> {
                if (event.type != MissionEventType.EVIDENCE_FOUND) return rejected(current, "A missão exige encontrar evidências.")
                "evidence"
            }
            kind.contains("escolta") -> {
                if (event.type != MissionEventType.ESCORT_STEP_COMPLETED) return rejected(current, "A missão exige avançar a escolta.")
                "escortSteps"
            }
            kind.contains("prote") -> {
                if (event.type != MissionEventType.PROTECTED_TARGET_SURVIVED) return rejected(current, "O alvo protegido precisa sobreviver.")
                "protection"
            }
            kind.contains("rastrea") -> {
                if (event.type != MissionEventType.TRACKING_CLUE_FOUND) return rejected(current, "A missão exige pistas de rastreamento.")
                "trackingClues"
            }
            kind.contains("purifica") -> {
                if (event.type != MissionEventType.CORRUPTION_SOURCE_CLEARED) return rejected(current, "A missão exige purificar focos de corrupção.")
                "purification"
            }
            kind.contains("raid") || kind.contains("masmorra") -> {
                if (event.type != MissionEventType.RAID_STEP_COMPLETED) return rejected(current, "A missão exige concluir etapas da incursão.")
                "raidSteps"
            }
            kind.contains("chefe") || mission.special -> {
                if (event.type != MissionEventType.REGIONAL_BOSS_DEFEATED || !event.isBoss) return rejected(current, "A missão exige derrotar o chefe indicado.")
                "bosses"
            }
            else -> return rejected(current, "Tipo de missão ainda não possui regra configurada.")
        }

        val nextValue = (current.counters[key] ?: 0).plus(event.amount).coerceAtMost(100_000)
        val nextCounters = current.counters + (key to nextValue)
        val required = quantityRegex.find(mission.objective)?.groupValues?.getOrNull(1)?.toIntOrNull() ?: 1
        val nowComplete = if (kind.contains("raid") || kind.contains("masmorra")) {
            (nextCounters["raidSteps"] ?: 0) >= 3 && (nextCounters["bosses"] ?: 0) >= 1
        } else if (mission.special) {
            (nextCounters["bosses"] ?: 0) >= 1
        } else nextValue >= required
        val next = MissionProgress(nextCounters, nowComplete)
        return MissionProgressResult(next, true, nowComplete && !current.completed)
    }

    private fun rejected(progress: MissionProgress, reason: String) =
        MissionProgressResult(progress, false, false, reason)
}
