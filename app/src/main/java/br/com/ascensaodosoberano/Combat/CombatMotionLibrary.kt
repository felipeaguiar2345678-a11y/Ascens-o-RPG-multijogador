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
 * Biblioteca procedural de coreografias. A habilidade não precisa existir
 * previamente: o texto é interpretado e combinado com uma família visual.
 */
enum class MovimentoCombate {
    AVANCO, INVESTIDA, DASH, SALTO, GIRO, RECUO, TELEPORTE, VOAR,
    FLUTUAR, CANALIZAR, CORTE, GOLPE_DUPLO, COMBO, PERFURACAO,
    ONDA, RAJADA, CHUVA, COLUNA, EXPLOSAO, BARREIRA, ESCUDO,
    CONTRA_ATAQUE, CURA, DRENAGEM, INVOCACAO, TRANSFORMACAO,
    CAMPO, ONDAS_PULSANTES, PRISAO, QUEDA, IMPULSO, GENERICO,
    TEMPO_PARADO, TEMPO_ACELERADO, REVERSAO, DISTORCAO_DIMENSIONAL,
    GRAVIDADE, MULTIPLICACAO, ILUSAO, CORRENTES, RAIO_EM_CADEIA,
    NEVASCA, METEOROS, TROCA_POSICAO, MARTELO_CELESTE, ABSORCAO
}

data class CoreografiaCombate(
    val movimento: MovimentoCombate,
    val ecos: Int,
    val camadas: Int,
    val intensidade: Float,
    val area: Boolean,
    val duracaoMs: Int
)

