
package br.com.ascensaodosoberano.character

import br.com.ascensaodosoberano.world.WorldApi

import br.com.ascensaodosoberano.companions.InventoryItem
import br.com.ascensaodosoberano.companions.PetEgg
import br.com.ascensaodosoberano.companions.Companion
import br.com.ascensaodosoberano.companions.PlayerInventory
import br.com.ascensaodosoberano.companions.Equipment
import br.com.ascensaodosoberano.companions.EquipmentType
import br.com.ascensaodosoberano.companions.EquipmentRarity
import br.com.ascensaodosoberano.companions.EquipmentAttributes
import br.com.ascensaodosoberano.companions.EquipmentLoadout
import br.com.ascensaodosoberano.powers.PowerStatus
import br.com.ascensaodosoberano.powers.PowerOrigin
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await

class CharacterProfileRepository(
    private val db: FirebaseFirestore =
        FirebaseFirestore.getInstance()
) {

    suspend fun save(profile: CharacterProfile) {
        val ownerUid = FirebaseAuth.getInstance()
            .currentUser?.uid
            ?: throw IllegalStateException(
                "Usuário precisa estar autenticado."
            )

        val data = profileData(profile, ownerUid)

        db.collection("characters")
            .document(profile.id)
            .set(data)
            .await()
    }

    suspend fun saveWorldPosition(
        profileId: String,
        x: Float,
        y: Float,
        worldPointId: String = "clareira_inicial"
    ) {
        require(profileId.isNotBlank()) { "Perfil inválido." }
        require(x.isFinite() && y.isFinite()) { "Posição do mundo inválida." }
        WorldApi.salvarPosicaoPersonagem(profileId, x, y, worldPointId)
    }

    suspend fun getForCurrentUser(): CharacterProfile? {

        val uid = FirebaseAuth.getInstance()
            .currentUser?.uid
            ?: return null

        val result = db.collection("characters")
            .whereEqualTo("ownerUid", uid)
            .limit(1)
            .get()
            .await()

        val doc = result.documents.firstOrNull()
            ?: return null

        val classData =
            doc.get("characterClass") as? Map<*, *>
                ?: emptyMap<Any, Any>()

        val attributesData =
            doc.get("attributes") as? Map<*, *>
                ?: emptyMap<Any, Any>()

        val appearanceData =
            doc.get("appearance") as? Map<*, *>
                ?: emptyMap<Any, Any>()

        val powerProfileData =
            doc.get("powerProfile") as? Map<*, *>
                ?: emptyMap<Any, Any>()

        val affinitiesData =
            classData["affinities"] as? Map<*, *>
                ?: emptyMap<Any, Any>()

        // Afinidades da classe
        val affinities = affinitiesData.mapNotNull { (key, value) ->

            val domain = runCatching {
                SkillDomain.valueOf(key.toString())
            }.getOrNull()

            val affinity = runCatching {
                Affinity.valueOf(value.toString())
            }.getOrNull()

            if (domain != null && affinity != null) {
                domain to affinity
            } else {
                null
            }
        }.toMap()

        val characterClass = CharacterClass(
            id = classData["id"]?.toString() ?: "desconhecida",
            name = classData["name"]?.toString() ?: "Aventureiro",
            description = classData["description"]?.toString() ?: "",
            isCustom = classData["isCustom"] as? Boolean ?: false,
            affinities = affinities
        )

        // Atributos
        val attributes = CharacterAttributes(
            strength = (attributesData["strength"] as? Number)?.toInt() ?: 5,
            intelligence = (attributesData["intelligence"] as? Number)?.toInt() ?: 5,
            agility = (attributesData["agility"] as? Number)?.toInt() ?: 5,
            vitality = (attributesData["vitality"] as? Number)?.toInt() ?: 5,
            spirit = (attributesData["spirit"] as? Number)?.toInt() ?: 5
        )

        // Aparência
        val appearance = CharacterAppearance(
            skinId = appearanceData["skinId"]?.toString() ?: "pele_01",
            faceId = appearanceData["faceId"]?.toString() ?: "rosto_01",
            hairId = appearanceData["hairId"]?.toString() ?: "cabelo_01",
            hairColorId = appearanceData["hairColorId"]?.toString() ?: "castanho",
            eyeId = appearanceData["eyeId"]?.toString() ?: "olhos_01",
            outfitId = appearanceData["outfitId"]?.toString() ?: "roupa_inicial_01",
            generatedImagePath = appearanceData["generatedImagePath"]?.toString() ?: "",
            generatedImageUrl = appearanceData["generatedImageUrl"]?.toString() ?: "",
            generationId = appearanceData["generationId"]?.toString() ?: "",
            visualVersion = (appearanceData["visualVersion"] as? Number)?.toInt() ?: 1,
            idleSpritePath = appearanceData["idleSpritePath"]?.toString() ?: "",
            walkingSpritesPath = appearanceData["walkingSpritesPath"]?.toString() ?: "",
            directionalSpritesPath = appearanceData["directionalSpritesPath"]?.toString() ?: ""
        )

        // Desejos de poderes
        val desires = (powerProfileData["desires"] as? List<*>)
            .orEmpty()
            .mapNotNull { item ->

                val map = item as? Map<*, *>
                    ?: return@mapNotNull null

                val type = runCatching {
                    br.com.ascensaodosoberano.powers.PowerType.valueOf(
                        map["desiredType"].toString()
                    )
                }.getOrNull() ?: return@mapNotNull null

                br.com.ascensaodosoberano.powers.PowerDesire(
                    id = map["id"]?.toString()
                        ?: return@mapNotNull null,
                    name = map["name"]?.toString() ?: "",
                    description = map["description"]?.toString() ?: "",
                    desiredType = type,
                    progress = (map["progress"] as? Number)?.toInt() ?: 0,
                    createdAt = (map["createdAt"] as? Number)?.toLong()
                        ?: System.currentTimeMillis()
                )
            }

        // Poderes despertados
        val powers = (powerProfileData["powers"] as? List<*>)
            .orEmpty()
            .mapNotNull { item ->

                val map = item as? Map<*, *>
                    ?: return@mapNotNull null

                val type = runCatching {
                    br.com.ascensaodosoberano.powers.PowerType.valueOf(
                        map["type"].toString()
                    )
                }.getOrNull() ?: return@mapNotNull null

                val origin = runCatching {
                    PowerOrigin.valueOf(map["origin"].toString())
                }.getOrNull() ?: return@mapNotNull null

                val status = runCatching {
                    PowerStatus.valueOf(map["status"].toString())
                }.getOrDefault(PowerStatus.AWAKENED)

                br.com.ascensaodosoberano.powers.AwakenedPower(
                    id = map["id"]?.toString()
                        ?: return@mapNotNull null,
                    name = map["name"]?.toString() ?: "",
                    description = map["description"]?.toString() ?: "",
                    type = type,
                    origin = origin,
                    status = status,
                    level = (map["level"] as? Number)?.toInt() ?: 1,
                    experience = (map["experience"] as? Number)?.toInt() ?: 0,
                    manaCost = (map["manaCost"] as? Number)?.toInt() ?: 0,
                    baseDamage = (map["baseDamage"] as? Number)?.toInt() ?: 0,
                    cooldown = (map["cooldown"] as? Number)?.toInt() ?: 0,
                    effects = (map["effects"] as? List<*>)
                        ?.map { it.toString() } ?: emptyList(),
                    limitations = (map["limitations"] as? List<*>)
                        ?.map { it.toString() } ?: emptyList()
                )
            }

        // Observações
        val observations = (powerProfileData["observations"] as? List<*>)
            .orEmpty()
            .mapNotNull { item ->

                val map = item as? Map<*, *>
                    ?: return@mapNotNull null

                br.com.ascensaodosoberano.powers.PowerObservation(
                    action = map["action"]?.toString() ?: "",
                    category = map["category"]?.toString() ?: "",
                    intensity = (map["intensity"] as? Number)?.toInt() ?: 0,
                    timestamp = (map["timestamp"] as? Number)?.toLong()
                        ?: System.currentTimeMillis(),
                    difficulty = (map["difficulty"] as? Number)?.toInt() ?: 1,
                    origin = map["origin"]?.toString()?.let {
                        runCatching {
                            PowerOrigin.valueOf(it)
                        }.getOrNull()
                    },
                    successful = map["successful"] as? Boolean ?: true,
                    tags = (map["tags"] as? List<*>)
                        ?.map { it.toString() } ?: emptyList()
                )
            }

        val powerProfile =
            br.com.ascensaodosoberano.powers.CharacterPowerProfile(
                desires = desires,
                powers = powers,
                observations = observations
            )

        // Inventário
        val inventoryData =
            doc.get("inventory") as? Map<*, *>
                ?: emptyMap<Any, Any>()

        // Itens
        val items = (inventoryData["items"] as? List<*>)
            .orEmpty()
            .mapNotNull { item ->

                val map = item as? Map<*, *>
                    ?: return@mapNotNull null

                InventoryItem(
                    id = map["id"]?.toString()
                        ?: return@mapNotNull null,
                    name = map["name"]?.toString() ?: "",
                    description = map["description"]?.toString() ?: "",
                    type = map["type"]?.toString() ?: "",
                    quantity = (map["quantity"] as? Number)?.toInt() ?: 1,
                    imagemIconeCaminho = map["imagemIconeCaminho"]?.toString() ?: "",
                    imagemDetalhadaCaminho = map["imagemDetalhadaCaminho"]?.toString() ?: "",
                    materialRank = map["materialRank"]?.toString() ?: "COMUM",
                    materialOrigin = map["materialOrigin"]?.toString() ?: "",
                    materialTraits = (map["materialTraits"] as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList(),
                    sourceCreatureId = map["sourceCreatureId"]?.toString() ?: ""
                )
            }

        // Ovos e mutações
        val eggs = (inventoryData["eggs"] as? List<*>)
            .orEmpty()
            .mapNotNull { item ->

                val map = item as? Map<*, *>
                    ?: return@mapNotNull null

                PetEgg(
                    id = map["id"]?.toString()
                        ?: return@mapNotNull null,
                    species = map["species"]?.toString() ?: "",
                    monsterId = map["monsterId"]?.toString() ?: "",
                    rank = map["rank"]?.toString() ?: "E",
                    imageKey = map["imageKey"]?.toString() ?: "",
                    hatchChance = (map["hatchChance"] as? Number)?.toInt() ?: 100,
                    quantity = (map["quantity"] as? Number)?.toInt() ?: 1,

                    imagemIconeCaminho =
                        map["imagemIconeCaminho"]?.toString() ?: "",
                    imagemDetalhadaCaminho =
                        map["imagemDetalhadaCaminho"]?.toString() ?: "",

                    mutationId = map["mutationId"]?.toString() ?: "NORMAL",
                    mutationName = map["mutationName"]?.toString() ?: "Normal",
                    mutationRarity = map["mutationRarity"]?.toString() ?: "COMUM",
                    mutationDescription =
                        map["mutationDescription"]?.toString() ?: "",

                    mutationHpPercent =
                        (map["mutationHpPercent"] as? Number)?.toInt() ?: 0,
                    mutationAttackPercent =
                        (map["mutationAttackPercent"] as? Number)?.toInt() ?: 0,
                    mutationDefensePercent =
                        (map["mutationDefensePercent"] as? Number)?.toInt() ?: 0,
                    mutationAgilityPercent =
                        (map["mutationAgilityPercent"] as? Number)?.toInt() ?: 0,
                    mutationMagicPercent =
                        (map["mutationMagicPercent"] as? Number)?.toInt() ?: 0
                )
            }

        // Companheiros
        val companions = (inventoryData["companions"] as? List<*>)
            .orEmpty()
            .mapNotNull { item ->

                val map = item as? Map<*, *>
                    ?: return@mapNotNull null

                Companion(
                    id = map["id"]?.toString()
                        ?: return@mapNotNull null,
                    name = map["name"]?.toString() ?: "",
                    species = map["species"]?.toString() ?: "",
                    rank = map["rank"]?.toString() ?: "E",

                    level = (map["level"] as? Number)?.toInt() ?: 1,
                    xp = (map["xp"] as? Number)?.toInt() ?: 0,
                    stage = map["stage"]?.toString() ?: "FILHOTE",

                    maxHp = (map["maxHp"] as? Number)?.toInt() ?: 100,
                    hp = (map["hp"] as? Number)?.toInt() ?: 100,
                    attack = (map["attack"] as? Number)?.toInt() ?: 10,
                    defense = (map["defense"] as? Number)?.toInt() ?: 5,
                    agility = (map["agility"] as? Number)?.toInt() ?: 5,
                    magicPower = (map["magicPower"] as? Number)?.toInt() ?: 0,

                    // Atributos originais
                    originalMonsterId =
                        map["originalMonsterId"]?.toString() ?: "",
                    originalMonsterRank =
                        map["originalMonsterRank"]?.toString()
                            ?: map["rank"]?.toString() ?: "E",
                    originalMaxHp =
                        (map["originalMaxHp"] as? Number)?.toInt()
                            ?: (map["maxHp"] as? Number)?.toInt() ?: 100,
                    originalAttack =
                        (map["originalAttack"] as? Number)?.toInt()
                            ?: (map["attack"] as? Number)?.toInt() ?: 10,
                    originalDefense =
                        (map["originalDefense"] as? Number)?.toInt()
                            ?: (map["defense"] as? Number)?.toInt() ?: 5,
                    originalAgility =
                        (map["originalAgility"] as? Number)?.toInt()
                            ?: (map["agility"] as? Number)?.toInt() ?: 5,
                    originalMagicPower =
                        (map["originalMagicPower"] as? Number)?.toInt()
                            ?: (map["magicPower"] as? Number)?.toInt() ?: 0,

                    // Mutação
                    mutationId = map["mutationId"]?.toString() ?: "NORMAL",
                    mutationName = map["mutationName"]?.toString() ?: "Normal",
                    mutationRarity = map["mutationRarity"]?.toString() ?: "COMUM",
                    mutationDescription =
                        map["mutationDescription"]?.toString() ?: "",

                    mutationHpPercent =
                        (map["mutationHpPercent"] as? Number)?.toInt() ?: 0,
                    mutationAttackPercent =
                        (map["mutationAttackPercent"] as? Number)?.toInt() ?: 0,
                    mutationDefensePercent =
                        (map["mutationDefensePercent"] as? Number)?.toInt() ?: 0,
                    mutationAgilityPercent =
                        (map["mutationAgilityPercent"] as? Number)?.toInt() ?: 0,
                    mutationMagicPercent =
                        (map["mutationMagicPercent"] as? Number)?.toInt() ?: 0,

                    imageKey = map["imageKey"]?.toString() ?: "",
                    isActive = map["isActive"] as? Boolean ?: false,

                    imagemIconeCaminho =
                        map["imagemIconeCaminho"]?.toString() ?: "",
                    imagemDetalhadaCaminho =
                        map["imagemDetalhadaCaminho"]?.toString() ?: "",
                    imagemSpriteCaminho =
                        map["imagemSpriteCaminho"]?.toString() ?: "",

                    filhoteImagemIconeCaminho =
                        map["filhoteImagemIconeCaminho"]?.toString() ?: "",
                    filhoteImagemDetalhadaCaminho =
                        map["filhoteImagemDetalhadaCaminho"]?.toString() ?: "",
                    filhoteImagemSpriteCaminho =
                        map["filhoteImagemSpriteCaminho"]?.toString() ?: "",

                    adolescenteImagemIconeCaminho =
                        map["adolescenteImagemIconeCaminho"]?.toString() ?: "",
                    adolescenteImagemDetalhadaCaminho =
                        map["adolescenteImagemDetalhadaCaminho"]?.toString() ?: "",
                    adolescenteImagemSpriteCaminho =
                        map["adolescenteImagemSpriteCaminho"]?.toString() ?: "",

                    adultoImagemIconeCaminho =
                        map["adultoImagemIconeCaminho"]?.toString() ?: "",
                    adultoImagemDetalhadaCaminho =
                        map["adultoImagemDetalhadaCaminho"]?.toString() ?: "",
                    adultoImagemSpriteCaminho =
                        map["adultoImagemSpriteCaminho"]?.toString() ?: ""
                )
            }

        // Equipamentos
        val equipment = (inventoryData["equipment"] as? List<*>)
            .orEmpty()
            .mapNotNull { item ->

                val map = item as? Map<*, *>
                    ?: return@mapNotNull null

                val type = runCatching {
                    EquipmentType.valueOf(map["type"].toString())
                }.getOrNull() ?: return@mapNotNull null

                val rarity = runCatching {
                    EquipmentRarity.valueOf(map["rarity"].toString())
                }.getOrNull() ?: return@mapNotNull null

                val equipmentAttributesData =
                    map["attributes"] as? Map<*, *>
                        ?: emptyMap<Any, Any>()

                Equipment(
                    id = map["id"]?.toString()
                        ?: return@mapNotNull null,
                    name = map["name"]?.toString() ?: "",
                    description = map["description"]?.toString() ?: "",
                    type = type,
                    rarity = rarity,
                    rank = map["rank"]?.toString() ?: "E",
                    levelRequired = (map["levelRequired"] as? Number)?.toInt() ?: 1,

                    attributes = EquipmentAttributes(
                        strength = (equipmentAttributesData["strength"] as? Number)?.toInt() ?: 0,
                        intelligence = (equipmentAttributesData["intelligence"] as? Number)?.toInt() ?: 0,
                        agility = (equipmentAttributesData["agility"] as? Number)?.toInt() ?: 0,
                        vitality = (equipmentAttributesData["vitality"] as? Number)?.toInt() ?: 0,
                        spirit = (equipmentAttributesData["spirit"] as? Number)?.toInt() ?: 0,
                        physicalDamage = (equipmentAttributesData["physicalDamage"] as? Number)?.toInt() ?: 0,
                        magicalDamage = (equipmentAttributesData["magicalDamage"] as? Number)?.toInt() ?: 0,
                        defense = (equipmentAttributesData["defense"] as? Number)?.toInt() ?: 0
                    ),

                    specialEffect = map["specialEffect"]?.toString(),
                    sourceMonsterId = map["sourceMonsterId"]?.toString(),
                    imagemIconeCaminho = map["imagemIconeCaminho"]?.toString() ?: "",
                    imagemDetalhadaCaminho = map["imagemDetalhadaCaminho"]?.toString() ?: "",
                    craftingMaterials = (map["craftingMaterials"] as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList(),
                    materialTraits = (map["materialTraits"] as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList()
                )
            }

        val inventory = PlayerInventory(
            items = items,
            eggs = eggs,
            companions = companions,
            equipment = equipment,
            gold = (inventoryData["gold"] as? Number)?.toLong() ?: 0L
        )

        val loadoutData = doc.get("equipmentLoadout") as? Map<*, *> ?: emptyMap<Any, Any>()
        val equipmentLoadout = EquipmentLoadout(
            weaponId = loadoutData["weaponId"]?.toString(),
            shieldId = loadoutData["shieldId"]?.toString(),
            armorId = loadoutData["armorId"]?.toString(),
            helmetId = loadoutData["helmetId"]?.toString(),
            bootsId = loadoutData["bootsId"]?.toString(),
            glovesId = loadoutData["glovesId"]?.toString(),
            ringId = loadoutData["ringId"]?.toString(),
            necklaceId = loadoutData["necklaceId"]?.toString()
        )

        // Perfil completo
        return CharacterProfile(
            id = doc.id,
            name = doc.getString("name") ?: "Aventureiro",
            hasSeenIntro = doc.getBoolean("hasSeenIntro") ?: false,
            powerProfile = powerProfile,

            currentWorldPointId =
                doc.getString("currentWorldPointId") ?: "clareira_inicial",

            respawnPointId =
                doc.getString("respawnPointId") ?: "clareira_inicial",

            worldX = (doc.getDouble("worldX") ?: 0.52).toFloat(),
            worldY = (doc.getDouble("worldY") ?: 0.78).toFloat(),

            level = (doc.getLong("level") ?: 1L).toInt(),
            xp = (doc.getLong("xp") ?: 0L).toInt(),

            characterClass = characterClass,
            attributes = attributes,
            attributePoints = (doc.getLong("attributePoints") ?: 0L).toInt(),
            appearance = appearance,
            inventory = inventory,
            equipmentLoadout = equipmentLoadout
        )
    }

    /**
     * Salva o progresso e confirma a recompensa Ally na mesma transação.
     * Se qualquer escrita falhar, nem o personagem nem a retirada são confirmados.
     */
    suspend fun saveAndClaimAllyBattleReward(
        profile: CharacterProfile,
        battleId: String,
        uid: String
    ): Boolean {
        val authenticatedUid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Usuário precisa estar autenticado.")
        require(authenticatedUid == uid) { "A conta autenticada não corresponde ao participante." }
        require(battleId.isNotBlank()) { "Batalha inválida." }
        require(profile.id.isNotBlank()) { "Personagem inválido." }

        val characterRef = db.collection("characters").document(profile.id)
        val battleRef = db.collection("allyBattles").document(battleId)
        val data = profileData(profile, uid)

        return db.runTransaction { tx ->
            val battle = tx.get(battleRef)
            require(battle.exists() && battle.getString("status") == "FINISHED") {
                "A batalha ainda não terminou."
            }
            val participants = (battle.get("participantUids") as? List<*>)
                ?.filterIsInstance<String>() ?: emptyList()
            require(uid in participants) { "Você não participou dessa batalha." }
            val claimed = (battle.get("claimedUids") as? List<*>)
                ?.filterIsInstance<String>() ?: emptyList()
            if (uid in claimed) {
                false
            } else {
                tx.set(characterRef, data)
                tx.update(battleRef, mapOf(
                    "claimedUids" to (claimed + uid),
                    "updatedAt" to com.google.firebase.firestore.FieldValue.serverTimestamp()
                ))
                true
            }
        }.await()
    }

    private fun profileData(profile: CharacterProfile, ownerUid: String): Map<String, Any?> =
        mapOf(

            "id" to profile.id,
            "ownerUid" to ownerUid,
            "name" to profile.name,
            "hasSeenIntro" to profile.hasSeenIntro,

            // Localização persistente no mundo
            "currentWorldPointId" to profile.currentWorldPointId,
            "respawnPointId" to profile.respawnPointId,
            "worldX" to profile.worldX,
            "worldY" to profile.worldY,

            "level" to profile.level,
            "xp" to profile.xp,
            "attributePoints" to profile.attributePoints,

            // Inventário
            "equipmentLoadout" to mapOf(
                "weaponId" to profile.equipmentLoadout.weaponId,
                "shieldId" to profile.equipmentLoadout.shieldId,
                "armorId" to profile.equipmentLoadout.armorId,
                "helmetId" to profile.equipmentLoadout.helmetId,
                "bootsId" to profile.equipmentLoadout.bootsId,
                "glovesId" to profile.equipmentLoadout.glovesId,
                "ringId" to profile.equipmentLoadout.ringId,
                "necklaceId" to profile.equipmentLoadout.necklaceId
            ),

            "inventory" to mapOf(

                // Itens
                "items" to profile.inventory.items.map { item ->
                    mapOf(
                        "id" to item.id,
                        "name" to item.name,
                        "description" to item.description,
                        "type" to item.type,
                        "quantity" to item.quantity,
                        "imagemIconeCaminho" to item.imagemIconeCaminho,
                        "imagemDetalhadaCaminho" to item.imagemDetalhadaCaminho,
                        "materialRank" to item.materialRank,
                        "materialOrigin" to item.materialOrigin,
                        "materialTraits" to item.materialTraits,
                        "sourceCreatureId" to item.sourceCreatureId
                    )
                },

                // Ovos e mutações
                "eggs" to profile.inventory.eggs.map { egg ->
                    mapOf(
                        "id" to egg.id,
                        "species" to egg.species,
                        "monsterId" to egg.monsterId,
                        "rank" to egg.rank,
                        "imageKey" to egg.imageKey,
                        "hatchChance" to egg.hatchChance,
                        "quantity" to egg.quantity,

                        "imagemIconeCaminho" to egg.imagemIconeCaminho,
                        "imagemDetalhadaCaminho" to egg.imagemDetalhadaCaminho,

                        "mutationId" to egg.mutationId,
                        "mutationName" to egg.mutationName,
                        "mutationRarity" to egg.mutationRarity,
                        "mutationDescription" to egg.mutationDescription,

                        "mutationHpPercent" to egg.mutationHpPercent,
                        "mutationAttackPercent" to egg.mutationAttackPercent,
                        "mutationDefensePercent" to egg.mutationDefensePercent,
                        "mutationAgilityPercent" to egg.mutationAgilityPercent,
                        "mutationMagicPercent" to egg.mutationMagicPercent
                    )
                },

                // Companheiros
                "companions" to profile.inventory.companions.map { companion ->
                    mapOf(
                        "id" to companion.id,
                        "name" to companion.name,
                        "species" to companion.species,
                        "rank" to companion.rank,

                        "level" to companion.level,
                        "xp" to companion.xp,
                        "stage" to companion.stage,

                        "maxHp" to companion.maxHp,
                        "hp" to companion.hp,
                        "attack" to companion.attack,
                        "defense" to companion.defense,
                        "agility" to companion.agility,
                        "magicPower" to companion.magicPower,

                        // Atributos originais do monstro
                        "originalMonsterId" to companion.originalMonsterId,
                        "originalMonsterRank" to companion.originalMonsterRank,
                        "originalMaxHp" to companion.originalMaxHp,
                        "originalAttack" to companion.originalAttack,
                        "originalDefense" to companion.originalDefense,
                        "originalAgility" to companion.originalAgility,
                        "originalMagicPower" to companion.originalMagicPower,

                        // Mutação
                        "mutationId" to companion.mutationId,
                        "mutationName" to companion.mutationName,
                        "mutationRarity" to companion.mutationRarity,
                        "mutationDescription" to companion.mutationDescription,

                        "mutationHpPercent" to companion.mutationHpPercent,
                        "mutationAttackPercent" to companion.mutationAttackPercent,
                        "mutationDefensePercent" to companion.mutationDefensePercent,
                        "mutationAgilityPercent" to companion.mutationAgilityPercent,
                        "mutationMagicPercent" to companion.mutationMagicPercent,

                        // Identificação e imagens
                        "imageKey" to companion.imageKey,
                        "isActive" to companion.isActive,

                        "imagemIconeCaminho" to companion.imagemIconeCaminho,
                        "imagemDetalhadaCaminho" to companion.imagemDetalhadaCaminho,
                        "imagemSpriteCaminho" to companion.imagemSpriteCaminho,

                        // Imagens do filhote
                        "filhoteImagemIconeCaminho" to companion.filhoteImagemIconeCaminho,
                        "filhoteImagemDetalhadaCaminho" to companion.filhoteImagemDetalhadaCaminho,
                        "filhoteImagemSpriteCaminho" to companion.filhoteImagemSpriteCaminho,

                        // Imagens do adolescente
                        "adolescenteImagemIconeCaminho" to companion.adolescenteImagemIconeCaminho,
                        "adolescenteImagemDetalhadaCaminho" to companion.adolescenteImagemDetalhadaCaminho,
                        "adolescenteImagemSpriteCaminho" to companion.adolescenteImagemSpriteCaminho,

                        // Imagens do adulto
                        "adultoImagemIconeCaminho" to companion.adultoImagemIconeCaminho,
                        "adultoImagemDetalhadaCaminho" to companion.adultoImagemDetalhadaCaminho,
                        "adultoImagemSpriteCaminho" to companion.adultoImagemSpriteCaminho
                    )
                },

                // Equipamentos
                "gold" to profile.inventory.gold,

                "equipment" to profile.inventory.equipment.map { equipment ->
                    mapOf(
                        "id" to equipment.id,
                        "name" to equipment.name,
                        "description" to equipment.description,
                        "type" to equipment.type.name,
                        "rarity" to equipment.rarity.name,
                        "rank" to equipment.rank,
                        "levelRequired" to equipment.levelRequired,

                        "attributes" to mapOf(
                            "strength" to equipment.attributes.strength,
                            "intelligence" to equipment.attributes.intelligence,
                            "agility" to equipment.attributes.agility,
                            "vitality" to equipment.attributes.vitality,
                            "spirit" to equipment.attributes.spirit,
                            "physicalDamage" to equipment.attributes.physicalDamage,
                            "magicalDamage" to equipment.attributes.magicalDamage,
                            "defense" to equipment.attributes.defense
                        ),

                        "specialEffect" to equipment.specialEffect,
                        "sourceMonsterId" to equipment.sourceMonsterId,
                        "imagemIconeCaminho" to equipment.imagemIconeCaminho,
                        "imagemDetalhadaCaminho" to equipment.imagemDetalhadaCaminho,
                        "craftingMaterials" to equipment.craftingMaterials,
                        "materialTraits" to equipment.materialTraits
                    )
                }
            ),

            // Poderes
            "powerProfile" to mapOf(

                "desires" to profile.powerProfile.desires.map { desire ->
                    mapOf(
                        "id" to desire.id,
                        "name" to desire.name,
                        "description" to desire.description,
                        "desiredType" to desire.desiredType.name,
                        "progress" to desire.progress,
                        "createdAt" to desire.createdAt
                    )
                },

                "powers" to profile.powerProfile.powers.map { power ->
                    mapOf(
                        "id" to power.id,
                        "name" to power.name,
                        "description" to power.description,
                        "type" to power.type.name,
                        "origin" to power.origin.name,
                        "status" to power.status.name,
                        "level" to power.level,
                        "experience" to power.experience,
                        "manaCost" to power.manaCost,
                        "baseDamage" to power.baseDamage,
                        "cooldown" to power.cooldown,
                        "effects" to power.effects,
                        "limitations" to power.limitations
                    )
                },

                "observations" to profile.powerProfile.observations.map { observation ->
                    mapOf(
                        "action" to observation.action,
                        "category" to observation.category,
                        "intensity" to observation.intensity,
                        "timestamp" to observation.timestamp,
                        "difficulty" to observation.difficulty,
                        "origin" to observation.origin?.name,
                        "successful" to observation.successful,
                        "tags" to observation.tags
                    )
                }
            ),

            // Classe
            "characterClass" to mapOf(
                "id" to profile.characterClass.id,
                "name" to profile.characterClass.name,
                "description" to profile.characterClass.description,
                "isCustom" to profile.characterClass.isCustom,
                "affinities" to profile.characterClass.affinities.mapKeys {
                    it.key.name
                }.mapValues {
                    it.value.name
                }
            ),

            // Atributos
            "attributes" to mapOf(
                "strength" to profile.attributes.strength,
                "intelligence" to profile.attributes.intelligence,
                "agility" to profile.attributes.agility,
                "vitality" to profile.attributes.vitality,
                "spirit" to profile.attributes.spirit
            ),

            // Aparência
            "appearance" to mapOf(
                "skinId" to profile.appearance.skinId,
                "faceId" to profile.appearance.faceId,
                "hairId" to profile.appearance.hairId,
                "hairColorId" to profile.appearance.hairColorId,
                "eyeId" to profile.appearance.eyeId,
                "outfitId" to profile.appearance.outfitId,
                "generatedImagePath" to profile.appearance.generatedImagePath,
                "generatedImageUrl" to profile.appearance.generatedImageUrl,
                "generationId" to profile.appearance.generationId,
                "visualVersion" to profile.appearance.visualVersion,
                "idleSpritePath" to profile.appearance.idleSpritePath,
                "walkingSpritesPath" to profile.appearance.walkingSpritesPath,
                "directionalSpritesPath" to profile.appearance.directionalSpritesPath
            )
        )


}
