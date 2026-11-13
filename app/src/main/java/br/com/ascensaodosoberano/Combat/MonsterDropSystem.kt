
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.companions.InventoryItem
import br.com.ascensaodosoberano.companions.Equipment
import br.com.ascensaodosoberano.companions.EquipmentType
import br.com.ascensaodosoberano.companions.EquipmentRarity
import br.com.ascensaodosoberano.companions.MaterialTraits
import br.com.ascensaodosoberano.companions.RarityVisuals
import br.com.ascensaodosoberano.world.CriaturaGerada
import kotlin.random.Random
import java.util.UUID

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
        val rankLootMultiplier = rankDropMultiplier(criatura.rank)
        val effectiveChanceMultiplier = chanceMultiplier.coerceAtLeast(0f) * rankLootMultiplier

        criatura.drops.forEach { drop ->

            val sucesso = drop.garantido ||
                Random.nextFloat() * 100f < (drop.chancePercentual * effectiveChanceMultiplier).coerceIn(0f, 100f)

            if (!sucesso) return@forEach

            when (drop.tipo.uppercase()) {

                "MATERIAL" -> {

                    val minimoBase = drop.quantidadeMinima.coerceIn(1, 999)
                    val maximoBase = drop.quantidadeMaxima.coerceIn(minimoBase, 999)
                    val minimo = (minimoBase * rankLootMultiplier).toInt().coerceIn(1, 999)
                    val maximo = (maximoBase * rankLootMultiplier).toInt().coerceIn(minimo, 999)

                    materials.add(
                        InventoryItem(
                            id = if (drop.itemId.isBlank()) "material_${criatura.id}_${drop.nome.lowercase().replace(' ', '_')}" else "${drop.itemId}_${criatura.id}",
                            name = drop.nome,
                            description = drop.descricao,
                            type = "MATERIAL",
                            quantity = Random.nextInt(
                                minimo,
                                maximo + 1
                            ),
                            imagemIconeCaminho = "",
                            imagemDetalhadaCaminho = "",
                            materialRank = normalizarRankMaterial(
                                RarityVisuals.label(raridadeDeDrop(drop.raridade).name)
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

                    val raridadeTier = raridadeDeDrop(drop.raridadeEquipamento)
                    val raridade = RarityVisuals.equipmentRarity(raridadeTier.name)
                    val atributos = if (raridadeTier == br.com.ascensaodosoberano.companions.RarityTier.WORLD) {
                        multiplicarAtributosWorld(drop.atributos, criatura.rank)
                    } else drop.atributos
                    val efeito = if (raridadeTier == br.com.ascensaodosoberano.companions.RarityTier.WORLD) {
                        drop.efeitoEspecial?.takeIf { it.isNotBlank() }
                            ?: "Soberania Mundial de ${drop.nome}: artefato único cuja presença distorce a energia ao redor."
                    } else drop.efeitoEspecial

                    equipment.add(
                        Equipment(
                            id = "${criatura.id}_${UUID.randomUUID()}",
                            name = drop.nome,
                            description = drop.descricao,
                            type = tipo,
                            rarity = raridade,
                            rank = rankMinimoEquipamento(drop.rankEquipamento, criatura.rank),
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
                    type = "MATERIAL",
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

    private fun rankMinimoEquipamento(rankDrop: String, rankCriatura: String): String {
        val ordem = listOf("E", "D", "C", "B", "A", "S", "SS", "SSS", "WORLD")
        val drop = ordem.indexOf(rankDrop.trim().uppercase())
        val criatura = ordem.indexOf(rankCriatura.trim().uppercase())
        return when {
            drop < 0 && criatura < 0 -> rankDrop
            drop < 0 -> ordem[criatura]
            criatura < 0 -> ordem[drop]
            else -> ordem[maxOf(drop, criatura)]
        }
    }

    private fun rankDropMultiplier(rank: String): Float = when (rank.trim().uppercase()) {
        "E" -> 1.00f
        "D" -> 1.10f
        "C" -> 1.20f
        "B" -> 1.35f
        "A" -> 1.50f
        "S" -> 1.75f
        "SS" -> 2.00f
        "SSS" -> 2.50f
        "WORLD", "MUNDIAL" -> 3.00f
        else -> 1.00f
    }

    private fun raridadeDeDrop(valorExplicito: String): br.com.ascensaodosoberano.companions.RarityTier =
        RarityVisuals.resolveDropRarity(valorExplicito, Random.nextFloat())

    private fun multiplicarAtributosWorld(
        base: br.com.ascensaodosoberano.companions.EquipmentAttributes,
        rankCriatura: String
    ) = base.copy(
        strength = multiplicar(base.strength, rankCriatura),
        intelligence = multiplicar(base.intelligence, rankCriatura),
        agility = multiplicar(base.agility, rankCriatura),
        vitality = multiplicar(base.vitality, rankCriatura),
        spirit = multiplicar(base.spirit, rankCriatura),
        physicalDamage = multiplicar(base.physicalDamage, rankCriatura),
        magicalDamage = multiplicar(base.magicalDamage, rankCriatura),
        defense = multiplicar(base.defense, rankCriatura)
    )

    private fun multiplicar(valor: Int, rankCriatura: String): Int =
        (valor.toDouble() * RarityVisuals.worldAttributeMultiplier(rankCriatura))
            .toLong().coerceIn(0L, 2_000_000L).toInt()

    private fun normalizarRankMaterial(rank: String): String = when (rank.trim().uppercase()) {
        "MUNDO", "MUNDIAL" -> "WORLD"
        "ÉPICO" -> "EPICO"
        "LENDÁRIO" -> "LENDARIO"
        "MÍTICO" -> "MITICO"
        else -> rank.trim().uppercase()
    }
}
