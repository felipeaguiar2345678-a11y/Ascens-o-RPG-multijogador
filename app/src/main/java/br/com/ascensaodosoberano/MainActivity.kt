
package br.com.ascensaodosoberano

import androidx.compose.ui.text.input.PasswordVisualTransformation
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import java.io.File
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.background
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.LocalContext

import coil.compose.AsyncImage
import androidx.compose.ui.layout.ContentScale
import br.com.ascensaodosoberano.world.CriaturaGerada
import                                                         val resultadoArte = br.com.ascensaodosoberano.world.RepositorioCriaturas
                                                             .solicitarImagemOficialComAutorizacao(criaturaDaArena.id)
                                                         val criaturaAtualizada = resultadoArte.criatura
                                                         val urlArte = criaturaAtualizada.imagemDetalhadaCaminho
                                                             .ifBlank { criaturaAtualizada.imagemIconeCaminho }
                                                         if (urlArte.isBlank()) {
                                                             throw IllegalStateException("A arte foi solicitada, mas a URL oficial ainda não está disponível no catálogo.")
                                                         }
                                                         if (criaturaBatalhaSolo?.id == criaturaAtualizada.id) {
                                                             criaturaBatalhaSolo = criaturaComArteAtualizada
                                                         }
                                                         combat = combat?.let { atual ->
                                                             if (atual.enemy.name == criaturaDaArena.nome) {
                                                                 atual.copy(enemy = atual.enemy.copy(spriteUrl = urlArte))
                                                             } else atual
                                                         }
                                                         erroArteCriatura = ""
                                                    try {
                                                        br.com.ascensaodosoberano.world.RepositorioCriaturas
                                                            .solicitarImagemOficialComAutorizacao(criaturaDaArena.id)
                                                        val documento = FirebaseFirestore.getInstance()
                                                            .collection("criaturas")
                                                            .document(criaturaDaArena.id)
                                                            .get()
                                                            .await()
                                                        val urlArte = documento.getString("imagemDetalhadaCaminho")
                                                            .orEmpty()
                                                            .ifBlank {
                                                                documento.getString("imagemIconeCaminho").orEmpty()
                                                            }
                                                        if (urlArte.isBlank()) {
                                                            throw IllegalStateException("A arte oficial ainda não apareceu no catálogo.")
                                                        }
                                                        combat = combat?.let { atual ->
                                                            if (atual.enemy.name == criaturaDaArena.nome) {
                                                                atual.copy(enemy = atual.enemy.copy(spriteUrl = urlArte))
                                                            } else atual
                                                        }
                                                        erroArteCriatura = ""
                                                        message = "Arte oficial de ${criaturaDaArena.nome} recuperada para esta batalha."
                                                    } catch (erro: Exception) {
                                                        erroArteCriatura = erro.localizedMessage
                                                            ?: "Não foi possível recuperar a arte oficial."
                                                        message = erroArteCriatura
                                                    } finally {
                                                        arteCriaturaEmGeracao = false
                                                    }
                                                }
                                            }
                                        }
                                    },
                                    onCombo = if (allyBattleId != null && allyBattleSnapshot?.members?.any { it.uid != uidAtual && it.hero.isAlive } == true) ({
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) scope.launch {
                                            runCatching { allyBattleRepository.executarAcao(battleId, uid, "COMBO") }
                                                .onFailure { message = "Combo não sincronizado: ${it.localizedMessage}" }
                                        }
                                    }) else null,
                                    onRevive = if (allyBattleId != null && allyBattleSnapshot?.members?.any { it.uid != uidAtual && !it.hero.isAlive } == true) ({
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) scope.launch {
                                            runCatching { allyBattleRepository.executarAcao(battleId, uid, "REVIVER") }
                                                .onFailure { message = "Não foi possível reanimar: ${it.localizedMessage}" }
                                        }
                                    }) else null,

                                    onSkill = { skillId ->
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) {
                                            // A evolução só é concedida após a transação confirmar dano real.
                                            scope.launch {
                                                runCatching { allyBattleRepository.executarAcao(battleId, uid, "HABILIDADE:$skillId") }
                                                    .onSuccess { result ->
                                                        if (result.enemyDamage > 0 && result.skillId != null) {
                                                            val powerBefore = powerProfile
                                                            val powerAfter = PowerAwakeningEngine.recordPowerUse(
                                                                powerBefore,
                                                                result.skillId,
                                                                characterLevel = profile.level,
                                                                successful = true
                                                            )
                                                            if (powerAfter != powerBefore) {
                                                                powerProfile = powerAfter
                                                                salvarPerfil((characterProfile ?: profile).copy(
                                                                    powerProfile = powerAfter,
                                                                    inventory = playerInventory
                                                                ), "Erro ao salvar evolução da habilidade")
                                                            }
                                                            observePowerAction(
                                                                action = "Manifestou repetidamente a habilidade ${result.skillId}",
                                                                category = "habilidade_${result.skillId}",
                                                                intensity = 15,
                                                                origin = PowerOrigin.TRAINING,
                                                                tags = emptyList()
                                                            )
                                                        }
                                                    }
                                                    .onFailure { message = "Habilidade não sincronizada: ${it.localizedMessage}" }
                                            }
                                        } else {
                                            // Só registra evolução e treino quando a habilidade realmente causa dano.
                                            val updated = CombatSystem.playerUseSkill(state, skillId)
                                            val causouDano = updated.enemy.hp < state.enemy.hp
                                            combat = updated
                                            if (causouDano) {
                                                val powerBefore = powerProfile
                                                val powerAfter = PowerAwakeningEngine.recordPowerUse(
                                                    powerBefore,
                                                    skillId,
                                                    characterLevel = profile.level,
                                                    successful = true
                                                )
                                                if (powerAfter != powerBefore) {
                                                    powerProfile = powerAfter
                                                    val updatedProfile = (characterProfile ?: profile).copy(
                                                        powerProfile = powerAfter,
                                                        inventory = playerInventory
                                                    )
                                                    salvarPerfil(updatedProfile, "Erro ao salvar evolução da habilidade")
                                                }
                                                observePowerAction(
                                                    action = "Manifestou repetidamente a habilidade $skillId",
                                                    category = "habilidade_$skillId",
                                                    intensity = 15,
                                                    origin = PowerOrigin.TRAINING,
                                                    tags = emptyList()
                                                )
                                            }
                                        }
                                    },

                                    onSpecial = {
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) {
                                            scope.launch {
                                                runCatching { allyBattleRepository.executarAcao(battleId, uid, "ESPECIAL") }
                                                    .onFailure { message = "Especial não sincronizado: ${it.localizedMessage}" }
                                            }
                                        } else combat = CombatSystem.playerSpecial(state)
                                    },
                                    onContinueCharge = {
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) scope.launch {
                                            runCatching { allyBattleRepository.executarAcao(battleId, uid, "CONTINUAR_CARREGAMENTO") }
                                                .onFailure { message = "Carregamento não sincronizado: ${it.localizedMessage}" }
                                        } else combat = CombatSystem.playerContinueCharge(state)
                                    },
                                    onReleaseCharged = {
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) scope.launch {
                                            runCatching { allyBattleRepository.executarAcao(battleId, uid, "LIBERAR_CARREGAMENTO") }
                                                .onSuccess { result ->
                                                    if (result.enemyDamage > 0 && result.skillId != null) {
                                                        val powerBefore = powerProfile
                                                        val powerAfter = PowerAwakeningEngine.recordPowerUse(
                                                            powerBefore,
                                                            result.skillId,
                                                            characterLevel = profile.level,
                                                            successful = true
                                                        )
                                                        if (powerAfter != powerBefore) {
                                                            powerProfile = powerAfter
                                                            salvarPerfil((characterProfile ?: profile).copy(
                                                                powerProfile = powerAfter,
                                                                inventory = playerInventory
                                                            ), "Erro ao salvar evolução da habilidade")
                                                        }
                                                        observePowerAction(
                                                            action = "Liberou com sucesso a habilidade carregada ${result.skillId}",
                                                            category = "habilidade_${result.skillId}",
                                                            intensity = 20,
                                                            origin = PowerOrigin.TRAINING,
                                                            tags = emptyList()
                                                        )
                                                    }
                                                }
                                                .onFailure { message = "Ataque carregado não sincronizado: ${it.localizedMessage}" }
                                        } else {
                                            val skillId = state.carregandoHabilidadeJogador?.id
                                            val updated = CombatSystem.playerReleaseChargedSkill(state)
                                            val causouDano = updated.enemy.hp < state.enemy.hp
                                            combat = updated
                                            if (causouDano && skillId != null) {
                                                val powerBefore = powerProfile
                                                val powerAfter = PowerAwakeningEngine.recordPowerUse(
                                                    powerBefore,
                                                    skillId,
                                                    characterLevel = profile.level,
                                                    successful = true
                                                )
                                                if (powerAfter != powerBefore) {
                                                    powerProfile = powerAfter
                                                    val updatedProfile = (characterProfile ?: profile).copy(
                                                        powerProfile = powerAfter,
                                                        inventory = playerInventory
                                                    )
                                                    salvarPerfil(updatedProfile, "Erro ao salvar evolução da habilidade")
                                                }
                                                observePowerAction(
                                                    action = "Liberou com sucesso a habilidade carregada $skillId",
                                                    category = "habilidade_$skillId",
                                                    intensity = 20,
                                                    origin = PowerOrigin.TRAINING,
                                                    tags = emptyList()
                                                )
                                            }
                                        }
                                    },

                                    onAttack = {
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) {
                                            scope.launch {
                                                runCatching { allyBattleRepository.executarAcao(battleId, uid, "ATACAR") }
                                                    .onSuccess { result ->
                                                        if (result.enemyDamage > 0) {
                                                            observePowerAction(
                                                                action = "Realizou um ataque físico bem-sucedido",
                                                                category = "fisico",
                                                                intensity = 10
                                                            )
                                                        }
                                                    }
                                                    .onFailure { message = "Ação não sincronizada: ${it.localizedMessage}" }
                                            }
                                        } else {
                                            val updated = CombatSystem.playerAttack(state)
                                            combat = updated
                                            if (updated.enemy.hp < state.enemy.hp) {
                                                observePowerAction(
                                                    action = "Realizou um ataque físico bem-sucedido",
                                                    category = "fisico",
                                                    intensity = 10
                                                )
                                            }
                                        }
                                    },

                                    onDefend = {
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) {
                                            scope.launch {
                                                runCatching { allyBattleRepository.executarAcao(battleId, uid, "DEFENDER") }
                                                    .onFailure { message = "Ação não sincronizada: ${it.localizedMessage}" }
                                            }
                                        } else {
                                            val updatedCombat = CombatSystem.playerDefend(state)
                                            combat = updatedCombat
                                            hero = updatedCombat.hero
                                        }
                                    },

                                    onEnemyTurn = {
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) {
                                            scope.launch {
                                                runCatching { allyBattleRepository.executarAcao(battleId, uid, "INIMIGO") }
                                                    .onSuccess { result ->
                                                        val danoRecebido = result.heroDamageReceived
                                                        if (danoRecebido > 0) {
                                                            if (!modoOfflineAtivo) {
                                                                runCatching {
                                                                    CharacterProfileRepository().registrarDanoDefensivo(
                                                                        profileId = profile.id,
                                                                        danoReal = danoRecebido,
                                                                        vidaMaxima = state.hero.maxHp,
                                                                        rankInimigo = state.enemy.rank,
                                                                        inimigoChefe = state.enemy.isBoss
                                                                    )
                                                                }.onFailure { message = "Dano recebido, mas o treino defensivo não foi salvo: ${it.localizedMessage}" }
                                                            }
                                                            observePowerAction(
                                                                action = "Suportou $danoRecebido de dano durante o combate",
                                                                category = "defesa",
                                                                intensity = (danoRecebido * 20 / state.hero.maxHp.coerceAtLeast(1)).coerceIn(1, 20)
                                                            )
                                                        }
                                                    }
                                                    .onFailure { message = "Turno do inimigo não sincronizado: ${it.localizedMessage}" }
                                            }
                                        } else {
                                            val updated = CombatSystem.enemyAttack(state)
                                            combat = updated
                                            hero = updated.hero
                                            val companionState = updated.companion
                                            val companionLocal = InventorySystem.obterCompanheiroAtivo(playerInventory)
                                            if (companionState != null && companionLocal != null &&
                                                companionState.hp != companionLocal.hp
                                            ) {
                                                playerInventory = playerInventory.copy(
                                                    companions = playerInventory.companions.map { pet ->
                                                        if (pet.id == companionLocal.id) {
                                                            pet.copy(hp = companionState.hp.coerceIn(0, pet.maxHp))
                                                        } else pet
                                                    }
                                                )
                                                salvarPerfil(
                                                    (characterProfile ?: profile).copy(inventory = playerInventory),
                                                    "Não foi possível salvar a vida do companheiro"
                                                )
                                            }
                                            val danoRecebido = (state.hero.hp - updated.hero.hp).coerceAtLeast(0)
                                            if (danoRecebido > 0) {
                                                if (!modoOfflineAtivo) {
                                                    scope.launch {
                                                        runCatching {
                                                            CharacterProfileRepository().registrarDanoDefensivo(
                                                                profileId = profile.id,
                                                                danoReal = danoRecebido,
                                                                vidaMaxima = state.hero.maxHp,
                                                                rankInimigo = state.enemy.rank,
                                                                inimigoChefe = state.enemy.isBoss
                                                            )
                                                        }.onFailure { message = "Dano recebido, mas o treino defensivo não foi salvo: ${it.localizedMessage}" }
                                                    }
                                                }
                                                observePowerAction(
                                                    action = "Suportou $danoRecebido de dano durante o combate",
                                                    category = "defesa",
                                                    intensity = (danoRecebido * 20 / state.hero.maxHp.coerceAtLeast(1)).coerceIn(1, 20)
                                                )
                                            }
                                        }
                                    },

                                    onEndCombat = {
                                        val snapshot = allyBattleSnapshot
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        // Dá retorno imediato ao toque, inclusive enquanto recupera
                                        // a criatura compartilhada necessária para calcular o saque.
                                        message = "Encerrando combate e preparando o salvamento das recompensas..."
                                        if (snapshot?.status == "FINISHED" && battleId != null && uid != null) {
                                            scope.launch {
                                                if (criaturaBatalhaCompartilhada == null && snapshot.creatureId.isNotBlank()) {
                                                    criaturaBatalhaCompartilhada = runCatching {
                                                        RepositorioCriaturas.buscarCriaturaComImagem(snapshot.creatureId)
                                                    }.getOrNull()
                                                }
                                                finalizarCombate(state, battleId)
                                            }
                                        } else {
                                            finalizarCombate(state)
                                        }
                                    }
                                )
                            }
                        }
                    )
                }

                // MULTIPLAYER
                page == 1 && modoOfflineAtivo -> Column(
                    modifier = Modifier.fillMaxWidth().weight(1f).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Text("MODO OFFLINE", style = MaterialTheme.typography.titleLarge)
                    Text("Você está jogando sozinho. O personagem, os atributos e o inventário são salvos neste aparelho. Para entrar no multiplayer, volte ao menu e escolha o modo conectado.")
                }

                page == 1 -> Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {

                    Text(
                        "MULTIPLAYER",
                        style = MaterialTheme.typography.titleLarge
                    )

                    Text("Jogue a mesma aventura, compartilhe missões e vote nas decisões com seu grupo.")

                    if (allyGroup == null) {
                        Button(
                            onClick = {
                                scope.launch {
                                    runCatching {
                                        allyRepository.criarGrupo(uidAtual ?: error("Sessão inválida."), profile.name)
                                    }.onSuccess {
                                        allyGroupId = allyRepository.obterGrupoId(uidAtual!!)
                                        message = "Grupo criado! Seu código de convite está disponível abaixo."
                                    }.onFailure { message = "Não foi possível criar o grupo: ${it.localizedMessage}" }
                                }
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("CRIAR GRUPO") }

                        OutlinedButton(
                            onClick = { mostrarEntradaPorCodigo = true },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("ENTRAR NO GRUPO") }
                    }

                    allyGroup?.let { group ->
                        Card(modifier = Modifier.fillMaxWidth()) {
                            Column(
                                modifier = Modifier.padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Text("GRUPO (${group.members.size}/4)", style = MaterialTheme.typography.titleMedium)
                                if (group.leaderUid == uidAtual && group.inviteCode.isNotBlank()) {
                                    Text("Código de convite")
                                    Text(group.inviteCode, style = MaterialTheme.typography.headlineMedium)
                                    Text("Compartilhe esse código com seus amigos.")
                                }
                                val batalhaFinalizada = allyBattleSnapshot?.status == "FINISHED"
                                val todosReivindicaram = batalhaFinalizada && allyBattleSnapshot?.claimedUids?.containsAll(
                                    allyBattleSnapshot?.members?.map { it.uid }.orEmpty()
                                ) == true
                                val podeGerenciarGrupo = group.activeBattleId.isBlank() || todosReivindicaram
                                group.members.forEach { memberUid ->
                                    val presence = allyMemberPresences.firstOrNull { it.uid == memberUid }
                                    val memberName = group.memberNames[memberUid] ?: presence?.nome ?: "Aventureiro"
                                    Text(
                                        buildString {
                                            append(if (memberUid == group.leaderUid) "Líder: " else "Integrante: ")
                                            append(memberName)
                                            if (presence != null) {
                                                append(" · Nv. ${presence.nivel}")
                                                if (presence.vidaMaxima > 0) append(" · Vida ${presence.vida}/${presence.vidaMaxima}")
                                            } else {
                                                append(" · Offline")
                                            }
                                        }
                                    )
                                    if (podeGerenciarGrupo && group.leaderUid == uidAtual && memberUid != uidAtual) {
                                        TextButton(onClick = {
                                            scope.launch {
                                                runCatching {
                                                    allyRepository.removerMembro(uidAtual!!, memberUid)
                                                }.onSuccess { message = "$memberName removido do grupo." }
                                                    .onFailure { message = "Não foi possível remover: ${it.localizedMessage}" }
                                            }
                                        }) { Text("Remover") }
                                    }
                                }
                                val jaEstaNaBatalha = allyBattleSnapshot?.members?.any { it.uid == uidAtual } == true
                                if (group.activeBattleId.isNotBlank() && allyBattleSnapshot?.status == "ACTIVE" && !jaEstaNaBatalha) {
                                    Button(onClick = {
                                        scope.launch {
                                            runCatching {
                                                allyBattleRepository.entrarNaBatalha(group.activeBattleId, uidAtual ?: error("Sessão inválida."))
                                            }.onSuccess { message = "Você entrou na batalha compartilhada." }
                                                .onFailure { message = "Não foi possível entrar: ${it.localizedMessage}" }
                                        }
                                    }, modifier = Modifier.fillMaxWidth()) {
                                        Text("ENTRAR NO COMBATE")
                                    }
                                }
                                if (group.activeBattleId.isNotBlank() && allyBattleSnapshot?.status == "ACTIVE" && jaEstaNaBatalha) {
                                    Text("Batalha em andamento · ${allyBattleSnapshot?.state?.enemy?.name ?: "Criatura"}")
                                } else if (batalhaFinalizada) {
                                    val total = allyBattleSnapshot?.members?.size ?: 0
                                    val retiradas = allyBattleSnapshot?.claimedUids?.size ?: 0
                                    Text("Último combate concluído · Recompensas retiradas: $retiradas/$total")
                                }
                                if (podeGerenciarGrupo) TextButton(onClick = {
                                    scope.launch {
                                        runCatching {
                                            allyRepository.sairDoGrupo(group.id, uidAtual ?: error("Sessão inválida."))
                                        }.onSuccess {
                                            allyGroupId = null
                                            allyGroup = null
                                            allyMemberPresences = emptyList()
                                            message = if (group.leaderUid == uidAtual) "Grupo encerrado." else "Você saiu do grupo."
                                        }.onFailure { message = "Não foi possível sair: ${it.localizedMessage}" }
                                    }
                                }) { Text(if (group.leaderUid == uidAtual) "Encerrar grupo" else "Sair do grupo") }
                            }
                        }
                    }

                    if (allyGroup != null) GuildaPanel(uid = uidAtual.orEmpty(), nomeJogador = profile.name) { message = it }

                    if (allyGroup != null) MultiplayerExpandidoPanel(
                        uid = uidAtual.orEmpty(),
                        aoAtualizarPersonagem = {
                            scope.launch {
                                runCatching { CharacterProfileRepository().getForCurrentUser() }
                                    .onSuccess { characterProfile = it }
                                    .onFailure { message = "Recompensa registrada, mas não foi possível atualizar a ficha: ${it.localizedMessage}" }
                            }
                        }
                    ) { message = it }

                    if (allyGroup != null && allyInvites.isNotEmpty()) {
                        Text("CONVITES PARA ALLY", style = MaterialTheme.typography.titleMedium)
                        allyInvites.forEach { allyInvite ->
                            Card(modifier = Modifier.fillMaxWidth()) {
                                Column(modifier = Modifier.padding(10.dp)) {
                                    Text("${allyInvite.senderName} convidou você para um grupo.")
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Button(onClick = {
                                            scope.launch {
                                                runCatching {
                                                    allyRepository.aceitarConvite(allyInvite.id, uidAtual ?: error("Sessão inválida."), profile.name)
                                                    allyGroupId = allyRepository.obterGrupoId(uidAtual!!)
                                                }.onSuccess { message = "Você entrou no grupo Ally!" }
                                                    .onFailure { message = "Não foi possível aceitar: ${it.localizedMessage}" }
                                            }
                                        }) { Text("Aceitar") }
                                        TextButton(onClick = {
                                            scope.launch {
                                                runCatching {
                                                    allyRepository.recusarConvite(allyInvite.id, uidAtual ?: error("Sessão inválida."))
                                                }.onSuccess { message = "Convite recusado." }
                                                    .onFailure { message = "Não foi possível recusar: ${it.localizedMessage}" }
                                            }
                                        }) { Text("Recusar") }
                                    }
                                }
                            }
                        }
                    }

                    Text("TROCAS", style = MaterialTheme.typography.titleMedium)
                    Text("Negocie itens, materiais, equipamentos e ovos. XP e companheiros já eclodidos não podem ser trocados.")
                    minhasTrocas.filter { it.status == "PENDENTE" || it.status == "CONCLUIDA" }.forEach { troca ->
                        val uid = uidAtual.orEmpty()
                        val minhaOferta = troca.ofertas[uid] as? Map<*, *> ?: emptyMap<Any, Any>()
                        val outraOferta = troca.ofertas[if (uid == troca.remetenteUid) troca.destinatarioUid else troca.remetenteUid] as? Map<*, *> ?: emptyMap<Any, Any>()
                        Card(modifier = Modifier.fillMaxWidth()) {
                            Column(modifier = Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(if (uid == troca.remetenteUid) "Troca enviada" else "Troca recebida", style = MaterialTheme.typography.titleSmall)
                                Text("Status: ${if (troca.status == "CONCLUIDA") "Concluída" else "Aguardando confirmações"}")
                                Text("Sua oferta: ${(minhaOferta["itens"] as? List<*>)?.size ?: 0} tipo(s) de item, ${(minhaOferta["ovos"] as? List<*>)?.size ?: 0} ovo(s), ${(minhaOferta["equipamentos"] as? List<*>)?.size ?: 0} equipamento(s)")
                                Text("Oferta do outro jogador: ${(outraOferta["itens"] as? List<*>)?.size ?: 0} tipo(s) de item, ${(outraOferta["ovos"] as? List<*>)?.size ?: 0} ovo(s), ${(outraOferta["equipamentos"] as? List<*>)?.size ?: 0} equipamento(s)")
                                if (troca.status == "PENDENTE") {
                                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                        TextButton(onClick = {
                                            trocaParaEditar = troca.id
                                            itensSelecionadosTroca = emptySet(); ovosSelecionadosTroca = emptySet(); equipamentosSelecionadosTroca = emptySet()
                                            mostrarEditorTroca = true
                                        }) { Text("Montar minha oferta") }
                                        Button(enabled = uid !in troca.aceitoPor, onClick = { scope.launch { runCatching { tradeRepository.aceitar(troca.id) }.onSuccess { message = "Confirmação registrada. A troca será concluída quando ambos aceitarem." }.onFailure { message = "Não foi possível confirmar: ${it.localizedMessage}" } } }) { Text("Confirmar") }
                                    }
                                    TextButton(onClick = { scope.launch { runCatching { tradeRepository.cancelar(troca.id) }.onSuccess { message = "Troca cancelada." }.onFailure { message = "Não foi possível cancelar: ${it.localizedMessage}" } } }) { Text("Cancelar troca") }
                                }
                            }
                        }
                    }

                    Text("CAMPANHAS", style = MaterialTheme.typography.titleMedium)

                    Button(
                        onClick = {

                            scope.launch {
                                try {
                                    val auth = FirebaseAuth.getInstance()

                                    val user = auth.currentUser
                                        ?: auth.signInAnonymously().await().user

                                    if (user == null) {
                                        error("Autenticação falhou.")
                                    }

                                    val db = FirebaseFirestore.getInstance()

                                    val id = db.collection("campaigns")
                                        .document().id

                                    val inviteCode = (1..6)
                                        .map { ('A'..'Z').random() }
                                        .joinToString("")

                                    // Campanha e convite nascem juntos: não existe campanha
                                    // com código que ainda não tenha um documento de convite.
                                    val batch = db.batch()

                                    val campaignRef = db.collection("campaigns")
                                        .document(id)

                                    val inviteRef = db.collection("campaignInvites")
                                        .document(inviteCode)

                                    batch.set(
                                        campaignRef,
                                        mapOf(
                                            "ownerUid" to user.uid,
                                            "inviteCode" to inviteCode,
                                            "name" to "Campanha de ${profile.name}",
                                            "visibility" to "private",
                                            "members" to listOf(user.uid),
                                            "createdAt" to System.currentTimeMillis()
                                        )
                                    )

                                    batch.set(
                                        inviteRef,
                                        mapOf(
                                            "campaignId" to id,
                                            "inviteCode" to inviteCode,
                                            "ownerUid" to user.uid,
                                            "active" to true,
                                            "createdAt" to System.currentTimeMillis()
                                        )
                                    )

                                    batch.commit().await()

                                    invite = inviteCode
                                    message =
                                        "Campanha criada! Código: $inviteCode"

                                } catch (e: Exception) {
                                    message =
                                        "Erro online: ${e.localizedMessage}"
                                }
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("CRIAR CAMPANHA")
                    }

                    if (invite.isNotBlank()) {
                        Text("Código de convite: $invite")
                    }

                    OutlinedTextField(
                        value = code,
                        onValueChange = {
                            code = it
                        },
                        label = {
                            Text("Código do amigo")
                        },
                        modifier = Modifier.fillMaxWidth()
                    )

                    Button(
                        onClick = {

                            scope.launch {
                                try {
                                    val auth = FirebaseAuth.getInstance()

                                    val user = auth.currentUser
                                        ?: auth.signInAnonymously().await().user

                                    if (user == null) {
                                        error("Autenticação falhou.")
                                    }

                                    val db = FirebaseFirestore.getInstance()

                                    val inviteCode = code.trim().uppercase()
                                    if (inviteCode.length != 6 || inviteCode.any { !it.isLetterOrDigit() }) {
                                        error("Digite um código válido de 6 caracteres.")
                                    }

                                    // O convite é lido diretamente pelo código. Não fazemos
                                    // consulta/listagem da coleção campaigns, que é bloqueada.
                                    val inviteSnapshot = db.collection("campaignInvites")
                                        .document(inviteCode)
                                        .get()
                                        .await()

                                    if (!inviteSnapshot.exists() ||
                                        inviteSnapshot.getBoolean("active") != true
                                    ) {
                                        error("Código não encontrado ou convite desativado.")
                                    }

                                    val campaignId = inviteSnapshot.getString("campaignId")
                                        ?: error("Convite inválido: campanha não identificada.")

                                    // A prova do convite e a inclusão do membro são gravadas
                                    // em um único lote atômico, validado pelas regras Firestore.
                                    val batch = db.batch()
                                    val campaignRef = db.collection("campaigns")
                                        .document(campaignId)
                                    val joinProofRef = db.collection("campaignInvites")
                                        .document(inviteCode)
                                        .collection("joins")
                                        .document(user.uid)

                                    batch.set(
                                        joinProofRef,
                                        mapOf(
                                            "userUid" to user.uid,
                                            "campaignId" to campaignId,
                                            "inviteCode" to inviteCode,
                                            "joinedAt" to System.currentTimeMillis()
                                        )
                                    )

                                    batch.update(
                                        campaignRef,
                                        "members",
                                        com.google.firebase.firestore.FieldValue
                                            .arrayUnion(user.uid)
                                    )

                                    batch.commit().await()

                                    code = ""
                                    message = "Você entrou na campanha!"

                                } catch (e: Exception) {
                                    message =
                                        "Erro ao entrar: ${e.localizedMessage}"
                                }
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("ENTRAR NA CAMPANHA")
                    }
                }

                // MUNDO ABERTO
                page == 2 -> Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                ) {

                    if (showWorldMap) {

                        TelaMapaMundi(
                            localAtualId = profile.currentWorldPointId,
                            regiaoDisponivel = WorldRegion.FLORESTA_ARCANA,

                            aoSelecionarDestino = { plan ->
                                // Selecionar um destino apenas marca a rota.
                                // A localização persistente só muda após deslocamento real no mundo.
                                pendingTravelPlan = plan
                                indiceTrechoRota = 0
                                progressoTrechoRota = 0f
                                message = "Rota marcada para ${plan.destination.name}. Siga o caminho andando na direção indicada; não há teletransporte."
                            },

                            aoVoltar = {
                                showWorldMap = false
                            },

                            modifier = Modifier.fillMaxSize()
                        )

                        if (worldDaylightFactor < 1f) {
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(
                                        androidx.compose.ui.graphics.Color(0xFF07152D)
                                            .copy(alpha = (1f - worldDaylightFactor) * 0.34f)
                                    )
                            )
                        }

                        if (worldSyncMessage.isNotBlank()) {
                            Text(
                                text = worldSyncMessage,
                                modifier = Modifier.align(androidx.compose.ui.Alignment.TopCenter),
                                color = MaterialTheme.colorScheme.tertiary,
                                style = MaterialTheme.typography.labelSmall
                            )
                        }

                    } else {

                        TelaMundo(
                            estado = estadoMundo,
                            aoAtualizarEstado = { novoEstado ->
                                estadoMundo = novoEstado
                                val perfilAtual = characterProfile
                                val agora = System.currentTimeMillis()
                                if (perfilAtual != null &&
                                    agora - ultimaPersistenciaPosicaoMs >= 15_000L
                                ) {
                                    ultimaPersistenciaPosicaoMs = agora
                                    val perfilComPosicao = perfilAtual.copy(
                                        worldX = novoEstado.posicaoNoMapa.x,
                                        worldY = novoEstado.posicaoNoMapa.y
                                    )
                                    characterProfile = perfilComPosicao
                                    scope.launch {
                                        runCatching {
                                            if (modoOfflineAtivo) {
                                                armazenamentoLocal.save(perfilComPosicao, uidAtual ?: armazenamentoLocal.loadRecord()?.ownerUid, true)
                                            } else {
                                                CharacterProfileRepository().saveWorldPosition(
                                                    perfilComPosicao.id,
                                                    novoEstado.posicaoNoMapa.x,
                                                    novoEstado.posicaoNoMapa.y,
                                                    perfilComPosicao.currentWorldPointId,
                                                    perfilComPosicao.respawnPointId
                                                )
                                            }
                                        }.onFailure {
                                            message = "Não foi possível salvar sua posição: ${it.localizedMessage}"
                                        }
                                    }
                                }
                            },
                            companheiro = InventorySystem.obterCompanheiroAtivo(
                                playerInventory
                            ),
                            modifier = Modifier.fillMaxSize(),
                            uidJogador = FirebaseAuth.getInstance().currentUser?.uid,
                            nomeJogador = characterProfile?.name ?: "Aventureiro",
                            nivelJogador = characterProfile?.level ?: 1,
                         rankJogador = characterProfile?.guildRank ?: "E",
                         chefesPromocaoDerrotados = characterProfile?.promotionBossesDefeated.orEmpty(),
                            vidaJogador = hero.hp,
                            vidaMaximaJogador = hero.maxHp,
                            ataqueJogador = hero.attack,
                            defesaJogador = hero.defense,
                            manaJogador = hero.mana,
                            manaMaximaJogador = hero.maxMana,
                            agilidadeJogador = hero.agility,
                            poderMagicoJogador = hero.magicPower,
                            worldPointId = characterProfile?.currentWorldPointId?.takeIf { it.isNotBlank() } ?: "clareira_inicial",
                            cameraZoomDestino = pendingTravelPlan?.destination?.let {
                                WorldSceneCatalog.profileFor(it.id).cameraZoom
                            },
                            progressoAproximacao = pendingTravelPlan?.let { plano ->
                                val distanciaConcluida = plano.route.take(indiceTrechoRota)
                                    .sumOf { it.distance.toDouble() }.toFloat() + progressoTrechoRota
                                if (plano.totalDistance > 0f) {
                                    (distanciaConcluida / plano.totalDistance).coerceIn(0f, 1f)
                                } else 0f
                            } ?: 0f,
                            xpAtual = characterProfile?.xp ?: profile.xp,
                            mensagem = message,
                            historiaCompartilhada = allyStorySnapshot,
                            votosHistoria = allyStoryVotes,
                            uidJogadorHistoria = uidAtual.orEmpty(),
                            totalMembrosGrupoHistoria = allyGroup?.members?.size ?: 0,
                            aoEscolherNaHistoria = { escolha ->
                                val groupId = allyGroupId
                                val uid = uidAtual
                                val story = allyStorySnapshot
                                if (groupId != null && uid != null && story != null &&
                                    story.resolvedChoice.isBlank()
                                ) {
                                    scope.launch {
                                        runCatching {
                                            allyStoryRepository.registrarEscolha(
                                                groupId = groupId,
                                                uid = uid,
                                                playerName = characterProfile?.name ?: "Aventureiro",
                                                choice = escolha,
                                                storyRevision = story.revision
                                            )
                                        }.onFailure {
                                            erroAventura = it.localizedMessage ?: "Não foi possível registrar seu voto."
                                        }
                                    }
                                }
                            },
                            tituloAventura = tituloAventura,
                            narrativaAventura = narrativaAventura,
                            erroAventura = erroAventura,
                            resultadoDadoAventura = resultadoDadoAventura,
                            escolhasAventura = escolhasAventura,
                            aoAceitarMissao = { missao ->
                                val atual = characterProfile
                                if (atual == null) {
                                    message = "Não foi possível aceitar a missão: personagem não carregado."
                                } else {
                                    scope.launch {
                                        aceitandoMissao = true
                                        erroAventura = ""
                                        runCatching {
                                            guildContractRepository.acceptMission(atual.id, missao)
                                        }.onSuccess {
                                            aceitandoMissao = false
                                            // Uma missão inicia uma sessão narrativa própria.
                                            // Não reutiliza capítulos, escolhas ou encontros da aventura livre.
                                            missaoGuildaAtiva = missao
                                            historiaAventura = emptyList()
                                            tituloAventura = ""
                                            narrativaAventura = ""
                                            escolhasAventura = emptyList()
                                            acaoLivreAventura = ""
                                            resultadoDadoAventura = ""
                                            encounter = null
                                            tokenEncontroAtual = ""
                                            criaturaDoTokenEncontroId = ""
                                            erroAventura = ""
                                            runCatching {
                                                SoloAdventureRepository().save(
                                                    atual.id,
                                                    AdventureSessionSnapshot(
                                                        history = emptyList(),
                                                        chapterTitle = "",
                                                        narrative = "",
                                                        choices = emptyList()
                                                    )
                                                )
                                            }.onFailure {
                                                erroAventura = "Missão aceita, mas a memória anterior não pôde ser limpa: ${it.localizedMessage}"
                                            }
                                            val atualizado = atual.copy(currentWorldPointId = missao.destinationId)
                                            characterProfile = atualizado
                                            val acaoInicialMissao = "ACEITAR E INICIAR MISSÃO: \"${missao.title}\". Você está na Guilda de Aurelia e parte agora para ${missao.destinationName}, na região ${missao.regionName}. Tipo: ${missao.type}. Objetivo obrigatório: ${missao.objective}. Ameaça e recompensa devem respeitar o rank ${missao.rank}. Conduza esta missão em etapas narrativas claras, ofereça escolhas e encontros coerentes. Não declare a missão concluída antes de o objetivo ser cumprido."
                                            acaoLivreAventura = acaoInicialMissao
                                            message = "Missão aceita: ${missao.title}. Preparando a primeira cena..."
                                            erroAventura = ""
                                            guildActiveContracts = runCatching { guildContractRepository.listActive(atual.id) }.getOrDefault(emptyList())
                                            scope.launch {
                                                runCatching {
                                                    CharacterProfileRepository().saveWorldPosition(
                                                        atualizado.id, atualizado.worldX, atualizado.worldY,
                                                        missao.destinationId, atualizado.respawnPointId
                                                    )
                                                }.onFailure {
                                                    erroAventura = "A missão começou, mas a posição não foi sincronizada: ${it.localizedMessage}"
                                                }
                                            }
                                            executarTurnoAventura(acaoInicialMissao, missao.destinationId)
                                        }.onFailure { erro ->
                                            val detalhe = erro.localizedMessage ?: "Falha desconhecida ao registrar a missão."
                                            message = "Não foi possível aceitar a missão: $detalhe"
                                            erroAventura = "Falha ao aceitar missão: $detalhe"
                                            aceitandoMissao = false
                                        }
                                    }
                                }
                            },
                            aceitandoMissao = aceitandoMissao,
                            erroAceitarMissao = erroAventura,
                            acaoLivre = acaoLivreAventura,
                            aoAlterarAcaoLivre = { acaoLivreAventura = it.take(700) },
                            aoEscolherNaAventura = { executarTurnoAventura(it) },
                            aoEnviarAcaoLivre = { executarTurnoAventura(acaoLivreAventura) },
                            missaoAtiva = missaoGuildaAtiva,
                            aoAbandonarMissao = {
                                val atual = characterProfile
                                val missao = missaoGuildaAtiva
                                if (atual == null || missao == null) {
                                    missaoGuildaAtiva = null
                                } else {
                                    scope.launch {
                                        runCatching {
                                            guildContractRepository.abandon(atual.id, missao.id)
                                        }.onSuccess {
                                            missaoGuildaAtiva = null
                                            historiaAventura = emptyList()
                                            tituloAventura = ""
                                            narrativaAventura = ""
                                            escolhasAventura = emptyList()
                                            acaoLivreAventura = ""
                                            resultadoDadoAventura = ""
                                            encounter = null
                                            tokenEncontroAtual = ""
                                            criaturaDoTokenEncontroId = ""
                                            runCatching {
                                                SoloAdventureRepository().save(
                                                    atual.id,
                                                    AdventureSessionSnapshot(
                                                        history = emptyList(),
                                                        chapterTitle = "",
                                                        narrative = "",
                                                        choices = emptyList()
                                                    )
                                                )
                                            }
                                            guildActiveContracts = runCatching {
                                                guildContractRepository.listActive(atual.id)
                                            }.getOrDefault(emptyList())
                                            message = "Missão abandonada. Você pode aceitar outro contrato na Guilda."
                                        }.onFailure {
                                            message = it.localizedMessage ?: "Não foi possível abandonar a missão."
                                        }
                                    }
                                }
                            },
                            aoVoltar = {},
                            aoAbrirPainel = { painelMundo = it },
                            mercadorDisponivel = merchantAvailable && br.com.ascensaodosoberano.companions.BlacksmithSystem.city(
                                characterProfile?.currentWorldPointId?.takeIf { it.isNotBlank() } ?: "clareira_inicial"
                            ).availableHere,
                            ferreiroDisponivel = missaoGuildaAtiva == null,
                            curandeiroDisponivel = missaoGuildaAtiva == null,
                            criaturaEncontrada = encounter?.criatura,
                            arteOficialEmGeracao = arteCriaturaEmGeracao,
                            erroArteOficial = erroArteCriatura,
                            aoSolicitarArteOficial = { criaturaId ->
                                if (!arteCriaturaEmGeracao) {
                                    scope.launch {
                                        arteCriaturaEmGeracao = true
                                        erroArteCriatura = ""
                                        runCatching {
                                            br.com.ascensaodosoberano.world.RepositorioCriaturas
                                                .solicitarImagemOficialComAutorizacao(criaturaId)
                                        }.onSuccess { resultadoArte ->
                                            val criaturaAtualizada = resultadoArte.criatura
                                            encounter = encounter?.let { atual ->
                                                if (atual.criatura?.id == criaturaId) {
                                                    atual.copy(criatura = criaturaAtualizada)
                                                } else atual
                                            }
                                            val custoReal = String.format(
                                                java.util.Locale("pt", "BR"),
                                                "%.4f",
                                                resultadoArte.custoRealBRL
                                            )
                                            message = "Arte oficial de ${criaturaAtualizada.nome} carregada para todos os jogadores. Custo real do orçamento de IA: R$ $custoReal."
                                        }.onFailure { erro ->
                                            erroArteCriatura = erro.localizedMessage
                                                ?: "Não foi possível gerar a arte oficial."
                                        }
                                        arteCriaturaEmGeracao = false
                                    }
                                }
                            },
                            buscandoCriaturas = verificandoEncontro || carregandoMemoriaAventura,
                            aoEnfrentarCriatura = {
                                encounter?.criatura?.let { criatura ->
                                    scope.launch { iniciarCombateComCriatura(criatura) }
                                }
                            },
                            aoIgnorarCriatura = {
                                encounter = null
                                tokenEncontroAtual = ""
                                criaturaDoTokenEncontroId = ""
                                message = "Você decidiu continuar explorando."
                            },
                            aoSelecionarCriaturaNoMundo = { criatura ->
                                if (combat == null && !verificandoEncontro) {
                                    encounter = ExplorationEncounter(
                                        region = ExplorationSystem.regionForWorldPoint(
                                            characterProfile?.currentWorldPointId?.takeIf { it.isNotBlank() }
                                                ?: "clareira_inicial"
                                        ) ?: ExplorationSystem.regions.first(),
                                        enemyId = criatura.id,
                                        isBoss = criatura.chefe,
                                        message = "Você se aproximou de ${criatura.nome}.",
                                        criatura = criatura
                                    )
                                    scope.launch { iniciarCombateComCriatura(criatura) }
                                }
                            },
                            aoExplorar = {
                                executarTurnoAventura(
                                    if (historiaAventura.isEmpty()) "Começar a aventura." else "Continue a história com um novo acontecimento."
                                )
                            },
                        imagemPersonagemUrl = characterProfile?.appearance?.generatedImageUrl.orEmpty(),
                        skinId = characterProfile?.appearance?.skinId ?: "pele_02",
                        hairId = characterProfile?.appearance?.hairId ?: "cabelo_01",
                        hairColorId = characterProfile?.appearance?.hairColorId ?: "castanho",
                        eyeId = characterProfile?.appearance?.eyeId ?: "olhos_01",
                        outfitId = characterProfile?.appearance?.outfitId ?: "roupa_inicial_01",
                        equipamentosVestidos = br.com.ascensaodosoberano.character.EquipmentSystem.equipmentForVisuals(
                            (characterProfile ?: profile).equipmentLoadout,
                            playerInventory.equipment
                        ),
                        espacosEquipamento = (characterProfile ?: profile).equipmentLoadout,
                            aoSelecionarJogador = { selectedPlayerForAlly = it },
                            aoPercorrer = { distancia, direcaoX, direcaoY ->
                                val plano = pendingTravelPlan
                                if (plano != null && page == 2 && !showWorldMap && combat == null) {
                                    val indice = indiceTrechoRota
                                    val trecho = plano.route.getOrNull(indice)
                                    if (trecho != null) {
                                        var pontoAnteriorId = plano.origin.id
                                        for (i in 0 until indice) {
                                            val anterior = plano.route[i]
                                            pontoAnteriorId = if (anterior.fromId == pontoAnteriorId) {
                                                anterior.toId
                                            } else {
                                                anterior.fromId
                                            }
                                        }
                                        val proximoPontoId = if (trecho.fromId == pontoAnteriorId) {
                                            trecho.toId
                                        } else {
                                            trecho.fromId
                                        }
                                        val pontoAnterior = WorldMapData.findPoint(pontoAnteriorId)
                                        val proximoPonto = WorldMapData.findPoint(proximoPontoId)
                                        if (pontoAnterior != null && proximoPonto != null) {
                                            val rotaX = proximoPonto.x - pontoAnterior.x
                                            val rotaY = proximoPonto.y - pontoAnterior.y
                                            val tamanhoRota = sqrt(rotaX * rotaX + rotaY * rotaY)
                                            val tamanhoDirecao = sqrt(direcaoX * direcaoX + direcaoY * direcaoY)
                                            if (tamanhoRota > 0.0001f && tamanhoDirecao > 0.0001f) {
                                                val alinhamento = (
                                                    (direcaoX / tamanhoDirecao) * (rotaX / tamanhoRota) +
                                                        (direcaoY / tamanhoDirecao) * (rotaY / tamanhoRota)
                                                    ).coerceIn(-1f, 1f)
                                                if (alinhamento >= 0.55f) {
                                                    progressoTrechoRota +=
                                                        distancia * alinhamento * trecho.distance / tamanhoRota
                                                    if (progressoTrechoRota >= trecho.distance) {
                                                        indiceTrechoRota += 1
                                                        progressoTrechoRota = 0f
                                                        if (indiceTrechoRota >= plano.route.size) {
                                                            val destino = plano.destination
                                                            val perfilAtual = characterProfile
                                                            if (perfilAtual != null) {
                                                                val destinoSeguro = destino.type in listOf(
                                                                    WorldPointType.CAPITAL,
                                                                    WorldPointType.CITY,
                                                                    WorldPointType.VILLAGE
                                                                )
                                                                val perfilAtualizado = perfilAtual.copy(
                                                                    currentWorldPointId = destino.id,
                                                                    respawnPointId = if (destinoSeguro) {
                                                                        destino.id
                                                                    } else {
                                                                        perfilAtual.respawnPointId
                                                                    },
                                                                    worldX = estadoMundo.posicaoNoMapa.x,
                                                                    worldY = estadoMundo.posicaoNoMapa.y
                                                                )
                                                                characterProfile = perfilAtualizado
                                                                pendingTravelPlan = null
                                                                indiceTrechoRota = 0
                                                                message = "Você chegou a ${destino.name}. A nova área está carregando."
                                                                scope.launch {
                                                                    runCatching {
                                                                        saveMutex.withLock {
                                                                            if (modoOfflineAtivo) {
                                                                                armazenamentoLocal.save(perfilAtualizado, uidAtual ?: armazenamentoLocal.loadRecord()?.ownerUid, true)
                                                                            } else {
                                                                                CharacterProfileRepository().saveWorldPosition(
                                                                                    perfilAtualizado.id,
                                                                                    perfilAtualizado.worldX,
                                                                                    perfilAtualizado.worldY,
                                                                                    perfilAtualizado.currentWorldPointId,
                                                                                    perfilAtualizado.respawnPointId
                                                                                )
                                                                            }
                                                                        }
                                                                    }.onFailure {
                                                                        message = "Você chegou a ${destino.name}, mas a localização ainda não foi sincronizada."
                                                                    }
                                                                }
                                                            }
                                                        } else {
                                                            message = "Trecho concluído. Continue seguindo a próxima parte da rota."
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                val pointId = characterProfile?.currentWorldPointId?.takeIf { it.isNotBlank() } ?: "clareira_inicial"
                                val regiao = ExplorationSystem.regionForWorldPoint(pointId)
                                if (regiao != null && page == 2 && !showWorldMap &&
                                    combat == null && !verificandoEncontro
                                ) {
                                    distanciaDesdeEncontro += distancia
                                    // Encontros mais responsivos: caminhada curta e intervalo de 12 s.
                                    val agora = System.currentTimeMillis()
                                    if (distanciaDesdeEncontro >= 0.0035f &&
                                        agora - ultimoTesteEncontroMs >= 5_000L
                                    ) {
                                        distanciaDesdeEncontro = 0f
                                        ultimoTesteEncontroMs = agora
                                        verificandoEncontro = true
                                        scope.launch {
                                            try {
                                                val resultado = ExplorationSystem.explore(
                                                    regiao,
                                                    permitirGeracaoRemota = !modoOfflineAtivo
                                                )
                                                encounter = resultado
                                                if (resultado.criatura != null) {
                                                    registrarAvistamentoCriatura(resultado.criatura)
                                                    message = resultado.message
                                                    } else if (resultado.worldEvent?.type != null &&
                                                    resultado.worldEvent.type != br.com.ascensaodosoberano.world.WorldEventType.NOTHING
                                                ) {
                                                    message = resultado.message
                                                }
                                            } catch (erro: Exception) {
                                                message = "Não foi possível explorar esta área: ${erro.localizedMessage ?: "erro desconhecido"}"
                                            } finally {
                                                verificandoEncontro = false
                                            }
                                        }
                                    }
                                }
                            }
                        )

                        pendingTravelPlan?.let { plano ->
                            val trechoAtual = plano.route.getOrNull(indiceTrechoRota)
                            val percentual = if (trechoAtual != null && trechoAtual.distance > 0f) {
                                (progressoTrechoRota / trechoAtual.distance * 100f)
                                    .toInt().coerceIn(0, 100)
                            } else 0
                            Surface(
                                modifier = Modifier
                                    .align(androidx.compose.ui.Alignment.TopCenter)
                                    .padding(12.dp),
                                color = androidx.compose.ui.graphics.Color(0xE61B2534),
                                shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp)
                            ) {
                                Text(
                                    text = "Rota: ${plano.destination.name} · Trecho ${(indiceTrechoRota + 1).coerceAtMost(plano.route.size)}/${plano.route.size} · ${percentual}%",
                                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 9.dp),
                                    color = androidx.compose.ui.graphics.Color.White,
                                    style = MaterialTheme.typography.labelMedium
                                )
                            }
                        }

                    }
                }

                else -> {
                    Text("Selecione uma tela.")
                }
            }
        }


        painelMundo?.let { painel ->
            androidx.compose.ui.window.Dialog(onDismissRequest = { painelMundo = null }) {
                Surface(
                    modifier = Modifier.fillMaxWidth().heightIn(max = 680.dp),
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(18.dp),
                    color = androidx.compose.ui.graphics.Color(0xFF172131)
                ) {
                    Column(
                        modifier = Modifier.verticalScroll(rememberScrollState()).padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(
                                when (painel) {
                                    "STATUS" -> "STATUS DO PERSONAGEM"
                                    "INVENTARIO" -> "INVENTÁRIO"
                                    "BESTIARIO" -> "BESTIÁRIO"
                                    "MULTIPLAYER" -> "MULTIPLAYER"
                                    "FERREIRO" -> "FERREIRO"
                                    "MERCADO" -> "MERCADO"
                                    "CURANDEIRA" -> "CURANDEIRA"
                                    "HABITANTES" -> "HABITANTES DA REGIÃO"
                                    else -> "MENU"
                                },
                                color = androidx.compose.ui.graphics.Color(0xFFFFD58E),
                                style = MaterialTheme.typography.titleMedium
                            )
                            TextButton(onClick = { painelMundo = null }) { Text("FECHAR") }
                        }
                        when (painel) {
                            "STATUS" -> br.com.ascensaodosoberano.character.PainelStatusPersonagem(
                                profile = characterProfile ?: profile,
                                hero = hero,
                                gold = playerInventory.gold,
                                xpProgress = xpProgress,
                                nextLevelXp = nextLevelXp,
                                onAllocateAttribute = { attribute -> allocateAttribute(attribute) }
                            )
                            "HABITANTES" -> br.com.ascensaodosoberano.world.PainelHabitantes(
                                settlementId = when ((characterProfile ?: profile).currentWorldPointId) {
                                    "aurelia", "malachar", "cidade_do_sol", "arkanis",
                                    "vila_esperanca", "mina_dourada", "vila_verdejante",
                                    "eldarion", "torre_natureza" -> (characterProfile ?: profile).currentWorldPointId
                                    "torre_sabedoria" -> "torre_da_sabedoria"
                                    else -> "vila_verdejante"
                                },
                                onMessage = { message = it }
                            )
                            "INVENTARIO" -> {
                                Text("OURO: ${playerInventory.gold}", color = androidx.compose.ui.graphics.Color(0xFFFFD58E))
                                Text("ITENS E MATERIAIS")
                                if (playerInventory.items.isEmpty()) Text("Sua bolsa está vazia.")
                                playerInventory.items.forEach { item ->
                                    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                        MaterialPixelArt(tipo = item.name, rank = item.materialRank, modifier = Modifier.size(42.dp))
                                        Column {
                                            Text(item.name)
                                            Text("Quantidade: ${item.quantity} · Rank ${item.materialRank}", style = MaterialTheme.typography.bodySmall)
                                        }
                                    }
                                }
                                Text("EQUIPAMENTOS")
                                if (playerInventory.equipment.isEmpty()) Text("Nenhum equipamento encontrado.")
                                playerInventory.equipment.forEach { equipamento ->
                                    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                        EquipamentoPixelArt(tipo = equipamento.type, raridade = equipamento.rarity.name, modifier = Modifier.size(46.dp))
                                        Column(Modifier.weight(1f)) {
                                            Text(equipamento.name)
                                            Text("Rank ${equipamento.rank}", style = MaterialTheme.typography.bodySmall)
                                        }
                                        TextButton(onClick = { alternarEquipamento(equipamento) }) {
                                            Text(if ((characterProfile ?: profile).equipmentLoadout.contains(equipamento.id)) "Retirar" else "Equipar")
                                        }
                                    }
                                }
                                Text("OVOS DE COMPANHEIRO")
                                if (playerInventory.eggs.isEmpty()) Text("Você ainda não possui ovos.")
                                playerInventory.eggs.forEach { ovo ->
                                    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                        OvoCompanheiroPixelArt(rank = ovo.rank, mutacao = ovo.mutationRarity, modifier = Modifier.size(42.dp))
                                        Column(Modifier.weight(1f)) {
                                            Text(ovo.species)
                                            Text("Rank ${ovo.rank} · ${ovo.mutationName}", style = MaterialTheme.typography.bodySmall)
                                        }
                                        TextButton(
                                            enabled = eclodindoOvoId == null,
                                            onClick = {
                                                scope.launch {
                                                    eclodindoOvoId = ovo.id
                                                    runCatching { CompanionHatchingSystem.hatchEgg(playerInventory, ovo.id) }
                                                        .onSuccess { resultado ->
                                                            if (resultado.success) atualizarInventario(resultado.inventory)
                                                            message = resultado.message
                                                        }
                                                        .onFailure { message = "Falha ao eclodir: ${it.localizedMessage}" }
                                                    eclodindoOvoId = null
                                                }
                                            }
                                        ) { Text("Eclodir") }
                                    }
                                }
                                Text("COMPANHEIROS")
                                if (playerInventory.companions.isEmpty()) Text("Você ainda não possui companheiros.")
                                playerInventory.companions.forEach { companheiro ->
                                    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                        br.com.ascensaodosoberano.companions.CompanionPixelArt(
                                            especie = companheiro.species, rank = companheiro.rank, modifier = Modifier.size(48.dp),
                                            mutacao = companheiro.mutationId, estagio = companheiro.stage
                                        )
                                        Column(Modifier.weight(1f)) {
                                            Text(companheiro.name)
                                            Text("Nível ${companheiro.level} · ${if (companheiro.isActive) "Ativo" else "Inativo"}", style = MaterialTheme.typography.bodySmall)
                                        }
                                        TextButton(onClick = {
                                            atualizarInventario(InventorySystem.ativarCompanheiro(playerInventory, companheiro.id))
                                        }) { Text("Ativar") }
                                    }
                                }
                            }
                            "BESTIARIO" -> {
                                Text("Criaturas que você já descobriu.")
                                if (carregandoBestiario) CircularProgressIndicator()
                                else if (bestiario.isEmpty()) Text("Você ainda não descobriu nenhuma criatura.")
                                bestiario.forEach { criatura ->
                                    Card(Modifier.fillMaxWidth()) {
                                        Row(Modifier.padding(10.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                            if (criatura.imagemIconeCaminho.startsWith("https://") ||
                                                criatura.imagemIconeCaminho.startsWith("http://")) {
                                                AsyncImage(
                                                    model = criatura.imagemIconeCaminho,
                                                    contentDescription = "Imagem de ${criatura.nome}",
                                                    modifier = Modifier.size(64.dp),
                                                    contentScale = ContentScale.Fit
                                                )
                                            } else {
                                                br.com.ascensaodosoberano.combat.CriaturaPixelArt(
                                                    nome = criatura.nome, rank = criatura.rank,
                                                    chefe = criatura.chefe, modifier = Modifier.size(64.dp)
                                                )
                                            }
                                            Column {
                                                val estatisticasGlobais = estatisticasGlobaisBestiario[criatura.id]
                                                if (estatisticasGlobais != null) {
                                                    Text("Derrotas globais: ${estatisticasGlobais.totalDefeats}", style = MaterialTheme.typography.bodySmall)
                                                    Text("Primeiro descobridor: ${estatisticasGlobais.firstDiscovererName.ifBlank { "Ainda não registrado" }}", style = MaterialTheme.typography.bodySmall)
                                                    Text("Jogadores que encontraram: ${estatisticasGlobais.totalPlayersEncountered}", style = MaterialTheme.typography.bodySmall)
                                                    if (estatisticasGlobais.firstDiscoveryAt > 0L) {
                                                        Text("Descoberta em: ${java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale("pt", "BR")).format(java.util.Date(estatisticasGlobais.firstDiscoveryAt))}", style = MaterialTheme.typography.bodySmall)
                                                    }
                                                    if (estatisticasGlobais.firstDefeaterName.isNotBlank()) {
                                                        Text("Primeiro a derrotar: ${estatisticasGlobais.firstDefeaterName}", style = MaterialTheme.typography.bodySmall)
                                                    }
                                                    if (estatisticasGlobais.firstDefeatAt > 0L) {
                                                        Text("Primeira derrota: ${java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale("pt", "BR")).format(java.util.Date(estatisticasGlobais.firstDefeatAt))}", style = MaterialTheme.typography.bodySmall)
                                                    }
                                                    if (estatisticasGlobais.highestDamageName.isNotBlank()) {
                                                        Text("Maior dano: ${estatisticasGlobais.highestDamageName} (${estatisticasGlobais.highestDamage})", style = MaterialTheme.typography.bodySmall)
                                                    }
                                                    if (estatisticasGlobais.mostDefeatsName.isNotBlank()) {
                                                        Text("Mais derrotas: ${estatisticasGlobais.mostDefeatsName} (${estatisticasGlobais.mostDefeatsCount})", style = MaterialTheme.typography.bodySmall)
                                                    }
                                                } else {
                                                    Text("Estatísticas globais indisponíveis", style = MaterialTheme.typography.bodySmall)
                                                }
                                                Text(criatura.nome, style = MaterialTheme.typography.titleSmall)
                                                Text("Rank ${criatura.rank} · Nível ${criatura.nivel}")
                                                Text("Raridade: ${criatura.raridade} · ${criatura.bioma}", style = MaterialTheme.typography.bodySmall)
                                            }
                                        }
                                    }
                                }
                            }
                            "MULTIPLAYER" -> if (modoOfflineAtivo) {
                                Text("O multiplayer precisa de conexão. Seu personagem e todos os seus itens continuam salvos no modo offline.")
                            } else {
                                allyGroup?.let { grupo ->
                                    Text("GRUPO ALLY (${grupo.members.size}/4)", style = MaterialTheme.typography.titleSmall)
                                    grupo.members.forEach { membro ->
                                        Text(grupo.memberNames[membro] ?: "Aventureiro")
                                    }
                                }
                                GuildaPanel(uid = uidAtual.orEmpty(), nomeJogador = profile.name) { message = it }
                                GuildContractsPanel(
                                    playerRankValue = profile.guildRank,
                                    defeatedPromotionBosses = profile.promotionBossesDefeated,
                                    onAcceptContract = { contract ->
                                        scope.launch {
                                            runCatching {
                                                guildContractRepository.accept(profile.id, contract)
                                                guildContractRepository.listActive(profile.id)
                                            }.onSuccess { active ->
                                                guildActiveContracts = active
                                                message = "Contrato aceito: ${contract.title}. Ele já está salvo na sua ficha da Guilda."
                                            }.onFailure {
                                                message = it.localizedMessage ?: "Não foi possível aceitar o contrato."
                                            }
                                        }
                                    },
                                    onRequestPromotionExam = { currentRank, nextRank ->
                                        val pointId = profile.currentWorldPointId.takeIf { it.isNotBlank() } ?: "guilda_aurelia"
                                        val local = NarrativeLocationCatalog.displayName(pointId)
                                        val region = ExplorationSystem.regionForNarrativeLocation(pointId)
                                        val biome = region?.biome ?: "ecossistema próprio de $local"
                                        acaoLivreAventura = "Solicito iniciar meu exame oficial de promoção da Guilda de Aurelia: rank ${currentRank.label} para ${nextRank.label}. Estou em $local, no ecossistema $biome. Gere um chefe de promoção original exatamente do rank ${currentRank.label}, coerente com esse ecossistema, com identidade, aparência, habilidades e condição de surgimento próprias. A cena deve conduzir diretamente ao encontro desse chefe e oferecer a possibilidade de iniciar o combate. Não me promova automaticamente, não conceda recompensas e não registre vitória; isso só pode acontecer depois de um combate realmente concluído e validado."
                                        painelMundo = null
                                        page = 2
                                        message = "Exame preparado. Na aventura, revise a solicitação e toque em REALIZAR AÇÃO para chamar o chefe. A promoção não é concedida antes da vitória validada."
                                    }
                                )
                                GuildActiveContractsPanel(
                                    contracts = guildActiveContracts,
                                    onAbandon = { contractId ->
                                        scope.launch {
                                            runCatching {
                                                guildContractRepository.abandon(profile.id, contractId)
                                                guildContractRepository.listActive(profile.id)
                                            }.onSuccess { active ->
                                                guildActiveContracts = active
                                                message = "Contrato abandonado. O histórico foi preservado."
                                            }.onFailure {
                                                message = it.localizedMessage ?: "Não foi possível abandonar o contrato."
                                            }
                                        }
                                    }
                                )
                                MultiplayerExpandidoPanel(
                                    uid = uidAtual.orEmpty(),
                                    aoAtualizarPersonagem = {
                                        scope.launch {
                                            runCatching { CharacterProfileRepository().getForCurrentUser() }
                                                .onSuccess { characterProfile = it }
                                                .onFailure { message = "Não foi possível atualizar: ${it.localizedMessage}" }
                                        }
                                    }
                                ) { message = it }
                                allyInvites.forEach { convite ->
                                    Card(Modifier.fillMaxWidth()) {
                                        Column(Modifier.padding(10.dp)) {
                                            Text("${convite.senderName} convidou você para Ally.")
                                            Row {
                                                TextButton(onClick = {
                                                    scope.launch {
                                                        runCatching {
                                                            allyRepository.aceitarConvite(convite.id, uidAtual ?: error("Sessão inválida."), profile.name)
                                                            allyGroupId = allyRepository.obterGrupoId(uidAtual!!)
                                                        }.onSuccess { message = "Você entrou no grupo Ally!" }
                                                            .onFailure { message = "Não foi possível aceitar: ${it.localizedMessage}" }
                                                    }
                                                }) { Text("Aceitar") }
                                                TextButton(onClick = {
                                                    scope.launch {
                                                        runCatching { allyRepository.recusarConvite(convite.id, uidAtual ?: error("Sessão inválida.")) }
                                                            .onSuccess { message = "Convite recusado." }
                                                            .onFailure { message = "Não foi possível recusar: ${it.localizedMessage}" }
                                                    }
                                                }) { Text("Recusar") }
                                            }
                                        }
                                    }
                                }
                            }
                            "MERCADO" -> {
                                val pontoAtual = characterProfile?.currentWorldPointId ?: profile.currentWorldPointId
                                br.com.ascensaodosoberano.companions.MerchantPanel(
                                    pointId = pontoAtual,
                                    inventory = playerInventory,
                                    merchantOpen = merchantAvailable,
                                    onInventoryChanged = { atualizarInventario(it) },
                                    onMessage = { message = it },
                                    rolagemInterna = false
                                )
                            }
                            "FERREIRO" -> {
                                val pontoAtual = characterProfile?.currentWorldPointId ?: profile.currentWorldPointId
                                if (missaoGuildaAtiva == null) {
                                    BlacksmithPanel(
                                        pointId = pontoAtual,
                                        inventory = playerInventory,
                                        onInventoryChanged = { atualizarInventario(it) },
                                        onMessage = { message = it },
                                        rolagemInterna = false
                                    )
                                } else Text("O ferreiro fica indisponível durante uma missão.")
                            }
                            "CURANDEIRA" -> {
                                val pontoAtual = characterProfile?.currentWorldPointId ?: profile.currentWorldPointId
                                if (missaoGuildaAtiva == null) {
                                val companheiroAtivo = InventorySystem.obterCompanheiroAtivo(playerInventory)
                                CurandeiroPanel(
                                    vidaAtual = hero.hp,
                                    vidaMaxima = hero.maxHp,
                                    manaAtual = hero.mana,
                                    manaMaxima = hero.maxMana,
                                    companheiro = companheiroAtivo,
                                    ouroDisponivel = playerInventory.gold,
                                    onCurar = { custoCalculado, vidaRecuperada, manaRecuperada, vidaCompanheiroRecuperada ->
                                        val custoFinal = if (playerInventory.gold <= 0L) 0L else custoCalculado.coerceAtMost(playerInventory.gold)
                                        val vidaNova = (hero.hp + vidaRecuperada).coerceAtMost(hero.maxHp)
                                        val manaNova = (hero.mana + manaRecuperada).coerceAtMost(hero.maxMana)
                                        val inventarioCurado = playerInventory.copy(
                                            gold = playerInventory.gold - custoFinal,
                                            companions = playerInventory.companions.map { companheiro ->
                                                if (companheiroAtivo != null && companheiro.id == companheiroAtivo.id) {
                                                    companheiro.copy(hp = (companheiro.hp + vidaCompanheiroRecuperada).coerceAtMost(companheiro.maxHp))
                                                } else companheiro
                                            }
                                        )
                                        hero = hero.copy(hp = vidaNova, mana = manaNova)
                                        playerInventory = inventarioCurado
                                        val perfilCurado = (characterProfile ?: profile).copy(
                                            inventory = inventarioCurado,
                                            currentHp = vidaNova,
                                            currentMana = manaNova
                                        )
                                        salvarPerfil(perfilCurado, "Não foi possível salvar a cura")
                                        val totalRecuperado = vidaRecuperada + manaRecuperada + vidaCompanheiroRecuperada
                                        message = if (custoFinal == 0L) {
                                            "A curandeira recuperou $totalRecuperado pontos gratuitamente!"
                                        } else {
                                            "A curandeira recuperou $totalRecuperado pontos e cobrou $custoFinal moedas."
                                        }
                                        painelMundo = null
                                    }
                                )
                                } else {
                                    Text("A curandeira fica indisponível durante uma missão.")
                                }
                            }
                        }
                    }
                }
            }
        }

        if (mostrarEntradaPorCodigo) {
            AlertDialog(
                onDismissRequest = { mostrarEntradaPorCodigo = false; codigoGrupoDigitado = "" },
                title = { Text("Entrar no grupo") },
                text = {
                    OutlinedTextField(
                        value = codigoGrupoDigitado,
                        onValueChange = { novo -> codigoGrupoDigitado = novo.filter { it.isLetterOrDigit() }.take(8).uppercase() },
                        label = { Text("Código de convite") },
                        singleLine = true
                    )
                },
                confirmButton = {
                    TextButton(
                        enabled = codigoGrupoDigitado.length == 8,
                        onClick = {
                            scope.launch {
                                runCatching {
                                    allyRepository.entrarPorCodigo(codigoGrupoDigitado, uidAtual ?: error("Sessão inválida."), profile.name)
                                    allyGroupId = allyRepository.obterGrupoId(uidAtual!!)
                                }.onSuccess {
                                    mostrarEntradaPorCodigo = false
                                    codigoGrupoDigitado = ""
                                    message = "Você entrou no grupo! A aventura será compartilhada."
                                }.onFailure { message = "Não foi possível entrar: ${it.localizedMessage}" }
                            }
                        }
                    ) { Text("ENTRAR") }
                },
                dismissButton = {
                    TextButton(onClick = { mostrarEntradaPorCodigo = false; codigoGrupoDigitado = "" }) { Text("Cancelar") }
                }
            )
        }

        selectedPlayerForAlly?.let { jogador ->
            AlertDialog(
                onDismissRequest = { selectedPlayerForAlly = null },
                title = { Text(jogador.nome) },
                text = { Text("Nível ${jogador.nivel}. Deseja convidar este jogador para seu grupo Ally?") },
                confirmButton = {
                    Column {
                        TextButton(onClick = {
                            selectedPlayerForAlly = null
                            scope.launch {
                                runCatching {
                                    allyRepository.enviarConvite(
                                        senderUid = uidAtual ?: error("Sessão inválida."),
                                        senderName = profile.name,
                                        receiverUid = jogador.uid
                                    )
                                }.onSuccess {
                                    allyGroupId = allyRepository.obterGrupoId(uidAtual!!)
                                    message = "Convite enviado para ${jogador.nome}."
                                }.onFailure { message = "Não foi possível convidar: ${it.localizedMessage}" }
                            }
                        }) { Text("Convidar para Ally") }
                        TextButton(onClick = {
                            selectedPlayerForAlly = null
                            scope.launch {
                                runCatching { tradeRepository.criarTroca(jogador.uid) }
                                    .onSuccess { message = "Proposta de troca enviada para ${jogador.nome}. Abra a seção TROCAS para montar sua oferta." }
                                    .onFailure { message = "Não foi possível iniciar a troca: ${it.localizedMessage}" }
                            }
                        }) { Text("Propor troca") }
                    }
                },
                dismissButton = {
                    TextButton(onClick = { selectedPlayerForAlly = null }) { Text("Cancelar") }
                }
            )
        }

        if (mostrarEditorTroca && trocaParaEditar != null) {
            AlertDialog(
                onDismissRequest = { mostrarEditorTroca = false },
                title = { Text("Montar oferta") },
                text = {
                    Column(modifier = Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("Itens e materiais")
                        playerInventory.items.forEach { item ->
                            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                Checkbox(checked = item.id in itensSelecionadosTroca, onCheckedChange = { checked -> itensSelecionadosTroca = if (checked) itensSelecionadosTroca + item.id else itensSelecionadosTroca - item.id })
                                MaterialPixelArt(tipo = item.name, rank = item.materialRank, modifier = Modifier.size(34.dp))
                                Text("${item.name} (x${item.quantity})")
                            }
                        }
                        Text("Ovos")
                        playerInventory.eggs.forEach { egg ->
                            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                Checkbox(checked = egg.id in ovosSelecionadosTroca, onCheckedChange = { checked -> ovosSelecionadosTroca = if (checked) ovosSelecionadosTroca + egg.id else ovosSelecionadosTroca - egg.id })
                                OvoCompanheiroPixelArt(rank = egg.rank, mutacao = egg.mutationRarity, modifier = Modifier.size(34.dp))
                                Text("${egg.species} · Rank ${egg.rank} · ${egg.mutationName}")
                            }
                        }
                        Text("Equipamentos")
                        playerInventory.equipment.forEach { equipment ->
                            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                Checkbox(checked = equipment.id in equipamentosSelecionadosTroca, onCheckedChange = { checked -> equipamentosSelecionadosTroca = if (checked) equipamentosSelecionadosTroca + equipment.id else equipamentosSelecionadosTroca - equipment.id })
                                EquipamentoPixelArt(tipo = equipment.type, raridade = equipment.rarity.name, modifier = Modifier.size(34.dp))
                                Text(equipment.name)
                            }
                        }
                        Text("XP e companheiros eclodidos não aparecem nesta lista e não podem ser negociados.", style = MaterialTheme.typography.bodySmall)
                    }
                },
                confirmButton = {
                    TextButton(onClick = {
                        val tradeId = trocaParaEditar!!
                        val oferta = OfertaTroca(
                            itens = playerInventory.items.filter { it.id in itensSelecionadosTroca }.map { mapOf("id" to it.id, "quantidade" to it.quantity) },
                            ovos = ovosSelecionadosTroca.toList(),
                            equipamentos = equipamentosSelecionadosTroca.toList()
                        )
                        mostrarEditorTroca = false
                        scope.launch {
                            runCatching { tradeRepository.enviarOferta(tradeId, oferta) }
                                .onSuccess { message = "Sua oferta foi enviada. Agora os dois jogadores precisam confirmar." }
                                .onFailure { message = "Não foi possível enviar a oferta: ${it.localizedMessage}" }
                        }
                    }) { Text("Enviar oferta") }
                },
                dismissButton = { TextButton(onClick = { mostrarEditorTroca = false }) { Text("Voltar") } }
            )
        }
    }
}
