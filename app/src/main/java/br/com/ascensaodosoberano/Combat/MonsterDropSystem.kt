
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.companions.InventoryItem
import br.com.ascensaodosoberano.companions.Equipment
import br.com.ascensaodosoberano.companions.EquipmentType
import br.com.ascensaodosoberano.companions.EquipmentRarity
import br.com.ascensaodosoberano.companions.MaterialTraits
import br.com.ascensaodosoberano.companions.RarityVisuals
import br.com.ascensaodosoberano.world.CriaturaGerada
import kotlin.random.Random
import java.security.MessageDigest
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

            when (drop.tipo.trim().uppercase()) {

                "MATERIAL" -> {

                    val minimoBase = drop.quantidadeMinima.coerceIn(1, 999)
                    val maximoBase = drop.quantidadeMaxima.coerceIn(minimoBase, 999)
                    val minimo = (minimoBase * rankLootMultiplier).toInt().coerceIn(1, 999)
                    val maximo = (maximoBase * rankLootMultiplier).toInt().coerceIn(minimo, 999)

                    val materialRank = normalizarRankMaterial(
                        RarityVisuals.label(raridadeDeDrop(drop.raridade, criatura.rank).name)
                    )
                    materials.add(
                        InventoryItem(
                            id = materialDropId(criatura.id, drop, materialRank),
                            name = drop.nome,
                            description = drop.descricao,
                            type = "MATERIAL",
                            quantity = Random.nextInt(
                                minimo,
                                maximo + 1
                            ),
                            imagemIconeCaminho = "",
                            imagemDetalhadaCaminho = "",
                            materialRank = materialRank,
                            materialOrigin = criatura.nome,
                            materialTraits = MaterialTraits.fromCreature(criatura),
                            sourceCreatureId = criatura.id
                        )
                    )
                }

                "EQUIPAMENTO" -> {

                    val tipo = normalizarTipoEquipamento(drop.tipoEquipamento) ?: return@forEach
                    val nomeCriatura = criatura.nome.trim().ifBlank { "Criatura desconhecida" }
                    val nomeEquipamento = drop.nome.trim().ifBlank {
                        "${nomeTipoEquipamento(tipo)} de ${nomeCriatura}"
                    }
                    val descricaoEquipamento = drop.descricao.trim().ifBlank {
                        "Equipamento obtido de ${nomeCriatura}, adaptado às propriedades de sua origem."
                    }

                    val raridadeTier = raridadeDeDrop(drop.raridadeEquipamento, criatura.rank)
                    val raridade = RarityVisuals.equipmentRarity(raridadeTier.name)
                    val atributosBase = normalizarAtributos(drop.atributos)
                    val atributos = if (raridadeTier == br.com.ascensaodosoberano.companions.RarityTier.WORLD) {
                        multiplicarAtributosWorld(atributosBase, criatura.rank)
                    } else atributosBase
                    val efeito = if (raridadeTier == br.com.ascensaodosoberano.companions.RarityTier.WORLD) {
                        drop.efeitoEspecial?.takeIf { it.isNotBlank() }
                            ?: "Soberania Mundial de $nomeEquipamento: artefato único cuja presença distorce a energia ao redor."
                    } else drop.efeitoEspecial?.takeIf { it.isNotBlank() }

                    equipment.add(
                        Equipment(
                            id = "${criatura.id}_${UUID.randomUUID()}",
                            name = nomeEquipamento,
                            description = descricaoEquipamento,
                            type = tipo,
                            rarity = raridade,
                            rank = rankMinimoEquipamento(drop.rankEquipamento, criatura.rank),
                            levelRequired = drop.nivelRequerido.coerceAtLeast(1),
                            attributes = atributos,
                            specialEffect = efeito,
                            sourceMonsterId = criatura.id,
                            craftingMaterials = drop.craftingMaterials
                                .map(String::trim)
                                .filter(String::isNotBlank)
                                .distinct()
                                .ifEmpty { listOf("Material natural de $nomeCriatura") },
                            materialTraits = (drop.materialTraits + MaterialTraits.fromCreature(criatura))
                                .map(String::trim)
                                .filter(String::isNotBlank)
                                .distinct()
                        )
                    )
                }
            }
        }

        // Fallback procedural gratuito quando a IA não definiu equipamento utilizável.
        val possuiDropEquipamentoConfigurado = criatura.drops.any {
            it.tipo.trim().equals("EQUIPAMENTO", true) &&
                normalizarTipoEquipamento(it.tipoEquipamento) != null
        }
        if (!possuiDropEquipamentoConfigurado) {
            val chanceBase = when (criatura.rank.trim().uppercase()) {
                "E" -> 0.04f; "D" -> 0.05f; "C" -> 0.06f; "B" -> 0.07f
                "A" -> 0.08f; "S" -> 0.10f; "SS" -> 0.12f; "SSS" -> 0.15f
                "WORLD", "MUNDIAL" -> 0.20f
                else -> 0.05f
            }
            val chanceFinal = (chanceBase * if (criatura.chefe) 1.5f else 1f).coerceAtMost(0.35f)
            if (Random.nextFloat() < chanceFinal) {
                val modelo = EquipamentoProceduralGenerator.gerar(
                    criatura,
                    criatura.id.hashCode().toLong()
                )
                // A identidade visual fica estável por criatura; cada cópia ainda
                // recebe ID próprio para poder ser guardada, vendida ou melhorada.
                equipment.add(modelo.copy(id = "${criatura.id}_procedural_${UUID.randomUUID()}"))
            }
        }

        // Se a criatura não possuir materiais configurados pela geração, ainda pode
        // deixar uma parte natural aproveitável, com rank ligado à própria raridade.
        val possuiDropMaterialConfigurado = criatura.drops.any { it.tipo.trim().equals("MATERIAL", true) }
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
                    materialRank = normalizarRankMaterial(RarityVisuals.label(raridadeDeDrop("", criatura.rank).name)),
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

    // A identidade do material precisa distinguir drops diferentes da mesma criatura,
    // mas permanecer estável para que cópias do mesmo drop possam ser empilhadas.
    private fun materialDropId(creatureId: String, drop: br.com.ascensaodosoberano.world.DropCriatura, materialRank: String): String {
        val identity = listOf(
            drop.itemId.trim(),
            drop.nome.trim().lowercase(),
            drop.descricao.trim().lowercase(),
            drop.tipo.trim().uppercase(),
            drop.raridade.trim().uppercase(),
            materialRank.trim().uppercase()
        ).joinToString("\u001f")
        val digest = MessageDigest.getInstance("SHA-256").digest(identity.toByteArray(Charsets.UTF_8))
        val suffix = digest.take(12).joinToString("") { byte ->
            (byte.toInt() and 0xff).toString(16).padStart(2, '0')
        }
        return "material_${creatureId}_${suffix}"
    }

    private fun normalizarTipoEquipamento(valor: String): EquipmentType? =
        runCatching { EquipmentType.valueOf(valor.trim().uppercase()) }.getOrNull()

    private fun nomeTipoEquipamento(tipo: EquipmentType): String = when (tipo) {
        EquipmentType.WEAPON -> "Arma"
        EquipmentType.ARMOR -> "Armadura"
        EquipmentType.HELMET -> "Elmo"
        EquipmentType.BOOTS -> "Botas"
        EquipmentType.GLOVES -> "Luvas"
        EquipmentType.RING -> "Anel"
        EquipmentType.NECKLACE -> "Colar"
        EquipmentType.SHIELD -> "Escudo"
    }

    private fun normalizarRank(rank: String): String = when (rank.trim().uppercase()) {
        "D" -> "D"; "C" -> "C"; "B" -> "B"; "A" -> "A"
        "S" -> "S"; "SS" -> "SS"; "SSS" -> "SSS"
        "WORLD", "MUNDIAL", "MUNDO" -> "WORLD"
        else -> "E"
    }

    private fun rankMinimoEquipamento(rankDrop: String, rankCriatura: String): String {
        val ordem = listOf("E", "D", "C", "B", "A", "S", "SS", "SSS", "WORLD")
        val drop = ordem.indexOf(normalizarRank(rankDrop))
        val criatura = ordem.indexOf(normalizarRank(rankCriatura))
        return ordem[maxOf(drop, criatura)]
    }

    private fun normalizarAtributos(
        base: br.com.ascensaodosoberano.companions.EquipmentAttributes
    ) = base.copy(
        strength = base.strength.coerceIn(0, 2_000_000),
        intelligence = base.intelligence.coerceIn(0, 2_000_000),
        agility = base.agility.coerceIn(0, 2_000_000),
        vitality = base.vitality.coerceIn(0, 2_000_000),
        spirit = base.spirit.coerceIn(0, 2_000_000),
        physicalDamage = base.physicalDamage.coerceIn(0, 2_000_000),
        magicalDamage = base.magicalDamage.coerceIn(0, 2_000_000),
        defense = base.defense.coerceIn(0, 2_000_000)
    )

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

    private fun raridadeDeDrop(
        valorExplicito: String,
        rankCriatura: String
    ): br.com.ascensaodosoberano.companions.RarityTier {
        var tier = RarityVisuals.resolveDropRarity(valorExplicito, Random.nextFloat())
        val chanceMelhoria = when (rankCriatura.trim().uppercase()) {
            "E" -> 0f
            "D" -> 2f
            "C" -> 4f
            "B" -> 7f
            "A" -> 10f
            "S" -> 14f
            "SS" -> 18f
            "SSS" -> 22f
            "WORLD", "MUNDIAL" -> 28f
            else -> 0f
        }
        val tentativas = when (rankCriatura.trim().uppercase()) {
            "SSS", "WORLD", "MUNDIAL" -> 2
            else -> 1
        }
        repeat(tentativas) {
            if (tier != br.com.ascensaodosoberano.companions.RarityTier.WORLD &&
                tier != br.com.ascensaodosoberano.companions.RarityTier.ANCESTRAL &&
                Random.nextFloat() * 100f < chanceMelhoria
            ) {
                tier = when (tier) {
                    br.com.ascensaodosoberano.companions.RarityTier.COMMON -> br.com.ascensaodosoberano.companions.RarityTier.UNCOMMON
                    br.com.ascensaodosoberano.companions.RarityTier.UNCOMMON -> br.com.ascensaodosoberano.companions.RarityTier.RARE
                    br.com.ascensaodosoberano.companions.RarityTier.RARE -> br.com.ascensaodosoberano.companions.RarityTier.EPIC
                    br.com.ascensaodosoberano.companions.RarityTier.EPIC -> br.com.ascensaodosoberano.companions.RarityTier.LEGENDARY
                    br.com.ascensaodosoberano.companions.RarityTier.LEGENDARY -> br.com.ascensaodosoberano.companions.RarityTier.MYTHIC
                    br.com.ascensaodosoberano.companions.RarityTier.MYTHIC -> br.com.ascensaodosoberano.companions.RarityTier.DIVINE
                    br.com.ascensaodosoberano.companions.RarityTier.DIVINE -> br.com.ascensaodosoberano.companions.RarityTier.ANCESTRAL
                    else -> tier
                }
            }
        }
        return tier
    }

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
