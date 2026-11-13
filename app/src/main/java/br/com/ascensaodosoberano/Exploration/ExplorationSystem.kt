
package br.com.ascensaodosoberano.exploration

import br.com.ascensaodosoberano.world.CriaturaGerada
import br.com.ascensaodosoberano.world.CreatureApi
import br.com.ascensaodosoberano.world.RepositorioCriaturas
import br.com.ascensaodosoberano.world.WorldContext
import br.com.ascensaodosoberano.world.WorldDirector
import br.com.ascensaodosoberano.world.WorldEvent
import br.com.ascensaodosoberano.world.WorldEventType
import br.com.ascensaodosoberano.world.WorldMapData
import br.com.ascensaodosoberano.world.WorldRegion
import br.com.ascensaodosoberano.world.WorldPointType

enum class RegionRank {
    E, D, C, B, A, S, SS, SSS
}

data class ExplorationRegion(
    val id: String,
    val name: String,
    val rank: RegionRank,
    val encounterChance: Int,
    val bossChance: Double,
    val ecosystemId: String = "unknown",
    val biome: String = "unknown"
)

data class ExplorationEncounter(
    val region: ExplorationRegion,
    val enemyId: String?,
    val isBoss: Boolean,
    val message: String,
    val worldEvent: WorldEvent? = null,
    val criatura: CriaturaGerada? = null
)

object ExplorationSystem {

    // A geração pode acontecer sempre que o encontro precisar de uma criatura.
    // O limite mensal e a reserva por turno continuam protegendo o orçamento.

    /**
     * Conecta os pontos reais do mapa aos ecossistemas.
     * Capitais, cidades e vilas permanecem seguras; masmorras, ruínas,
     * torres e marcos selvagens podem gerar encontros durante a caminhada.
     */
    fun regionForWorldPoint(worldPointId: String): ExplorationRegion? {
        val id = worldPointId.ifBlank { "clareira_inicial" }.lowercase()

        // Compatibilidade com ecossistemas já existentes no catálogo global.
        when (id) {
            "clareira_inicial", "dark_forest", "floresta_sombras" ->
                return regions.first { it.id == "dark_forest" }
            "ruinas_elficas", "forgotten_ruins" ->
                return regions.first { it.id == "forgotten_ruins" }
            "vale_abismo", "abyss_valley" ->
                return regions.first { it.id == "abyss_valley" }
            "nhar_zul", "terras_mortas", "dead_lands" ->
                return regions.first { it.id == "dead_lands" }
        }

        val ponto = WorldMapData.findPoint(id) ?: return null
        if (ponto.type == WorldPointType.CAPITAL ||
            ponto.type == WorldPointType.CITY ||
            ponto.type == WorldPointType.VILLAGE
        ) return null

        return regionForWorldRegion(ponto.region)
    }

    /**
     * Resolve o contexto de uma cena narrativa sem aplicar as antigas regras
     * de segurança do mapa. Uma emboscada ou evento escrito pelo narrador pode
     * acontecer dentro ou nos arredores de uma cidade, se a história justificar.
     */
    fun regionForNarrativeLocation(locationId: String): ExplorationRegion? {
        val id = locationId.ifBlank { "clareira_inicial" }.trim().lowercase()
        val location = NarrativeLocationCatalog.find(id) ?: return null
        return regions.firstOrNull { it.id == location.regionId }
    }

    private fun regionForWorldRegion(region: WorldRegion): ExplorationRegion =
        when (region) {
            WorldRegion.MONTANHAS_GELIDAS -> regions.first { it.id == "frost_mountains" }
            WorldRegion.FLORESTA_ARCANA -> regions.first { it.id == "dark_forest" }
            WorldRegion.IMPERIO -> regions.first { it.id == "imperial_frontier" }
            WorldRegion.CENTRAL -> regions.first { it.id == "central_wilds" }
            WorldRegion.SOMBRAS -> regions.first { it.id == "shadowlands" }
            WorldRegion.DESERTO_ANCESTRAL -> regions.first { it.id == "ancestral_desert" }
            WorldRegion.MAR_ETERNAL -> regions.first { it.id == "eternal_sea" }
        }

