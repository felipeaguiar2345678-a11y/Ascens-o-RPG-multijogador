package br.com.ascensaodosoberano.companions

data class MerchantOffer(
    val id: String,
    val item: InventoryItem,
    val price: Long
)

object MerchantSystem {
    fun offers(pointId: String): List<MerchantOffer> {
        val city = BlacksmithSystem.city(pointId)
        if (!city.availableHere) return emptyList()
        val base = listOf(
            Triple("fibra_resistente", "Fibra Resistente", "E"),
            Triple("fragmento_mineral", "Fragmento Mineral", "E"),
            Triple("presa_simples", "Presa Simples", "D")
        )
        return base.mapIndexed { index, (id, name, rank) ->
            val trait = when (index) {
                0 -> if (city.preferredTrait == "NATUREZA") "NATUREZA" else "BESTIAL"
                1 -> "MINERAL"
                else -> if (city.preferredTrait == "PREDADOR") "PREDADOR" else "BESTIAL"
            }
            val item = InventoryItem(
                id = "mercado_${city.pointId}_$id",
                name = name,
                description = "Material básico vendido no mercado de ${city.cityName}.",
                type = "MATERIAL",
                quantity = 1,
                materialRank = rank,
                materialOrigin = city.cityName,
                materialTraits = listOf(trait)
            )
            MerchantOffer(id, item, if (rank == "E") 35L else 90L)
        }
    }

    fun buy(inventory: PlayerInventory, pointId: String, offerId: String): PlayerInventory? {
        val offer = offers(pointId).firstOrNull { it.id == offerId } ?: return null
        if (offer.price <= 0L || inventory.gold < offer.price) return null
        val matchingItems = inventory.items.filter { it.id == offer.item.id }
        if (matchingItems.size > 1) return null
        val existing = matchingItems.singleOrNull()
        if (existing != null) {
            val sameIdentity = existing.name == offer.item.name &&
                existing.description == offer.item.description &&
                existing.type == offer.item.type &&
                existing.imagemIconeCaminho == offer.item.imagemIconeCaminho &&
                existing.imagemDetalhadaCaminho == offer.item.imagemDetalhadaCaminho &&
                existing.materialRank == offer.item.materialRank &&
                existing.materialOrigin == offer.item.materialOrigin &&
                existing.materialTraits == offer.item.materialTraits &&
                existing.sourceCreatureId == offer.item.sourceCreatureId
            if (!sameIdentity || existing.quantity <= 0 || existing.quantity == Int.MAX_VALUE) return null
        }
        val updatedItems = if (existing == null) inventory.items + offer.item
        else inventory.items.map { if (it.id == offer.item.id) it.copy(quantity = it.quantity + 1) else it }
        return inventory.copy(items = updatedItems, gold = inventory.gold - offer.price)
    }

    fun sellPrice(item: InventoryItem): Long {
        if (!item.type.equals("MATERIAL", ignoreCase = true) || item.quantity <= 0) return 0L
        val rank = item.materialRank.trim().uppercase()
            .replace('Í', 'I')
            .replace('É', 'E')
        return when (rank) {
            "E", "COMUM", "COMMON" -> 5L
            "D", "INCOMUM", "UNCOMMON" -> 12L
            "C", "RARO", "RARE" -> 28L
            "B", "EPICO", "EPIC" -> 65L
            "A", "LENDARIO", "LEGENDARY" -> 150L
            "S", "MITICO", "MYTHIC" -> 350L
            "SS", "DIVINO", "DIVINE" -> 800L
            "SSS", "ANCESTRAL" -> 2_000L
            "WORLD", "MUNDIAL", "MUNDO" -> 8_000L
            else -> 0L
        }
    }

    fun sellOne(inventory: PlayerInventory, itemId: String): PlayerInventory? {
        val matchingItems = inventory.items.filter { it.id == itemId }
        if (matchingItems.size != 1) return null
        val item = matchingItems.single()
        val price = sellPrice(item)
        if (price <= 0L || item.quantity <= 0 || inventory.gold > Long.MAX_VALUE - price) return null
        val items = if (item.quantity == 1) inventory.items.filterNot { it.id == itemId }
        else inventory.items.map { if (it.id == itemId) it.copy(quantity = it.quantity - 1) else it }
        return inventory.copy(items = items, gold = inventory.gold + price)
    }
}
