# Bounty Studio · Live Control

Aplicativo Windows para configurar bônus de talismã e Preferred List, visualizar a live e criar um overlay transparente para o OBS. A interface desktop inclui o painel, o servidor local e o codificador de vídeo; o modo Windows não exige Python nem privilégios de administrador. O WebView2 Runtime do Windows é necessário.

## Baixar o aplicativo

O executável Windows pronto para uso está disponível diretamente na raiz deste repositório: [baixar BountyStudio.exe](https://github.com/imzallan/Bounty-Studio/raw/refs/heads/main/BountyStudio.exe). No Windows, salve o arquivo em uma pasta gravável pelo usuário, como Downloads, e abra-o. O aplicativo consulta atualizações estáveis do GitHub ao iniciar.

## Projeto

```text
assets/ffmpeg/             Codificador Windows e licenças
docs/                      Guia do usuário e créditos de terceiros
src/BountyStudio.Desktop/   Aplicativo WinForms/WebView2 e compilação
src/BountyStudio.Server/    Servidores local Windows e Python
src/BountyStudio.Web/       Painel e overlay
```

`dados/` contém configuração e caches locais e nunca deve ser publicado. `dist/` e `src/BountyStudio.Desktop/obj/` são gerados durante a compilação e também ficam fora do Git.

## Compilar no Windows

Abra PowerShell na raiz do projeto:

```powershell
./src/BountyStudio.Desktop/build.ps1
```

O executável sai em `dist/BountyStudio.exe`. Para preparar builds de release manualmente, informe a versão e o identificador `owner/repository` do GitHub:

```powershell
./src/BountyStudio.Desktop/build.ps1 -Version 1.0.0 -GitHubRepository owner/repository
```

O build local sem repositório definido continua funcionando, mas não consulta atualizações. A action de release define automaticamente o repositório do GitHub e injeta essa origem no executável publicado.

## Releases e atualização automática

Crie uma release estável com uma tag SemVer, por exemplo `v1.0.1`. A action `.github/workflows/release-windows.yml` compila o aplicativo em Windows e publica `BountyStudio.exe` como asset da release. Ao iniciar, o executável consulta a release estável mais recente. Se houver uma versão mais nova, baixa o asset por HTTPS, confere o SHA-256 informado pela API do GitHub, troca o executável e o inicia novamente. Se a rede estiver indisponível ou a resposta não puder ser validada, o aplicativo atual continua abrindo.

O atualizador não solicita elevação de administrador. Portanto, o executável deve ficar em uma pasta gravável pelo usuário (como Downloads ou `%LOCALAPPDATA%`). Não há certificado Authenticode incluído; a verificação do asset reduz riscos de corrupção ou troca no transporte, mas não substitui a assinatura digital do publicador.

## Desenvolvimento

- Faça alterações da interface em `src/BountyStudio.Web/`.
- O servidor Windows é PowerShell 5.1+, sem módulos externos; `src/BountyStudio.Server/servidor.py` usa somente a biblioteca padrão do Python 3.8+.
- Atualize `VERSION` e publique uma tag `v<versão>` para distribuir uma release.
- Mantenha dados de usuários e caches fora dos commits. Builds locais continuam em `dist/`; o `BountyStudio.exe` da raiz é a distribuição Windows incluída no repositório.
- Consulte `docs/GUIA.md` para o uso do aplicativo e `docs/CREDITOS.md` para os componentes e licenças de terceiros.

## Licença

O código original do Bounty Studio está sob a licença [MIT](LICENSE). Componentes de terceiros mantêm suas próprias licenças; consulte `docs/CREDITOS.md` e os arquivos de licença distribuídos junto a cada componente. Em particular, o FFmpeg incluído está sob GPLv3.
