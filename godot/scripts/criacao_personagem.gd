extends Control

const TEMA_VISUAL = preload("res://scripts/tema_visual.gd")

const CATALOGO = preload("res://scripts/catalogo_criacao_personagem.gd")
var campo_nome: LineEdit
var escolha_sexo: OptionButton
var escolha_aparencia: OptionButton
var escolha_raca: OptionButton
var escolha_classe: OptionButton
var texto_detalhes: Label
var texto_atributos: Label
var texto_afinidades: Label
var texto_estado: Label
var botao_criar: Button

func _ready() -> void:
	RedeMultiplayer.perfil_personagem_recebido.connect(_ao_receber_perfil)
	RedeMultiplayer.erro_conexao.connect(_ao_erro)
	_montar_interface()
	var perfil: Dictionary = RedeMultiplayer.perfil_personagem_atual
	if not perfil.is_empty():
		_ao_receber_perfil(perfil)

func _montar_interface() -> void:
	TEMA_VISUAL.aplicar(self)
	var fundo := ColorRect.new()
	fundo.color = Color("#101b20")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var rolagem := ScrollContainer.new()
	rolagem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rolagem.offset_left = 14
	rolagem.offset_top = 10
	rolagem.offset_right = -14
	rolagem.offset_bottom = -10
	add_child(rolagem)
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 8)
	rolagem.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "CRIE SEU PERSONAGEM"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 23)
	coluna.add_child(titulo)
	var subtitulo := Label.new()
	subtitulo.text = "Sua origem molda seus talentos. Suas escolhas serão salvas no mundo compartilhado."
	subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(subtitulo)
	_adicionar_rotulo(coluna, "Nome (3 a 20 caracteres)")
	campo_nome = LineEdit.new()
	campo_nome.placeholder_text = "Nome do aventureiro"
	coluna.add_child(campo_nome)
	_adicionar_rotulo(coluna, "Sexo")
	escolha_sexo = OptionButton.new()
	escolha_sexo.add_item("Masculino")
	escolha_sexo.set_item_metadata(0, "masculino")
	escolha_sexo.add_item("Feminino")
	escolha_sexo.set_item_metadata(1, "feminino")
	escolha_sexo.item_selected.connect(_ao_mudar_sexo)
	coluna.add_child(escolha_sexo)
	_adicionar_rotulo(coluna, "Aparência")
	escolha_aparencia = OptionButton.new()
	coluna.add_child(escolha_aparencia)
	_adicionar_rotulo(coluna, "Raça")
	escolha_raca = OptionButton.new()
	_adicionar_opcoes_catalogo(escolha_raca, CATALOGO.RACAS)
	escolha_raca.item_selected.connect(_atualizar_previa)
	coluna.add_child(escolha_raca)
	_adicionar_rotulo(coluna, "Classe inicial")
	escolha_classe = OptionButton.new()
	_adicionar_opcoes_catalogo(escolha_classe, CATALOGO.CLASSES)
	escolha_classe.item_selected.connect(_atualizar_previa)
	coluna.add_child(escolha_classe)
	texto_detalhes = Label.new()
	texto_detalhes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(texto_detalhes)
	texto_atributos = Label.new()
	texto_atributos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(texto_atributos)
	texto_afinidades = Label.new()
	texto_afinidades.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(texto_afinidades)
	texto_estado = Label.new()
	texto_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(texto_estado)
	botao_criar = Button.new()
	botao_criar.text = "CRIAR PERSONAGEM E ENTRAR NO MUNDO"
	botao_criar.custom_minimum_size.y = 48
	botao_criar.pressed.connect(_criar_personagem)
	coluna.add_child(botao_criar)
	_atualizar_aparencias()
	_atualizar_previa()

func _adicionar_rotulo(pai: VBoxContainer, texto: String) -> void:
	var label := Label.new()
	label.text = texto
	pai.add_child(label)

func _adicionar_opcoes_catalogo(botao: OptionButton, catalogo: Dictionary) -> void:
	for id in catalogo:
		botao.add_item(str(catalogo[id]["nome"]))
		botao.set_item_metadata(botao.item_count - 1, id)

func _ao_mudar_sexo(_indice: int) -> void:
	_atualizar_aparencias()
	_atualizar_previa()

