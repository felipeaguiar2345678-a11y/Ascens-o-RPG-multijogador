package br.com.ascensaodosoberano.exploration

data class MissionAction(
    val label: String,
    val eventType: String,
    val targetId: String,
    val amount: Int = 1
)

/**
 * Ações determinísticas da aventura. Não chamam IA e não concluem a missão
 * sozinhas: cada ação registra uma etapa específica no servidor.
 */
object MissionActionSystem {
    private fun normalize(value: String): String = java.text.Normalizer.normalize(
        value.lowercase(), java.text.Normalizer.Form.NFD
    ).replace(Regex("\\p{Mn}+"), "").replace(Regex("[^a-z0-9 ]"), " ")
        .replace(Regex("\\s+"), " ").trim()

    private fun required(objective: String): Int {
        val normalized = normalize(objective)
        val match = Regex("(?:derrote|elimine|afaste|recolha|obtenha|encontre|recupere|descubra|purifique)\\s+(\\d+)")
            .find(normalized)
        return (match?.groupValues?.getOrNull(1)?.toIntOrNull() ?: 1).coerceIn(1, 100)
    }

    fun actionsFor(
        mission: GuildMission,
        currentLocationId: String,
        counters: Map<String, Int> = mission.progressCounters,
        stages: Set<String> = mission.completedStages
    ): List<MissionAction> {
        if (currentLocationId != mission.destinationId) return emptyList()
        val kind = normalize(mission.type)
        val objective = normalize(mission.objective)
        val actions = mutableListOf<MissionAction>()
        val amount = required(mission.objective)

        when {
            kind.contains("coleta") -> {
                val collected = counters["materials"] ?: 0
                if (collected < amount) {
                    val objectiveStart = mission.objective.substringBefore(".").trim()
                    val resource = Regex("(?:unidades? de|quantidade de)\\s+([^.;]+)", RegexOption.IGNORE_CASE)
                        .find(mission.objective)?.groupValues?.getOrNull(1)?.trim()
                        ?: objectiveStart.replace(Regex("^(obtenha\\s+\\d+\\s+unidades?\\s+de|recuperar|entregar|encontrar)\\s+", RegexOption.IGNORE_CASE), "")
                            .removePrefix("um ").removePrefix("uma ").trim()
                            .ifBlank { mission.title.substringAfter(":", mission.title).trim() }
                    val resourceFinal = resource.replace(Regex("\\s+e uma amostra única.*$", RegexOption.IGNORE_CASE), "")
                    actions += MissionAction("Coletar $resourceFinal", "MATERIAL_OBTAINED", "resource_${collected + 1}")
                }
            }
            kind.contains("explora") -> {
                val count = counters["locations"] ?: 0
                if (count < amount) actions += MissionAction("Explorar e mapear o destino", "LOCATION_DISCOVERED", "location_${count + 1}")
            }
            kind.contains("investiga") -> {
                val count = counters["evidence"] ?: 0
                if (count < amount) actions += MissionAction("Examinar vestígios e registrar evidência", "EVIDENCE_FOUND", "evidence_${count + 1}")
            }
            kind.contains("escolta") -> {
                val count = counters["escort"] ?: 0
                if (count < amount) actions += MissionAction("Conduzir a escolta pelo próximo trecho", "ESCORT_STEP_COMPLETED", "escort_${count + 1}")
            }
            kind.contains("protec") || kind.contains("defesa") -> {
                val count = counters["protection"] ?: 0
                if (count < amount) actions += MissionAction("Defender o alvo durante a próxima etapa", "PROTECTED_TARGET_SURVIVED", "protection_${count + 1}")
            }
            kind.contains("rastrea") -> {
                val count = counters["tracking"] ?: 0
                if (count < amount) actions += MissionAction("Seguir e confirmar os rastros", "TRACKING_CLUE_FOUND", "clue_${count + 1}")
            }
            kind.contains("purifica") -> {
                val count = counters["purification"] ?: 0
                if (count < amount) actions += MissionAction("Purificar o foco de corrupção", "CORRUPTION_SOURCE_CLEARED", "focus_${count + 1}")
            }
            kind.contains("raid") || kind.contains("masmorra") -> {
                if ("entrada" !in stages) actions += MissionAction("Investigar a entrada da masmorra", "RAID_STEP_COMPLETED", "entrada")
                if ("grupos" in stages && "nucleo" !in stages) actions += MissionAction("Desativar o núcleo da masmorra", "RAID_STEP_COMPLETED", "nucleo")
            }
        }

        val needsEvidence = objective.contains("prova") || objective.contains("evidencia")
        val hasEvidence = (counters["evidence"] ?: 0) + (counters["extraEvidence"] ?: 0) > 0
        if (needsEvidence && !hasEvidence && !kind.contains("investiga")) {
            actions += MissionAction("Registrar uma prova verificável", "EVIDENCE_FOUND", "proof_1")
        }

        val needsArtifact = objective.contains("artefato raro") || objective.contains("reliquia unica") ||
            objective.contains("suprimentos roubados") || objective.contains("selo imperial")
        if (needsArtifact && (counters["artifact"] ?: 0) == 0) {
            val label = when {
                objective.contains("suprimentos roubados") -> "Recuperar os suprimentos roubados"
                objective.contains("selo imperial") -> "Recuperar o selo imperial"
                objective.contains("reliquia unica") -> "Recuperar a relíquia única"
                else -> "Recuperar o artefato exigido"
            }
            actions += MissionAction(label, "MATERIAL_OBTAINED", "artifact")
        }
        if (objective.contains("amostra unica") && (counters["sample"] ?: 0) == 0) {
            actions += MissionAction("Coletar a amostra única", "MATERIAL_OBTAINED", "sample")
        }
        return actions
    }
    fun resolve(
        mission: GuildMission,
        currentLocationId: String,
        label: String
    ): MissionAction? = actionsFor(mission, currentLocationId).firstOrNull { it.label == label }

}
