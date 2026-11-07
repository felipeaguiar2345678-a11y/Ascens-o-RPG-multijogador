package br.com.ascensaodosoberano.companions

import java.util.UUID
import br.com.ascensaodosoberano.world.WorldMapData
import br.com.ascensaodosoberano.world.WorldPointType

private enum class MaterialTier(val power: Int, val cost: Long, val rank: String) {
    COMUM(1, 5, "E"), INCOMUM(2, 15, "D"), RARO(4, 40, "C"), EPICO(7, 100, "B"),
    LENDARIO(11, 250, "A"), MITICO(17, 600, "S"), DIVINO(25, 1400, "SS"),
    ANCESTRAL(38, 3200, "SSS"), MUNDIAL(60, 8000, "WORLD")
}

data class BlacksmithCity(
    val pointId: String,
    val cityName: String,
    val blacksmithName: String,
    val specialty: String,
    val preferredTrait: String,
    val availableHere: Boolean = true
)

data class BlacksmithOption(
    val id: String,
    val equipment: Equipment,
    val materialsRequired: Map<String, Int>,
    val goldCost: Long,
    val explanation: String
)

object BlacksmithSystem {
    private val cities = listOf(
        BlacksmithCity("aurelia", "Aurelia", "Darian", "armas e armaduras equilibradas", "BESTIAL"),
        BlacksmithCity("mina_dourada", "Mina Dourada", "Brom", "equipamentos minerais e defensivos", "MINERAL"),
        BlacksmithCity("arkanis", "Arkanis", "Ilyra", "armas arcanas e catalisadores", "ESPIRITUAL"),
        BlacksmithCity("cidade_do_sol", "Cidade do Sol", "Solmar", "armas de fogo e combate físico", "FOGO"),
        BlacksmithCity("vila_esperanca", "Vila Esperança", "Tomas", "equipamentos naturais e leves", "NATUREZA"),
        BlacksmithCity("malachar", "Malachar", "Varkun", "armas sombrias e de alto risco", "VENENO")
    )

    fun city(pointId: String): BlacksmithCity {
        val normalized = pointId.lowercase().replace(' ', '_')
        cities.firstOrNull { it.pointId == normalized }?.let { return it }
        val point = WorldMapData.points.firstOrNull { it.id == normalized }
        val isTown = point != null && point.type in setOf(WorldPointType.CAPITAL, WorldPointType.CITY, WorldPointType.VILLAGE)
        val name = point?.name ?: pointId.replace('_', ' ').ifBlank { "Local desconhecido" }
        return BlacksmithCity(
            pointId = normalized,
            cityName = name,
            blacksmithName = "Ferreiro de $name",
            specialty = "equipamentos adaptados aos recursos da região",
            preferredTrait = "BESTIAL",
            availableHere = isTown
        )
    }

    private fun tier(item: InventoryItem): MaterialTier {
        val raw = item.materialRank.uppercase().replace('Í', 'I').replace('É', 'E')
        return when (raw) {
            "INCOMUM", "UNCOMMON", "D" -> MaterialTier.INCOMUM
            "RARO", "RARE", "C" -> MaterialTier.RARO
            "EPICO", "EPIC", "B" -> MaterialTier.EPICO
            "LENDARIO", "LEGENDARY", "A" -> MaterialTier.LENDARIO
            "MITICO", "MYTHIC", "S" -> MaterialTier.MITICO
            "DIVINO", "DIVINE", "SS" -> MaterialTier.DIVINO
            "ANCESTRAL", "SSS" -> MaterialTier.ANCESTRAL
            "WORLD", "MUNDIAL", "MUNDO" -> MaterialTier.MUNDIAL
            else -> MaterialTier.COMUM
        }
    }

    private fun isMaterial(item: InventoryItem): Boolean =
        item.type.contains("material", true) || item.materialOrigin.isNotBlank() || item.sourceCreatureId.isNotBlank()

