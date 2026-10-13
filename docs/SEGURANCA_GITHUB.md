# Reforçar a segurança do repositório no GitHub

Este guia complementa as proteções já definidas nos arquivos do projeto. As configurações abaixo ficam na conta ou no próprio GitHub e precisam ser aplicadas pelo proprietário.

## 1. Proteger a conta que pode publicar

1. Ative autenticação de dois fatores com uma passkey ou chave de segurança em **Settings → Password and authentication**.
2. Em **Settings → Sessions**, encerre sessões que não reconhecer.
3. Revise **Settings → SSH and GPG keys**, **Applications** e **Personal access tokens**. Remova chaves, integrações e tokens que não reconhece ou não usa.
4. Abra **Settings → Security log** e procure eventos que não reconhece, especialmente criação de chaves, tokens, autorizações de aplicativos e mudanças nos repositórios.

Somente contas com permissão de escrita podem enviar commits diretamente. Um token, uma chave ou uma sessão roubada pode agir com as permissões da conta associada.

## 2. Restringir alterações na branch principal

Em **Bounty-Studio → Settings → Rules → Rulesets**, crie um ruleset ativo para branches com destino `main`:

- Exija Pull Request para todas as alterações.
- Bloqueie force-push e exclusão da branch.
- Exija histórico linear.
- Não adicione bypass para administradores, colaboradores ou aplicações.
- Para uma revisão independente mais forte, adicione uma pessoa de confiança como revisora e exija ao menos uma aprovação. Não exija aprovação se você for o único revisor, pois o GitHub não permite que o autor aprove o próprio Pull Request.

Crie outro ruleset ativo para tags que correspondam a `v*`:

- Restrinja atualizações e exclusões de tags existentes.
- Deixe a criação de novas tags permitida para a conta mantenedora, pois as releases são iniciadas por uma nova tag `vX.Y.Z`.
- Não adicione bypass desnecessário.

## 3. Limitar o GitHub Actions

Em **Settings → Actions → General**:

- Defina as permissões padrão do `GITHUB_TOKEN` como somente leitura.
- Ative a exigência de que as Actions sejam fixadas por SHA completo.
- Se usar a lista de Actions permitidas, autorize somente as Actions oficiais `actions/checkout`, `actions/upload-artifact`, `actions/download-artifact` e `actions/attest` usadas pelo workflow.
- Deixe desativada a permissão para Actions criarem ou aprovarem Pull Requests, pois este projeto não precisa dela.

O workflow de release já declara permissões mínimas por etapa, remove as credenciais persistentes do checkout e mantém a publicação em um job separado da compilação.

## 4. Ativar os alertas do repositório

Em **Settings → Advanced Security** ou **Security and quality**, confirme que estão ativos:

- Secret scanning e push protection, para detectar e bloquear credenciais antes de chegarem ao histórico público.
- Dependabot alerts e Dependabot security updates.
- Relato privado de vulnerabilidades.

O arquivo `.github/dependabot.yml` mantém as Actions do workflow sob atualização automática semanal.

## 5. Conferir uma release

As próximas releases geradas pelo workflow publicam o executável, seu SHA-256 e uma atestação assinada de procedência do build. Depois de baixar `BountyStudio.exe`, valide a atestação com:

```powershell
gh attestation verify .\BountyStudio.exe -R imzallan/Bounty-Studio
```

Isso confirma que o arquivo corresponde a um build do workflow declarado no GitHub. Não substitui Authenticode: o Windows ainda não identifica o publicador por certificado de assinatura de código.