object CombatMotionLibrary {
    fun interpretar(skill: AtaqueCriatura?, efeito: String = "", log: String = ""): CoreografiaCombate {
        val texto = listOfNotNull(
            skill?.nome, skill?.descricao, skill?.elemento, skill?.tipoDano,
            skill?.categoria, skill?.efeitos?.joinToString(" "), efeito, log
        ).joinToString(" ").lowercase()

        val movimento = when {
            listOf("parada do instante", "congela o tempo", "tempo para", "paralisa o tempo", "distorção temporal", "eco temporal").any(texto::contains) -> MovimentoCombate.TEMPO_PARADO
            listOf("reversão temporal", "reverte o tempo", "volta no tempo", "retrocede o tempo").any(texto::contains) -> MovimentoCombate.REVERSAO
            listOf("aceleração temporal", "acelera o tempo", "tempo acelerado").any(texto::contains) -> MovimentoCombate.TEMPO_ACELERADO
            listOf("dobra dimensional", "rasgo dimensional", "fenda dimensional", "rasga a dimensão").any(texto::contains) -> MovimentoCombate.DISTORCAO_DIMENSIONAL
            listOf("gravidade", "peso esmagador", "campo gravitacional").any(texto::contains) -> MovimentoCombate.GRAVIDADE
            listOf("multiplica", "clones", "réplicas", "duplicatas").any(texto::contains) -> MovimentoCombate.MULTIPLICACAO
            listOf("ilusão", "ilusao", "miragem", "imagem falsa").any(texto::contains) -> MovimentoCombate.ILUSAO
            listOf("correntes", "algemas", "grilhões", "elos").any(texto::contains) -> MovimentoCombate.CORRENTES
            listOf("raios em cadeia", "relâmpagos saltam", "descarga encadeada").any(texto::contains) -> MovimentoCombate.RAIO_EM_CADEIA
            listOf("nevasca", "tempestade de gelo", "flocos congelantes").any(texto::contains) -> MovimentoCombate.NEVASCA
            listOf("meteoros", "chuva de estrelas", "bombardeio celeste").any(texto::contains) -> MovimentoCombate.METEOROS
            listOf("troca de posição", "troca de lugar", "inverte posições").any(texto::contains) -> MovimentoCombate.TROCA_POSICAO
            listOf("martelo celeste", "martelo colossal", "impacto de cima").any(texto::contains) -> MovimentoCombate.MARTELO_CELESTE
            listOf("absorve magia", "absorção de magia", "devora energia").any(texto::contains) -> MovimentoCombate.ABSORCAO
            listOf("teleport", "teletrans", "desaparece", "surge atrás", "dobra o espaço").any(texto::contains) -> MovimentoCombate.TELEPORTE
            listOf("investida", "avança violentamente", "carga brutal", "atropela").any(texto::contains) -> MovimentoCombate.INVESTIDA
            listOf("dash", "avanço rápido", "disparo", "arrancada", "velocidade extrema").any(texto::contains) -> MovimentoCombate.DASH
            listOf("salta", "salto", "pula", "mergulha do alto", "ataque aéreo").any(texto::contains) -> MovimentoCombate.SALTO
            listOf("gira", "rotação", "rodopia", "turbilhão", "espiral").any(texto::contains) -> MovimentoCombate.GIRO
            listOf("recu", "afasta-se", "esquiva para trás", "retirada").any(texto::contains) -> MovimentoCombate.RECUO
            listOf("voa", "voo", "asa", "rasante", "planando").any(texto::contains) -> MovimentoCombate.VOAR
            listOf("flutua", "levita", "antigravidade", "suspende no ar").any(texto::contains) -> MovimentoCombate.FLUTUAR
            listOf("canaliza", "concentra energia", "carrega energia", "acumula poder").any(texto::contains) -> MovimentoCombate.CANALIZAR
            listOf("cura", "regenera", "restaura vida", "fecha feridas", "purifica").any(texto::contains) -> MovimentoCombate.CURA
            listOf("drena", "suga energia", "rouba vida", "absorve vitalidade").any(texto::contains) -> MovimentoCombate.DRENAGEM
            listOf("invoca", "convoca", "chama um familiar", "cria um servo").any(texto::contains) -> MovimentoCombate.INVOCACAO
            listOf("transforma", "metamorfose", "muda de forma", "armadura viva").any(texto::contains) -> MovimentoCombate.TRANSFORMACAO
            listOf("barreira", "parede de energia", "muralha", "cúpula protetora").any(texto::contains) -> MovimentoCombate.BARREIRA
            listOf("escudo", "bloqueia", "protege", "defesa absoluta").any(texto::contains) -> MovimentoCombate.ESCUDO
            listOf("contra-ataque", "revida", "aparar e responder", "retalia").any(texto::contains) -> MovimentoCombate.CONTRA_ATAQUE
            listOf("perfura", "estocada", "lança", "projétil perfurante", "atravessa").any(texto::contains) -> MovimentoCombate.PERFURACAO
            listOf("chuva de", "chovem", "meteoros", "fragmentos caem").any(texto::contains) -> MovimentoCombate.CHUVA
            listOf("coluna", "pilar", "ergue-se do chão", "explosão vertical").any(texto::contains) -> MovimentoCombate.COLUNA
            listOf("explos", "detona", "detonação", "implos").any(texto::contains) -> MovimentoCombate.EXPLOSAO
            listOf("onda", "pulso", "onda de choque", "maré de energia").any(texto::contains) -> MovimentoCombate.ONDA
            listOf("rajada", "sopro", "jato", "feixe contínuo", "laser").any(texto::contains) -> MovimentoCombate.RAJADA
            listOf("prisão", "aprisiona", "imobiliza", "raízes prendem", "correntes").any(texto::contains) -> MovimentoCombate.PRISAO
            listOf("queda", "esmaga de cima", "impacto descendente", "cai sobre").any(texto::contains) -> MovimentoCombate.QUEDA
            listOf("campo", "aura", "zona", "área ao redor", "domínio").any(texto::contains) -> MovimentoCombate.CAMPO
            listOf("corte", "talho", "golpe de espada", "lâmina", "fatia").any(texto::contains) -> MovimentoCombate.CORTE
            listOf("combo", "sequência de golpes", "golpes consecutivos").any(texto::contains) -> MovimentoCombate.COMBO
            listOf("dois golpes", "golpe duplo", "ataque duplo").any(texto::contains) -> MovimentoCombate.GOLPE_DUPLO
            listOf("soco", "martelo", "impacto", "pancada", "golpe físico").any(texto::contains) -> MovimentoCombate.IMPULSO
            texto.isNotBlank() -> MovimentoCombate.GENERICO
            else -> MovimentoCombate.GENERICO
        }

        val categoria = skill?.categoria.orEmpty().uppercase()
        val intensidade = when (categoria) {
            "SUPREMO", "LENDARIO", "LENDÁRIO" -> 1.9f
            "DEVASTADOR" -> 1.55f
            "PODEROSO" -> 1.3f
            else -> 1f
        } * if ((skill?.turnosCarregamento ?: 0) > 0) 1.18f else 1f

        val area = movimento in setOf(
            MovimentoCombate.ONDA, MovimentoCombate.CHUVA, MovimentoCombate.COLUNA,
            MovimentoCombate.EXPLOSAO, MovimentoCombate.CAMPO, MovimentoCombate.BARREIRA,
            MovimentoCombate.NEVASCA, MovimentoCombate.METEOROS, MovimentoCombate.RAIO_EM_CADEIA,
            MovimentoCombate.DISTORCAO_DIMENSIONAL, MovimentoCombate.GRAVIDADE,
            MovimentoCombate.PRISAO, MovimentoCombate.INVOCACAO, MovimentoCombate.TRANSFORMACAO
        )
        return CoreografiaCombate(
            movimento = movimento,
            ecos = when (movimento) {
                MovimentoCombate.COMBO -> 5
                MovimentoCombate.GOLPE_DUPLO -> 2
                MovimentoCombate.DASH, MovimentoCombate.TELEPORTE -> 3
                MovimentoCombate.GIRO, MovimentoCombate.CHUVA, MovimentoCombate.METEOROS, MovimentoCombate.RAIO_EM_CADEIA -> 8
                MovimentoCombate.MULTIPLICACAO, MovimentoCombate.ILUSAO -> 6
                else -> 4
            },
            camadas = if (area) 4 else 2,
            intensidade = intensidade,
            area = area,
            duracaoMs = if (intensidade > 1.5f) 1150 else 850
        )
    }