    fun suggestions(inventory: PlayerInventory, pointId: String, query: String = ""): List<BlacksmithOption> {
        val city = city(pointId)
        if (!city.availableHere) return emptyList()
        val text = query.lowercase()
        val materials = inventory.items.filter { isMaterial(it) && it.quantity > 0 }
            .sortedWith(compareByDescending<InventoryItem> { text.contains(it.name.lowercase()) }
                .thenByDescending { tier(it).power })
        if (materials.isEmpty()) return emptyList()

        val templates = listOf(
            Triple("espada", EquipmentType.WEAPON, listOf("espada", "arma", "lâmina", "lamina")),
            Triple("armadura", EquipmentType.ARMOR, listOf("armadura", "peitoral", "proteção", "protecao")),
            Triple("escudo", EquipmentType.SHIELD, listOf("escudo", "defesa", "bloqueio")),
            Triple("elmo", EquipmentType.HELMET, listOf("elmo", "capacete", "cabeça", "cabeca")),
            Triple("botas", EquipmentType.BOOTS, listOf("bota", "botas", "pé", "pe")),
            Triple("luvas", EquipmentType.GLOVES, listOf("luva", "luvas", "mão", "mao")),
            Triple("anel", EquipmentType.RING, listOf("anel", "acessório", "acessorio")),
            Triple("colar", EquipmentType.NECKLACE, listOf("colar", "amuleto", "pescoço", "pescoco"))
        )
        val selectedTemplates = if (text.isBlank() || text.contains("consigo") || text.contains("itens") || text.contains("fazer")) templates
            else templates.filter { t -> t.third.any { keyword -> text.contains(keyword) } }
        val options = mutableListOf<BlacksmithOption>()

        selectedTemplates.forEach { (label, type, _) ->
            materials.forEachIndexed { _, primary ->
                val secondary = materials.firstOrNull { it.id != primary.id }
                val requirements = linkedMapOf(primary.id to 2)
                if (secondary != null) requirements[secondary.id] = 1
                if (requirements.any { (id, amount) -> materials.first { it.id == id }.quantity < amount }) return@forEachIndexed

                val primaryTier = tier(primary)
                val secondaryTier = secondary?.let(::tier) ?: primaryTier
                val strongest = if (primaryTier.power >= secondaryTier.power) primaryTier else secondaryTier
                val traits = (primary.materialTraits + (secondary?.materialTraits ?: emptyList())).toSet()
                val cityBonus = if (city.preferredTrait in traits) 1.15 else 1.0
                val power = ((primaryTier.power * 2 + secondaryTier.power) * cityBonus).toInt().coerceAtLeast(1)
                val prefix = when {
                    "DRACONICO" in traits -> "Dracônica"
                    "PREDADOR" in traits -> "Predadora"
                    "NATUREZA" in traits -> "Silvestre"
                    "FOGO" in traits -> "Ígnea"
                    "GELO" in traits -> "Glacial"
                    "VENENO" in traits -> "Peçonhenta"
                    "ESPIRITUAL" in traits -> "Espiritual"
                    "MINERAL" in traits -> "Rocheda"
                    else -> "Forjada"
                }
                val materialNames = listOfNotNull(primary.name, secondary?.name).distinct()
                val displayType = when (type) {
                    EquipmentType.WEAPON -> "Espada"
                    EquipmentType.ARMOR -> "Armadura"
                    EquipmentType.SHIELD -> "Escudo"
                    EquipmentType.HELMET -> "Elmo"
                    EquipmentType.BOOTS -> "Botas"
                    EquipmentType.GLOVES -> "Luvas"
                    EquipmentType.RING -> "Anel"
                    EquipmentType.NECKLACE -> "Colar"
                }
                val name = "$displayType $prefix de ${materialNames.joinToString(" e ")}"
                val rarity = when (strongest) {
                    MaterialTier.COMUM -> EquipmentRarity.COMMON
                    MaterialTier.INCOMUM -> EquipmentRarity.UNCOMMON
                    MaterialTier.RARO -> EquipmentRarity.RARE
                    MaterialTier.EPICO -> EquipmentRarity.EPIC
                    MaterialTier.LENDARIO -> EquipmentRarity.LEGENDARY
                    else -> EquipmentRarity.MYTHIC
                }
                val attributes = attributesFor(type, power, traits)
                val cost = ((primaryTier.cost * 2 + secondaryTier.cost) * (1.0 + power * 0.12)).toLong().coerceAtLeast(10L)
                val rank = strongest.rank
                val equipment = Equipment(
                    id = UUID.randomUUID().toString(), name = name,
                    description = "Forjado em ${city.cityName} por ${city.blacksmithName}. ${city.blacksmithName} preservou as propriedades de ${materialNames.joinToString(" e ")}.",
                    type = type, rarity = rarity, rank = rank,
                    levelRequired = (strongest.power * 3).coerceAtLeast(1),
                    attributes = attributes,
                    specialEffect = effectFor(traits),
                    sourceMonsterId = primary.sourceCreatureId.ifBlank { secondary?.sourceCreatureId.orEmpty() },
                    craftingMaterials = materialNames,
                    materialTraits = traits.toList()
                )
                options.add(BlacksmithOption("${label}_${primary.id}_${secondary?.id ?: "solo"}", equipment, requirements, cost,
                    "${materialNames.joinToString(" + ")} preservam ${traits.joinToString(", ").ifBlank { "as propriedades naturais" }}."))
            }
        }
        return options.distinctBy { it.equipment.type to it.equipment.craftingMaterials }.take(12)
    }

