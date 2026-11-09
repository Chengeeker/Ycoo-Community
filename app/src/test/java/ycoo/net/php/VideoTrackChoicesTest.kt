package ycoo.net.php

import androidx.media3.common.*
import org.junit.Assert.*
import org.junit.Test

class VideoTrackChoicesTest {
    @Test fun onlyDistinctSupportedVideoResolutionsCanBeSelected() {
        fun format(w: Int, h: Int) = Format.Builder().setSampleMimeType(MimeTypes.VIDEO_H264).setWidth(w).setHeight(h).build()
        val video = TrackGroup("video", format(1920,1080), format(720,1280), format(1280,720), format(3840,2160))
        val supported = C.FORMAT_HANDLED
        val notSupported = C.FORMAT_EXCEEDS_CAPABILITIES
        fun tracks(vararg support: Int) = Tracks(listOf(Tracks.Group(video, true, support, BooleanArray(4))))
        val options = videoTrackChoices(tracks(supported, supported, supported, notSupported))
        assertEquals(listOf("1080P", "720P"), options.keys.toList())
        assertEquals(listOf(1), options.getValue("720P").trackIndices)
        assertTrue(videoTrackChoices(tracks(supported, notSupported, notSupported, notSupported)).isEmpty())
    }
}
