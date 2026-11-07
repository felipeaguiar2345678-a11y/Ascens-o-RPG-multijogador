
package br.com.ascensaodosoberano.companions

enum class EquipmentType {
    WEAPON,
    ARMOR,
    HELMET,
    BOOTS,
    GLOVES,
    RING,
    NECKLACE,
    SHIELD
}

enum class EquipmentRarity {
    COMMON,
    UNCOMMON,
    RARE,
    EPIC,
    LEGENDARY,
    MYTHIC
}

data class EquipmentAttributes(
    val strength: Int = 0,
    val intelligence: Int = 0,
    val agility: Int = 0,
    val vitality: Int = 0,
    val spirit: Int = 0,
    val physicalDamage: Int = 0,
    val magicalDamage: Int = 0,
    val defense: Int = 0
)

data class Equipment(
    val id: String,
    val name: String,
    val description: String,
    val type: EquipmentType,
    val rarity: EquipmentRarity,
    val rank: String,
    val levelRequired: Int = 1,
    val attributes: EquipmentAttributes = EquipmentAttributes(),
    val specialEffect: String? = null,
    val sourceMonsterId: String? = null,
    val imagemIconeCaminho: String = "",
    val imagemDetalhadaCaminho: String = "",
    val craftingMaterials: List<String> = emptyList(),
    val materialTraits: List<String> = emptyList()
)