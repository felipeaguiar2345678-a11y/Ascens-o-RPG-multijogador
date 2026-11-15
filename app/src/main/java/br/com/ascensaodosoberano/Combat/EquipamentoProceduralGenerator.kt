package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.companions.Equipment
import br.com.ascensaodosoberano.companions.EquipmentAttributes
import br.com.ascensaodosoberano.companions.EquipmentType
import br.com.ascensaodosoberano.companions.MaterialTraits
import br.com.ascensaodosoberano.companions.RarityVisuals
import br.com.ascensaodosoberano.world.CriaturaGerada
import kotlin.random.Random

/** Geração local, gratuita e repetível de equipamento a partir da criatura de origem. */
object EquipamentoProceduralGenerator {
    fun gerar(criatura: CriaturaGerada, seed: Long): Equipment {
        require(criatura.id.isNotBlank()) { "A criatura precisa ter um ID." }
        val random = Random(seed)
        val texto = listOf(criatura.nome, criatura.descricao, criatura.bioma, criatura.habitat,
            criatura.ecosystemId, criatura.raridade, criatura.habilidades.joinToString(" "))
            .joinToString(" ").lowercase()
        val traits = MaterialTraits.fromCreature(criatura)
        val tipo = escolherTipo(texto, traits, random)
        val material = materialPrincipal(texto, traits)
        val tema = temaElemental(texto, traits)
        val sufixo = when (tipo) {
            EquipmentType.WEAPON -> listOf("do Predador", "da Ruptura", "da Caçada")[random.nextInt(3)]
            EquipmentType.ARMOR -> listOf("da Carapaça", "do Guardião", "da Resistência")[random.nextInt(3)]
            EquipmentType.HELMET -> "do Instinto"
            EquipmentType.BOOTS -> "da Perseguição"
            EquipmentType.GLOVES -> "das Garras"
            EquipmentType.RING -> "do Núcleo"
            EquipmentType.NECKLACE -> "do Coração"
            EquipmentType.SHIELD -> "da Fortaleza"
        }
        val rank = normalizarRank(criatura.rank)
        val raridade = RarityVisuals.equipmentRarity(RarityVisuals.rollDropRarity(random.nextFloat()).name)
        val nivel = criatura.nivel.coerceAtLeast(1)
        val escala = (nivel * (1.0 + indiceRank(rank) * 0.18) *
            (1.0 + criatura.perigo.coerceAtLeast(0) / 250.0)).coerceIn(1.0, 100_000.0)
        val base = escala.toInt().coerceAtLeast(1)
        val multiplicador = when (raridade) {
            br.com.ascensaodosoberano.companions.EquipmentRarity.COMMON -> 1.0
            br.com.ascensaodosoberano.companions.EquipmentRarity.UNCOMMON -> 1.15
            br.com.ascensaodosoberano.companions.EquipmentRarity.RARE -> 1.35
            br.com.ascensaodosoberano.companions.EquipmentRarity.EPIC -> 1.65
            br.com.ascensaodosoberano.companions.EquipmentRarity.LEGENDARY -> 2.0
            br.com.ascensaodosoberano.companions.EquipmentRarity.MYTHIC -> 2.5
            br.com.ascensaodosoberano.companions.EquipmentRarity.DIVINE -> 3.2
            br.com.ascensaodosoberano.companions.EquipmentRarity.ANCESTRAL -> 4.2
            br.com.ascensaodosoberano.companions.EquipmentRarity.WORLD -> 6.0
        }
        val poder = (base * multiplicador).toInt().coerceAtLeast(1)
        val magico = tema in setOf("fogo", "gelo", "veneno", "espiritual", "raio", "água")
        val atributos = when (tipo) {
            EquipmentType.WEAPON -> EquipmentAttributes(strength = poder / 3, agility = poder / 5,
                intelligence = if (magico) poder / 4 else 0, physicalDamage = poder * 2,
                magicalDamage = if (magico) poder * 2 else 0)
            EquipmentType.ARMOR, EquipmentType.SHIELD -> EquipmentAttributes(
                vitality = poder / 2, defense = poder * 2,
                strength = if (tema == "mineral") poder / 5 else 0)
            EquipmentType.HELMET -> EquipmentAttributes(intelligence = if (magico) poder / 2 else poder / 4,
                spirit = poder / 4, defense = poder)
            EquipmentType.BOOTS -> EquipmentAttributes(agility = poder * 2,
                vitality = poder / 4, defense = poder / 2)
            EquipmentType.GLOVES -> EquipmentAttributes(strength = poder, agility = poder / 2,
                physicalDamage = poder / 2, magicalDamage = if (magico) poder / 2 else 0)
            EquipmentType.RING, EquipmentType.NECKLACE -> EquipmentAttributes(
                intelligence = if (magico) poder else poder / 3, spirit = poder,
                vitality = poder / 3, magicalDamage = if (magico) poder else 0)
        }
        val efeito = when (tema) {
            "fogo" -> "Brasas de ${criatura.nome}: ataques podem deixar queimadura."
            "gelo" -> "Frio de ${criatura.nome}: aumenta a resistência ao gelo."
            "veneno" -> "Toxina de ${criatura.nome}: ataques podem envenenar o alvo."
            "espiritual" -> "Eco espiritual de ${criatura.nome}: fortalece energia e resistência mágica."
            "raio" -> "Pulso elétrico de ${criatura.nome}: pode acelerar o próximo golpe."
            "água" -> "Maré de ${criatura.nome}: favorece recuperação e resistência."
            "mineral" -> "Núcleo mineral de ${criatura.nome}: reforça a defesa."
            "natureza" -> "Seiva viva de ${criatura.nome}: concede vigor natural."
            else -> "Instinto de ${criatura.nome}: propriedades ligadas à sua origem."
        }
        val nome = "$material $sufixo de ${criatura.nome}"
        val habitat = criatura.bioma.ifBlank { criatura.habitat.ifBlank { "seu habitat natural" } }
        val descricao = "$nome. Material e acabamento refletem ${criatura.nome} e $habitat. Afinidade: $tema."
        return Equipment(
            id = "procedural_${criatura.id}_${seed.toULong().toString(16)}",
            name = nome, description = descricao, type = tipo, rarity = raridade, rank = rank,
            levelRequired = (nivel * 0.75).toInt().coerceAtLeast(1), attributes = atributos,
            specialEffect = efeito, sourceMonsterId = criatura.id,
            craftingMaterials = listOf(material, "Essência de ${criatura.nome}"),
            materialTraits = traits + tema.uppercase()
        )
    }

