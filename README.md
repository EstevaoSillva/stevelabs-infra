# POC — Plataforma de Agentes Steve Lab

> **Este repositório (`stevelabs-infra`) contém a infraestrutura:** Docker Compose, modelos de `.env`, `config/` e scripts de implantação e teste de fumaça. O projeto está dividido em quatro repositórios, que devem ser clonados lado a lado:
>
> | Repositório | Conteúdo |
> |---|---|
> | `stevelabs-back` | Serviços `agentes` e `exportador`, `requirements*.txt`, modo nativo (`scripts/rodar-nativo.*`, `.env.nativo.example`) |
> | `stevelabs-front` | Protótipo navegável e, depois, a interface própria |
> | `stevelabs-infra` | Este repositório |
> | `stevelabs-sdd` | Documento da ideia e marca (`marca-steve-lab/`) |
>
> O compose constrói as imagens a partir de `../stevelabs-back`. Para outro caminho, defina `STEVELABS_BACK` no `.env`. Caminhos citados abaixo, como `servicos/` e `scripts/rodar-nativo.*`, estão no `stevelabs-back`; o documento da ideia e `marca-steve-lab/` estão no `stevelabs-sdd`.

Prova de conceito da **Steve Lab**, marca de Estevão Silva: colaboradores de uma indústria enviam planilhas, documentos e PDFs, conversam com um agente que roda em modelo local (Ollama) e recebem artefatos prontos em HTML, PDF, DOCX e PPTX.

Não há fluxos fixos. A cada pedido, um **agente coordenador** decide sozinho se resolve a tarefa ou se cria **subagentes especialistas sob demanda**, definindo para cada um o papel, as instruções e as ferramentas. O subagente existe só durante aquela tarefa. É o mesmo padrão de delegação que assistentes como o Claude usam.

Tudo é open source e roda em Docker.

**Status:** POC para validação interna. Documento da ideia: `IDEIA_Plataforma_Agentes_SteveLab.md` (v3.4). Identidade visual: pasta `marca-steve-lab/` (guia de marca em PDF e ativos).

---

## Por que a Steve Lab é diferente

> **Agentes de IA que rodam dentro da sua empresa, entregam trabalho pronto e provam que funcionam.**

O modelo de IA virou commodity. A Steve Lab compete no que fica em volta dele:

| # | Diferencial | Onde está na POC | Status |
|---|---|---|---|
| 1 | **IA que não sai da empresa** | Ollama, Qdrant, Langfuse e SeaweedFS locais; modo nativo sem Docker; nenhuma chamada a API externa | Pronto |
| 2 | **Trabalho pronto, não conversa** | Exportador: PDF, DOCX e PPTX editável; CSS da identidade; `modelo.pptx` e `referencia.docx` do cliente | Pronto |
| 3 | **Prova de que funciona** | Rastreamento de cada pedido, ferramenta e subagente no Langfuse; `teste-fumaca` | Parcial — falta regressão por agente e dono do dado |
| 4 | **Segurança de IA** | SQL só leitura sem acesso a disco ou rede; bloqueio de caminho fora da pasta; limites de chamadas e de subagentes; chave de API | Parcial — falta aprovação humana, ataques simulados e perfis |
| 5 | **Construir com quem vive a rotina** | Catálogo de ferramentas extensível: uma função Python registrada em `REGISTRO` | Parcial — falta o fluxo para o time do cliente propor e homologar agentes |

Detalhes, lacunas e métricas de prova: documento da ideia, seção 6-A. Um exemplo de como os cinco aparecem num projeto está no case ilustrativo `marca-steve-lab/cases/Steve_Lab_Case_Industria_PIM.pdf` (cliente e números fictícios).

---

## 1. Arquitetura

