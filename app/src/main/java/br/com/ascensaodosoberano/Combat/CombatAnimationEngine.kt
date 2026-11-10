package br.com.ascensaodosoberano.combat

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import br.com.ascensaodosoberano.world.AtaqueCriatura
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * Converte a intenção de uma habilidade em uma receita visual.
 * Não depende de IDs ou nomes cadastrados: poderes inéditos são interpretados
 * a partir de nome, descrição, elemento, tipo e efeitos.
 */
enum class FamiliaAnimacao {
    TEMPO, ESPACO, FOGO, GELO, RAIO, SOMBRA, LUZ, VENENO,
    SANGUE, NATUREZA, AGUA, VENTO, TERRA, FISICO, MAGIA, IMPACTO
}

data class PerfilAnimacaoCombate(
    val familia: FamiliaAnimacao,
    val corPrimaria: Color,
    val corSecundaria: Color,
    val usaProjetil: Boolean,
    val usaRuptura: Boolean,
    val usaCirculoMagico: Boolean,
    val intensidade: Float
)

object CombatAnimationEngine {
    fun interpretar(skill: AtaqueCriatura?, efeito: String = "", log: String = ""): PerfilAnimacaoCombate {
        val texto = listOfNotNull(
            skill?.nome, skill?.descricao, skill?.elemento,
            skill?.tipoDano, skill?.categoria, skill?.efeitos?.joinToString(" "),
            efeito, log
        ).joinToString(" ").lowercase()
        val familia = when {
            listOf("tempo", "cron", "aceler", "retardar", "parar o tempo", "distorção temporal").any(texto::contains) -> FamiliaAnimacao.TEMPO
            listOf("espaço", "espacial", "portal", "dimensão", "gravit", "dobra").any(texto::contains) -> FamiliaAnimacao.ESPACO
            listOf("fogo", "chama", "incendi", "bras").any(texto::contains) -> FamiliaAnimacao.FOGO
            listOf("gelo", "congel", "nevasca", "cristal").any(texto::contains) -> FamiliaAnimacao.GELO
            listOf("raio", "elétr", "eletric", "trovão").any(texto::contains) -> FamiliaAnimacao.RAIO
            listOf("sombra", "sombrio", "trevas", "escuridão").any(texto::contains) -> FamiliaAnimacao.SOMBRA
            listOf("luz", "sagrado", "solar", "radiante").any(texto::contains) -> FamiliaAnimacao.LUZ
            listOf("veneno", "toxina", "ácido", "corros").any(texto::contains) -> FamiliaAnimacao.VENENO
            listOf("sangue", "hemorr", "vitalidade").any(texto::contains) -> FamiliaAnimacao.SANGUE
            listOf("natureza", "raiz", "flora", "espinho", "planta").any(texto::contains) -> FamiliaAnimacao.NATUREZA
            listOf("água", "agua", "maré", "onda", "hidro").any(texto::contains) -> FamiliaAnimacao.AGUA
            listOf("vento", "furac", "tornado", "corrente de ar").any(texto::contains) -> FamiliaAnimacao.VENTO
            listOf("terra", "pedra", "rocha", "metal", "minério").any(texto::contains) -> FamiliaAnimacao.TERRA
            listOf("corte", "espada", "golpe", "soco", "impacto", "físico", "fisico").any(texto::contains) -> FamiliaAnimacao.FISICO
            texto.isNotBlank() -> FamiliaAnimacao.MAGIA
            else -> FamiliaAnimacao.IMPACTO
        }
        val cores = when (familia) {
            FamiliaAnimacao.TEMPO -> Color(0xFF66E5D1) to Color(0xFFB5A0FF)
            FamiliaAnimacao.ESPACO -> Color(0xFF9B83FF) to Color(0xFF50D9F5)
            FamiliaAnimacao.FOGO -> Color(0xFFFF7138) to Color(0xFFFFD16A)
            FamiliaAnimacao.GELO -> Color(0xFF76DFFF) to Color(0xFFE5FBFF)
            FamiliaAnimacao.RAIO -> Color(0xFFFFE65C) to Color(0xFF9CEBFF)
            FamiliaAnimacao.SOMBRA -> Color(0xFF8C65C9) to Color(0xFF34234F)
            FamiliaAnimacao.LUZ -> Color(0xFFFFE6A1) to Color(0xFFFFFFFF)
            FamiliaAnimacao.VENENO -> Color(0xFF8BE05A) to Color(0xFFDAFF75)
            FamiliaAnimacao.SANGUE -> Color(0xFFCF3454) to Color(0xFFFF8295)
            FamiliaAnimacao.NATUREZA -> Color(0xFF65D58B) to Color(0xFFCBF58A)
            FamiliaAnimacao.AGUA -> Color(0xFF3FADFF) to Color(0xFFB2F2FF)
            FamiliaAnimacao.VENTO -> Color(0xFFB4E8E7) to Color(0xFFFFFFFF)
            FamiliaAnimacao.TERRA -> Color(0xFFC69B69) to Color(0xFFFFD59A)
            FamiliaAnimacao.FISICO -> Color(0xFFFFD27A) to Color(0xFFFFFFFF)
            FamiliaAnimacao.MAGIA -> Color(0xFFB68CFF) to Color(0xFFE6D5FF)
            FamiliaAnimacao.IMPACTO -> Color(0xFFFFD76A) to Color(0xFFFFFFFF)
        }
        val intensidade = when {
            skill?.categoria.equals("DEVASTADOR", true) -> 1.45f
            skill?.categoria.equals("SUPREMO", true) -> 1.7f
            skill?.turnosCarregamento?.let { it > 0 } == true -> 1.25f
            else -> 1f
        }
        return PerfilAnimacaoCombate(
            familia, cores.first, cores.second,
            usaProjetil = familia !in setOf(FamiliaAnimacao.TEMPO, FamiliaAnimacao.ESPACO, FamiliaAnimacao.FISICO, FamiliaAnimacao.IMPACTO),
            usaRuptura = familia in setOf(FamiliaAnimacao.TEMPO, FamiliaAnimacao.ESPACO, FamiliaAnimacao.RAIO, FamiliaAnimacao.FISICO),
            usaCirculoMagico = familia !in setOf(FamiliaAnimacao.FISICO, FamiliaAnimacao.IMPACTO),
            intensidade = intensidade
        )
    }

