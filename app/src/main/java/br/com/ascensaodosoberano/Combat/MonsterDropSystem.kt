
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.companions.InventoryItem
import br.com.ascensaodosoberano.companions.Equipment
import br.com.ascensaodosoberano.companions.EquipmentType
import br.com.ascensaodosoberano.companions.EquipmentRarity
import br.com.ascensaodosoberano.companions.MaterialTraits
import br.com.ascensaodosoberano.companions.RarityVisuals
import br.com.ascensaodosoberano.world.CriaturaGerada
import kotlin.random.Random

data class MonsterDropResult(
    val materials: List<InventoryItem>,
    val equipment: List<Equipment>
)

object MonsterDropSystem {

    fun roll(
        criatura: CriaturaGerada,
        chanceMultiplier: Float = 1f
    ): MonsterDropResult {

        val materials = mutableListOf<InventoryItem>()
        val equipment = mutableListOf<Equipment>()
        // World só pode surgir de chefes de rank SSS; o restante da tabela é redistribuído
        // entre as outras raridades quando a criatura não atende a essa condição.
        val podeGerarWorld = criatura.chefe && criatura.rank.trim().equals("SSS", ignoreCase = true)

        criatura.drops.forEach { drop ->

            val sucesso = drop.garantido ||
                Random.nextFloat() * 100f < (drop.chancePercentual * chanceMultiplier).coerceAtMost(100f)

            if (!sucesso) return@forEach

            when (drop.tipo.uppercase()) {

                "MATERIAL" -> {

                    val minimo = drop.quantidadeMinima.coerceIn(1, 999)
                    val maximo = drop.quantidadeMaxima
                        .coerceIn(minimo, 999)

                    materials.add(
                        InventoryItem(
                            id = if (drop.itemId.isBlank()) "material_${criatura.id}_${drop.nome.lowercase().replace(' ', '_')}" else "${drop.itemId}_${criatura.id}",
                            name = drop.nome,
                            description = drop.descricao,
                            type = "Material de criação",
                            quantity = Random.nextInt(
                                minimo,
                                maximo + 1
                            ),
                            imagemIconeCaminho = "",
                            imagemDetalhadaCaminho = "",
                            materialRank = normalizarRankMaterial(
                                RarityVisuals.label(raridadeDeDrop(drop.raridade, podeGerarWorld).name)
                            ),
                            materialOrigin = criatura.nome,
                            materialTraits = MaterialTraits.fromCreature(criatura),
                            sourceCreatureId = criatura.id
                        )
                    )
                }

                "EQUIPAMENTO" -> {

                    val tipo = runCatching {
                        EquipmentType.valueOf(
                            drop.tipoEquipamento.uppercase()
                        )
                    }.getOrNull() ?: return@forEach

                    val raridadeTier = raridadeDeDrop(drop.raridadeEquipamento, podeGerarWorld)
                    val raridade = RarityVisuals.equipmentRarity(raridadeTier.name)
                    val atributos = if (raridadeTier == br.com.ascensaodosoberano.companions.RarityTier.WORLD) {
                        multiplicarAtributosWorld(drop.atributos)
                    } else drop.atributos
                    val efeito = if (raridadeTier == br.com.ascensaodosoberano.companions.RarityTier.WORLD) {
                        drop.efeitoEspecial?.takeIf { it.isNotBlank() }
                            ?: "Soberania Mundial de ${drop.nome}: artefato único cuja presença distorce a energia ao redor."
                    } else drop.efeitoEspecial

                    equipment.add(
                        Equipment(
                            id = drop.itemId,
                            name = drop.nome,
                            description = drop.descricao,
                            type = tipo,
                            rarity = raridade,
                            rank = drop.rankEquipamento,
                            levelRequired = drop.nivelRequerido,
                            attributes = atributos,
                            specialEffect = efeito,
                            sourceMonsterId = criatura.id
                        )
                    )
                }
            }
        }

        // Se a criatura não possuir materiais configurados pela geração, ainda pode
        // deixar uma parte natural aproveitável, com rank ligado à própria raridade.
        val possuiDropMaterialConfigurado = criatura.drops.any { it.tipo.equals("MATERIAL", true) }
        if (!possuiDropMaterialConfigurado && Random.nextFloat() < 0.65f) {
            val nomeMaterial = when {
                criatura.nome.contains("lobo", true) -> "Presa de ${criatura.nome}"
                criatura.nome.contains("planta", true) || criatura.bioma.contains("floresta", true) -> "Fibra de ${criatura.nome}"
                criatura.nome.contains("drag", true) -> "Escama de ${criatura.nome}"
                else -> "Fragmento de ${criatura.nome}"
            }
            materials.add(
                InventoryItem(
                    id = "material_${criatura.id}",
                    name = nomeMaterial,
                    description = "Material natural obtido de ${criatura.nome}. Mantém as propriedades da criatura e de seu habitat.",
                    type = "Material de criação",
                    quantity = Random.nextInt(1, 3),
                    materialRank = normalizarRankMaterial(RarityVisuals.label(RarityVisuals.rollDropRarity(Random.nextFloat(), podeGerarWorld).name)),
                    materialOrigin = criatura.nome,
                    materialTraits = MaterialTraits.fromCreature(criatura),
                    sourceCreatureId = criatura.id
                )
            )
        }

        return MonsterDropResult(
            materials = materials,
            equipment = equipment
        )
    }

    private fun raridadeDeDrop(valorExplicito: String, podeGerarWorld: Boolean): br.com.ascensaodosoberano.companions.RarityTier {
        if (valorExplicito.isBlank()) {
            return RarityVisuals.rollDropRarity(Random.nextFloat(), podeGerarWorld)
        }
        val raridade = RarityVisuals.normalize(valorExplicito)
        // A geração por IA não pode contornar a regra de elegibilidade de World.
        return if (raridade == br.com.ascensaodosoberano.companions.RarityTier.WORLD && !podeGerarWorld) {
            br.com.ascensaodosoberano.companions.RarityTier.ANCESTRAL
        } else raridade
    }

    private fun multiplicarAtributosWorld(base: br.com.ascensaodosoberano.companions.EquipmentAttributes) =
        base.copy(
            strength = (base.strength.toLong() * 10L).coerceAtMost(2_000_000L).toInt(),
            intelligence = (base.intelligence.toLong() * 10L).coerceAtMost(2_000_000L).toInt(),
            agility = (base.agility.toLong() * 10L).coerceAtMost(2_000_000L).toInt(),
            vitality = (base.vitality.toLong() * 10L).coerceAtMost(2_000_000L).toInt(),
            spirit = (base.spirit.toLong() * 10L).coerceAtMost(2_000_000L).toInt(),
            physicalDamage = (base.physicalDamage.toLong() * 10L).coerceAtMost(2_000_000L).toInt(),
            magicalDamage = (base.magicalDamage.toLong() * 10L).coerceAtMost(2_000_000L).toInt(),
            defense = (base.defense.toLong() * 10L).coerceAtMost(2_000_000L).toInt()
        )

    private fun normalizarRankMaterial(rank: String): String = when (rank.trim().uppercase()) {
        "MUNDO", "MUNDIAL" -> "WORLD"
        "ÉPICO" -> "EPICO"
        "LENDÁRIO" -> "LENDARIO"
        "MÍTICO" -> "MITICO"
        else -> rank.trim().uppercase()
    }
}
