package com.paul.sprintsync.core.services

import android.content.Context
import com.google.android.gms.nearby.connection.AdvertisingOptions
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.tasks.Tasks
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class NearbyConnectionsManagerTest {
    @Test
    fun `native clock sync host config survives host startup normalization`() {
        val context = mockk<Context>(relaxed = true)
        val connectionsClient = mockk<ConnectionsClient>(relaxed = true)
        every {
            connectionsClient.startAdvertising(
                any<String>(),
                any<String>(),
                any<ConnectionLifecycleCallback>(),
                any<AdvertisingOptions>(),
            )
        } returns Tasks.forResult<Void>(null)

        val manager = NearbyConnectionsManager(
            context = context,
            nowNativeClockSyncElapsedNanos = { 1L },
            connectionsClient = connectionsClient,
        )

        manager.configureNativeClockSyncHost(enabled = true, requireSensorDomainClock = false)

        manager.startHosting(
            serviceId = "svc",
            endpointName = "host",
            strategy = NearbyTransportStrategy.POINT_TO_POINT,
        ) { _ -> }

        val (enabled, requireSensorDomain) = manager.nativeClockSyncHostConfigForTest()
        assertTrue(enabled)
        assertEquals(false, requireSensorDomain)
    }
}
