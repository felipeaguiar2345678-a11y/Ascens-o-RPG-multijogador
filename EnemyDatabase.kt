
package br.com.ascensaodosoberano.combat

data class Enemy(
    val id: String,
    val name: String,
    val rank: String,
    val maxHp: Int,
    val attack: Int,
    val defense: Int,
    val xpReward: Int,
    val imageKey: String,
    val description: String,
    val isBoss: Boolean = false,
    val ecosystemId: String = "unknown",
    val rarity: String = "common",
    val globalId: String = id
)

object EnemyDatabase {

    // Catálogo inicialmente vazio.
    // As criaturas serão registradas dinamicamente.
    private val enemies = mutableListOf<Enemy>()

    private val validRanks = setOf(
        "E", "D", "C", "B", "A", "S", "SS", "SSS"
    )

    private val validRarities = setOf(
        "common",
        "uncommon",
        "rare",
        "epic",
        "legendary",
        "mythic",
        "world"
    )

    fun getAll(): List<Enemy> {
        return enemies.toList()
    }

    fun getById(id: String): Enemy? {
        return enemies.find { it.id == id }
    }

    fun getByRank(rank: String): List<Enemy> {
        return enemies.filter {
            it.rank.equals(rank, ignoreCase = true)
        }
    }

    fun getByEcosystem(ecosystemId: String): List<Enemy> {
        return enemies.filter {
            it.ecosystemId.equals(ecosystemId, ignoreCase = true)
        }
    }

    fun getBosses(): List<Enemy> {
        return enemies.filter { it.isBoss }
    }

    fun getBossesByEcosystem(ecosystemId: String): List<Enemy> {
        return enemies.filter {
            it.isBoss &&
            it.ecosystemId.equals(ecosystemId, ignoreCase = true)
        }
    }

    fun registerEnemy(enemy: Enemy): Boolean {

        if (
            enemy.id.isBlank() ||
            enemy.globalId.isBlank() ||
            enemy.name.isBlank() ||
            enemy.rank.uppercase() !in validRanks ||
            enemy.maxHp <= 0 ||
            enemy.attack < 0 ||
            enemy.defense < 0 ||
            enemy.xpReward < 0 ||
            enemy.ecosystemId.isBlank() ||
            enemy.rarity.lowercase() !in validRarities
        ) {
            return false
        }

        val alreadyExists = enemies.any {
            it.id.equals(enemy.id, ignoreCase = true) ||
            it.globalId.equals(enemy.globalId, ignoreCase = true)
        }

        if (alreadyExists) {
            return false
        }

        enemies.add(enemy)

        return true
    }

    fun removeEnemy(id: String): Boolean {
        return enemies.removeAll {
            it.id.equals(id, ignoreCase = true)
        }
    }

    fun clearAll() {
        enemies.clear()
    }
}