func _atualizar_aparencias() -> void:
	if escolha_aparencia == null or escolha_sexo == null:
		return
	escolha_aparencia.clear()
	var sexo := str(escolha_sexo.get_item_metadata(escolha_sexo.selected))
	for id in CATALOGO.opcoes_aparencia(sexo):
		escolha_aparencia.add_item(_nome_aparencia(id))
		escolha_aparencia.set_item_metadata(escolha_aparencia.item_count - 1, id)

func _nome_aparencia(id: String) -> String:
	var nomes := {
		"masc_cabelo_curto":"Cabelo curto","masc_cabelo_longo":"Cabelo longo","masc_trancas":"Tranças",
		"masc_careca":"Careca","masc_cabelo_prateado":"Cabelo prateado","masc_cabelo_ruivo":"Cabelo ruivo",
		"masc_cicatriz":"Cicatriz","masc_elmo_leve":"Elmo leve","fem_cabelo_longo":"Cabelo longo",
		"fem_cabelo_curto":"Cabelo curto","fem_trancas":"Tranças","fem_rabo_cavalo":"Rabo de cavalo",
		"fem_cabelo_prateado":"Cabelo prateado","fem_cabelo_ruivo":"Cabelo ruivo","fem_cicatriz":"Cicatriz",
		"fem_cor_de_lua":"Cabelos cor de lua"
	}
	return str(nomes.get(id, id))

func _id_selecionado(botao: OptionButton) -> String:
	if botao.item_count == 0 or botao.selected < 0:
		return ""
	return str(botao.get_item_metadata(botao.selected))

func _atualizar_previa(_indice: int = 0) -> void:
	if texto_detalhes == null or escolha_raca == null or escolha_classe == null:
		return
	var raca_id := _id_selecionado(escolha_raca)
	var classe_id := _id_selecionado(escolha_classe)
	if not CATALOGO.RACAS.has(raca_id) or not CATALOGO.CLASSES.has(classe_id):
		return
	var raca: Dictionary = CATALOGO.RACAS[raca_id]
	var classe: Dictionary = CATALOGO.CLASSES[classe_id]
	texto_detalhes.text = "RAÇA — %s\n%s\n\nCLASSE — %s\n%s" % [raca["nome"], raca["descricao"], classe["nome"], classe["descricao"]]
	var perfil := CATALOGO.montar_perfil(str(escolha_sexo.get_item_metadata(escolha_sexo.selected)), _id_selecionado(escolha_aparencia), raca_id, classe_id)
	texto_atributos.text = "ATRIBUTOS INICIAIS\nForça: %d   Inteligência: %d   Agilidade: %d\nVitalidade: %d   Espírito: %d\nVida máxima: %d   Mana máxima: %d" % [perfil["forca"], perfil["inteligencia"], perfil["agilidade"], perfil["vitalidade"], perfil["espirito"], perfil["vidaMaxima"], perfil["manaMaxima"]]
	texto_afinidades.text = "AFINIDADES FÍSICAS\n%s\n\nAFINIDADES MÁGICAS\n%s" % [", ".join(PackedStringArray(perfil["afinidadesFisicas"])), ", ".join(PackedStringArray(perfil["afinidadesMagicas"]))]

func _criar_personagem() -> void:
	var nome := campo_nome.text.strip_edges()
	if nome.length() < 3 or nome.length() > 20:
		texto_estado.text = "O nome precisa ter entre 3 e 20 caracteres."
		return
	var sexo := str(escolha_sexo.get_item_metadata(escolha_sexo.selected))
	var aparencia := _id_selecionado(escolha_aparencia)
	var raca := _id_selecionado(escolha_raca)
	var classe := _id_selecionado(escolha_classe)
	if not CATALOGO.validar(sexo, aparencia, raca, classe):
		texto_estado.text = "Confira as opções selecionadas."
		return
	botao_criar.disabled = true
	texto_estado.text = "Enviando escolhas para validação do servidor..."
	RedeMultiplayer.solicitar_criacao_personagem(nome, sexo, aparencia, raca, classe)

func _ao_receber_perfil(dados: Dictionary) -> void:
	if bool(dados.get("personagemCriado", false)):
		get_tree().change_scene_to_file("res://scenes/mundo_principal.tscn")

func _ao_erro(mensagem: String) -> void:
	if is_instance_valid(texto_estado):
		texto_estado.text = mensagem
	if is_instance_valid(botao_criar):
		botao_criar.disabled = false
