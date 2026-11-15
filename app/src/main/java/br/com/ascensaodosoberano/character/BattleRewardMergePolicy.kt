package br.com.ascensaodosoberano.character

/**
 * Mescla somente as mudanças produzidas durante uma batalha sobre o documento
 * remoto mais recente. Campos que não fazem parte do resultado da batalha
 * permanecem no servidor, evitando restaurar snapshots antigos.
 */
internal object BattleRewardMergePolicy {
    private fun stringMap(value: Any?): MutableMap<String, Any?> =
        (value as? Map<*, *>)?.entries
            ?.mapNotNull { (key, item) -> (key as? String)?.let { it to item } }
            ?.toMap()?.toMutableMap() ?: mutableMapOf()

    private fun list(value: Any?): List<Any?> = value as? List<Any?> ?: emptyList()

    private fun id(item: Any?): String =
        (item as? Map<*, *>)?.get("id")?.toString().orEmpty()

    private fun quantity(item: Any?): Long =
        ((item as? Map<*, *>)?.get("quantity") as? Number)?.toLong() ?: 0L

    private fun totalPlayerXp(level: Int, xp: Int): Long {
        val safeLevel = level.coerceIn(1, 100_000)
        var total = xp.coerceAtLeast(0).toLong()
        for (current in 1 until safeLevel) total += current.toLong() * 100L
        return total
    }

    private fun levelAndXp(total: Long): Pair<Int, Int> {
        var remaining = total.coerceAtLeast(0L)
        var level = 1
        while (level < 100_000) {
            val required = level.toLong() * 100L
            if (remaining < required) break
            remaining -= required
            level++
        }
        return level to remaining.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
    }

    private fun addSafely(current: Long, delta: Long): Long =
        (current + delta).coerceAtLeast(0L)

    private fun mergeItems(base: List<Any?>, updated: List<Any?>, remote: List<Any?>): List<Any?> {
        val result = remote.toMutableList()
        val baseById = base.filter { id(it).isNotBlank() }.associateBy(::id)
        val remoteCounts = remote.map(::id).filter(String::isNotBlank).groupingBy { it }.eachCount()
        updated.forEach { earned ->
            val earnedId = id(earned)
            if (earnedId.isBlank()) return@forEach
            val old = baseById[earnedId]
            val delta = quantity(earned) - quantity(old)
            if (delta <= 0L) return@forEach
            val matches = result.withIndex().filter { id(it.value) == earnedId }
            if (matches.size > 1) return@forEach
            if (matches.size == 1) {
                val index = matches.single().index
                val remoteItem = stringMap(result[index])
                val identityKeys = listOf("name", "description", "type", "materialRank", "materialOrigin", "sourceCreatureId")
                val sameIdentity = identityKeys.all { key ->
                    (remoteItem[key]?.toString().orEmpty()) ==
                        ((earned as? Map<*, *>)?.get(key)?.toString().orEmpty())
                }
                if (sameIdentity) {
                    remoteItem["quantity"] = addSafely(quantity(result[index]), delta)
                        .coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
                    result[index] = remoteItem
                }
            } else if (old == null && remoteCounts[earnedId] == null) {
                val copy = stringMap(earned)
                copy["quantity"] = delta.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
                result.add(copy)
            }
        }
        return result
    }

    private fun mergeUniqueNewItems(base: List<Any?>, updated: List<Any?>, remote: List<Any?>): List<Any?> {
        val baseIds = base.map(::id).filter(String::isNotBlank).toSet()
        val result = remote.toMutableList()
        val remoteIds = remote.map(::id).filter(String::isNotBlank).toMutableSet()
        updated.forEach { item ->
            val itemId = id(item)
            if (itemId.isNotBlank() && itemId !in baseIds && remoteIds.add(itemId)) {
                result.add(item)
            }
        }
        return result
    }

