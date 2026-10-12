# Bounty Studio · Talismã + Preferred List

Painel separado da transmissão, cinco slots de criaturas e download de vídeo transparente.

## Abrir no Windows

**Opcao recomendada:** execute `BountyStudio.exe`. O painel abre dentro de uma janela desktop do proprio aplicativo, sem abas ou janelas do navegador. Builds publicados consultam a release estavel do GitHub ao iniciar; quando existe uma versão mais recente, ela é validada, aplicada e o aplicativo reinicia. Se a rede estiver indisponivel, a versão atual abre normalmente. O aplicativo mantem o servidor local ativo enquanto estiver aberto. Nao requer Python, instalacao ou permissao de administrador. Usa componentes do Windows e o WebView2 Runtime, normalmente pre-instalado nas versoes atuais do Windows 10 e 11. Se o runtime estiver ausente, o aplicativo informa como instalar o componente oficial da Microsoft. No primeiro uso, ele prepara os arquivos em `%LOCALAPPDATA%\Bounty Studio\App`; seus dados e caches permanecem nessa pasta. Se o executavel estiver junto a uma copia do projeto que ja tenha uma pasta `dados`, as configuracoes e os caches existentes serao importados uma vez. O executavel ainda nao e assinado com certificado Authenticode; o SmartScreen pode exibir um aviso ao baixar uma nova versao.

Se preferir iniciar os arquivos do projeto diretamente, extraia o ZIP completo, incluindo `assets/ffmpeg`, e abra **INICIAR_WINDOWS.bat**. O painel abre em `http://127.0.0.1:8787/painel`.

No OBS, adicione uma fonte **Navegador** com `http://127.0.0.1:8787/overlay` e configure largura **1200** e altura **360**.

O iniciador usa Python quando disponível ou o PowerShell do Windows. O codificador de vídeo Windows x64 acompanha `assets/ffmpeg` no código-fonte e é incorporado ao executável publicado. Os controles ficam no painel; a fonte `/overlay` mostra somente o gráfico da transmissão.

## Aprimorar e remover níveis

Cada clique em **Aprimorar X%** adiciona um nível. **Remover X%** retorna ao nível anterior. Os dois botões mostram o incremento exato de cada direção, inclusive na passagem entre faixas. Os percentuais iniciais são mantidos: 2,5% para dano, Life Leech e loot; 5% para bestiário.

| Atributos | Faixa | Incremento por aprimoramento | Níveis acumulados no limite |
| --- | --- | ---: | ---: |
| Dano, Life Leech e loot | 2,5% → 10% | 0,5% | 15 |
| Dano, Life Leech e loot | 10% → 20% | 0,25% | 55 |
| Dano, Life Leech e loot | 20% → 50% | 0,10% | 355 |
| Bestiário | 5% → 100% | 1% | 95 |

Exemplos: em 10%, aprimorar leva a 10,25%, enquanto remover retorna a 9,5%. Em 20%, aprimorar leva a 20,10%, enquanto remover retorna a 19,75%.

Também é possível digitar um percentual. O painel usa o nível permitido mais próximo e atualiza os pontos. O valor é limitado ao intervalo do atributo.

O custo de cada aprimoramento segue a faixa do atributo. Ao entrar em uma nova faixa, a sequência começa pelo custo inicial correspondente:

| Atributos | Faixa | Primeiro aprimoramento | Aumento do custo por melhoria | Custo acumulado no limite |
| --- | --- | ---: | ---: | ---: |
| Dano, Life Leech e loot, cada um | 2,5% → 10% | 5 pontos | +12 pontos | 1.335 pontos |
| Dano, Life Leech e loot, cada um | 10% → 20% | 175 pontos | +2 pontos | 9.895 pontos |
| Dano, Life Leech e loot, cada um | 20% → 50% | 259 pontos | +6 pontos | 356.695 pontos |
| Bestiário | 5% → 100% | 5 pontos | +12 pontos | 54.055 pontos |

