package dev.meteora.meteora.direct

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DirectSegmentPlanTest {

    @Test
    fun `plans contiguous ranges covering the whole file`() {
        val segments = DirectSegment.plan(totalBytes = 10_000_000L, maxSegments = 4)

        assertEquals(4, segments.size)
        assertEquals(0L, segments.first().start)
        assertEquals(9_999_999L, segments.last().end)
        segments.zipWithNext().forEach { (current, next) ->
            assertEquals(current.end + 1, next.start)
        }
        assertEquals(10_000_000L, segments.sumOf { it.length })
    }

    @Test
    fun `spreads the remainder over leading ranges`() {
        val segments = DirectSegment.plan(totalBytes = 10L, maxSegments = 3)

        assertEquals(3, segments.size)
        assertEquals(4L, segments[0].length)
        assertEquals(3L, segments[1].length)
        assertEquals(3L, segments[2].length)
        assertEquals(9L, segments.last().end)
    }

    @Test
    fun `single range when segmentation is disabled`() {
        val segments = DirectSegment.plan(totalBytes = 5_000_000L, maxSegments = 1)
        assertEquals(1, segments.size)
        assertEquals(0L, segments.single().start)
        assertEquals(4_999_999L, segments.single().end)
    }

    @Test
    fun `unknown size yields no ranges`() {
        assertTrue(DirectSegment.plan(totalBytes = -1L, maxSegments = 4).isEmpty())
        assertTrue(DirectSegment.plan(totalBytes = 0L, maxSegments = 4).isEmpty())
    }

    @Test
    fun `remaining becomes zero once every byte of a range is written`() {
        val segment = DirectSegment(0, 0L, 1023L)
        assertEquals(1024L, segment.remaining)
        segment.downloaded = 1024L
        assertEquals(0L, segment.remaining)
        assertTrue(segment.isComplete)
    }
}

class DirectUrlGuardTest {

    @Test
    fun `accepts public http and https URLs`() {
        assertNull(DirectUrlGuard.validate("https://cdn.example.com/file.mp4"))
        assertNull(DirectUrlGuard.validate("http://mirror.example.org/a.zip?token=1"))
    }

    @Test
    fun `rejects non-http schemes`() {
        assertTrue(DirectUrlGuard.validate("file:///sdcard/movie.mp4")!!.contains("http"))
        assertTrue(DirectUrlGuard.validate("ftp://example.com/a.mp4")!!.contains("http"))
        assertTrue(DirectUrlGuard.validate("javascript:alert(1)")!!.contains("http"))
    }

    @Test
    fun `rejects loopback and link-local addresses`() {
        assertTrue(DirectUrlGuard.validate("http://127.0.0.1:8080/file.mp4")!!.contains("blocked"))
        assertTrue(DirectUrlGuard.validate("http://localhost/file.mp4")!!.contains("blocked"))
        assertTrue(DirectUrlGuard.validate("http://169.254.169.254/latest/meta-data")!!.contains("blocked"))
        assertTrue(DirectUrlGuard.validate("http://[::1]/file.mp4")!!.contains("blocked"))
        assertTrue(DirectUrlGuard.validate("http://0.0.0.0/file.mp4")!!.contains("blocked"))
    }

    @Test
    fun `allows a LAN host so a NAS can be a destination`() {
        assertNull(DirectUrlGuard.validate("http://192.168.1.20:5000/file.mkv"))
    }

    @Test
    fun `rejects empty and malformed URLs`() {
        assertTrue(DirectUrlGuard.validate("   ")!!.isNotEmpty())
        assertTrue(DirectUrlGuard.validate("not a url")!!.isNotEmpty())
    }
}

class DirectFileNameTest {

    @Test
    fun `reads a quoted content disposition filename`() {
        assertEquals(
            "Report 2026.pdf",
            DirectFileName.fromContentDisposition("attachment; filename=\"Report 2026.pdf\""),
        )
    }

    @Test
    fun `reads an unquoted content disposition filename`() {
        assertEquals(
            "movie.mp4",
            DirectFileName.fromContentDisposition("inline; filename=movie.mp4; size=10"),
        )
    }

    @Test
    fun `decodes an RFC 5987 filename`() {
        assertEquals(
            "vidéo finale.mp4",
            DirectFileName.fromContentDisposition(
                "attachment; filename=\"video.mp4\"; filename*=UTF-8''vid%C3%A9o%20finale.mp4",
            ),
        )
    }

    @Test
    fun `keeps plus signs literal`() {
        assertEquals(
            "a+b.mp4",
            DirectFileName.fromContentDisposition("attachment; filename=a+b.mp4"),
        )
    }

    @Test
    fun `falls back to the URL leaf`() {
        assertEquals(
            "episode 1.mp4",
            DirectFileName.fromUrl("https://cdn.example.com/media/episode%201.mp4?x=1"),
        )
        assertNull(DirectFileName.fromUrl("https://example.com/"))
    }

    @Test
    fun `appends an extension from the content type when missing`() {
        assertEquals("clip.mp4", DirectFileName.withExtension("clip", "video/mp4"))
        assertEquals("clip.mkv", DirectFileName.withExtension("clip", "video/x-matroska"))
        assertEquals("clip.mp4", DirectFileName.withExtension("clip.mp4", "video/x-matroska"))
        assertEquals("clip", DirectFileName.withExtension("clip", "text/html"))
    }

    @Test
    fun `sanitises path separators and control characters`() {
        assertEquals("a_b_c.mp4", DirectFileName.sanitize("a/b\\c.mp4"))
        assertFalse(DirectFileName.sanitize("..").isEmpty())
    }
}
