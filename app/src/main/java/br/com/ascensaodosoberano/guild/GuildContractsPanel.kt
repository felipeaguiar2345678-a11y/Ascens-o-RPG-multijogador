package br.com.ascensaodosoberano.guild

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

enum class GuildRank(val label: String, val order: Int) {
    E("E", 0), D("D", 1), C("C", 2), B("B", 3),
    A("A", 4), S("S", 5), SS("SS", 6), SSS("SSS", 7);

    fun canAccept(missionRank: GuildRank) = missionRank.order <= order
    fun next(): GuildRank? = entries.getOrNull(order + 1)
    companion object {
        fun parse(value: String?) = entries.firstOrNull { it.label == value?.uppercase() } ?: E
    }
}

enum class GuildRegion(val label: String, val ecosystemId: String, val biome: String) {
    AURELIA("Aurelia", "aurelia_outskirts", "Arredores e estradas da capital"),
    FLORESTA_ARCANA("Floresta Arcana", "arcane_forest", "Mata antiga, clareiras e ruínas vivas"),
    MONTANHAS_GELIDAS("Montanhas Gélidas", "frozen_mountains", "Picos nevados e passagens congeladas"),
    IMPERIO("Império", "imperial_heartland", "Cidades imperiais e distritos antigos"),
    CENTRAL("Terras Centrais", "central_lands", "Planícies e cruzamentos do continente"),
    SOMBRAS("Terras das Sombras", "shadowlands", "Terras crepusculares e fortalezas esquecidas"),
    DESERTO_ANCESTRAL("Deserto Ancestral", "ancestral_desert", "Dunas, oásis e santuários soterrados"),
    MAR_ETERNAL("Mar Eterno", "eternal_sea", "Arquipélagos, fossas e rotas marítimas"),
    MALACHAR("Malachar", "malachar_ruins", "Ruínas e muralhas da cidade de Malachar")
}

enum class ContractKind(val label: String) {
    HUNT("Caçada"), ESCORT("Escolta"), EXPLORATION("Exploração"),
    INVESTIGATION("Investigação"), DEFENSE("Defesa"), CALAMITY("Calamidade")
}

data class GuildContract(
    val id: String,
    val title: String,
    val rank: GuildRank,
    val region: GuildRegion,
    val location: String,
    val kind: ContractKind,
    val objective: String,
    val threat: String,
    val reward: String
)

object GuildContractBoard {
    val contracts = listOf(
        GuildContract("aurelia_missing_caravan", "Rastros da Caravana Perdida", GuildRank.E, GuildRegion.AURELIA, "Estrada Norte de Aurelia", ContractKind.INVESTIGATION, "Investigar os destroços e descobrir o paradeiro dos viajantes", "Ladrões e uma criatura ainda não identificada", "Moedas, experiência e reputação"),
        GuildContract("forest_wolves", "Uivos na Trilha Verde", GuildRank.E, GuildRegion.FLORESTA_ARCANA, "Trilha da Vila Verdejante", ContractKind.HUNT, "Reduzir a ameaça sem destruir o ecossistema", "Matilha de feras da floresta", "Moedas, materiais e reputação"),
        GuildContract("ice_pass", "Suprimentos para o Passo Gelado", GuildRank.D, GuildRegion.MONTANHAS_GELIDAS, "Passagem do Norte", ContractKind.ESCORT, "Escoltar os suprimentos até o posto avançado", "Clima extremo e emboscadas", "Moedas, equipamento e reputação"),
        GuildContract("empire_archive", "O Arquivo Silenciado", GuildRank.C, GuildRegion.IMPERIO, "Distrito Antigo", ContractKind.INVESTIGATION, "Recuperar registros e identificar quem os ocultou", "Agentes desconhecidos", "Moedas, informação e reputação"),
        GuildContract("shadow_watch", "Vigília nas Terras das Sombras", GuildRank.B, GuildRegion.SOMBRAS, "Fortim do Crepúsculo", ContractKind.DEFENSE, "Proteger o fortim durante a noite", "Ondas de criaturas sombrias", "Moedas, materiais raros e reputação"),
        GuildContract("desert_ruins", "O Santuário sob a Areia", GuildRank.A, GuildRegion.DESERTO_ANCESTRAL, "Ruínas do Primeiro Sol", ContractKind.EXPLORATION, "Mapear o santuário e recuperar uma relíquia", "Armadilhas antigas e guardião", "Relíquia, experiência e reputação"),
        GuildContract("sea_storm", "A Tempestade que Respira", GuildRank.S, GuildRegion.MAR_ETERNAL, "Arquipélago das Brumas", ContractKind.CALAMITY, "Conter a anomalia antes que alcance as rotas marítimas", "Entidade abissal", "Recompensa lendária e reconhecimento"),
        GuildContract("malachar_breach", "Fenda sobre Malachar", GuildRank.SS, GuildRegion.MALACHAR, "Muralha Exterior", ContractKind.CALAMITY, "Impedir a expansão da fenda", "Ameaça de classe SS", "Tesouro excepcional e título"),
        GuildContract("central_last_stand", "O Último Sinal", GuildRank.SSS, GuildRegion.CENTRAL, "Marco do Centro do Mundo", ContractKind.CALAMITY, "Responder ao chamado de calamidade mundial", "Ameaça de classe SSS", "Reconhecimento histórico")
    )
}

