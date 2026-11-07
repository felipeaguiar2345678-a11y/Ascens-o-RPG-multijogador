package br.com.ascensaodosoberano

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.EmailAuthProvider
import com.google.firebase.auth.FirebaseUser
import kotlinx.coroutines.tasks.await

object AutenticacaoJogador {

    private val autenticacao: FirebaseAuth
        get() = FirebaseAuth.getInstance()

    val jogadorAtual: FirebaseUser?
        get() = autenticacao.currentUser

    // Entrar como visitante
    suspend fun entrarComoVisitante(): FirebaseUser {
        val atual = autenticacao.currentUser

        if (atual != null) return atual

        return autenticacao.signInAnonymously()
            .await()
            .user ?: error("Não foi possível criar a conta de visitante.")
    }

    // Criar conta com e-mail e senha
    suspend fun criarConta(
        email: String,
        senha: String
    ): FirebaseUser {
        return autenticacao
            .createUserWithEmailAndPassword(email.trim(), senha)
            .await()
            .user ?: error("Não foi possível criar a conta.")
    }

    // Entrar em conta existente
    suspend fun entrar(
        email: String,
        senha: String
    ): FirebaseUser {
        return autenticacao
            .signInWithEmailAndPassword(email.trim(), senha)
            .await()
            .user ?: error("Não foi possível entrar.")
    }

    // Transformar conta visitante em conta permanente
    suspend fun vincularConta(
        email: String,
        senha: String
    ): FirebaseUser {
        val atual = autenticacao.currentUser
            ?: error("Nenhum jogador está conectado.")

        if (!atual.isAnonymous) {
            error("Esta conta já é permanente.")
        }

        val credencial = EmailAuthProvider.getCredential(
            email.trim(),
            senha
        )

        return atual.linkWithCredential(credencial)
            .await()
            .user ?: error("Não foi possível vincular a conta.")
    }

    // Recuperar senha
    suspend fun recuperarSenha(email: String) {
        autenticacao.sendPasswordResetEmail(email.trim()).await()
    }

    // Sair da conta
    fun sair() {
        autenticacao.signOut()
    }
}