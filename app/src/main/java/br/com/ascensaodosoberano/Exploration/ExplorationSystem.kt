
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

    // Protege o orçamento sem deixar uma falha temporária bloquear a região por 10 minutos.
    private val ultimaTentativaGeracaoPorEcossistema = mutableMapOf<String, Long>()
    private val ultimaGeracaoBemSucedidaPorEcossistema = mutableMapOf<String, Long>()
    private const val INTERVALO_GERACAO_MS = 10 * 60 * 1000L
    private const val INTERVALO_RETENTATIVA_FALHA_MS = 60 * 1000L

    private fun reservarTentativaDeGeracao(ecosystemId: String): Boolean =
        synchronized(ultimaTentativaGeracaoPorEcossistema) {
            val agora = System.currentTimeMillis()
            val ultimaGeracao = ultimaGeracaoBemSucedidaPorEcossistema[ecosystemId] ?: 0L
            val ultimaTentativa = ultimaTentativaGeracaoPorEcossistema[ecosystemId] ?: 0L
            if (agora - ultimaGeracao < INTERVALO_GERACAO_MS ||
                agora - ultimaTentativa < INTERVALO_RETENTATIVA_FALHA_MS
            ) {
                false
            } else {
                ultimaTentativaGeracaoPorEcossistema[ecosystemId] = agora
                true
            }
        }

    private fun registrarGeracaoBemSucedida(ecosystemId: String) {
        synchronized(ultimaTentativaGeracaoPorEcossistema) {
            val agora = System.currentTimeMillis()
            ultimaTentativaGeracaoPorEcossistema[ecosystemId] = agora
            ultimaGeracaoBemSucedidaPorEcossistema[ecosystemId] = agora
        }
    }

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

        return when (ponto.region) {
            WorldRegion.MONTANHAS_GELIDAS -> regions.first { it.id == "frost_mountains" }
            WorldRegion.FLORESTA_ARCANA -> regions.first { it.id == "dark_forest" }
            WorldRegion.IMPERIO -> regions.first { it.id == "imperial_frontier" }
            WorldRegion.CENTRAL -> regions.first { it.id == "central_wilds" }
            WorldRegion.SOMBRAS -> regions.first { it.id == "shadowlands" }
            WorldRegion.DESERTO_ANCESTRAL -> regions.first { it.id == "ancestral_desert" }
            WorldRegion.MAR_ETERNAL -> regions.first { it.id == "eternal_sea" }
        }
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
        forcarChefe: Boolean = false
    ): ExplorationEncounter {

        val event = if (forcarChefe) {
            WorldEvent(
                type = WorldEventType.BOSS,
                title = "Sinal de chefe",
                description = "A presença de uma criatura-chefe foi revelada pela história.",
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

        val rankLimit = region.rank.ordinal

        val criaturas = runCatching {
            RepositorioCriaturas.buscarPorEcossistema(
                ecosystemId = region.ecosystemId,
                somenteCache = !permitirGeracaoRemota
            )
        }.getOrDefault(emptyList())
            .filter { criatura ->
                val rank = runCatching {
                    RegionRank.valueOf(criatura.rank.uppercase())
                }.getOrNull()

                rank != null && rank.ordinal <= rankLimit
            }

        fun correspondeAoEvento(
            criatura: CriaturaGerada
        ): Boolean {
            return when (event.type) {
                WorldEventType.BOSS -> criatura.chefe
                WorldEventType.ENCOUNTER -> !criatura.chefe
                else -> false
            }
        }

        val candidatas = criaturas.filter {
            correspondeAoEvento(it)
        }

        var selecionada = candidatas.randomOrNull()
        var detalheFalhaGeracao: String? = null
        val minimoCatalogo = if (event.type == WorldEventType.BOSS) 2 else 5
        val catalogoPrecisaDeVariedade =
            (event.type == WorldEventType.BOSS || event.type == WorldEventType.ENCOUNTER) &&
                candidatas.size < minimoCatalogo

        // Mantém variedade: até 5 criaturas comuns e 2 chefes por ecossistema,
        // gerando no máximo uma nova a cada 10 minutos por região.
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
                        ?: "Serviço de criaturas indisponível (HTTP ${status?.statusCode ?: 0})."
                }
                !status.body.optBoolean("aiConfigured", false) -> {
                    detalheFalhaGeracao = "A geração de criaturas por IA ainda não está configurada no servidor."
                }
                !reservarTentativaDeGeracao(region.ecosystemId) -> {
                    if (selecionada == null) {
                        detalheFalhaGeracao = "O ecossistema está aguardando o intervalo de geração para evitar custos repetidos."
                    }
                }
                else -> {
                    val gerada = runCatching {
                        CreatureApi.gerarERegistrarCriatura(
                            ecosystemId = region.ecosystemId,
                            biome = region.biome,
                            rank = region.rank.name,
                            danger = region.encounterChance,
                            isBoss = event.type == WorldEventType.BOSS,
                            bossChance = region.bossChance
                        )
                    }.onFailure { erro ->
                        detalheFalhaGeracao = erro.message ?: "Falha desconhecida ao gerar criatura."
                    }.getOrNull()

                    if (gerada != null) {
                        registrarGeracaoBemSucedida(region.ecosystemId)
                    }

                    selecionada = gerada?.takeIf { criatura ->
                        val rank = runCatching {
                            RegionRank.valueOf(criatura.rank.uppercase())
                        }.getOrNull()
                        rank != null &&
                            rank.ordinal <= rankLimit &&
                            correspondeAoEvento(criatura)
                    } ?: selecionada
                }
            }
        }

        if (selecionada != null) {
            selecionada = runCatching {
                RepositorioCriaturas.buscarCriaturaComImagem(
                    selecionada!!.id,
                    somenteCache = !permitirGeracaoRemota
                )
            }.getOrNull() ?: selecionada
        }

        return ExplorationEncounter(
            region = region,
            enemyId = selecionada?.id,
            isBoss = selecionada?.chefe == true,
            message = when {
                selecionada == null && (event.type == WorldEventType.ENCOUNTER || event.type == WorldEventType.BOSS) ->
                    detalheFalhaGeracao?.let { "Nenhuma criatura apareceu. $it" }
                        ?: "Nenhuma criatura deste ecossistema está disponível no catálogo. Tente procurar novamente."
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