    val regions = listOf(
        ExplorationRegion(
            "dark_forest",
            "Floresta das Sombras",
            RegionRank.E,
            65,
            1.0,
            ecosystemId = "dark_forest",
            biome = "floresta sombria"
        ),
        ExplorationRegion(
            "forgotten_ruins",
            "Ruínas Esquecidas",
            RegionRank.C,
            60,
            10.0,
            ecosystemId = "forgotten_ruins",
            biome = "ruínas antigas"
        ),
        ExplorationRegion(
            "abyss_valley",
            "Vale do Abismo",
            RegionRank.S,
            75,
            20.0,
            ecosystemId = "abyss_valley",
            biome = "vale abissal"
        ),
        ExplorationRegion(
            "dead_lands",
            "Terras Mortas de Nhar-Zul",
            RegionRank.SSS,
            90,
            30.0,
            ecosystemId = "dead_lands",
            biome = "terras mortas"
        ),
        ExplorationRegion(
            "frost_mountains", "Montanhas Gélidas", RegionRank.D,
            60, 1.5, ecosystemId = "frost_mountains", biome = "montanhas nevadas"
        ),
        ExplorationRegion(
            "imperial_frontier", "Fronteiras do Império", RegionRank.C,
            48, 6.0, ecosystemId = "imperial_frontier", biome = "campos imperiais"
        ),
        ExplorationRegion(
            "central_wilds", "Terras Selvagens Centrais", RegionRank.D,
            32, 3.0, ecosystemId = "central_wilds", biome = "campos e bosques centrais"
        ),
        ExplorationRegion(
            "shadowlands", "Terras das Sombras", RegionRank.A,
            68, 12.0, ecosystemId = "shadowlands", biome = "terras sombrias"
        ),
        ExplorationRegion(
            "ancestral_desert", "Deserto Ancestral", RegionRank.B,
            58, 8.0, ecosystemId = "ancestral_desert", biome = "deserto ancestral"
        ),
        ExplorationRegion(
            "eternal_sea", "Mar Eterno", RegionRank.B,
            55, 7.0, ecosystemId = "eternal_sea", biome = "ilhas e costa do mar eterno"
        )
    )

