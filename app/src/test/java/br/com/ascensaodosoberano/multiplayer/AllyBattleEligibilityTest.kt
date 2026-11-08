package br.com.ascensaodosoberano.multiplayer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import br.com.ascensaodosoberano.combat.Combatant
import org.junit.Test

class AllyBattleEligibilityTest {
    @Test fun presenceMustBeOnlineAndRecent() {
        assertTrue(AllyBattleEligibility.isFresh(true, 70_000L, 100_000L))
        assertFalse(AllyBattleEligibility.isFresh(false, 99_000L, 100_000L))
        assertFalse(AllyBattleEligibility.isFresh(true, 0L, 100_000L))
        assertFalse(AllyBattleEligibility.isFresh(true, 69_999L, 100_000L))
        assertFalse(AllyBattleEligibility.isFresh(true, 101_000L, 100_000L))
    }

    @Test fun alliesMustBeWithinTheConfiguredRadius() {
        assertTrue(AllyBattleEligibility.isNearby(0.5f, 0.5f, 0.55f, 0.5f))
        assertTrue(AllyBattleEligibility.isNearby(0.5f, 0.5f, 0.5f, 0.58f))
        assertFalse(AllyBattleEligibility.isNearby(0.5f, 0.5f, 0.59f, 0.5f))
    }

    @Test fun groupMustContainAtMostFourUniqueNonBlankPlayers() {
        assertTrue(AllyBattleEligibility.hasValidGroupMembers(listOf("a")))
        assertTrue(AllyBattleEligibility.hasValidGroupMembers(listOf("a", "b", "c", "d")))
        assertFalse(AllyBattleEligibility.hasValidGroupMembers(emptyList<Any>()))
        assertFalse(AllyBattleEligibility.hasValidGroupMembers(listOf("a", "b", "c", "d", "e")))
        assertFalse(AllyBattleEligibility.hasValidGroupMembers(listOf("a", "b", "b")))
        assertFalse(AllyBattleEligibility.hasValidGroupMembers(listOf("a", " ")))
        assertFalse(AllyBattleEligibility.hasValidGroupMembers(listOf("a", 42)))
        assertFalse(AllyBattleEligibility.hasValidGroupMembers(listOf("a", "b", "c", "d", null)))
    }

    @Test fun battleRejectsJoinWhenFourPlayersAreAlreadyPresent() {
        assertTrue(AllyBattleEligibility.hasOpenBattleSlot(0))
        assertTrue(AllyBattleEligibility.hasOpenBattleSlot(3))
        assertFalse(AllyBattleEligibility.hasOpenBattleSlot(4))
        assertFalse(AllyBattleEligibility.hasOpenBattleSlot(5))
    }

    @Test fun battleRosterMustMatchParticipantsAndActivePlayer() {
        assertTrue(AllyBattleEligibility.hasValidBattleRoster(
            listOf("a", "b", "c"), listOf("a", "b", "c"), "b"
        ))
        assertFalse(AllyBattleEligibility.hasValidBattleRoster(
            listOf("a", "b"), listOf("a"), "a"
        ))
        assertFalse(AllyBattleEligibility.hasValidBattleRoster(
            listOf("a", "b"), listOf("a", "c"), "a"
        ))
        assertFalse(AllyBattleEligibility.hasValidBattleRoster(
            listOf("a", "a"), listOf("a", "a"), "a"
        ))
        assertFalse(AllyBattleEligibility.hasValidBattleRoster(
            listOf("a", "b", "c", "d", "e"),
            listOf("a", "b", "c", "d", "e"), "a"
        ))
        assertFalse(AllyBattleEligibility.hasValidBattleRoster(
            listOf("a", "b"), listOf("a", "b"), "offline"
        ))
        assertFalse(AllyBattleEligibility.hasValidBattleRoster(
            listOf("a", "b"), listOf("a", 42), "a"
        ))
    }

    private fun member(uid: String, hp: Int) = AllyBattleMember(
        uid = uid,
        name = uid,
        hero = Combatant(
            name = uid, maxHp = 100, hp = hp, attack = 10,
            defense = 5, agility = 5
        )
    )

    @Test fun turnRotationSkipsDefeatedMembersAndWrapsAround() {
        val team = listOf(member("a", 100), member("b", 0), member("c", 50), member("d", 0))

        assertEquals("c", AllyBattleTurnRules.nextLivingMember(team, "a")?.uid)
        assertEquals("a", AllyBattleTurnRules.nextLivingMember(team, "c")?.uid)
    }

    @Test fun oneSurvivorKeepsTheBattleAliveAndReceivesTheNextTurn() {
        val team = listOf(member("a", 0), member("b", 25), member("c", 0))

        assertFalse(AllyBattleTurnRules.allMembersDefeated(team))
        assertEquals("b", AllyBattleTurnRules.nextLivingMember(team, "b")?.uid)
    }

    @Test fun battleOnlyEndsWhenEveryMemberIsDefeated() {
        assertTrue(AllyBattleTurnRules.allMembersDefeated(listOf(member("a", 0), member("b", 0))))
        assertFalse(AllyBattleTurnRules.allMembersDefeated(listOf(member("a", 0), member("b", 1))))
        assertTrue(AllyBattleTurnRules.allMembersDefeated(emptyList()))
        assertEquals(null, AllyBattleTurnRules.nextLivingMember(emptyList(), "a"))
    }
}
