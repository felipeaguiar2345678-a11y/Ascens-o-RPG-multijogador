package br.com.ascensaodosoberano.character

import org.junit.Assert.assertEquals
import org.junit.Test

class BattleRewardMergePolicyTest {
    private fun profile(level: Int = 1, xp: Int = 0, points: Int = 0) = CharacterProfile(
        name = "Herói",
        level = level,
        xp = xp,
        characterClass = CharacterClass(
            id = "guerreiro", name = "Guerreiro", description = "",
            affinities = SkillDomain.values().associateWith { Affinity.MEDIUM }
        ),
        attributePoints = points,
        id = "character-1"
    )

    private fun inventory(
        gold: Long,
        items: List<Map<String, Any?>> = emptyList(),
        eggs: List<Map<String, Any?>> = emptyList(),
        companions: List<Map<String, Any?>> = emptyList(),
        equipment: List<Map<String, Any?>> = emptyList()
    ) = mapOf(
        "gold" to gold, "items" to items, "eggs" to eggs,
        "companions" to companions, "equipment" to equipment
    )

    @Test
    fun recompensaAplicaDeltasSemRestaurarItensGastosNemApagarAtualizacoesRemotas() {
        val base = profile(level = 2, xp = 20, points = 5)
        val updated = base.copy(level = 2, xp = 120, attributePoints = 10)
        val baseInventory = inventory(
            100,
            items = listOf(
                mapOf("id" to "pedra", "name" to "Pedra", "description" to "", "type" to "MATERIAL", "quantity" to 3),
                mapOf("id" to "madeira", "name" to "Madeira", "description" to "", "type" to "MATERIAL", "quantity" to 2)
            )
        )
        val updatedInventory = inventory(
            150,
            items = listOf(
                mapOf("id" to "pedra", "name" to "Pedra", "description" to "", "type" to "MATERIAL", "quantity" to 5),
                mapOf("id" to "madeira", "name" to "Madeira", "description" to "", "type" to "MATERIAL", "quantity" to 0)
            ),
            eggs = listOf(mapOf("id" to "ovo-novo", "quantity" to 1)),
            equipment = listOf(mapOf("id" to "espada-premio"))
        )
        val remoteInventory = inventory(
            500,
            items = listOf(mapOf("id" to "pedra", "name" to "Pedra", "description" to "", "type" to "MATERIAL", "quantity" to 4)),
            equipment = listOf(mapOf("id" to "armadura-remota"))
        )
        val remote = mapOf<String, Any?>(
            "level" to 4, "xp" to 50, "attributePoints" to 20,
            "inventory" to remoteInventory,
            "guildRank" to "B", "powerProfile" to mapOf("powers" to listOf("poder-remoto"))
        )
        val result = BattleRewardMergePolicy.merge(
            base, updated, remote,
            mapOf("inventory" to baseInventory),
            mapOf("inventory" to updatedInventory),
            equipmentRewardIds = listOf("espada-premio"),
            battleId = "battle-1"
        )
        assertEquals(4, result["level"])
        assertEquals(150, result["xp"])
        assertEquals(25, result["attributePoints"])
        assertEquals("B", result["guildRank"])
        assertEquals(listOf("poder-remoto"), (result["powerProfile"] as Map<*, *>)["powers"])
        val mergedInventory = result["inventory"] as Map<*, *>
        assertEquals(550L, mergedInventory["gold"])
        val items = mergedInventory["items"] as List<*>
        assertEquals(6, (items.single() as Map<*, *>)["quantity"])
        val equipment = mergedInventory["equipment"] as List<*>
        assertEquals(setOf("armadura-remota", "espada-premio"), equipment.map { (it as Map<*, *>)["id"] }.toSet())
        assertEquals(listOf("ovo-novo"), (mergedInventory["eggs"] as List<*>).map { (it as Map<*, *>)["id"] })
    }

    @Test
    fun xpDoCompanheiroEhSomadoAoEstadoRemotoSemReativarColecaoAntiga() {
        val base = profile()
        val companionBase = mapOf(
            "id" to "pet-1", "name" to "Lobo", "species" to "Lobo", "rank" to "E",
            "level" to 1, "xp" to 10, "stage" to "FILHOTE",
            "maxHp" to 20, "hp" to 20, "attack" to 5, "defense" to 2,
            "agility" to 3, "magicPower" to 0, "originalMaxHp" to 100,
            "originalAttack" to 25, "originalDefense" to 10, "originalAgility" to 15,
            "originalMagicPower" to 0, "imageKey" to "lobo", "isActive" to true
        )
        val companionUpdated = companionBase.toMutableMap().apply { this["xp"] = 60 }
        val remoteCompanion = companionBase.toMutableMap().apply {
            this["level"] = 2
            this["xp"] = 20
            this["isActive"] = false
        }
        val baseInventory = inventory(0, companions = listOf(companionBase))
        val updatedInventory = inventory(0, companions = listOf(companionUpdated))
        val remoteInventory = inventory(0, companions = listOf(remoteCompanion))
        val result = BattleRewardMergePolicy.merge(
            base, base, mapOf("inventory" to remoteInventory),
            mapOf("inventory" to baseInventory),
            mapOf("inventory" to updatedInventory),
            emptyList()
        )
        val merged = ((result["inventory"] as Map<*, *>)["companions"] as List<*>).single() as Map<*, *>
        assertEquals(2, merged["level"])
        assertEquals(70, merged["xp"])
        assertEquals(false, merged["isActive"])
    }
    @Test
    fun penalidadeDeDerrotaAplicaSomentePerdaDaBatalhaSobreOuroEExperienciaRemotos() {
        val base = profile(level = 6, xp = 10)
        val updated = profile(level = 4, xp = 155)
        val baseInventory = inventory(500)
        val updatedInventory = inventory(400)
        val remote = mapOf<String, Any?>(
            "level" to 6, "xp" to 10, "attributePoints" to 30,
            "inventory" to inventory(1_000)
        )
        val result = BattleRewardMergePolicy.merge(
            base, updated, remote,
            mapOf("inventory" to baseInventory),
            mapOf("inventory" to updatedInventory),
            emptyList()
        )
        assertEquals(4, result["level"])
        assertEquals(155, result["xp"])
        assertEquals(900L, (result["inventory"] as Map<*, *>)["gold"])
        assertEquals(30, result["attributePoints"])
    }
}