Exemplos de custo: subir de 9,5% para 10% custa 173 pontos; de 10% para 10,25%, 175; de 19,75% para 20%, 253; de 20% para 20,10%, 259. Remover um nível subtrai exatamente o custo daquela melhoria. Os percentuais iniciais não gastam pontos.

O total soma os custos acumulados dos quatro atributos e dos slots pagos liberados. O máximo combinado é **1.127.140 pontos**: 1.124.140 nos atributos e 3.000 nos quatro slots adicionais. Ao abrir esta versão, os pontos salvos são recalculados com esses custos, preservando os percentuais e os monstros selecionados.

## Preferred List: Slot 0 gratuito + quatro slots pagos

| Slot | Pontos adicionados | Condição |
| --- | ---: | --- |
| 0 | Grátis | Sempre liberado |
| 1 | 300 | Slot 0 disponível |
| 2 | 600 | Slot 1 liberado |
| 3 | 900 | Slots 1 e 2 liberados |
| 4 | 1.200 | Slots 1, 2 e 3 liberados |

Escolha um monstro no Slot 0 sem precisar marcar uma opção de compra. Para os demais, marque os slots adquiridos em ordem. Os quatro slots pagos adicionam **3.000 pontos** ao total; o Slot 0 não adiciona pontos.

Desmarcar um slot bloqueia também todos os posteriores e retira seus pontos do total. Os nomes dos monstros escolhidos ficam guardados para quando os slots forem liberados novamente. O bloqueio em ordem é validado pelo servidor e pelo painel.

Busque os monstros pelo nome e selecione uma sugestão da lista. O painel mostra a prévia do GIF. Alguns GIFs estão incorporados ao pacote, incluindo Deepworm; outros precisam de internet no primeiro uso e ficam guardados em `dados/sprites`. Em caso de falha, verifique a conexão e use **Recarregar GIF**.

Cada slot também permite selecionar um **Major Charm** e um **Minor Charm**. As escolhas ficam salvas junto com a Preferred List, aparecem no card correspondente do overlay e têm uma prévia no painel de edição do slot. A opção **Dificuldade da bounty** fica em Aparência; escolha **Beginner**, **Adept**, **Expert** ou **Master**, ou deixe como **Não definida**. A dificuldade aparece como uma etiqueta à direita do título do overlay.

HP e XP do monstro são consultados na página correspondente da Tibia Wiki e exibidos empilhados ao lado do GIF, com ícones próprios. O nome do monstro aparece acima do GIF. O primeiro acesso a cada criatura precisa de internet; os dados são mantidos em cache por 30 dias em `dados/creature-info-cache.json`. Quando a Wiki não tiver os números ou a conexão estiver indisponível e não houver cache, o overlay mostra “—”.

Os charms selecionados aparecem em linhas próprias abaixo das informações do monstro, cada um com o nome sem quebra e o ícone oficial da Tibia Wiki. O primeiro acesso a cada ícone precisa de internet; os GIFs ficam em cache local em `dados/charm-icons`. A exportação WebM aguarda os ícones dos charms selecionados antes de gerar os quadros.

## Overlay da transmissão

O ciclo mostra **3 segundos de bônus do talismã**, **3 segundos da Preferred List com HP/XP** e **3 segundos da Preferred List com charms**, repetindo continuamente. O nome do personagem aparece destacado em todas as telas. A cena de HP/XP prioriza o GIF e os dados da criatura; a cena de charms destaca os ícones e nomes dos charms. Slots bloqueados mostram um cadeado; slots liberados recebem um selo de verificado.

Os textos **Bônus do talismã** e **Preferred List** no rodapé estão maiores e não mostram “5s”. A barra de progresso e os campos “Próximo aprimoramento” e “Progresso (%)” foram removidos.

