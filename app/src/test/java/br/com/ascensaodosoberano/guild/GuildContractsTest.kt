package br.com.ascensaodosoberano.guild

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GuildContractsTest {
    @Test
    fun rankEOnlyAcceptsRankEContracts() {
        val rank = GuildRank.E
        assertTrue(rank.canAccept(GuildRank.E))
        assertFalse(rank.canAccept(GuildRank.D))
        assertFalse(rank.canAccept(GuildRank.SSS))
    }

    @Test
    fun higherRankIncludesAllLowerRankContracts() {
        assertTrue(GuildRank.A.canAccept(GuildRank.E))
        assertTrue(GuildRank.A.canAccept(GuildRank.C))
        assertTrue(GuildRank.A.canAccept(GuildRank.A))
        assertFalse(GuildRank.A.canAccept(GuildRank.S))
    }

    @Test
    fun promotionOrderIsSequentialAndEndsAtSss() {
        assertEquals(GuildRank.D, GuildRank.E.next())
        assertEquals(GuildRank.SSS, GuildRank.SS.next())
        assertEquals(null, GuildRank.SSS.next())
    }

    @Test
    fun contractBoardHasMultipleRegionsAndRanks() {
        assertTrue(GuildContractBoard.contracts.map { it.region }.distinct().size >= 7)
        assertEquals(GuildRank.entries.toSet(), GuildContractBoard.contracts.map { it.rank }.toSet())
    }
}
