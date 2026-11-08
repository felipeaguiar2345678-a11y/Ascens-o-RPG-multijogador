
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
                            materialRank = normalizarRankMaterial(drop.raridade.ifBlank { RarityVisuals.label(RarityVisuals.rollDropRarity(Random.nextFloat()).name) }),
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

                    val raridade = if (drop.raridadeEquipamento.isBlank()) {
                        RarityVisuals.equipmentRarity(RarityVisuals.rollDropRarity(Random.nextFloat()).name)
                    } else {
                        RarityVisuals.equipmentRarity(drop.raridadeEquipamento)
                    }

                    equipment.add(
                        Equipment(
                            id = drop.itemId,
                            name = drop.nome,
                            description = drop.descricao,
                            type = tipo,
                            rarity = raridade,
                            rank = drop.rankEquipamento,
                            levelRequired = drop.nivelRequerido,
                            attributes = drop.atributos,
                            specialEffect = drop.efeitoEspecial,
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
                    materialRank = normalizarRankMaterial(RarityVisuals.label(RarityVisuals.rollDropRarity(Random.nextFloat()).name)),
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

    private fun normalizarRankMaterial(rank: String): String = when (rank.trim().uppercase()) {
        "MUNDO", "MUNDIAL" -> "WORLD"
        "ÉPICO" -> "EPICO"
        "LENDÁRIO" -> "LENDARIO"
        "MÍTICO" -> "MITICO"
        else -> rank.trim().uppercase()
    }
}
