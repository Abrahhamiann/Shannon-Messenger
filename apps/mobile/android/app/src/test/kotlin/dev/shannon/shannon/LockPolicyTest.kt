package dev.shannon.shannon

import org.junit.Assert.*
import org.junit.Test

class LockPolicyTest {
    @Test fun foregroundDoesNotLock() {
        assertFalse(LockPolicy.expired(null, 900000, 0))
    }
    @Test fun backgroundBoundaries() {
        for (seconds in listOf(30, 60, 300)) {
            assertFalse(LockPolicy.expired(1000, 1000 + seconds * 1000L - 1, seconds))
            assertTrue(LockPolicy.expired(1000, 1000 + seconds * 1000L, seconds))
        }
        assertTrue(LockPolicy.expired(1000, 1000, 0))
    }
    @Test fun monotonicResetFailsClosed() {
        assertTrue(LockPolicy.expired(1000, 500, 300))
    }
}
