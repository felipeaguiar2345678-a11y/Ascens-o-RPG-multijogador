package br.com.ascensaodosoberano.exploration

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import java.util.UUID

/**
 * Centro inicial da experiência: todos os personagens começam na sede da
 * Guilda de Aventureiros de Aurelia. A aventura continua textual; regiões são
 * contexto narrativo e não exigem mapa, coordenadas ou deslocamento visual.
 */
data class GuildMission(
    val id: String,
    val title: String,
    val rank: String,
    val type: String,
    val regionId: String,
    val regionName: String,
    val destinationId: String,
    val destinationName: String,
    val summary: String,
    val objective: String,
    val rewardGold: Int,
    val rewardXp: Int,
    val recommendedLevel: Int,
    val special: Boolean = false,
    val rarity: String = "Comum",
    val rarityMultiplier: Double = 1.0,
    val difficultyMultiplier: Double = 1.0
)

enum class MissionRarity(
    val label: String,
    val weight: Int,
    val rewardMultiplier: Double,
    val difficultyMultiplier: Double
) {
    COMMON("Comum", 6000, 1.0, 1.0),
    UNCOMMON("Incomum", 2500, 1.5, 1.2),
    RARE("Rara", 1000, 2.0, 1.5),
    EPIC("Épica", 350, 3.0, 2.0),
    LEGENDARY("Lendária", 120, 5.0, 3.0),
    MYTHIC("Mítica", 25, 8.0, 4.5),
    DIVINE("Divina", 4, 12.0, 7.0),
    WORLD("World", 1, 20.0, 10.0)
}

object GuildMissionCatalog {
    // Pesos somam 10.000: raridade World tem chance-base de 0,01%.
    // O resultado é estável por contrato; atualizar a tela não faz novo sorteio.
    private fun rarityFor(): MissionRarity {
        val total = MissionRarity.entries.sumOf { it.weight }
        var roll = kotlin.random.Random.nextInt(total)
        for (rarity in MissionRarity.entries) {
            if (roll < rarity.weight) return rarity
            roll -= rarity.weight
        }
        return MissionRarity.COMMON
    }

    fun fromPersisted(data: Map<String, Any?>): GuildMission? {
        val id = data["contractId"] as? String ?: return null
        val fallback = find(id)
        val rank = data["rank"] as? String ?: fallback?.rank ?: return null
        val rarity = data["rarity"] as? String ?: fallback?.rarity ?: "Comum"
        return GuildMission(
            id = id,
            title = data["title"] as? String ?: fallback?.title ?: "Contrato da Guilda",
            rank = rank,
            type = data["kind"] as? String ?: fallback?.type ?: "Aventura",
            regionId = data["ecosystemId"] as? String ?: fallback?.regionId ?: "central_wilds",
            regionName = data["region"] as? String ?: fallback?.regionName ?: "Região desconhecida",
            destinationId = data["destinationId"] as? String ?: fallback?.destinationId ?: "destino_desconhecido",
            destinationName = data["location"] as? String ?: fallback?.destinationName ?: "Local desconhecido",
            summary = data["summary"] as? String ?: fallback?.summary ?: "Contrato aceito na Guilda.",
            objective = data["objective"] as? String ?: fallback?.objective ?: "Concluir o objetivo registrado.",
            rewardGold = (data["rewardGold"] as? Number)?.toInt() ?: fallback?.rewardGold ?: 0,
            rewardXp = (data["rewardXp"] as? Number)?.toInt() ?: fallback?.rewardXp ?: 0,
            recommendedLevel = (data["recommendedLevel"] as? Number)?.toInt() ?: fallback?.recommendedLevel ?: 1,
            special = data["special"] as? Boolean ?: fallback?.special ?: false,
            rarity = rarity,
            rarityMultiplier = (data["rarityMultiplier"] as? Number)?.toDouble() ?: fallback?.rarityMultiplier ?: 1.0,
            difficultyMultiplier = (data["difficultyMultiplier"] as? Number)?.toDouble() ?: fallback?.difficultyMultiplier ?: 1.0
        )
    }

