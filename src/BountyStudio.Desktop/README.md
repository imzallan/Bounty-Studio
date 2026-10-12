# Aplicativo desktop

O aplicativo é um executável Windows x64 em WinForms e WebView2. O build incorpora o painel, o servidor PowerShell, o FFmpeg, as licenças e o auxiliar de atualização; por isso, a distribuição da release é um único arquivo `BountyStudio.exe`.

Compile a partir da raiz com `./src/BountyStudio.Desktop/build.ps1`. A saída vai para `dist/`, que não deve ser versionada. Consulte o [README do projeto](../../README.md) para desenvolvimento, configuração de releases e atualização automática.

O executável não solicita elevação e guarda dados em `%LOCALAPPDATA%\Bounty Studio\App`. Para a troca automática de versão, mantenha-o em uma pasta gravável pelo usuário. O WebView2 Runtime do Windows continua sendo necessário.
