package br.com.ascensaodosoberano

import androidx.compose.runtime.*
import androidx.compose.material3.*
import androidx.compose.foundation.layout.*
import androidx.compose.ui.Modifier
import kotlinx.coroutines.launch

@Composable
fun FluxoInicial() {

    // Sempre mostra a seleção de modo; uma sessão já autenticada pode continuar sem novo login.
    var tela by remember {
        mutableStateOf("inicio")
    }

    var mensagem by remember { mutableStateOf("") }
    var carregando by remember { mutableStateOf(false) }
    var abrirMultiplayerAoEntrar by remember { mutableStateOf(false) }
    var abrirOffline by remember { mutableStateOf(false) }

    val escopo = rememberCoroutineScope()

    fun executar(
        cadastro: Boolean,
        email: String,
        senha: String
    ) {
        escopo.launch {
            carregando = true
            mensagem = ""

            try {
                if (cadastro) {
                    AutenticacaoJogador.criarConta(email, senha)
                } else {
                    AutenticacaoJogador.entrar(email, senha)
                }

                tela = "jogo"

            } catch (e: Exception) {
                mensagem = e.localizedMessage
                    ?: "Não foi possível realizar o acesso."
            } finally {
                carregando = false
            }
        }
    }

    when (tela) {

        "inicio" -> TelaInicial(
            onEntrar = {
                mensagem = ""
                if (AutenticacaoJogador.jogadorAtual != null) {
                    abrirOffline = false
                    abrirMultiplayerAoEntrar = false
                    tela = "jogo"
                } else {
                    tela = "entrar"
                }
            },
            onCriarConta = {
                mensagem = ""
                tela = "cadastro"
            },
            onVisitante = {
                escopo.launch {
                    carregando = true
                    mensagem = ""

                    try {
                        AutenticacaoJogador.entrarComoVisitante()
                        tela = "jogo"
                    } catch (e: Exception) {
                        mensagem = e.localizedMessage
                            ?: "Não foi possível entrar como visitante."
                    } finally {
                        carregando = false
                    }
                }
            },
            onOffline = {
                abrirOffline = true
                abrirMultiplayerAoEntrar = false
                tela = "jogo"
            },
            onMultiplayer = {
                abrirOffline = false
                abrirMultiplayerAoEntrar = true
                mensagem = "Entre na sua conta para acessar o multiplayer."
                tela = "entrar"
            }
        )

        "entrar" -> TelaAcesso(
            cadastro = false,
            mensagem = mensagem,
            carregando = carregando,
            onConfirmar = { email, senha ->
                executar(false, email, senha)
            },
            onVoltar = {
                tela = "inicio"
            },
            onRecuperarSenha = { email ->
                escopo.launch {
                    carregando = true
                    mensagem = ""

                    try {
                        AutenticacaoJogador.recuperarSenha(email)
                        mensagem = "E-mail de recuperação enviado."
                    } catch (e: Exception) {
                        mensagem = e.localizedMessage
                            ?: "Não foi possível enviar o e-mail."
                    } finally {
                        carregando = false
                    }
                }
            }
        )

        "cadastro" -> TelaAcesso(
            cadastro = true,
            mensagem = mensagem,
            carregando = carregando,
            onConfirmar = { email, senha ->
                executar(true, email, senha)
            },
            onVoltar = {
                tela = "inicio"
            },
            onRecuperarSenha = {}
        )

        else -> GameApp(
            abrirMultiplayerInicial = abrirMultiplayerAoEntrar,
            modoOffline = abrirOffline
        )
    }
}