    private fun mergeInventory(
        baseRaw: Any?, updatedRaw: Any?, remoteRaw: Any?, equipmentRewardIds: Set<String>
    ): Map<String, Any?> {
        val base = stringMap(baseRaw)
        val updated = stringMap(updatedRaw)
        val remote = stringMap(remoteRaw)
        val merged = remote.toMutableMap()

        val baseGold = (base["gold"] as? Number)?.toLong() ?: 0L
        val updatedGold = (updated["gold"] as? Number)?.toLong() ?: baseGold
        val remoteGold = (remote["gold"] as? Number)?.toLong() ?: 0L
        merged["gold"] = addSafely(remoteGold, updatedGold - baseGold)

        merged["items"] = mergeItems(list(base["items"]), list(updated["items"]), list(remote["items"]))
        merged["eggs"] = mergeUniqueNewItems(list(base["eggs"]), list(updated["eggs"]), list(remote["eggs"]))

        val baseEquipmentIds = list(base["equipment"]).map(::id).filter(String::isNotBlank).toSet()
        val remoteEquipment = list(remote["equipment"]).toMutableList()
        val equipmentIds = remoteEquipment.map(::id).filter(String::isNotBlank).toMutableSet()
        list(updated["equipment"]).forEach { item ->
            val itemId = id(item)
            if (itemId.isNotBlank() && itemId in equipmentRewardIds &&
                itemId !in baseEquipmentIds && equipmentIds.add(itemId)
            ) remoteEquipment.add(item)
        }
        merged["equipment"] = remoteEquipment

        // A batalha só concede XP ao companheiro ativo; não substitui a coleção
        // remota, nem reativa ou ressuscita companheiros removidos durante a sessão.
        merged["companions"] = list(remote["companions"])
        return merged
    }

    fun merge(
        base: CharacterProfile,
        updated: CharacterProfile,
        remoteData: Map<String, Any?>,
        baseData: Map<String, Any?>,
        updatedData: Map<String, Any?>,
        equipmentRewardIds: List<String>,
        battleId: String? = null
    ): Map<String, Any?> {
        val result = remoteData.toMutableMap()

        val baseTotalXp = totalPlayerXp(base.level, base.xp)
        val updatedTotalXp = totalPlayerXp(updated.level, updated.xp)
        val remoteLevel = (remoteData["level"] as? Number)?.toInt() ?: base.level
        val remoteXp = (remoteData["xp"] as? Number)?.toInt() ?: base.xp
        val (mergedLevel, mergedXp) = levelAndXp(
            addSafely(totalPlayerXp(remoteLevel, remoteXp), updatedTotalXp - baseTotalXp)
        )
        result["level"] = mergedLevel
        result["xp"] = mergedXp

        val basePoints = base.attributePoints
        val pointDelta = updated.attributePoints - basePoints
        result["attributePoints"] = addSafely(
            (remoteData["attributePoints"] as? Number)?.toLong() ?: basePoints.toLong(),
            pointDelta.toLong()
        ).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()

        if (updated.currentHp != base.currentHp) result["currentHp"] = updated.currentHp.coerceAtLeast(0)
        if (updated.currentMana != base.currentMana) result["currentMana"] = updated.currentMana.coerceAtLeast(0)

        if (updated.currentWorldPointId != base.currentWorldPointId) {
            result["currentWorldPointId"] = updated.currentWorldPointId
        }
        if (updated.respawnPointId != base.respawnPointId) result["respawnPointId"] = updated.respawnPointId
        if (updated.worldX != base.worldX) result["worldX"] = updated.worldX
        if (updated.worldY != base.worldY) result["worldY"] = updated.worldY

        result["inventory"] = mergeInventory(
            baseData["inventory"], updatedData["inventory"], remoteData["inventory"],
            equipmentRewardIds.filter(String::isNotBlank).toSet()
        )
        if (battleId != null) {
            val ids = (remoteData["processedSoloBattleIds"] as? List<*>)
                .orEmpty().filterIsInstance<String>()
            result["processedSoloBattleIds"] = (ids + battleId).distinct().takeLast(100)
        }
        // Identidade, atributos gastos fora da batalha, poderes, classe, aparência,
        // treino defensivo, equipamentos vestidos e metadados ficam com o servidor.
        return result
    }
}
