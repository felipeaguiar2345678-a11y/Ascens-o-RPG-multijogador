package br.com.ascensaodosoberano

import androidx.compose.foundation.background
import androidx.compose.foundation.Canvas
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val FundoNoite = Color(0xFF101522)
private val Ouro = Color(0xFFE8BD72)
private val Painel = Color(0xE91B2434)

@Composable
fun TelaInicial(
    onEntrar: () -> Unit,
    onCriarConta: () -> Unit,
    onVisitante: () -> Unit,
    onMultiplayer: () -> Unit = {}
) {
    Box(modifier = Modifier.fillMaxSize()) {
        VideoFundo(modifier = Modifier.fillMaxSize())
        // Céu estrelado e selo arcano em primeiro plano sobre o vídeo de abertura.
        Canvas(Modifier.fillMaxSize()) {
            for (i in 0..52) {
                val x = (i * 137f + 31f).mod(size.width)
                val y = (i * 83f + 19f).mod(size.height)
                val raio = if (i % 9 == 0) 2.2.dp.toPx() else 1.1.dp.toPx()
                val alpha = .12f + (i % 5) * .055f
                drawCircle(Color(0xFFFFE4AC).copy(alpha = alpha), raio, Offset(x, y))
                if (i % 13 == 0) {
                    drawLine(
                        Color(0xFFFFD58A).copy(alpha = .18f),
                        Offset(x - 5.dp.toPx(), y),
                        Offset(x + 5.dp.toPx(), y),
                        1.dp.toPx()
                    )
                    drawLine(
                        Color(0xFFFFD58A).copy(alpha = .18f),
                        Offset(x, y - 5.dp.toPx()),
                        Offset(x, y + 5.dp.toPx()),
                        1.dp.toPx()
                    )
                }
            }
            val centro = Offset(size.width / 2f, size.height * .20f)
            drawCircle(
                Color(0xFFFFD58A).copy(alpha = .10f),
                size.minDimension * .19f,
                centro
            )
            drawCircle(
                Color(0xFFFFD58A).copy(alpha = .18f),
                size.minDimension * .16f,
                centro,
                style = Stroke(width = 1.dp.toPx())
            )
        }
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    listOf(Color(0xD908101C), Color(0x99101827), Color(0xF20A0F19))
                )
            )
        )

        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 26.dp, vertical = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("✦", color = Ouro, fontSize = 34.sp)
                Text(
                    "ASCENSÃO",
                    color = Color(0xFFFFE4AC),
                    fontSize = 34.sp,
                    fontWeight = FontWeight.Black,
                    letterSpacing = 5.sp,
                    textAlign = TextAlign.Center
                )
                Text(
                    "DO SOBERANO",
                    color = Ouro,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 7.sp,
                    textAlign = TextAlign.Center
                )
                Spacer(Modifier.height(10.dp))
                Box(Modifier.width(150.dp).height(1.dp).background(Ouro.copy(alpha = 0.75f)))
                Text(
                    "Seu destino será escrito pela sua força.",
                    color = Color(0xFFE1D8C8),
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 12.dp)
                )
            }

            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(22.dp),
                colors = CardDefaults.cardColors(containerColor = Painel),
                border = androidx.compose.foundation.BorderStroke(1.dp, Ouro.copy(alpha = 0.38f))
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(
                        "ENTRE NESTE MUNDO",
                        color = Ouro,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 2.sp
                    )
                    Button(
                        onClick = onEntrar,
                        modifier = Modifier.fillMaxWidth().height(54.dp),
                        shape = RoundedCornerShape(13.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF60458D))
                    ) {
                        Text("CONTINUAR A JORNADA", fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                    }
                    Button(
                        onClick = onCriarConta,
                        modifier = Modifier.fillMaxWidth().height(52.dp),
                        shape = RoundedCornerShape(13.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF87602F))
                    ) {
                        Text("CRIAR CONTA", color = Color(0xFFFFF3DA), fontWeight = FontWeight.Bold)
                    }
                    OutlinedButton(
                        onClick = onVisitante,
                        modifier = Modifier.fillMaxWidth().height(50.dp),
                        shape = RoundedCornerShape(13.dp),
                        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFB8C2D2))
                    ) {
                        Text("JOGAR COMO VISITANTE", color = Color.White, fontWeight = FontWeight.SemiBold)
                    }
                    OutlinedButton(
                        onClick = onMultiplayer,
                        modifier = Modifier.fillMaxWidth().height(46.dp),
                        shape = RoundedCornerShape(13.dp),
                        border = androidx.compose.foundation.BorderStroke(1.dp, Ouro.copy(alpha = 0.7f))
                    ) {
                        Text("MULTIPLAYER", color = Ouro, fontWeight = FontWeight.Bold)
                    }
                }
            }

            Text(
                "UM MUNDO. INÚMERAS HISTÓRIAS. UM SOBERANO.",
                color = Color(0xFFB9B4AC),
                fontSize = 10.sp,
                letterSpacing = 1.5.sp,
                textAlign = TextAlign.Center
            )
        }
    }
}