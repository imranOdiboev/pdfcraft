package com.odibo.pdf.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ToolArgumentsTest {
    @Test fun fullSequentialPartitionsBecomeSafeCutIndices() {
        val ranges = ToolArguments.parseRanges("1-2, 3,4-6", 6)
        assertEquals(listOf(1..2, 3..3, 4..6), ranges)
        assertEquals(listOf(2, 3), ranges.drop(1).map { it.first - 1 })
    }
    @Test fun unsafePartitionsAreRejected() {
        for (value in listOf("", "1-6", "0-2,3-6", "1-2,2-6", "1-2,4-6", "3-6,1-2", "1-5", "1-2,3-7", "1-2,3-999999999999999", "1-2,3-6,", "1-2;3-6", "1-2,6-3")) {
            assertThrows(value, IllegalArgumentException::class.java) { ToolArguments.parseRanges(value, 6) }
        }
    }
    @Test fun reorderRequiresExactlyOneOfEveryPage() {
        ToolArguments.validateOrder(listOf(2, 0, 1), 3)
        for (order in listOf(emptyList(), listOf(0, 1), listOf(0, 0, 2), listOf(-1, 0, 1), listOf(0, 1, 3))) {
            assertThrows(IllegalArgumentException::class.java) { ToolArguments.validateOrder(order, 3) }
        }
    }
    @Test fun combineRetainsAggregateBudgetAndFileCountLimits() {
        ToolArguments.validateAggregate(listOf(1, ToolArguments.MAX_INPUT - 1))
        for (sizes in listOf<List<Long>>(emptyList(), listOf(1), listOf(0, 1), listOf(-1, 1), listOf(ToolArguments.MAX_INPUT, 1), List(33) { 1L }, listOf(Long.MAX_VALUE, 1))) {
            assertThrows(IllegalArgumentException::class.java) { ToolArguments.validateAggregate(sizes) }
        }
    }
}