    fun encontrarHabilidade(state: CombatState): AtaqueCriatura? {
        val texto = state.log.lastOrNull().orEmpty()
        return (state.hero.attacks + state.enemy.attacks).firstOrNull { it.nome.isNotBlank() && texto.contains(it.nome, ignoreCase = true) }
    }

    fun modifier(state: CombatState): Modifier = Modifier.composed {
        val perfil = remember(state.efeitoVisualAtual, state.log.size) {
            interpretar(encontrarHabilidade(state), state.efeitoVisualAtual, state.log.lastOrNull().orEmpty())
        }
        val progresso = remember { Animatable(0f) }
        LaunchedEffect(state.efeitoVisualAtual, state.log.size) {
            if (state.efeitoVisualAtual.isNotBlank() || state.log.size > 1) {
                progresso.snapTo(0f)
                progresso.animateTo(1f, animationSpec = tween(760))
            }
        }
        val p = progresso.value
        Modifier.drawWithContent {
            drawContent()
            if (p > 0f && p < 1f) {
                val centro = Offset(size.width * .55f, size.height * .52f)
                val raio = size.minDimension * (.08f + p * .34f) * perfil.intensidade
                if (perfil.usaCirculoMagico) {
                    drawCircle(perfil.corPrimaria.copy(alpha = (1f - p) * .65f), raio, centro, style = Stroke(width = 2.2f))
                    drawCircle(perfil.corSecundaria.copy(alpha = (1f - p) * .38f), raio * .72f, centro, style = Stroke(width = 1.2f))
                }
                if (perfil.usaRuptura) {
                    val caminho = Path().apply {
                        moveTo(centro.x - raio, centro.y - raio * .35f)
                        cubicTo(centro.x - raio * .2f, centro.y - raio, centro.x + raio * .2f, centro.y + raio, centro.x + raio, centro.y + raio * .25f)
                    }
                    drawPath(caminho, perfil.corSecundaria.copy(alpha = 1f - p), style = Stroke(width = 4f))
                }
                val atacanteInimigo = state.log.lastOrNull()?.contains(state.enemy.name, ignoreCase = true) == true &&
                    !state.log.lastOrNull().orEmpty().contains(state.hero.name, ignoreCase = true)
                val inicioX = size.width * if (atacanteInimigo) .76f else .24f
                val fimX = size.width * if (atacanteInimigo) .24f else .76f
                val trilhaY = size.height * .50f
                if (perfil.usaProjetil) {
                    val orbX = inicioX + (fimX - inicioX) * p
                    drawLine(
                        perfil.corSecundaria.copy(alpha = (1f - p) * .8f),
                        Offset(inicioX, trilhaY),
                        Offset(orbX, trilhaY),
                        strokeWidth = 5f * (1f - p) + 1f
                    )
                    drawCircle(perfil.corPrimaria, 7f * (1f - p) + 2f, Offset(orbX, trilhaY))
                    drawCircle(Color.White.copy(alpha = 1f - p), 2.5f, Offset(orbX, trilhaY))
                } else if (perfil.familia == FamiliaAnimacao.FISICO) {
                    val corte = Path().apply {
                        moveTo(inicioX, trilhaY + 24f * (1f - p))
                        quadraticTo(size.width * .5f, trilhaY - 45f, fimX, trilhaY - 18f * (1f - p))
                    }
                    drawPath(corte, perfil.corSecundaria.copy(alpha = 1f - p), style = Stroke(width = 5f * (1f - p) + 1f))
                }
                val quantidade = if (perfil.usaProjetil) 12 else 8
                for (i in 0 until quantidade) {
                    val angulo = (2.0 * PI * i / quantidade) + p * 2.4
                    val distancia = raio * (if (perfil.usaProjetil) 1.35f else .9f)
                    val pos = Offset(centro.x + cos(angulo).toFloat() * distancia, centro.y + sin(angulo).toFloat() * distancia)
                    drawCircle(if (i % 2 == 0) perfil.corPrimaria else perfil.corSecundaria, (5f * (1f - p) + 1f) * perfil.intensidade, pos)
                }
                if (perfil.familia == FamiliaAnimacao.TEMPO) {
                    for (i in 0..2) {
                        val r = raio * (0.45f + i * .28f)
                        drawCircle(perfil.corPrimaria.copy(alpha = (1f - p) * .55f), r, centro, style = Stroke(width = 1.5f))
                    }
                }
                if (perfil.familia == FamiliaAnimacao.ESPACO) {
                    drawCircle(Color.White.copy(alpha = (1f - p) * .7f), raio * .16f, centro)
                }
            }
        }
    }
}
