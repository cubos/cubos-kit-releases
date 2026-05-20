# cubos-kit

Distribuição oficial do `cubos-kit` — ferramenta da Cubos para gerenciar prompts, skills e comandos do Claude Code.

## Instalação

### Linux / macOS

```sh
curl -fsSL https://kit.cubos.dev/install.sh | sh
```

### Windows (PowerShell)

```powershell
irm https://kit.cubos.dev/install.ps1 | iex
```

### Variáveis opcionais

| Variável | Descrição | Default |
|---|---|---|
| `CUBOS_KIT_VERSION` | Versão específica (ex.: `v0.2.0`) | `latest` |
| `INSTALL_DIR` | Diretório de instalação | `~/.local/bin` (Unix) / `%LOCALAPPDATA%\cubos-kit\bin` (Windows) |

## Plataformas suportadas

- Linux x86_64
- Linux aarch64
- macOS x86_64 (Intel)
- macOS aarch64 (Apple Silicon)
- Windows x86_64

## Desinstalar

```sh
rm ~/.local/bin/cubos-kit
```

```powershell
Remove-Item "$env:LOCALAPPDATA\cubos-kit\bin\cubos-kit.exe"
```

## Licença

Proprietária. Todos os direitos reservados à Cubos Tecnologia.
