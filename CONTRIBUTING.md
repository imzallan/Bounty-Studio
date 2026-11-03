# Guia de Contribuição · Bounty Studio

Obrigado por ajudar a lapidar o **Bounty Studio**! Este documento orienta sobre a estrutura do projeto, padrões de código e procedimentos de teste e compilação.

---

## 🏛 Arquitetura do Repositório

```text
├── .github/
│   └── workflows/
│       ├── ci.yml                 # Testes unitários e integração no CI
│       └── release-windows.yml    # Build e publicação de releases com atestação
├── assets/
│   └── ffmpeg/                    # Codificador de vídeo para WebM/MP4
├── docs/                          # Documentação detalhada, guia e segurança
├── scripts/
│   ├── build.ps1                  # Compilação unificada do BountyStudio.exe
│   ├── bundle-web.ps1             # Sincronização de dados compartilhados com o overlay
│   ├── clean.ps1                  # Limpeza de binários e diretórios temporários
│   ├── dev.ps1                    # Servidor local de desenvolvimento
│   └── test.ps1                   # Executor unificado de testes
├── src/
│   ├── BountyStudio.Desktop/      # Aplicação C# WinForms / WebView2 (.NET 4.8)
│   ├── BountyStudio.Server/       # Servidores locais (PowerShell 5.1+ e Python 3.8+)
│   ├── BountyStudio.Shared/       # Dados compartilhados e schemas (JSON)
│   │   └── Data/                  # Regras, custos de slots, criaturas, charms
│   └── BountyStudio.Web/          # Interface do painel de controle e overlay OBS
├── tests/
│   ├── Test-BountyRules.ps1       # Testes unitários de regras e cálculo de pontos
│   ├── Test-ServerApi.ps1         # Testes de integração das rotas HTTP do servidor
│   └── test_bounty.py             # Testes unitários em Python
├── BountyStudio.sln               # Solução para Visual Studio / VS Code / Rider
├── INICIAR_WINDOWS.bat            # Inicializador rápido para Windows
└── INICIAR_MAC_LINUX.command      # Inicializador para macOS e Linux
```

---

## 🚀 Como Executar em Desenvolvimento

### Servidor Local
Para rodar o servidor em desenvolvimento:
```powershell
./scripts/dev.ps1
```
O painel abrirá automaticamente em `http://127.0.0.1:8787/painel`.

---

## 🧪 Como Rodar os Testes

Execute a suíte de testes antes de enviar qualquer alteração:

```powershell
./scripts/test.ps1
```

A suíte valida:
1. **Regras de Atributos**: Progressão matemática do Talismã (Damage, Leech, Loot, Bestiary), faixas de custo e tetos.
2. **Preferred List**: Desbloqueio progressivo de slots (0, 300, 600, 900, 1200 pontos).
3. **API HTTP**: Health checks, mutações atômicas de estado via `POST /api/state`, recálculo automático de pontos e persistência em `dados/bounty-state.json`.

---

## 🔨 Como Compilar o Executável

O executável standalone Windows sai em `dist/BountyStudio.exe`:

```powershell
./scripts/build.ps1
```

O build utiliza o compilador `csc.exe` embutido nativamente no Windows (.NET Framework 4.8), dispensando a instalação de SDKs adicionais. Caso possua o .NET SDK instalado, a solução `BountyStudio.sln` pode ser aberta e gerenciada em qualquer IDE moderna.

---

## 💎 Padrões de Código e Boas Práticas

1. **Fonte Única de Verdade (Single Source of Truth)**:
   - Todas as regras do jogo, custos e criaturas ficam centralizadas em `src/BountyStudio.Shared/Data/`.
   - Sempre que alterar os dados base, execute `./scripts/bundle-web.ps1` para atualizar o `overlay.html` embutido.
2. **Higienização de Git**:
   - Nunca comite binários compilados (`dist/`, `BountyStudio.exe`) nem dados de usuários (`dados/`).
3. **Resiliência e Zero Dependências Externas**:
   - O backend PowerShell não deve exigir módulos do PowerShell Gallery.
   - O backend Python deve utilizar exclusivamente a biblioteca padrão (`standard library`).

