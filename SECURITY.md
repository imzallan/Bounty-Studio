# Política de segurança

## Versões com suporte

Somente a versão estável mais recente publicada na página de Releases recebe correções de segurança.

## Como relatar uma vulnerabilidade

Não publique vulnerabilidades em Issues ou Pull Requests públicos. Use **Security → Advisories → Report a vulnerability** na página deste repositório para enviar um relato privado. Se a opção não aparecer, o proprietário do repositório precisa ativar **Private vulnerability reporting** nas configurações de segurança do GitHub.

Inclua a versão afetada, os passos para reproduzir o problema, o impacto observado e uma prova de conceito mínima, se houver. Não inclua senhas, tokens ou dados pessoais no relato.

O mantenedor confirmará o recebimento e coordenará a análise e a divulgação de uma correção.

## Verificar downloads

A partir das próximas releases produzidas pelo workflow protegido, o executável terá uma atestação de procedência do GitHub. Depois de baixar `BountyStudio.exe`, verifique-a com o [GitHub CLI](https://cli.github.com/):

```powershell
gh attestation verify .\BountyStudio.exe -R imzallan/Bounty-Studio
```

A atestação comprova a origem do build e seu workflow. Ela não é uma assinatura Authenticode e não substitui a verificação do publicador pelo Windows.