```
 Navegador ──► LibreChat (chat) ──► Serviço de agentes (Agno + FastAPI)
                                      │  coordenador ─┬─► subagente A (criado sob demanda)
                                      │               └─► subagente B …
                                      │  ferramentas:
                                      ├─► ler arquivos ── MarkItDown (leve) / Docling (PDF difícil)
                                      ├─► planilhas ───── DuckDB (SQL somente leitura)
                                      ├─► conhecimento ── Qdrant + embeddings do Ollama
                                      ├─► artefatos ───── Exportador (Chromium · Pandoc · python-pptx)
                                      └─► modelo ──────── Ollama
                   traces ──► Langfuse (ClickHouse · Redis · Postgres · SeaweedFS)
```

| Componente | Função | Licença |
|---|---|---|
| **LibreChat** | Interface de chat | MIT |
| **Agno** | Coordenador, subagentes e ferramentas | Apache 2.0 |
| **Ollama** | Modelo de linguagem e embeddings, local | MIT |
| **Qdrant** | Base vetorial | Apache 2.0 |
| **Docling** | Leitura de PDF escaneado, tabelas, layout | MIT |
| **MarkItDown** | Leitura leve de DOCX, XLSX, PPTX, PDF com texto | MIT |
| **DuckDB** | Consultas SQL sobre planilhas | MIT |
| **Postgres** | Metadados (Langfuse; sessões do Agno na fase 2) | PostgreSQL |
| **Langfuse** | Rastreamento de cada pedido, ferramenta e subagente | MIT (núcleo) |
| **SeaweedFS** | Armazenamento S3 (Langfuse e cópia dos artefatos) | Apache 2.0 |
| **Chromium, Pandoc, python-pptx** | Exportação para PDF, DOCX e PPTX | BSD / GPL / MIT |

O exportador monta o PPTX nativo, editável, a partir de uma descrição estruturada dos slides. Não converte HTML em PPTX, porque essa conversão gera slides-imagem ou layout quebrado.

---

## 2. Parecer: PCs com 16 GB de RAM

**A stack completa não cabe num PC de 16 GB.** Somando o Docling (8 GB ou mais), o Langfuse com ClickHouse (~4 GB), o modelo (~10 GB ou mais) e o Windows (~4 GB), passa de 25 GB.

**O que cabe:** o PC de 16 GB roda só a interface e o núcleo (~4 a 5 GB), e o modelo, o Docling e o Langfuse ficam num **servidor central com GPU**. Para quem só vai usar, basta o navegador.

**O modelo local é o gargalo de verdade, não a memória.** Os modelos que cabem em 16 GB sem GPU são bem mais fracos em chamar ferramentas, que é a base dos subagentes. No benchmark agêntico τ²-bench publicado na página do Gemma 4 no Ollama, o E4B faz 42,2%, contra 68,2% do 26B e 76,9% do 31B. Em CPU, a resposta também fica lenta.

**Docker no WSL:** o Docker Engine roda direto dentro do WSL2, sem Docker Desktop. É gratuito (a cobrança por porte de empresa vale só para o Docker Desktop) e é o cenário assumido neste pacote. Como o Docker mora dentro da VM do WSL, o limite de memória do `.wslconfig` vale para toda a stack.

O parecer completo, com orçamento de memória e dimensionamento de GPU, está no documento da ideia, seção 7-B.

---

## 3. Modos de execução

| Modo | Para quem | O que roda na máquina | RAM usada no Docker |
|---|---|---|---|
| **Servidor** | Infraestrutura central, máquina com GPU | Tudo | 20 GB ou mais, fora a VRAM |
| **Híbrido** (perfil `aluno`) | PC de 16 GB, uso técnico ou desenvolvimento | Núcleo + LibreChat | ~4 a 5 GB |
| **Só navegador** | Colaborador usuário final | Nada | 0 |
| **Local offline** | Demonstração sem rede | Núcleo + Ollama em contêiner | ~12 GB, no limite dos 16 GB |
| **Nativo (sem Docker)** | Quem não pode ou não quer Docker | Núcleo em Python (pip) + Qdrant embutido; Ollama nativo ou no servidor | ~1,5 a 3 GB (sem o modelo) |