    fun craft(inventory: PlayerInventory, option: BlacksmithOption): PlayerInventory? {
        if (inventory.gold < option.goldCost) return null
        val remaining = inventory.items.toMutableList()
        option.materialsRequired.forEach { (id, amount) ->
            val index = remaining.indexOfFirst { it.id == id }
            if (index < 0 || remaining[index].quantity < amount) return null
            val item = remaining[index]
            if (item.quantity == amount) remaining.removeAt(index)
            else remaining[index] = item.copy(quantity = item.quantity - amount)
        }
        return inventory.copy(
            items = remaining,
            equipment = inventory.equipment + option.equipment,
            gold = inventory.gold - option.goldCost
        )
    }

    private fun attributesFor(type: EquipmentType, power: Int, traits: Set<String>): EquipmentAttributes {
        val physical = if ("PREDADOR" in traits || "DRACONICO" in traits || "FOGO" in traits) power * 2 else power
        val magic = if ("ESPIRITUAL" in traits || "NATUREZA" in traits || "FOGO" in traits) power * 2 else 0
        val defense = if ("MINERAL" in traits || "GELO" in traits || type == EquipmentType.ARMOR || type == EquipmentType.SHIELD) power * 2 else power / 2
        return when (type) {
            EquipmentType.WEAPON -> EquipmentAttributes(strength = if (physical > 0) power else 0, agility = if ("PREDADOR" in traits) power / 2 else 0, physicalDamage = physical, magicalDamage = magic, spirit = if (magic > 0) power / 2 else 0)
            EquipmentType.ARMOR, EquipmentType.SHIELD, EquipmentType.HELMET -> EquipmentAttributes(vitality = power, defense = defense, spirit = if ("ESPIRITUAL" in traits) power / 2 else 0)
            EquipmentType.BOOTS, EquipmentType.GLOVES -> EquipmentAttributes(agility = power, defense = defense, vitality = if ("NATUREZA" in traits) power / 2 else 0)
            EquipmentType.RING, EquipmentType.NECKLACE -> EquipmentAttributes(intelligence = if (magic > 0) power else 0, spirit = power, magicalDamage = magic, physicalDamage = physical / 2)
        }
    }

    private fun effectFor(traits: Set<String>): String? = when {
        "PREDADOR" in traits -> "Instinto predador: favorece ataques físicos e agilidade."
        "NATUREZA" in traits -> "Vitalidade natural: favorece resistência e recuperação."
        "DRACONICO" in traits -> "Essência dracônica: reforça poder ofensivo."
        "FOGO" in traits -> "Brasa viva: amplia o dano físico e mágico."
        "GELO" in traits -> "Casca glacial: reforça defesa."
        "VENENO" in traits -> "Toxina residual: afinidade com efeitos venenosos."
        "ESPIRITUAL" in traits -> "Eco espiritual: favorece mana e magia."
        "MINERAL" in traits -> "Estrutura mineral: reforça proteção."
        else -> null
    }
}