    const val GUILD_SPAWN_ID = "guilda_aurelia"
    const val GUILD_SPAWN_NAME = "Guilda dos Aventureiros de Aurelia"

    private val regions = listOf(
        RegionMissions("central_wilds", "Região Central", listOf("aurelia", "cidade_do_sol", "arkanis", "mina_dourada", "vila_esperanca"),
            listOf("Investigar cartas desaparecidas", "Escoltar uma caravana", "Rastrear ladrões na estrada", "Proteger os arredores de Aurelia")),
        RegionMissions("dark_forest", "Floresta Arcana", listOf("clareira_inicial", "eldarion", "vila_verdejante", "ruinas_elficas"),
            listOf("Recolher ervas luminosas", "Investigar rastros entre as raízes", "Encontrar uma patrulha desaparecida", "Purificar um foco de corrupção")),
        RegionMissions("frost_mountains", "Montanhas Gélidas", listOf("fortaleza_glacial", "caverna_gelo", "pico_aurora"),
            listOf("Recolher cristais de gelo", "Localizar exploradores perdidos", "Investigar uma caverna congelada", "Caçar a fera da nevasca")),
        RegionMissions("imperial_frontier", "Terras do Império", listOf("valdracon", "forte_guarda", "catacumbas_reais", "vila_helios"),
            listOf("Entregar um selo imperial", "Escoltar suprimentos", "Investigar as catacumbas", "Impedir uma conspiração na fronteira")),
        RegionMissions("shadowlands", "Terras das Sombras", listOf("malachar", "templo_sombrio", "covil_mortos", "vila_necropole"),
            listOf("Encontrar um mensageiro", "Investigar vozes no templo", "Destruir um altar corrompido", "Rastrear uma presença ancestral")),
        RegionMissions("ancestral_desert", "Deserto Ancestral", listOf("tharion", "oasis_perdido", "ruinas_antigas", "caverna_escorpiao"),
            listOf("Encontrar água para uma caravana", "Mapear ruínas soterradas", "Recuperar uma relíquia", "Enfrentar o guardião das dunas")),
        RegionMissions("eternal_sea", "Mar Eterno", listOf("kyrath", "ilha_serpente", "torre_oceano"),
            listOf("Localizar um barco à deriva", "Escoltar um navio mercante", "Investigar uma torre submersa", "Rastrear a criatura das profundezas")),
        RegionMissions("forgotten_ruins", "Ruínas Esquecidas", listOf("ruinas_elficas", "ruinas_antigas", "catacumbas_reais"),
            listOf("Decifrar inscrições antigas", "Recuperar um artefato perdido", "Investigar uma câmara selada", "Impedir o despertar de uma entidade"))
    )

    private fun objectiveFor(task: String, rarity: MissionRarity): String {
        val quantity = when (rarity) {
            MissionRarity.COMMON -> 3
            MissionRarity.UNCOMMON -> 5
            MissionRarity.RARE -> 8
            MissionRarity.EPIC -> 12
            MissionRarity.LEGENDARY -> 20
            MissionRarity.MYTHIC -> 30
            MissionRarity.DIVINE -> 50
            MissionRarity.WORLD -> 100
        }
        val condition = when (rarity) {
            MissionRarity.COMMON -> "Retorne à Guilda com uma prova simples da conclusão."
            MissionRarity.UNCOMMON -> "Retorne com uma prova verificável e não abandone o objetivo."
            MissionRarity.RARE -> "Conclua em uma área remota e traga uma evidência adicional."
            MissionRarity.EPIC -> "Conclua em uma área perigosa e supere uma criatura de rank compatível."
            MissionRarity.LEGENDARY -> "Conclua sem perder o objetivo e derrote o guardião que o protege."
            MissionRarity.MYTHIC -> "Conclua e derrote um chefe regional antes de retornar."
            MissionRarity.DIVINE -> "Conclua, derrote um chefe de alto rank e recupere um artefato raro."
            MissionRarity.WORLD -> "Conclua em uma zona extrema, derrote um chefe World e recupere uma relíquia única."
        }
        val normalized = task.trim().trimEnd('.')
        val isGathering = normalized.startsWith("Recolher ", ignoreCase = true) ||
            normalized.startsWith("Encontrar água", ignoreCase = true)
        if (isGathering) {
            val resource = when {
                normalized.startsWith("Recolher ", ignoreCase = true) ->
                    normalized.substringAfter("Recolher ", normalized).trim()
                else -> "água potável para a caravana"
            }
            val uniqueSample = if (rarity == MissionRarity.WORLD) " e uma amostra única" else ""
            return "Obtenha $quantity unidades de $resource$uniqueSample. $condition"
        }
        return "$normalized. $condition"
    }

