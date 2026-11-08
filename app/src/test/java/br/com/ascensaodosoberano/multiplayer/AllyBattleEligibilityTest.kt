package br.com.ascensaodosoberano.multiplayer

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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
}
