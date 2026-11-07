
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.CriaturaGerada

object CombatFactory {

    fun createCombat(
        hero: Combatant,
        criatura: CriaturaGerada
    ): CombatState {

        val inimigo = Combatant(
            name = criatura.nome,
            maxHp = criatura.vidaMaxima,
            hp = criatura.vidaMaxima,
            attack = criatura.ataque,
            defense = criatura.defesa,
            mana = criatura.manaMaxima,
            maxMana = criatura.manaMaxima,
            rank = criatura.rank,
            level = criatura.nivel,
            danger = criatura.perigo,
            xpReward = criatura.experienciaBase,
            isBoss = criatura.chefe,
            agility = criatura.agilidade,
            magicPower = criatura.poderMagico,
            attacks = criatura.ataques
        )

        return CombatSystem.startCombat(
            hero = hero,
            enemy = inimigo
        )
    }
}