    private data class RegionMissions(
        val id: String, val name: String, val destinations: List<String>, val tasks: List<String>
    )

    private val rankDefinitions = listOf(
        Triple("E", 1, 35), Triple("D", 3, 60), Triple("C", 7, 100),
        Triple("B", 14, 160), Triple("A", 25, 240), Triple("S", 40, 360),
        Triple("SS", 60, 520), Triple("SSS", 80, 800)
    )

    private val missions: List<GuildMission> = buildList {
        regions.forEachIndexed { regionIndex, region ->
            rankDefinitions.forEachIndexed { rankIndex, (rank, level, baseReward) ->
                val task = region.tasks[rankIndex % region.tasks.size]
                val destination = region.destinations[(rankIndex + regionIndex) % region.destinations.size]
                val location = NarrativeLocationCatalog.find(destination)
                val destinationName = location?.name ?: destination.replace('_', ' ').replaceFirstChar { it.uppercase() }
                val type = when {
                    rankIndex % 4 == 0 -> "Coleta e investigação"
                    rankIndex % 4 == 1 -> "Escolta e proteção"
                    rankIndex % 4 == 2 -> "Exploração"
                    else -> "Caçada e ameaça regional"
                }
                // Cada oferta recebe identidade própria. Ao reiniciar, a Guilda
                // publica novos contratos; os aceitos permanecem no Firestore.
                val missionId = "guild_${region.id}_${rank.lowercase()}_${UUID.randomUUID()}"
                val rarity = rarityFor()
                val rankRegionGold = baseReward.toDouble() * (regionIndex + 1)
                val rewardGold = (rankRegionGold * rarity.rewardMultiplier).toLong().coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
                val rewardXp = (baseReward.toDouble() * 2.0 * rarity.rewardMultiplier).toLong().coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
                add(GuildMission(
                    id = missionId,
                    title = when (rank) {
                        "SSS" -> "Calamidade: $task"
                        "SS" -> "Contrato lendário: $task"
                        "S" -> "Contrato de elite: $task"
                        else -> task
                    },
                    rank = rank,
                    type = type,
                    regionId = region.id,
                    regionName = region.name,
                    destinationId = destination,
                    destinationName = destinationName,
                    summary = "A guilda recebeu um relato de atividade incomum em $destinationName.",
                    objective = objectiveFor(task, rarity),
                    rewardGold = rewardGold,
                    rewardXp = rewardXp,
                    recommendedLevel = level,
                    special = rank == "SS" || rank == "SSS",
                    rarity = rarity.label,
                    rarityMultiplier = rarity.rewardMultiplier,
                    difficultyMultiplier = rarity.difficultyMultiplier
                ))
            }
        }
    }

    fun all(): List<GuildMission> = missions
    fun regions(): List<String> = missions.map { it.regionName }.distinct()
    fun byRegion(regionName: String): List<GuildMission> =
        missions.filter { it.regionName == regionName }
    fun availableForLevel(level: Int): List<GuildMission> =
        missions.filter { it.recommendedLevel <= level }
    fun find(id: String): GuildMission? = missions.firstOrNull { it.id == id }
}

