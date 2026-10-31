package com.odibo.pdf.data

/** Pure argument validation shared by previews and worker dispatch. No Android APIs. */
object ToolArguments {
    const val MAX_INPUT = 16L * 1024 * 1024
    const val MAX_OUTPUT = 32L * 1024 * 1024

    fun parseRanges(text: String, pageCount: Int): List<IntRange> {
        require(pageCount in 2..2000 && text.length in 1..20000)
        val parts = text.split(',')
        require(parts.size in 2..minOf(pageCount, 32))
        var next = 1
        val result = parts.map { part ->
            val match = Regex("\\s*(\\d+)\\s*(?:-\\s*(\\d+)\\s*)?").matchEntire(part) ?: throw IllegalArgumentException()
            val first = match.groupValues[1].toIntOrNull() ?: throw IllegalArgumentException()
            val end = match.groupValues[2]
            val last = if (end.isEmpty()) first else end.toIntOrNull() ?: throw IllegalArgumentException()
            require(first == next && last in first..pageCount)
            next = last + 1
            first..last
        }
        require(next == pageCount + 1)
        return result
    }

    fun validateOrder(order: List<Int>, count: Int) {
        require(count in 1..2000 && order.size == count && order.toSet().size == count && order.all { it in 0 until count })
    }

    fun validateAggregate(sizes: List<Long>) {
        require(sizes.size in 2..32 && sizes.all { it in 1..MAX_INPUT })
        require(sizes.sum() <= MAX_INPUT)
    }
}
