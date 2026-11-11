package br.com.ascensaodosoberano.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * Identidade visual central do Ascensão do Soberano.
 * Tons de pergaminho, ouro antigo e violeta sobre superfícies noturnas.
 */
object AscensaoPalette {
    val Ouro = Color(0xFFE8BD72)
    val OuroClaro = Color(0xFFFFE8C1)
    val OuroEscuro = Color(0xFF4C3A27)
    val Violeta = Color(0xFF9B82C8)
    val VioletaEscuro = Color(0xFF342C48)
    val Fundo = Color(0xFF101722)
    val Superficie = Color(0xFF1B2534)
    val SuperficieElevada = Color(0xFF293548)
    val Texto = Color(0xFFE7ECF4)
    val TextoSecundario = Color(0xFFC3CDDA)
    val Sucesso = Color(0xFF78C99A)
    val Perigo = Color(0xFFE47C78)
    val Agua = Color(0xFF70C9D8)
}

@Composable
fun AscensaoTheme(content: @Composable () -> Unit) {
    val colors = darkColorScheme(
        primary = AscensaoPalette.Ouro,
        onPrimary = Color(0xFF21170A),
        primaryContainer = AscensaoPalette.OuroEscuro,
        onPrimaryContainer = AscensaoPalette.OuroClaro,
        secondary = AscensaoPalette.Violeta,
        secondaryContainer = AscensaoPalette.VioletaEscuro,
        onSecondaryContainer = Color(0xFFE8DCFF),
        background = AscensaoPalette.Fundo,
        onBackground = AscensaoPalette.Texto,
        surface = AscensaoPalette.Superficie,
        onSurface = AscensaoPalette.Texto,
        surfaceVariant = AscensaoPalette.SuperficieElevada,
        onSurfaceVariant = AscensaoPalette.TextoSecundario,
        error = AscensaoPalette.Perigo
    )
    MaterialTheme(
        colorScheme = colors,
        content = content
    )
}