Altere o personagem, título, linha de apoio, tema, logo e efeitos no painel. A opção de animações controla os efeitos decorativos; os GIFs das criaturas mantêm suas animações. As edições atualizam a fonte Navegador em tempo real, sem reiniciar o ciclo. **Desfazer** reverte até 20 alterações desta sessão, inclusive bloqueios de slots. **Restaurar valores** retorna ao padrão e mantém apenas o Slot 0 gratuito liberado; também pode ser desfeito.

## Baixar vídeo

Abra o painel pelo iniciador e clique em **Baixar vídeo**, abaixo da prévia. O arquivo é **WebM de 1200 × 360, com 9 segundos, 30 quadros por segundo, sem áudio, codificação VP9 sem perdas e com transparência**. O vídeo mostra cada uma das três cenas por 3 segundos e inclui os GIFs da Preferred List. O botão **Cancelar** interrompe a preparação.

Esta revisão corrige o executável incompleto que causava o erro “Não foi possível abrir o codificador de vídeo”. Antes de preparar os quadros, o servidor verifica a integridade do codificador incluído e confirma que ele consegue iniciar. No Windows, mantenha juntos `tools/ffmpeg.exe`, `tools/ffmpeg-manifest.json` e a licença; extraia o ZIP inteiro.

A exportação aguarda as edições pendentes e carrega os GIFs e ícones selecionados. O vídeo usa os valores e escolhas do momento do clique; novas edições continuam atualizando a live sem alterar a exportação em andamento. A codificação ocorre no computador. Deixe o painel aberto enquanto o vídeo é preparado. O gráfico também pode ser exportado quando “Exibir overlay na live” estiver desligado.

No OBS, adicione uma fonte **Mídia**, selecione o WebM e marque **Repetir**. Para atualizar um vídeo salvo, exporte um novo. A fonte Navegador recebe alterações ao vivo.

## Atualizar uma versão anterior

1. Feche o iniciador antigo.
2. Substitua os arquivos pelo conteúdo completo deste ZIP, mantendo sua pasta **dados**.
3. Abra **INICIAR_WINDOWS.bat** novamente.
4. Recarregue o painel e a fonte Navegador no OBS.

Os percentuais, textos e monstros existentes são preservados. Os níveis e pontos são recalculados pelas novas faixas. O Slot 0 começa livre para escolher um monstro. Se dados antigos tinham slots pagos fora de ordem, os slots após a primeira lacuna ficam bloqueados; marque-os novamente em sequência. A escolha dos monstros fica guardada.

Os dados ficam em `dados/bounty-state.json`. Os endereços e a resolução do overlay permanecem iguais.

## Demonstração, macOS e Linux

`src/BountyStudio.Web/painel.html` permite experimentar os controles e a prévia sem iniciar o servidor. `src/BountyStudio.Web/overlay.html` contém somente o gráfico. A busca de HP/XP na Tibia Wiki requer que o painel esteja aberto pelo iniciador. Para exportar vídeo ou sincronizar com o OBS, use o iniciador.

No macOS/Linux, use Python 3.8 ou mais recente e disponibilize FFmpeg no terminal para exportar vídeo:

```sh
python3 src/BountyStudio.Server/servidor.py
```

Também é possível executar `INICIAR_MAC_LINUX.command`; se necessário, autorize com `chmod +x INICIAR_MAC_LINUX.command`. O codificador incluído em `assets/ffmpeg` é para Windows.

Se a conexão parar, deixe o iniciador aberto e clique em **Reconectar**. Alterações digitadas sem confirmação são reenviadas após a reconexão; cliques de aprimoramento não confirmados devem ser repetidos. Se a porta 8787 estiver ocupada, feche o programa que a está usando. Para erros de exportação no Windows, confira se o ZIP foi extraído por completo, incluindo `tools`.

Créditos e licenças dos GIFs, dados de criaturas, charms, logo e componentes estão em [CREDITOS.md](CREDITOS.md).

