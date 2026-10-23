package com.chesslab.puzzles

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

/** Le plan d'un programme Woodpecker. Pendant de `WoodpeckerPlanTests`. */
class WoodpeckerPlanTest {

    private fun items(count: Int) = (0 until count).map {
        WoodpeckerPlan.Item("fen$it", listOf("e2e4"), "fork", "middlegame", 1500)
    }

    @Test fun `un nouveau programme passe chaque puzzle une fois au premier cycle`() {
        val plan = WoodpeckerPlan.start(items(50), now = 0, random = Random(42))!!
        assertEquals(1, plan.cycles.size)
        assertEquals(1, plan.currentCycle.number)
        assertEquals((0 until 50).toSet(), plan.currentCycle.order.toSet())
        assertEquals(50, plan.currentCycle.order.size)
        assertEquals(plan.currentCycle.order[0], plan.currentItemIndex)
    }

    @Test fun `pas de programme sans puzzle`() {
        assertNull(WoodpeckerPlan.start(emptyList()))
    }

    @Test fun `les réponses font avancer le cycle puis le bouclent`() {
        var plan = WoodpeckerPlan.start(items(3), now = 0)!!
        val order = plan.currentCycle.order
        plan = plan.record(true, 10.0, now = 0)
        assertEquals(order[1], plan.currentItemIndex)
        plan = plan.record(false, 20.0, now = 0).record(true, 30.0, now = 60_000)

        assertNull(plan.currentItemIndex)
        assertTrue(plan.currentCycle.isComplete)
        assertEquals(2, plan.currentCycle.solvedCount)
        assertEquals(60.0, plan.currentCycle.activeSeconds, 0.0)
        assertEquals(60_000L, plan.currentCycle.finishedAt)
        // Cycle bouclé : une réponse de plus ne compte pas.
        assertEquals(3, plan.record(true, 99.0).currentCycle.attempts.size)
    }

    @Test fun `le cycle suivant rejoue le même lot dans un nouvel ordre`() {
        val random = Random(7)
        var plan = WoodpeckerPlan.start(items(25), now = 0, random = random)!!
        assertEquals(1, plan.startNextCycle(random = random).cycles.size)

        repeat(25) { plan = plan.record(true, 4.0) }
        val firstOrder = plan.currentCycle.order
        plan = plan.startNextCycle(random = random)

        assertEquals(2, plan.cycles.size)
        assertEquals(2, plan.currentCycle.number)
        assertEquals((0 until 25).toSet(), plan.currentCycle.order.toSet())
        assertNotEquals("mélangé à chaque cycle (décision du 23/10)", firstOrder, plan.currentCycle.order)
        assertEquals(1, plan.previousCycle?.number)
        assertEquals(25, plan.items.size)
    }

    @Test fun `l'objectif est la moitié du dernier cycle fini`() {
        var plan = WoodpeckerPlan.start(items(2))!!
        assertNull(plan.nextCycleTargetSeconds)
        plan = plan.record(true, 100.0).record(true, 140.0)
        assertEquals(120.0, plan.nextCycleTargetSeconds!!, 0.0)
    }

    @Test fun `un temps négatif est ignoré`() {
        val plan = WoodpeckerPlan.start(items(1))!!.record(true, -5.0)
        assertEquals(0.0, plan.currentCycle.activeSeconds, 0.0)
    }

    @Test fun `survit à un aller-retour JSON`() {
        val plan = WoodpeckerPlan.start(items(4), now = 1_000)!!.record(true, 12.5, now = 2_000)
        assertEquals(plan, WoodpeckerPlan.fromJson(plan.toJson()))
        assertNull(WoodpeckerPlan.fromJson("pas du JSON"))
    }

    @Test fun `formate les durées`() {
        assertEquals("0:00", WoodpeckerPlan.formatDuration(0.0))
        assertEquals("7:05", WoodpeckerPlan.formatDuration(425.0))
        assertEquals("1:02:03", WoodpeckerPlan.formatDuration(3723.0))
    }
}
