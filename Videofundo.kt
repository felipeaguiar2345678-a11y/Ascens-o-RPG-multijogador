package br.com.ascensaodosoberano

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.foundation.layout.fillMaxSize

import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.datasource.RawResourceDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView

@Composable
fun VideoFundo(modifier: Modifier = Modifier) {

    val context = androidx.compose.ui.platform.LocalContext.current

    val player = remember {
        ExoPlayer.Builder(context).build().apply {

            val primeiroVideo = MediaItem.fromUri(
                RawResourceDataSource.buildRawResourceUri(
                    R.raw.video_inicio_1
                )
            )

            val segundoVideo = MediaItem.fromUri(
                RawResourceDataSource.buildRawResourceUri(
                    R.raw.video_inicio_2
                )
            )

            setMediaItems(
                listOf(primeiroVideo, segundoVideo)
            )

            repeatMode = Player.REPEAT_MODE_ALL

            prepare()
            playWhenReady = true
        }
    }

    DisposableEffect(player) {
        onDispose {
            player.release()
        }
    }

AndroidView<PlayerView>(
    modifier = modifier.fillMaxSize(),
    factory = { viewContext ->
        PlayerView(viewContext).apply {
            this.player = player
            useController = false
isClickable = false
isFocusable = false
resizeMode = AspectRatioFrameLayout.RESIZE_MODE_ZOOM
setShowBuffering(PlayerView.SHOW_BUFFERING_NEVER)
        }
    },
    update = { view: PlayerView ->
        view.player = player
    }
)
}