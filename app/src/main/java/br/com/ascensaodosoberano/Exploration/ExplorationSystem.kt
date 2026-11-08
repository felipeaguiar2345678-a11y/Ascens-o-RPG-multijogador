
package br.com.ascensaodosoberano.exploration

import br.com.ascensaodosoberano.world.CriaturaGerada
import br.com.ascensaodosoberano.world.CreatureApi
import br.com.ascensaodosoberano.world.RepositorioCriaturas
import br.com.ascensaodosoberano.world.WorldContext
import br.com.ascensaodosoberano.world.WorldDirector
import br.com.ascensaodosoberano.world.WorldEvent
import br.com.ascensaodosoberano.world.WorldEventType

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

    /** Retorna apenas ecossistemas selvagens conhecidos; cidades não geram encontros aleatórios. */
    fun regionForWorldPoint(worldPointId: String): ExplorationRegion? {
        return when (worldPointId.lowercase()) {
            "clareira_inicial", "dark_forest", "floresta_sombras" -> regions.first { it.id == "dark_forest" }
            "ruinas_elficas", "ruinas_antigas", "forgotten_ruins" -> regions.first { it.id == "forgotten_ruins" }
            "vale_abismo", "abyss_valley" -> regions.first { it.id == "abyss_valley" }
            "nhar_zul", "terras_mortas", "dead_lands" -> regions.first { it.id == "dead_lands" }
            else -> null
        }
    }

    val regions = listOf(
        ExplorationRegion(
            "dark_forest",
            "Floresta das Sombras",
            RegionRank.E,
            45,
            5.0,
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
        )
    )

    suspend fun explore(
        region: ExplorationRegion,
        forcarEncontro: Boolean = false
    ): ExplorationEncounter {

        val event = if (forcarEncontro) {
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

        val criaturas = RepositorioCriaturas
            .buscarPorEcossistema(region.ecosystemId)
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

        // Só tenta gerar quando não existe criatura adequada.
        if (
            selecionada == null &&
            (event.type == WorldEventType.BOSS ||
             event.type == WorldEventType.ENCOUNTER)
        ) {
            val gerada = runCatching {
                val status = CreatureApi.checkHealth()

                if (
                    status.success &&
                    status.body.optBoolean("aiConfigured", false)
                ) {
                    CreatureApi.gerarERegistrarCriatura(
    ecosystemId = region.ecosystemId,
    biome = region.biome,
    rank = region.rank.name,
    danger = region.encounterChance,
    isBoss = event.type == WorldEventType.BOSS,
    bossChance = region.bossChance
)
                } else {
                    null
                }
            }.getOrNull()

            selecionada = gerada?.takeIf { criatura ->
                val rank = runCatching {
                    RegionRank.valueOf(criatura.rank.uppercase())
                }.getOrNull()

                rank != null &&
                    rank.ordinal <= rankLimit &&
                    correspondeAoEvento(criatura)
            }
        }

        // Carrega a arte já registrada no catálogo; nenhuma imagem nova é gerada aqui.
        if (selecionada != null) {
            selecionada = runCatching {
                RepositorioCriaturas.buscarCriaturaComImagem(selecionada!!.id)
            }.getOrNull() ?: selecionada
        }

        return ExplorationEncounter(
            region = region,
            enemyId = selecionada?.id,
            isBoss = selecionada?.chefe == true,
            message = when {
                selecionada == null && (event.type == WorldEventType.ENCOUNTER || event.type == WorldEventType.BOSS) ->
                    "Nenhuma criatura deste ecossistema está disponível no catálogo. Verifique a conexão da IA e tente novamente."
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
