package br.com.ascensaodosoberano.companions

import org.junit.Assert.*
import org.junit.Test

class MerchantSystemTest {
    private fun material(id: String, rank: String = "E", quantity: Int = 2) = InventoryItem(
        id = id, name = "Material $id", description = "Teste", type = "MATERIAL",
        quantity = quantity, materialRank = rank, materialOrigin = "Floresta Arcana"
    )

    @Test fun mercadoSoExisteEmPovoados() {
        assertTrue(MerchantSystem.offers("aurelia").isNotEmpty())
        assertTrue(MerchantSystem.offers("clareira_inicial").isEmpty())
    }

    @Test fun compraDescontaOuroEAdicionaMaterial() {
        val inventory = PlayerInventory(gold = 100L)
        val offer = MerchantSystem.offers("aurelia").first()
        val result = MerchantSystem.buy(inventory, "aurelia", offer.id)
        assertNotNull(result)
        assertEquals(100L - offer.price, result!!.gold)
        assertEquals(1, result.items.single().quantity)
        assertTrue(inventory.items.isEmpty())
    }

    @Test fun compraNaoAumentaPilhaAdulterada() {
        val offer = MerchantSystem.offers("aurelia").first()
        val forged = offer.item.copy(name = "Material falso", quantity = 1)
        val inventory = PlayerInventory(items = listOf(forged), gold = 1000L)
        assertNull(MerchantSystem.buy(inventory, "aurelia", offer.id))
        assertEquals(1000L, inventory.gold)
        assertEquals("Material falso", inventory.items.single().name)
    }

    @Test fun compraRejeitaPilhaComQuantidadeNoLimite() {
        val offer = MerchantSystem.offers("aurelia").first()
        val fullStack = offer.item.copy(quantity = Int.MAX_VALUE)
        val inventory = PlayerInventory(items = listOf(fullStack), gold = 1000L)
        assertNull(MerchantSystem.buy(inventory, "aurelia", offer.id))
    }

    @Test fun compraNaoAconteceSemOuro() {
        val offer = MerchantSystem.offers("aurelia").first()
        assertNull(MerchantSystem.buy(PlayerInventory(gold = 0L), "aurelia", offer.id))
    }

    @Test fun naoAceitaOfertaDeOutraCidadeOuInventada() {
        val offer = MerchantSystem.offers("aurelia").first()
        assertNull(MerchantSystem.buy(PlayerInventory(gold = 1000L), "clareira_inicial", offer.id))
        assertNull(MerchantSystem.buy(PlayerInventory(gold = 1000L), "aurelia", "oferta_falsa"))
    }

    @Test fun vendaRemoveUmaUnidadeEAdicionaOuro() {
        val inventory = PlayerInventory(items = listOf(material("couro", quantity = 2)), gold = 10L)
        val result = MerchantSystem.sellOne(inventory, "couro")
        assertNotNull(result)
        assertEquals(1, result!!.items.single().quantity)
        assertEquals(15L, result.gold)
        assertEquals(2, inventory.items.single().quantity)
    }

    @Test fun vendaDaUltimaUnidadeRemoveItem() {
        val inventory = PlayerInventory(items = listOf(material("couro", quantity = 1)))
        val result = MerchantSystem.sellOne(inventory, "couro")
        assertNotNull(result)
        assertTrue(result!!.items.isEmpty())
        assertEquals(5L, result.gold)
    }

    @Test fun naoPermiteVenderEquipamentoOuItemInvalido() {
        val equipment = InventoryItem("arma", "Espada", "", "EQUIPMENT", 1)
        assertEquals(0L, MerchantSystem.sellPrice(equipment))
        assertNull(MerchantSystem.sellOne(PlayerInventory(items = listOf(equipment)), "arma"))
    }

    @Test fun itemComOrigemDeMaterialMasTipoDiferenteNaoPodeSerVendido() {
        val forged = InventoryItem(
            id = "equipamento",
            name = "Armadura",
            description = "Equipamento",
            type = "EQUIPMENT",
            quantity = 1,
            materialRank = "SSS",
            materialOrigin = "Floresta Arcana"
        )
        assertEquals(0L, MerchantSystem.sellPrice(forged))
        assertNull(MerchantSystem.sellOne(PlayerInventory(items = listOf(forged)), "equipamento"))
    }

    @Test fun materiaisDeRankAltoValemMais() {
        assertTrue(MerchantSystem.sellPrice(material("world", "WORLD")) > MerchantSystem.sellPrice(material("comum", "E")))
    }
}
