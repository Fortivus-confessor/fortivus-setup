# ⚠️ Vídeos NÃO versionados

Os vídeos de fundo do FORTIVUS **não são commitados** no Git (binários grandes).
Baixe-os do Google Drive e coloque manualmente nos caminhos indicados abaixo.

## 📥 Download (Google Drive)

https://drive.google.com/drive/folders/1zTYE6nUSxrc5MmJ2OSE0BSurzlxONSPe?usp=sharing

## 📍 Onde colocar cada arquivo

| Arquivo | Destino |
|---|---|
| `video_keycloak_tema.mp4` | `keycloak/themes/fortivus/login/resources/img/` (deste ambiente de infra: local / dev / hom) |
| `video_home_fortivus.mp4` | `fire-command-center/public/` |

- `video_keycloak_tema.mp4` → fundo da **tela de login** (tema Keycloak `fortivus`).
- `video_home_fortivus.mp4` → fundo da **Landing Page** do frontend.

## Fallback

Sem os arquivos nada quebra: o login exibe um **degradê azul** e a landing usa o
poster/degradê. Basta colocar os vídeos nos caminhos acima e recarregar.