@Composable
fun GuildContractsPanel(
    playerRankValue: String,
    defeatedPromotionBosses: List<String>,
    onAcceptContract: (GuildContract) -> Unit,
    onRequestPromotionExam: (GuildRank, GuildRank) -> Unit
) {
    val rank = GuildRank.parse(playerRankValue)
    var region by remember { mutableStateOf<GuildRegion?>(null) }
    val visible = remember(region) {
        GuildContractBoard.contracts.filter { region == null || it.region == region }
    }
    val nextRank = rank.next()
    val promotionId = nextRank?.let { "promocao_${rank.label}_${it.label}" }
    val promotionDone = promotionId != null && promotionId in defeatedPromotionBosses

    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
            Text("QUADRO DE CONTRATOS", style = MaterialTheme.typography.titleLarge)
            Text("Rank atual: ${rank.label} · Você pode aceitar contratos até seu rank. Contratos superiores ficam visíveis, mas bloqueados.")
            Text("REGIÕES", style = MaterialTheme.typography.titleSmall)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                FilterChip(selected = region == null, onClick = { region = null }, label = { Text("Todas") })
            }
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                GuildRegion.entries.chunked(2).forEach { regionRow ->
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        regionRow.forEach { item ->
                            FilterChip(
                                selected = region == item,
                                onClick = { region = item },
                                label = { Text(item.label) }
                            )
                        }
                    }
                }
            }
            visible.forEach { contract ->
                val unlocked = rank.canAccept(contract.rank)
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("${contract.title} · Rank ${contract.rank.label}", style = MaterialTheme.typography.titleMedium)
                        Text("${contract.region.label} · ${contract.location}")
                        Text("Ecossistema: ${contract.region.biome}")
                        Text("Tipo: ${contract.kind.label}")
                        Text("Objetivo: ${contract.objective}")
                        Text("Ameaça: ${contract.threat}")
                        Text("Recompensa prevista: ${contract.reward}")
                        if (unlocked) {
                            Button(onClick = { onAcceptContract(contract) }, modifier = Modifier.fillMaxWidth()) {
                                Text("Aceitar contrato")
                            }
                        } else {
                            Text("BLOQUEADO · alcance o rank ${contract.rank.label} na Guilda")
                        }
                    }
                }
            }
            if (nextRank != null) {
                Text("EXAME DE PROMOÇÃO · ${rank.label} → ${nextRank.label}", style = MaterialTheme.typography.titleMedium)
                Text("Para subir, você precisa derrotar o chefe de promoção do rank ${rank.label}. O nível e a experiência não substituem esse exame.")
                Text(if (promotionDone) "Chefe de promoção registrado." else "Exame ainda não concluído.")
                Text("A promoção só deve ser confirmada após uma vitória de combate validada e contribuição individual registrada.")
                Button(
                    onClick = { onRequestPromotionExam(rank, nextRank) },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Solicitar chefe do exame")
                }
            } else {
                Text("Você alcançou o rank máximo da Guilda: SSS.")
            }
        }
    }
}


@Composable
fun GuildActiveContractsPanel(
    contracts: List<Map<String, Any?>>,
    onAbandon: (String) -> Unit
) {
    if (contracts.isEmpty()) return
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("SEUS CONTRATOS ATIVOS", style = MaterialTheme.typography.titleLarge)
            contracts.forEach { contract ->
                val id = contract["contractId"]?.toString().orEmpty()
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(contract["title"]?.toString() ?: "Contrato", style = MaterialTheme.typography.titleMedium)
                        Text("Rank ${contract["rank"] ?: "E"} · ${contract["region"] ?: "Região desconhecida"}")
                        Text(contract["location"]?.toString() ?: "")
                        Text("Ecossistema: ${contract["biome"] ?: "Não informado"}")
                        Text("Estado: Aceito")
                        Text(contract["objective"]?.toString() ?: "")
                        Button(onClick = { if (id.isNotBlank()) onAbandon(id) }) {
                            Text("Abandonar contrato")
                        }
                    }
                }
            }
        }
    }
}