    suspend fun explore(
        region: ExplorationRegion,
        forcarEncontro: Boolean = false,
        permitirGeracaoRemota: Boolean = true,
        forcarChefe: Boolean = false,
        creatureHint: String = ""
    ): ExplorationEncounter {

        val event = if (forcarChefe) {
            WorldEvent(
                type = WorldEventType.BOSS,
                title = "Presença de chefe",
                description = "Uma presença dominante se revela neste território.",
                threatLevel = region.encounterChance
            )
        } else if (forcarEncontro) {
            WorldEvent(
                type = WorldEventType.ENCOUNTER,
                title = "Rastros de criatura",
                description = "Você encontrou rastros recentes. Uma criatura pode estar escondida neste território.",
                threatLevel = region.encounterChance
            )
        } else {
            WorldDirector.generateEvent(
                WorldContext(
                    regionName = region.name,
                    regionRank = region.rank.name,
                    dangerLevel = region.encounterChance,
                    bossChance = region.bossChance,
                    ecosystemId = region.ecosystemId,
                    biome = region.biome
                )
            )
        }

        var detalheFalhaCatalogo: String? = null
        val criaturas = runCatching {
            RepositorioCriaturas.buscarPorEcossistema(
                ecosystemId = region.ecosystemId,
                somenteCache = !permitirGeracaoRemota
            )
        }.onFailure { erro ->
            detalheFalhaCatalogo = erro.message
                ?: "Não foi possível consultar o bestiário deste ecossistema."
        }.getOrDefault(emptyList())

        fun correspondeAoEvento(
            criatura: CriaturaGerada
        ): Boolean {
            return when (event.type) {
                WorldEventType.BOSS -> criatura.chefe
                WorldEventType.ENCOUNTER -> !criatura.chefe
                else -> false
            }
        }

        val ordemRanks = listOf("E", "D", "C", "B", "A", "S", "SS", "SSS", "WORLD")
        val candidatas = criaturas.filter { criatura ->
            correspondeAoEvento(criatura) &&
                ordemRanks.indexOf(criatura.rank.uppercase()) >= region.rank.ordinal
        }

        val pista = creatureHint.trim().take(240)
        val correspondenciaDaPista = NarrativeCreatureMatcher.selectBest(candidatas, pista)
        val minimoCatalogo = if (event.type == WorldEventType.BOSS) 2 else 5
        var selecionada = when {
            pista.isBlank() -> candidatas.randomOrNull()
            // Quando o narrador nomeia ou descreve uma ameaça, nunca substituí-la
            // silenciosamente por outro monstro só porque o catálogo é grande.
            correspondenciaDaPista != null -> correspondenciaDaPista
            else -> null
        }
        var detalheFalhaGeracao: String? = null
        val catalogoPrecisaDeVariedade =
            pista.isBlank() &&
                (event.type == WorldEventType.BOSS || event.type == WorldEventType.ENCOUNTER) &&
                candidatas.size < minimoCatalogo

        // Expande o catálogo até manter variedade de criaturas comuns e chefes
        // sem substituir uma pista explícita da narrativa por outro inimigo.
        if (
            permitirGeracaoRemota &&
            (selecionada == null || catalogoPrecisaDeVariedade) &&
            (event.type == WorldEventType.BOSS ||
             event.type == WorldEventType.ENCOUNTER)
        ) {
            val status = runCatching { CreatureApi.checkHealth() }
                .onFailure { erro ->
                    detalheFalhaGeracao = erro.message ?: "Não foi possível consultar o serviço de criaturas."
                }
                .getOrNull()

            when {
                status == null || !status.success -> {
                    detalheFalhaGeracao = status?.body?.optString("message")
                        ?.takeIf { it.isNotBlank() }
                        ?: detalheFalhaCatalogo
                        ?: "Serviço de criaturas indisponível (HTTP ${status?.statusCode ?: 0})."
                }
                !status.body.optBoolean("aiConfigured", false) -> {
                    detalheFalhaGeracao = "A geração de criaturas por IA ainda não está configurada no servidor."
                }
                else -> {
                    val gerada = runCatching {
                        CreatureApi.gerarERegistrarCriatura(
                            ecosystemId = region.ecosystemId,
                            biome = region.biome,
                            rank = region.rank.name,
                            danger = region.encounterChance,
                            isBoss = event.type == WorldEventType.BOSS,
                            bossChance = region.bossChance,
                            creatureHint = pista
                        )
                    }.onFailure { erro ->
                        detalheFalhaGeracao = erro.message ?: "Falha desconhecida ao gerar criatura."
                    }.getOrNull()

                     selecionada = gerada?.takeIf { criatura ->
                        // O rank da região orienta a geração, mas não veta ranks
                        // originais ou raros criados pela IA. A coerência é validada
                        // pelo ecossistema e pelo tipo de encontro (chefe/comum).
                        correspondeAoEvento(criatura) &&
                            (pista.isBlank() ||
                                NarrativeCreatureMatcher.selectBest(listOf(criatura), pista) != null)
                    } ?: run {
                        if (gerada != null && pista.isNotBlank()) {
                            detalheFalhaGeracao = "A criatura gerada não correspondeu à pista da narrativa; ela não será apresentada como se fosse o monstro descrito."
                        }
                        selecionada
                    }
                }
            }
        }

        // Encontros narrativos usam os dados da criatura diretamente.
        // Carregar arte/imagens não é pré-requisito para criar o estado de combate.

        return ExplorationEncounter(
            region = region,
            enemyId = selecionada?.id,
            isBoss = selecionada?.chefe == true,
            message = when {
                selecionada == null && (event.type == WorldEventType.ENCOUNTER || event.type == WorldEventType.BOSS) ->
                    detalheFalhaGeracao?.let { "A ameaça foi narrada, mas não foi possível materializar a criatura. $it" }
                        ?: detalheFalhaCatalogo?.let { "Não foi possível consultar o bestiário: $it" }
                        ?: "Nenhuma criatura compatível com esta ameaça está disponível. Tente novamente."
                selecionada == null -> event.description
                selecionada.chefe ->
                    "CHEFE ENCONTRADO: ${selecionada.nome}!"
                else ->
                    "CRIATURA ENCONTRADA: ${selecionada.nome}!"
            },
            worldEvent = event,
            criatura = selecionada
        )
    }
}
