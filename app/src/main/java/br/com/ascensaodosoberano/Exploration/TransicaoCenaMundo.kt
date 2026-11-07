
package br.com.ascensaodosoberano.exploration

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.ContentTransform
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

@Composable
fun TransicaoCenaMundo(
    modo: ModoCenaMundo,
    modifier: Modifier = Modifier,
    viagem: @Composable () -> Unit,
    exploracao: @Composable () -> Unit,
    combate: @Composable () -> Unit
) {
    AnimatedContent(
        targetState = modo,
        modifier = modifier.fillMaxSize(),
        transitionSpec = {
            ContentTransform(
                targetContentEnter = fadeIn(
                    animationSpec = tween(450)
                ) + scaleIn(
                    initialScale = 0.96f,
                    animationSpec = tween(450)
                ),
                initialContentExit = fadeOut(
                    animationSpec = tween(300)
                ) + scaleOut(
                    targetScale = 1.04f,
                    animationSpec = tween(300)
                )
            )
        },
        label = "Transicao do Mundo"
    ) { cena ->

        Box(
            modifier = Modifier.fillMaxSize()
        ) {
            when (cena) {
                ModoCenaMundo.VIAGEM -> viagem()

                ModoCenaMundo.EXPLORACAO -> exploracao()

                ModoCenaMundo.COMBATE -> combate()
            }
        }
    }
}