@Composable
fun QuadroMissoesGuilda(
    nivelJogador: Int,
    rankJogador: String = "E",
    chefesPromocaoDerrotados: List<String> = emptyList(),
    aoAceitarMissao: (GuildMission) -> Unit,
    modifier: Modifier = Modifier
) {
    var regiaoSelecionada by remember { mutableStateOf("Todas") }
    var mostrarBloqueadas by remember { mutableStateOf(false) }
    val regioes = listOf("Todas") + GuildMissionCatalog.regions()
    val missoes = GuildMissionCatalog.all().filter {
        (regiaoSelecionada == "Todas" || it.regionName == regiaoSelecionada) &&
            (mostrarBloqueadas || it.recommendedLevel <= nivelJogador) &&
            (mostrarBloqueadas || GuildRankProgression.canAcceptMission(rankJogador, it.rank))
    }

    Card(modifier = modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("GUILDA DOS AVENTUREIROS", style = MaterialTheme.typography.titleLarge)
            Text("Sede: Aurelia · Quadro de contratos regionais", style = MaterialTheme.typography.bodyMedium)
            Text("Seu rank: ${GuildRankProgression.normalize(rankJogador)}", style = MaterialTheme.typography.titleMedium)
            val exam = GuildPromotionCatalog.examFor(rankJogador)
            if (exam != null) {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer)) {
                    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Text("EXAME DE PROMOÇÃO · ${exam.currentRank} → ${exam.targetRank}", style = MaterialTheme.typography.titleMedium)
                        Text("Chefe: ${exam.bossName} · Rank ${exam.bossRank}")
                        Text("Região: ${exam.regionName}", style = MaterialTheme.typography.bodySmall)
                        Text("Derrote o chefe de promoção e contribua com pelo menos 10% do dano para validar sua conquista.", style = MaterialTheme.typography.bodySmall)
                        Text(if (exam.bossId in chefesPromocaoDerrotados) "Chefe já registrado." else "Exame ainda não concluído.", style = MaterialTheme.typography.labelMedium)
                    }
                }
            } else Text("Você alcançou o rank máximo da guilda: SSS.")
            Text("Escolha uma região. Cada contrato leva a um destino e ecossistema próprios.", style = MaterialTheme.typography.bodySmall)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                OutlinedButton(onClick = { regiaoSelecionada = "Todas" }) { Text("Todas") }
                OutlinedButton(onClick = { mostrarBloqueadas = !mostrarBloqueadas }) {
                    Text(if (mostrarBloqueadas) "Ocultar bloqueadas" else "Ver todos os ranks")
                }
            }
            regioes.drop(1).chunked(2).forEach { grupo ->
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    grupo.forEach { nome ->
                        OutlinedButton(
                            onClick = { regiaoSelecionada = if (regiaoSelecionada == nome) "Todas" else nome },
                            modifier = Modifier.weight(1f)
                        ) { Text(nome, style = MaterialTheme.typography.labelSmall) }
                    }
                    if (grupo.size == 1) androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))
                }
            }
            if (missoes.isEmpty()) Text("Nenhuma missão disponível com esse filtro.")
            missoes.forEach { mission ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("RANK ${mission.rank}", style = MaterialTheme.typography.labelLarge)
                            Text("RARIDADE ${mission.rarity.uppercase()}", color = MaterialTheme.colorScheme.tertiary, style = MaterialTheme.typography.labelLarge)
                            Text(mission.type, style = MaterialTheme.typography.labelMedium)
                        }
                        Text(mission.title, style = MaterialTheme.typography.titleMedium)
                        Text("${mission.regionName} · ${mission.destinationName}", style = MaterialTheme.typography.bodySmall)
                        Text(mission.summary, style = MaterialTheme.typography.bodyMedium)
                        Text("Objetivo: ${mission.objective}", style = MaterialTheme.typography.bodySmall)
                        Text("Recompensa: ${mission.rewardGold} ouro · ${mission.rewardXp} XP", style = MaterialTheme.typography.labelMedium)
                        Text("Raridade ${mission.rarity} · dificuldade ×${"%.1f".format(mission.difficultyMultiplier)}", style = MaterialTheme.typography.labelSmall)
                        if (mission.recommendedLevel > nivelJogador) {
                            Text("Recomendado nível ${mission.recommendedLevel} · bloqueada para seu nível", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.labelSmall)
                        } else {
                            Button(onClick = { aoAceitarMissao(mission) }, modifier = Modifier.fillMaxWidth()) {
                                Text("ACEITAR MISSÃO")
                            }
                        }
                    }
                }
            }
        }
    }
}