    private fun escolherTipo(texto: String, traits: List<String>, random: Random): EquipmentType {
        val opcoes = when {
            "drag" in texto || "dracon" in texto -> listOf(EquipmentType.ARMOR, EquipmentType.WEAPON, EquipmentType.SHIELD, EquipmentType.HELMET)
            "aranha" in texto || "inset" in texto || "quitina" in texto -> listOf(EquipmentType.GLOVES, EquipmentType.ARMOR, EquipmentType.HELMET, EquipmentType.RING)
            "lobo" in texto || "canino" in texto || "predador" in texto -> listOf(EquipmentType.WEAPON, EquipmentType.BOOTS, EquipmentType.GLOVES)
            "planta" in texto || "flor" in texto || "raiz" in texto -> listOf(EquipmentType.ARMOR, EquipmentType.RING, EquipmentType.NECKLACE)
            "mar" in texto || "aquatic" in texto || "água" in texto -> listOf(EquipmentType.NECKLACE, EquipmentType.SHIELD, EquipmentType.WEAPON)
            "golem" in texto || "pedra" in texto || "MINERAL" in traits -> listOf(EquipmentType.ARMOR, EquipmentType.SHIELD, EquipmentType.WEAPON)
            else -> listOf(EquipmentType.WEAPON, EquipmentType.ARMOR, EquipmentType.BOOTS, EquipmentType.RING)
        }
        return opcoes[random.nextInt(opcoes.size)]
    }

    private fun materialPrincipal(texto: String, traits: List<String>): String = when {
        "DRACONICO" in traits || "drag" in texto -> "Escamas dracônicas"
        "PREDADOR" in traits -> "Presas e couro bestial"
        "NATUREZA" in traits -> "Fibra viva e madeira ancestral"
        "GELO" in traits -> "Cristal glacial"
        "FOGO" in traits -> "Obsidiana vulcânica"
        "VENENO" in traits -> "Quitina tóxica"
        "ESPIRITUAL" in traits -> "Essência espectral"
        "MINERAL" in traits -> "Minério natural"
        "AQUATICO" in traits -> "Pérolas e escamas marinhas"
        else -> "Fragmentos orgânicos"
    }

    private fun temaElemental(texto: String, traits: List<String>): String = when {
        "GELO" in traits -> "gelo"
        "FOGO" in traits -> "fogo"
        "VENENO" in traits -> "veneno"
        "ESPIRITUAL" in traits -> "espiritual"
        "raio" in texto || "elétr" in texto || "eletr" in texto -> "raio"
        "AQUATICO" in traits -> "água"
        "MINERAL" in traits -> "mineral"
        "NATUREZA" in traits -> "natureza"
        else -> "bestial"
    }

    private fun normalizarRank(rank: String): String {
        val validos = listOf("E", "D", "C", "B", "A", "S", "SS", "SSS", "WORLD")
        return rank.trim().uppercase().let { if (it in validos) it else "E" }
    }

    private fun indiceRank(rank: String): Int =
        listOf("E", "D", "C", "B", "A", "S", "SS", "SSS", "WORLD").indexOf(rank).coerceAtLeast(0)
}
