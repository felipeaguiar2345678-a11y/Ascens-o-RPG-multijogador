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
    CONTRA_ATAQUE, DEFESA, BLOQUEIO, ESQUIVA, APARO, CURA, DRENAGEM, INVOCACAO, TRANSFORMACAO,
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
            listOf("esquivou", "esquiva", "desviou do golpe", "evitou o ataque", "rolou para longe").any(texto::contains) -> MovimentoCombate.ESQUIVA
            listOf("aparou", "aparar", "parry", "defletiu", "desviou a lâmina").any(texto::contains) -> MovimentoCombate.APARO
            listOf("bloqueou", "bloqueio", "golpe bloqueado", "ataque bloqueado").any(texto::contains) -> MovimentoCombate.BLOQUEIO
            listOf("entrou em defesa", "postura defensiva", "se preparou para defender", "defendeu", "defesa").any(texto::contains) -> MovimentoCombate.DEFESA
            listOf("barreira", "parede de energia", "muralha", "cúpula protetora").any(texto::contains) -> MovimentoCombate.BARREIRA
            listOf("escudo", "protege", "defesa absoluta").any(texto::contains) -> MovimentoCombate.ESCUDO
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
            camadas = (if (area) 4 else 2) + if (intensidade >= 1.55f) 2 else if (intensidade >= 1.3f) 1 else 0,
            intensidade = intensidade,
            area = area,
            duracaoMs = when {
                intensidade > 1.5f -> 1320
                movimento in setOf(MovimentoCombate.CANALIZAR, MovimentoCombate.TRANSFORMACAO, MovimentoCombate.INVOCACAO) -> 1120
                movimento in setOf(MovimentoCombate.TELEPORTE, MovimentoCombate.DASH, MovimentoCombate.INVESTIDA) -> 760
                movimento in setOf(MovimentoCombate.COMBO, MovimentoCombate.GOLPE_DUPLO, MovimentoCombate.RAIO_EM_CADEIA) -> 1040
                else -> 900
            }
        )
    }

    fun modifier(state: CombatState): Modifier = Modifier.composed {
        val habilidadeCarregada = state.carregandoHabilidadeJogador ?: state.carregandoHabilidadeInimigo
        val habilidadeLog = CombatAnimationEngine.encontrarHabilidade(state)
        val habilidadeVisual = habilidadeCarregada ?: habilidadeLog
        val perfil = remember(habilidadeVisual, state.efeitoVisualAtual, state.log.size) {
            CombatAnimationEngine.interpretar(habilidadeVisual, state.efeitoVisualAtual, state.log.lastOrNull().orEmpty())
        }
        val progresso = remember { Animatable(0f) }
        LaunchedEffect(
            habilidadeCarregada?.nome,
            state.turnosRestantesCarregamentoJogador,
            state.turnosRestantesCarregamentoInimigo,
            state.efeitoVisualAtual,
            state.log.size
        ) {
            if (habilidadeCarregada != null) {
                progresso.snapTo(0f)
                while (true) {
                    progresso.animateTo(1f, animationSpec = tween(950))
                    progresso.snapTo(0f)
                }
            } else if (state.efeitoVisualAtual.isNotBlank() || state.log.size > 1) {
                progresso.snapTo(0f)
                progresso.animateTo(1f, animationSpec = tween(760))
            } else {
                progresso.snapTo(0f)
            }
        }
        val p = progresso.value
        Modifier.drawWithContent {
            drawContent()
            if (habilidadeCarregada != null) {
                val carregandoInimigo = state.carregandoHabilidadeInimigo != null
                val centro = Offset(size.width * if (carregandoInimigo) .76f else .24f, size.height * .52f)
                val alcance = size.minDimension * (.10f + .19f * p) * perfil.intensidade
                val pulso = .72f + .28f * sin((p * 2f * PI).toFloat())
                val alpha = (.48f + .42f * pulso).coerceIn(0f, 1f)
                val prim = perfil.corPrimaria.copy(alpha = alpha)
                val sec = perfil.corSecundaria.copy(alpha = alpha * .82f)
                fun aroCarga(r: Float, cor: Color = prim, largura: Float = 2.4f) {
                    drawCircle(cor, r.coerceAtLeast(1f), centro, style = Stroke(width = largura))
                }
                // A preparação tem identidade própria por família elemental.
                when (perfil.familia) {
                    FamiliaAnimacao.FOGO -> {
                        for (i in 0..8) {
                            val ang = (i * 2.0 * PI / 9.0 + p * 5.0)
                            val r = alcance * (.58f + .25f * sin((p * 2f * PI + i).toFloat()).let { (it + 1f) / 2f })
                            val pos = Offset(centro.x + cos(ang).toFloat() * r, centro.y + sin(ang).toFloat() * r)
                            drawCircle(if (i % 2 == 0) prim else sec, 3f + 4f * p, pos)
                        }
                        aroCarga(alcance * .72f, sec, 3f)
                    }
                    FamiliaAnimacao.GELO -> {
                        aroCarga(alcance, sec, 2.5f)
                        for (i in 0..5) {
                            val ang = (i * PI / 3.0 + p * .7).toFloat()
                            val x = centro.x + cos(ang) * alcance
                            val y = centro.y + sin(ang) * alcance
                            drawLine(sec, Offset(x - 7f, y - 7f), Offset(x + 7f, y + 7f), 3f)
                            drawLine(sec, Offset(x - 7f, y + 7f), Offset(x + 7f, y - 7f), 3f)
                        }
                    }
                    FamiliaAnimacao.RAIO -> {
                        for (i in 0..5) {
                            val ang = (i * PI / 3.0 + p * 3.0).toFloat()
                            val fim = Offset(centro.x + cos(ang) * alcance, centro.y + sin(ang) * alcance)
                            val meio = Offset((centro.x + fim.x) / 2f + sin(ang * 4f) * 12f, (centro.y + fim.y) / 2f)
                            val caminho = Path().apply { moveTo(centro.x, centro.y); lineTo(meio.x, meio.y); lineTo(fim.x, fim.y) }
                            drawPath(caminho, sec, style = Stroke(width = 2.5f + p * 2f))
                        }
                    }
                    FamiliaAnimacao.GRAVIDADE, FamiliaAnimacao.ESPACO -> {
                        for (i in 0..3) aroCarga(alcance * (.45f + i * .22f), if (i % 2 == 0) prim else sec, 2f)
                        for (i in 0..7) {
                            val ang = (i * PI / 4.0 - p * 2.0).toFloat()
                            val r = alcance * (1.15f - p * .28f)
                            drawCircle(sec, 3f + p * 2f, Offset(centro.x + cos(ang) * r, centro.y + sin(ang) * r))
                        }
                    }
                    FamiliaAnimacao.SOMBRA, FamiliaAnimacao.VENENO -> {
                        aroCarga(alcance, prim, 5f)
                        aroCarga(alcance * .62f, sec, 2f)
                        for (i in 0..9) {
                            val ang = (i * 2.0 * PI / 10.0 - p * 2.5).toFloat()
                            drawCircle(if (i % 2 == 0) prim else sec, 3f + 3f * p, Offset(centro.x + cos(ang) * alcance, centro.y + sin(ang) * alcance))
                        }
                    }
                    FamiliaAnimacao.LUZ, FamiliaAnimacao.TEMPO -> {
                        for (i in 0..3) aroCarga(alcance * (.4f + i * .2f), if (i % 2 == 0) sec else prim, 2f)
                        for (i in 0..11) {
                            val ang = (i * 2.0 * PI / 12.0 + p * 1.8).toFloat()
                            val r = alcance * (.75f + .2f * sin((p * PI * 2f).toFloat()))
                            drawCircle(sec, 2.5f + p * 2f, Offset(centro.x + cos(ang) * r, centro.y + sin(ang) * r))
                        }
                    }
                    else -> {
                        aroCarga(alcance, prim, 3f)
                        aroCarga(alcance * .58f, sec, 1.8f)
                        for (i in 0..7) {
                            val ang = (i * PI / 4.0 + p * 2.2).toFloat()
                            drawCircle(sec, 3f + p * 2f, Offset(centro.x + cos(ang) * alcance, centro.y + sin(ang) * alcance))
                        }
                    }
                }
                // Núcleo cresce conforme a energia se concentra.
                drawCircle(sec.copy(alpha = .18f + p * .22f), 8f + alcance * .20f, centro)
                drawCircle(prim, 3f + p * 5f, centro)
                return@drawWithContent
            }
            if (p <= 0f || p >= 1f) return@drawWithContent
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
                drawLine(perfil.corSecundaria.copy(alpha = (1f - p) * .8f), Offset(inicioX, trilhaY), Offset(orbX, trilhaY), strokeWidth = 5f * (1f - p) + 1f)
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