### 3.1 Servidor central (GPU NVIDIA)

Pré-requisitos: Linux, Docker Engine com Compose v2, NVIDIA Container Toolkit, 32 GB de RAM ou mais e GPU de 24 GB ou mais.

```bash
./scripts/gerar-env.sh servidor
nano .env                      # troque SERVIDOR pelo IP ou nome do host
docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d --build
docker compose logs -f ollama-baixar-modelos   # aguarde "Modelos prontos."
./scripts/teste-fumaca.sh
```

| Endereço | O quê |
|---|---|
| `http://SERVIDOR:3080` | Chat (LibreChat). O primeiro cadastro vira administrador |
| `http://SERVIDOR:8000/arquivos` | Envio de arquivos e lista de artefatos (usuário qualquer, senha em `SENHA_ARQUIVOS`) |
| `http://SERVIDOR:3000` | Langfuse (login em `LANGFUSE_ADMIN_EMAIL` / `LANGFUSE_ADMIN_PASSWORD`) |
| `http://SERVIDOR:8000/docs` | API dos agentes (Swagger) |

As portas 11434 (Ollama), 5001 (Docling) e 3000 (Langfuse) ficam expostas para os PCs da rede. **Restrinja o acesso no firewall à rede interna autorizada.** O Ollama não tem autenticação; o Docling exige a `DOCLING_API_KEY`.

### 3.2 PC de 16 GB (híbrido, perfil `aluno`, Docker no WSL)

**Uma vez por máquina** — no PowerShell do Windows:

```powershell
copy config\wslconfig-16gb.example $env:USERPROFILE\.wslconfig   # limita o WSL a 7 GB
wsl --shutdown
```

No terminal do WSL (Ubuntu), confira se o Docker está de pé:

```bash
docker version && docker compose version    # Compose v2 é obrigatório (perfis)
```

**Projeto** — sempre no terminal do WSL, com a pasta **dentro do Linux** (`~`), não em `/mnt/c`:

```bash
cp -r /mnt/c/Users/<seu-usuario>/Desktop/poc ~/poc     # copia a pasta do Windows para o Linux
cd ~/poc
bash scripts/gerar-env.sh aluno
nano .env                      # IP_DO_SERVIDOR e chaves do Langfuse, fornecidos pelo responsável do servidor
docker compose up -d --build
bash scripts/teste-fumaca.sh
```

No navegador do Windows: chat em `http://localhost:3080` e arquivos em `http://localhost:8000/arquivos`. O WSL repassa as portas para o `localhost` do Windows.

### 3.3 Local offline (só demonstração)

Suba o WSL para 12 GB no `.wslconfig` (`memory=12GB`), rode `wsl --shutdown` e, no terminal do WSL:

```bash
bash scripts/gerar-env.sh local
docker compose up -d --build
docker compose logs -f ollama-baixar-modelos   # aguarde "Modelos prontos." (~8 GB de download)
bash scripts/teste-fumaca.sh
```

O Ollama roda em contêiner junto com o resto. Não há LibreChat nesse modo: use `http://localhost:8000/docs` ou o `teste-fumaca.sh`. O Windows fica com ~4 GB, então feche o resto. Espere respostas lentas e subagentes pouco confiáveis.

### 3.4 Modo nativo: o que vai por pip e o que continua fora

A stack é a mesma. O que é Python passou a instalar por `requirements.txt`, sem contêiner:

| Componente | Instalação no modo nativo | Observação |
|---|---|---|
| Serviço de agentes (Agno, FastAPI, MarkItDown, pandas, DuckDB) | **pip** | `servicos/agentes/requirements.txt` |
| Exportador (python-pptx) | **pip** | `servicos/exportador/requirements.txt` |
| Pandoc (HTML → DOCX) | **pip** (`pypandoc_binary`) | Traz o executável dentro do pacote; não precisa mais de apt/instalador, nem no Dockerfile |
| Chromium (HTML → PDF) | **pip** + `playwright install chromium` | Baixa o navegador sem permissão de administrador |
| Qdrant | **pip** (modo embutido do `qdrant-client`) | `QDRANT_URL` vazio = arquivos em `./dados/qdrant`. Para vários usuários ao mesmo tempo, use o servidor Qdrant |
| Envio de traces ao Langfuse | **pip** | O Langfuse em si continua em contêiner |
| Docling | **pip opcional** (`requirements-docling.txt`) | Biblioteca pesada (PyTorch); ative com `DOCLING_LOCAL=1`. Sem ela, o MarkItDown cobre DOCX, XLSX, PPTX e PDF com texto |
| Ollama | Instalador nativo (Windows, macOS, Linux) | Não é pacote Python |
| LibreChat + MongoDB, Langfuse + ClickHouse + Redis, SeaweedFS, docling-serve, Postgres | Contêiner | Aplicações de servidor; ficam no servidor central. No modo nativo, use a API em `http://localhost:8000/docs` ou aponte um LibreChat do servidor para esta máquina |

Para rodar (Python 3.11 ou mais novo):

```bash
bash scripts/gerar-env.sh nativo      # Windows: .\scripts\gerar-env.ps1 -Perfil nativo
bash scripts/rodar-nativo.sh          # Windows: .\scripts\rodar-nativo.ps1
```

O script cria o `.venv`, instala o `requirements.txt` da raiz, baixa o Chromium na primeira vez e sobe o exportador (porta 8010) e os agentes (porta 8000). Com `OLLAMA_HOST` apontando para o servidor central, o PC de 16 GB roda o núcleo sem Docker e sem modelo local.

O mesmo `requirements.txt` é usado nos Dockerfiles: contêiner e modo nativo instalam exatamente as mesmas versões.

### 3.5 Docker no WSL: cuidados

| Ponto | Por quê |
|---|---|
| **Projeto em `~/`, nunca em `/mnt/c/...`** | Pastas montadas do Windows deixam o Docker lento e causam erro de permissão nos volumes (`dados/entrada`, `config/`) |
| **systemd ligado no WSL** | Sem ele o Docker não sobe sozinho. Em `/etc/wsl.conf`: `[boot]` + `systemd=true`, depois `wsl --shutdown`. Alternativa: `sudo service docker start` a cada sessão |
| **Scripts `.sh`, não `.ps1`** | O Docker está no Linux. Os `.ps1` ficam para quem usar Docker no Windows |
| **Quebra de linha LF** | Um CRLF em `.sh` ou `.env` quebra o bash e o compose. O `.gitattributes` protege clones via Git; ao editar no Windows, salve como LF |
| **Memória presa no WSL** | O Linux guarda cache e demora a devolver ao Windows. A opção `autoMemoryReclaim` do `.wslconfig` ajuda; `wsl --shutdown` libera tudo |
| **GPU no servidor, se ele também for Windows + WSL** | Funciona com o driver NVIDIA do Windows e o NVIDIA Container Toolkit instalado dentro do WSL. Teste com `docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi` antes de subir o `docker-compose.gpu.yml` |
| **Acesso de outros PCs ao servidor em WSL** | Com a rede padrão (NAT), o WSL só repassa portas para o `localhost` do próprio Windows. Para servir a rede interna, use `networkingMode=mirrored` no `.wslconfig` (Windows 11) ou `netsh interface portproxy` |

---

## 4. Como usar

1. Envie os arquivos em `/arquivos` (ou copie para `dados/entrada/`).
2. No LibreChat, escolha o endpoint **Agentes Steve Lab**.
3. Peça em linguagem natural. Exemplos com a planilha fictícia que vem no pacote:

- *"Descreva a planilha exemplo_chamados.csv e diga qual setor tem o maior tempo médio de resolução."*
- *"Monte um relatório de uma página com os indicadores de chamados por setor e prioridade e exporte em PDF."*
- *"Crie uma apresentação de 5 slides com os principais achados da planilha de chamados para a reunião de gestão."*
- *"Indexe o manual.pdf na coleção qualidade e me diga o que ele fala sobre calibração, citando o trecho."*

No fim da resposta aparece quais subagentes foram criados, e o Langfuse mostra a árvore completa de cada pedido.

O endpoint **Modelo direto** fala com o Ollama sem ferramentas. Serve para perguntas rápidas.

---

## 5. Ferramentas do agente

| Ferramenta | O que faz |
|---|---|
| `listar_arquivos` | Lista o que está em `dados/entrada` |
| `ler_arquivo` | Converte qualquer arquivo em Markdown, com paginação. PDF e imagem vão para o Docling, se configurado |
| `descrever_planilha` | Abas, colunas, tipos e amostra |
| `consultar_planilha` | SQL somente leitura (DuckDB), sem acesso a disco ou rede |
| `indexar_arquivo` / `buscar_conhecimento` / `listar_colecoes` | RAG com Qdrant |
| `criar_artefato_html` | Página autocontida com o CSS da identidade Steve Lab |
| `exportar_artefato` | HTML → PDF (Chromium) ou DOCX (Pandoc) |
| `gerar_apresentacao` | PPTX editável 16:9 na identidade Steve Lab, ou num `modelo.pptx` próprio |
| `delegar_subagente` | Cria um especialista sob demanda, com papel, instruções e ferramentas escolhidos pelo coordenador |

Para criar uma ferramenta nova, escreva uma função Python com type hints e docstring em `servicos/agentes/app/ferramentas/` e registre em `REGISTRO`.

**Identidade visual:** artefatos, PDF e PPTX saem na identidade **Steve Lab · Camadas** (carbono e papel, "Lab" em azul sinal, filete de três camadas ciano → azul → roxo; no PPTX, o símbolo entra na capa em vetor editável). As fontes Instrument Sans e Geist Mono (OFL) já estão em `servicos/exportador/fontes/`. Para outro padrão, coloque `modelo.pptx` e `referencia.docx` em `config/modelos/`. O guia de marca e os ativos estão em `marca-steve-lab/`.

---

## 6. Limitações conhecidas desta POC

- **Pasta de arquivos compartilhada** entre todos os usuários, sem isolamento. Não use com dado pessoal ou sigiloso real antes da fase de governança.
- **Links de artefato sem autenticação:** protegidos só por um sufixo aleatório no nome.
- **Resposta chega de uma vez no chat.** O serviço mantém a conexão viva enquanto trabalha, mas ainda não transmite a resposta aos poucos.
- **Anexos enviados pelo LibreChat não chegam aos agentes.** Use a página `/arquivos`.
- **Ollama serve poucos usuários simultâneos.** Para muitos usuários simultâneos em produção, avaliar vLLM.
- **Versões `latest`** em algumas imagens: fixe as tags depois da primeira validação.
- **Não testado ponta a ponta nesta entrega.** Os arquivos foram escritos e revisados, mas a stack não foi subida. Primeira tarefa: rodar o `teste-fumaca`.

---

## 7. E o "Claude Design" open source?

Há duas alternativas abertas: **Open CoDesign** (MIT, aplicativo desktop que fala direto com o Ollama) e **Open Design** (nexu-io, que usa o agente de linha de comando que já estiver instalado e exporta HTML, PDF, PPTX e MP4). Elas não entram no compose porque são aplicativos de desktop. Para quem faz design visual, o Open CoDesign pode ser apontado para o mesmo Ollama do servidor. A POC resolve os artefatos do dia a dia (relatório, one-pager, apresentação) dentro do próprio agente.

---

*Steve Lab · Estevão Silva · 28/09/2026*
