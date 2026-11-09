
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.character.CharacterProfile
import br.com.ascensaodosoberano.character.SkillDomain
import br.com.ascensaodosoberano.character.Affinity

object CharacterCombatFactory {

    fun createHero(profile: CharacterProfile): Combatant {

        val affinities = profile.characterClass.affinities
        val attributes = profile.attributes

        fun affinity(domain: SkillDomain): Affinity {
            return affinities[domain] ?: Affinity.MEDIUM
        }

        val levelBonus = (profile.level - 1).coerceAtLeast(0)

        // Bônus dos atributos distribuídos
        val strengthBonus =
            (attributes.strength - 5).coerceAtLeast(0) * 2

        val intelligenceBonus =
            (attributes.intelligence - 5).coerceAtLeast(0) * 3

        val agilityBonus =
            (attributes.agility - 5).coerceAtLeast(0) / 2

        val vitalityBonus =
            (attributes.vitality - 5).coerceAtLeast(0) * 10

        val spiritBonus =
            (attributes.spirit - 5).coerceAtLeast(0) * 10

        val equipamentosVestidos = profile.inventory.equipment.filter {
            it.id in profile.equipmentLoadout.equippedIds()
        }
        val bonusEquipamento = equipamentosVestidos.fold(
            br.com.ascensaodosoberano.companions.EquipmentAttributes()
        ) { total, equipamento ->
            total.copy(
                strength = total.strength + equipamento.attributes.strength,
                intelligence = total.intelligence + equipamento.attributes.intelligence,
                agility = total.agility + equipamento.attributes.agility,
                vitality = total.vitality + equipamento.attributes.vitality,
                spirit = total.spirit + equipamento.attributes.spirit,
                physicalDamage = total.physicalDamage + equipamento.attributes.physicalDamage,
                magicalDamage = total.magicalDamage + equipamento.attributes.magicalDamage,
                defense = total.defense + equipamento.attributes.defense
            )
        }

        val hpBase = when (affinity(SkillDomain.DEFENSE)) {
            Affinity.HIGH -> 130
            Affinity.MEDIUM -> 115
            Affinity.LOW -> 100
        }

        val manaBase = when (affinity(SkillDomain.MAGIC)) {
            Affinity.HIGH -> 100
            Affinity.MEDIUM -> 70
            Affinity.LOW -> 40
        }

        val attackBase = when (affinity(SkillDomain.PHYSICAL)) {
            Affinity.HIGH -> 30
            Affinity.MEDIUM -> 25
            Affinity.LOW -> 20
        }

        val defenseBase = when (affinity(SkillDomain.DEFENSE)) {
            Affinity.HIGH -> 15
            Affinity.MEDIUM -> 10
            Affinity.LOW -> 5
        }

        val summoningBonus = when (affinity(SkillDomain.SUMMONING)) {
            Affinity.HIGH -> 25
            Affinity.MEDIUM -> 10
            Affinity.LOW -> 0
        }

        val maxHp =
            hpBase + levelBonus * 20 + vitalityBonus + bonusEquipamento.vitality * 10

        val maxMana =
            manaBase + summoningBonus +
                levelBonus * 10 + spiritBonus + bonusEquipamento.spirit * 10

        return Combatant(
            name = profile.name,
            maxHp = maxHp,
            hp = if (profile.currentHp >= 0) profile.currentHp.coerceIn(0, maxHp) else maxHp,
            attack = attackBase + levelBonus * 3 + strengthBonus +
                bonusEquipamento.physicalDamage + bonusEquipamento.strength * 2,
            defense = defenseBase + levelBonus * 2 + agilityBonus +
                bonusEquipamento.defense,
            mana = if (profile.currentMana >= 0) profile.currentMana.coerceIn(0, maxMana) else maxMana,
            maxMana = maxMana,
            magicPower = 15 + intelligenceBonus +
                bonusEquipamento.magicalDamage + bonusEquipamento.intelligence * 3,
            agility = attributes.agility + bonusEquipamento.agility,
            rank = "E",
            level = profile.level,
            // As habilidades do herói vêm exclusivamente dos poderes realmente
            // despertados e salvos na ficha. Nunca conceder uma lista genérica fixa.
            attacks = profile.powerProfile.powers
                .filter { power ->
                    power.status in setOf(
                        br.com.ascensaodosoberano.powers.PowerStatus.AWAKENED,
                        br.com.ascensaodosoberano.powers.PowerStatus.EVOLVING,
                        br.com.ascensaodosoberano.powers.PowerStatus.MASTERED
                    )
                }
                .map { power ->
                    val tipoDano = when (power.type) {
                        br.com.ascensaodosoberano.powers.PowerType.PHYSICAL -> "FISICO"
                        br.com.ascensaodosoberano.powers.PowerType.MAGIC,
                        br.com.ascensaodosoberano.powers.PowerType.ELEMENTAL,
                        br.com.ascensaodosoberano.powers.PowerType.SPATIAL,
                        br.com.ascensaodosoberano.powers.PowerType.GRAVITY -> "MAGICO"
                        else -> "ESPECIAL"
                    }
                    br.com.ascensaodosoberano.world.AtaqueCriatura(
                        id = power.id,
                        nome = power.name,
                        descricao = power.description,
                        tipoDano = tipoDano,
                        danoBase = power.baseDamage.coerceAtLeast(0),
                        // O dano gerado pela IA é uma parcela adicional; atributos do herói
                        // contribuem parcialmente para evitar explosão de poder no início.
                        multiplicador = if (power.baseDamage > 0) 0.35f else 0f,
                        custoMana = power.manaCost.coerceAtLeast(0),
                        turnosRecarga = power.cooldown.coerceAtLeast(0),
                        efeitos = power.effects,
                        categoria = "PODER_DESPERTADO"
                    )
                }
        )
    }
}
