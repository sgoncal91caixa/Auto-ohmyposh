# windows-terminal-setup

Script PowerShell interativo que deixa um Windows recém-formatado com **Windows Terminal**, **VS Code** e **PowerShell** prontos, usando o prompt [Oh My Posh](https://ohmyposh.dev) e a fonte **MesloLGM Nerd Font**. O tema padrão é o `montys`, mas você escolhe qualquer um dos mais de 120 temas oficiais durante a execução.

## Sumário

- [O que o script faz](#o-que-o-script-faz)
- [Requisitos](#requisitos)
- [Como usar](#como-usar)
- [Etapas](#etapas)
- [Parâmetros e atalhos](#parâmetros-e-atalhos)
- [Arquivos alterados](#arquivos-alterados)
- [Trocar de tema depois](#trocar-de-tema-depois)
- [Solução de problemas](#solução-de-problemas)
- [Desinstalação](#desinstalação)
- [Decisões de projeto](#decisões-de-projeto)

## O que o script faz

1. Instala os programas via `winget`.
2. Instala a fonte Nerd Font para o usuário atual.
3. Baixa todos os temas do Oh My Posh e deixa você escolher um.
4. Configura o `$PROFILE` do PowerShell 7 e do Windows PowerShell 5.1.
5. Define a fonte no Windows Terminal.
6. Define a fonte no terminal integrado do VS Code.

Cada etapa pede confirmação, então você pode pular o que já tem pronto.

## Requisitos

- Windows 10 ou 11 com o `winget` (App Installer) disponível. O Windows 11 já traz.
- Conexão com a internet (o script baixa a fonte e os temas do GitHub).
- **Não** precisa de privilégios de administrador: tudo é instalado no escopo do usuário.

## Como usar

Baixe ou clone o repositório e execute o script:

```powershell
git clone https://github.com/<usuario>/windows-terminal-setup.git
cd windows-terminal-setup
powershell -ExecutionPolicy Bypass -File .\setup-terminal.ps1
```

Numa máquina recém-formatada, sem o `git`, baixe apenas o arquivo `setup-terminal.ps1` pelo botão **Raw** do GitHub, ou pelo botão **Code → Download ZIP**.

Ao terminar, **feche e reabra** o Windows Terminal e o VS Code.

> `-ExecutionPolicy Bypass` vale apenas para essa execução e não altera a política do sistema.

## Etapas

Antes de cada etapa o script mostra o que vai fazer e pergunta:

| Resposta | Efeito |
|----------|--------|
| `S` ou Enter | Executa a etapa |
| `N` | Pula a etapa |
| `T` | Executa esta e todas as próximas sem perguntar |
| `Q` | Sai do script |

| # | Etapa | Detalhes |
|---|-------|----------|
| 1 | Instalar programas | `winget`: PowerShell 7 (`Microsoft.PowerShell`), Windows Terminal (`Microsoft.WindowsTerminal`), VS Code (`Microsoft.VisualStudioCode`) e Oh My Posh (`JanDeDobbeleer.OhMyPosh`, com `-s winget`) |
| 2 | Instalar a fonte | Baixa o `Meslo.zip` do Nerd Fonts e instala só a família **MesloLGM Nerd Font** em `%LOCALAPPDATA%\Microsoft\Windows\Fonts`, registrando em `HKCU` |
| 3 | Baixar temas e escolher um | Baixa o `themes.zip` oficial para `~\.poshthemes`, lista os temas e pergunta qual usar (Enter = `montys`) |
| 4 | Configurar perfis do PowerShell | Escreve a inicialização do Oh My Posh nos perfis do PowerShell 7 e do 5.1 |
| 5 | Fonte no Windows Terminal | Define `profiles.defaults.font.face` no `settings.json` |
| 6 | Fonte no VS Code | Define `terminal.integrated.fontFamily` no `settings.json` |

No final, o script mostra um resumo com o status de cada etapa (`[ok]`, `[pulada]` ou `[falhou]`) e o tema escolhido. Se uma etapa falhar, ele pergunta se deve continuar.

## Parâmetros e atalhos

Execução sem nenhuma pergunta, usando o tema padrão:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-terminal.ps1 -Yes
```

Para mudar o tema padrão ou a fonte, edite as variáveis no topo do script:

```powershell
$Theme    = 'montys'
$FontFace = 'MesloLGM Nerd Font'
```

## Arquivos alterados

| Arquivo | Alteração |
|---------|-----------|
| `Documents\PowerShell\Microsoft.PowerShell_profile.ps1` | Duas linhas que iniciam o Oh My Posh |
| `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` | As mesmas duas linhas, para o PowerShell 5.1 |
| `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` | Fonte padrão dos perfis |
| `%APPDATA%\Code\User\settings.json` | `terminal.integrated.fontFamily` |
| `~\.poshthemes\` | Pasta com todos os temas |
| `%LOCALAPPDATA%\Microsoft\Windows\Fonts\` e `HKCU\...\Fonts` | Arquivos e registro da fonte |

As linhas escritas nos perfis são:

```powershell
$env:POSH_THEMES_PATH = "$HOME\.poshthemes"
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\montys.omp.json" | Invoke-Expression
```

O script preserva o restante do seu perfil: remove só versões antigas dessas duas linhas antes de acrescentá-las. Antes de alterar cada `settings.json`, ele guarda uma cópia `settings.json.bak` ao lado do original.

> **Atenção:** ao regravar os `settings.json`, os comentários `//` desses arquivos são perdidos. Os valores continuam iguais.

## Trocar de tema depois

Edite o nome do arquivo na segunda linha do `$PROFILE` (`notepad $PROFILE`):

```powershell
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\atomic.omp.json" | Invoke-Expression
```

Depois recarregue com `. $PROFILE` ou abra um terminal novo. Para listar os temas disponíveis:

```powershell
Get-ChildItem $env:POSH_THEMES_PATH -Name
```

Para testar um tema só na sessão atual, sem editar o perfil, rode o `oh-my-posh init` com o tema desejado direto no terminal.

## Solução de problemas

**Ícones aparecem como quadrados ou `?`**
A Nerd Font não está sendo usada. Confira em Windows Terminal → Configurações → Padrões → Aparência → Tipo de fonte, e no VS Code a opção `terminal.integrated.fontFamily`. Se você já tinha um perfil com fonte própria, ela tem prioridade sobre o padrão.

**`oh-my-posh` não é reconhecido**
Feche e reabra o terminal para o PATH ser atualizado. Se continuar, confirme a instalação com `winget list JanDeDobbeleer.OhMyPosh`.

**O tema não muda mesmo editando o perfil**
Verifique se `$env:POSH_THEMES_PATH` está definido. A versão do Oh My Posh instalada pela Microsoft Store não cria essa variável nem traz os temas. Por isso o script a define no perfil e baixa os temas para `~\.poshthemes`.

**Erro de política de execução ao abrir o terminal**
Rode `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

**`winget` não encontrado**
Instale o **App Installer** pela Microsoft Store e rode o script de novo.

**Não foi possível editar um `settings.json`**
O script avisa e mostra o ajuste manual. Isso acontece se o arquivo tiver um formato que ele não consiga ler. Seu arquivo original não é alterado nesse caso.

## Desinstalação

- Remova do `$PROFILE` as duas linhas do Oh My Posh.
- Desinstale os programas, se quiser: `winget uninstall JanDeDobbeleer.OhMyPosh`.
- Apague a pasta `~\.poshthemes`.
- Restaure os `settings.json` a partir dos arquivos `.bak`.
- Desinstale a fonte em Configurações → Personalização → Fontes.

## Decisões de projeto

- **Sem administrador:** a fonte vai para o escopo do usuário e o `winget` instala os pacotes por usuário quando possível.
- **Compatível com o Windows PowerShell 5.1:** é o que existe numa instalação nova, antes de o PowerShell 7 ser instalado. Por isso as mensagens do script não têm acentos.
- **Idempotente:** pode ser executado várias vezes, sem duplicar linhas no perfil.
- **`POSH_THEMES_PATH` definido no perfil:** não depende do instalador do Oh My Posh criar a variável.

## Créditos

- [Oh My Posh](https://ohmyposh.dev), de Jan De Dobbeleer.
- [Nerd Fonts](https://www.nerdfonts.com), pela fonte Meslo patcheada.