    fun modifier(state: CombatState): Modifier = Modifier.composed {
        val skill = remember(state.log.size, state.efeitoVisualAtual) {
            val last = state.log.lastOrNull().orEmpty()
            (state.hero.attacks + state.enemy.attacks).firstOrNull {
                it.nome.isNotBlank() && last.contains(it.nome, ignoreCase = true)
            }
        }
        val coreografia = remember(skill, state.efeitoVisualAtual, state.log.size) {
            interpretar(skill, state.efeitoVisualAtual, state.log.lastOrNull().orEmpty())
        }
        val progresso = remember { Animatable(0f) }
        LaunchedEffect(state.log.size, state.efeitoVisualAtual) {
            if (state.log.isNotEmpty()) {
                progresso.snapTo(0f)
                progresso.animateTo(1f, tween(coreografia.duracaoMs))
            }
        }
        val p = progresso.value
        Modifier.drawWithContent {
            drawContent()
            if (p <= 0f || p >= 1f) return@drawWithContent

            val inimigoAtacou = state.log.lastOrNull()?.contains(state.enemy.name, true) == true &&
                state.log.lastOrNull()?.contains(state.hero.name, true) != true
            val inicio = Offset(size.width * if (inimigoAtacou) .76f else .23f, size.height * .54f)
            val fim = Offset(size.width * if (inimigoAtacou) .23f else .76f, size.height * .54f)
            val centro = Offset((inicio.x + fim.x) / 2f, size.height * .52f)
            val alcance = size.minDimension * .34f * coreografia.intensidade
            val alpha = (1f - p).coerceIn(0f, 1f)
            val cor = when (coreografia.movimento) {
                MovimentoCombate.TEMPO_PARADO, MovimentoCombate.TEMPO_ACELERADO, MovimentoCombate.REVERSAO -> Color(0xFF74E9D4)
                MovimentoCombate.DISTORCAO_DIMENSIONAL, MovimentoCombate.TROCA_POSICAO -> Color(0xFFAB8CFF)
                MovimentoCombate.GRAVIDADE, MovimentoCombate.MARTELO_CELESTE -> Color(0xFFDAA66D)
                MovimentoCombate.CORRENTES -> Color(0xFF9C85D6)
                MovimentoCombate.RAIO_EM_CADEIA -> Color(0xFFFFEA65)
                MovimentoCombate.NEVASCA -> Color(0xFF9AEAFF)
                MovimentoCombate.METEOROS -> Color(0xFFFF9B63)
                MovimentoCombate.CURA -> Color(0xFF72F0A0)
                MovimentoCombate.DRENAGEM, MovimentoCombate.PRISAO -> Color(0xFFB66BFF)
                MovimentoCombate.BARREIRA, MovimentoCombate.ESCUDO -> Color(0xFF72D9FF)
                MovimentoCombate.EXPLOSAO -> Color(0xFFFF9955)
                else -> Color(0xFFFFD78A)
            }
            val corBrilho = Color.White

            fun linha(a: Offset, b: Offset, largura: Float = 3f) {
                drawLine(cor.copy(alpha = alpha * .85f), a, b, largura * coreografia.intensidade)
            }
            fun aro(c: Offset, r: Float, largura: Float = 2f) {
                drawCircle(cor.copy(alpha = alpha * .65f), r.coerceAtLeast(1f), c, style = Stroke(largura))
            }

            when (coreografia.movimento) {
                MovimentoCombate.AVANCO, MovimentoCombate.INVESTIDA,
                MovimentoCombate.DASH, MovimentoCombate.RECUO -> {
                    val direcao = if (coreografia.movimento == MovimentoCombate.RECUO) -1f else 1f
                    for (i in 0 until coreografia.ecos) {
                        val desloc = (i + 1) * size.width * .035f * (1f - p)
                        val x = inicio.x + (fim.x - inicio.x) * p - desloc * direcao
                        linha(Offset(x, centro.y - i * 3f), Offset(x - 24f, centro.y + i * 3f), 4f - i * .25f)
                    }
                    aro(if (p < .55f) inicio else fim, 12f + p * 20f)
                }
                MovimentoCombate.SALTO, MovimentoCombate.VOAR, MovimentoCombate.FLUTUAR,
                MovimentoCombate.QUEDA -> {
                    val subida = if (coreografia.movimento == MovimentoCombate.QUEDA) -1f else 1f
                    val arco = Path().apply {
                        moveTo(inicio.x, centro.y + 25f * subida)
                        cubicTo(centro.x - 35f, centro.y - alcance * subida, centro.x + 35f, centro.y - alcance * subida, fim.x, centro.y + 18f * subida)
                    }
                    drawPath(arco, cor.copy(alpha = alpha), style = Stroke(4f * coreografia.intensidade))
                    for (i in 0 until 5) {
                        val x = inicio.x + (fim.x - inicio.x) * (i / 5f)
                        aro(Offset(x, centro.y - sin((i / 5f * PI).toFloat()) * alcance * .35f), 4f + 4f * p, 1.5f)
                    }
                }
                MovimentoCombate.GIRO, MovimentoCombate.CORTE, MovimentoCombate.GOLPE_DUPLO,
                MovimentoCombate.COMBO, MovimentoCombate.CONTRA_ATAQUE -> {
                    for (i in 0 until coreografia.ecos) {
                        val t = (p + i.toFloat() / coreografia.ecos) % 1f
                        val y = centro.y + (i - coreografia.ecos / 2f) * 8f
                        val path = Path().apply {
                            moveTo(inicio.x, y + 30f * (1f - t))
                            quadraticTo(centro.x, y - 55f * coreografia.intensidade, fim.x, y - 18f * (1f - t))
                        }
                        drawPath(path, (if (i % 2 == 0) cor else corBrilho).copy(alpha = alpha), style = Stroke(3.5f))
                    }
                    if (coreografia.movimento == MovimentoCombate.GIRO) {
                        for (i in 0..2) aro(centro, alcance * (.25f + i * .16f), 2f)
                    }
                }
                MovimentoCombate.TELEPORTE -> {
                    for (i in 0 until coreografia.ecos) {
                        val pos = if (i % 2 == 0) inicio else fim
                        drawCircle(cor.copy(alpha = alpha * (1f - i * .12f)), 18f + i * 8f, pos, style = Stroke(2f))
                    }
                    linha(inicio, fim, 2f)
                    aro(centro, alcance * .45f, 3f)
                }
                MovimentoCombate.TEMPO_PARADO, MovimentoCombate.TEMPO_ACELERADO,
                MovimentoCombate.REVERSAO, MovimentoCombate.DISTORCAO_DIMENSIONAL,
                MovimentoCombate.GRAVIDADE, MovimentoCombate.MULTIPLICACAO,
                MovimentoCombate.ILUSAO, MovimentoCombate.CORRENTES,
                MovimentoCombate.CANALIZAR, MovimentoCombate.CAMPO,
                MovimentoCombate.ONDAS_PULSANTES, MovimentoCombate.PRISAO -> {
                    for (i in 0 until coreografia.camadas + 2) {
                        aro(centro, alcance * ((i + 1f) / (coreografia.camadas + 2f)) * p.coerceAtLeast(.12f), 2f)
                    }
                    for (i in 0 until 12) {
                        val ang = i * 2.0 * PI / 12.0 + p * 2.0
                        drawCircle(cor, 3f, Offset(centro.x + cos(ang).toFloat() * alcance * .65f, centro.y + sin(ang).toFloat() * alcance * .65f))
                    }
                }
                MovimentoCombate.BARREIRA, MovimentoCombate.ESCUDO -> {
                    val w = alcance * .55f
                    val h = alcance * .75f
                    val shield = Path().apply {
                        moveTo(centro.x, centro.y - h)
                        lineTo(centro.x + w, centro.y - h * .55f)
                        lineTo(centro.x + w * .75f, centro.y + h * .55f)
                        lineTo(centro.x, centro.y + h)
                        lineTo(centro.x - w * .75f, centro.y + h * .55f)
                        lineTo(centro.x - w, centro.y - h * .55f)
                        close()
                    }
                    drawPath(shield, cor.copy(alpha = alpha * .8f), style = Stroke(4f))
                    aro(centro, w * .8f, 1.5f)
                }
                MovimentoCombate.CURA, MovimentoCombate.INVOCACAO,
                MovimentoCombate.TRANSFORMACAO -> {
                    for (i in 0 until 16) {
                        val x = centro.x + cos(i * PI / 8).toFloat() * alcance * .5f
                        val y = centro.y + sin(i * PI / 8).toFloat() * alcance * .35f - p * 35f
                        drawCircle(cor.copy(alpha = alpha), 2.5f + (i % 3), Offset(x, y))
                    }
                    aro(centro, alcance * .3f, 2f)
                }
                MovimentoCombate.DRENAGEM -> {
                    for (i in 0..5) {
                        val path = Path().apply {
                            moveTo(fim.x, fim.y - i * 7f)
                            cubicTo(centro.x + 45f, centro.y - 50f, centro.x - 30f, centro.y + 45f, inicio.x, inicio.y)
                        }
                        drawPath(path, cor.copy(alpha = alpha), style = Stroke(2.5f))
                    }
                }
                MovimentoCombate.CHUVA, MovimentoCombate.COLUNA,
                MovimentoCombate.NEVASCA, MovimentoCombate.METEOROS,
                MovimentoCombate.RAIO_EM_CADEIA, MovimentoCombate.MARTELO_CELESTE,
                MovimentoCombate.TROCA_POSICAO, MovimentoCombate.ABSORCAO,
                MovimentoCombate.ONDA, MovimentoCombate.RAJADA,
                MovimentoCombate.PERFURACAO, MovimentoCombate.IMPULSO,
                MovimentoCombate.EXPLOSAO, MovimentoCombate.GENERICO -> {
                    if (coreografia.area || coreografia.movimento == MovimentoCombate.EXPLOSAO) {
                        for (i in 0..3) aro(centro, alcance * (p + i * .18f), 2.5f - i * .3f)
                    }
                    for (i in 0 until 14) {
                        val x = centro.x + cos(i * 2.0 * PI / 14.0).toFloat() * alcance * (p + .15f)
                        val y = centro.y + sin(i * 2.0 * PI / 14.0).toFloat() * alcance * (p + .15f)
                        linha(centro, Offset(x, y), 2f)
                    }
                }
            }
        }
    }
}
