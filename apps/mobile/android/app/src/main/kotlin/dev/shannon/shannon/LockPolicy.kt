package dev.shannon.shannon

/** Monotonic elapsed time; foreground navigation never counts as inactivity. */
internal object LockPolicy {
    fun expired(start: Long?, now: Long, seconds: Int): Boolean =
        start != null && (now < start || now - start >= seconds * 1000L)
}
