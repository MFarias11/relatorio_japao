# Relatório JRC Brasil

Sistema web de compliance de TI para a JRC Brasil — gera e gerencia relatórios de auditoria de segurança da informação exigidos anualmente pela matriz japonesa.

**Disciplina:** Laboratório de Desenvolvimento de Software
**Status:** Em desenvolvimento

## Problema

A JRC Brasil precisa enviar anualmente para a matriz no Japão uma série de relatórios sobre seus ativos de TI: computadores, usuários, licenças de software, acessos a servidores/ERP, antivírus, criptografia, celulares corporativos, entre outros. Hoje esse processo é manual e propenso a erros. Este sistema automatiza a geração desses relatórios a partir de um cadastro centralizado.

## Arquitetura

```text
React SPA (:8080)  <-->  Django REST API (:8000)  <-->  PostgreSQL (:5432)
```

| Camada | Tecnologia |
|--------|-----------|
| Backend | Django 4.2 + Django REST Framework |
| Frontend | React 18 + TypeScript + Vite + Tailwind CSS + shadcn/ui |
| Autenticação | JWT (djangorestframework-simplejwt) |
| Banco de Dados | PostgreSQL |
| Deploy | Docker Compose (3 containers) |

## Estrutura do Projeto

```text
relatorio_japao/
├── README.md
├── CLAUDE.md
├── ANALISE.md                 # Analise das versões originais
├── PLANO_IMPLEMENTACAO.md     # Plano de 7 fases
├── docker-compose.yml
├── .env.example              # Variáveis de ambiente (copiar para .env)
├── docs/
│   ├── BACKEND.md             # Referência Django/DRF
│   ├── FRONTEND.md            # Referência React SPA
│   └── INFRA.md               # Docker e deploy
└── packages/
    ├── backend/
    │   ├── config/                # Settings, URLs, WSGI
    │   ├── accounts/              # Auth JWT
    │   ├── core/                  # 14 modelos + Controllers/Services/Repositories
    │   └── reports/               # relatórios + Controllers/Services/Repositories/Exporters
    └── frontend/
        └── src/
            ├── api/               # Cliente Axios + JWT
            ├── auth/              # AuthContext, ProtectedRoute
            ├── types/             # Interfaces TypeScript
            ├── hooks/             # React Query hooks
            ├── mocks/             # MSW (Mock Service Worker)
            ├── components/        # Componentes reutilizáveis
            └── pages/             # Páginas da aplicação
```

## Como Executar

### Início rápido (recomendado)

Um único comando sobe todo o sistema (db + backend + frontend) — não precisa configurar nada antes:

```bash
scripts/dev.sh
```

O script cuida de tudo: cria o `.env` a partir do `.env.example` se faltar, normaliza CRLF
(WSL/Windows), builda e sobe os 3 containers, **espera cada serviço ficar pronto** e mostra as URLs.

| Comando | O que faz |
|---------|-----------|
| `scripts/dev.sh` | build + sobe o stack (detached) e segue os logs |
| `scripts/dev.sh --no-build` | sobe sem reconstruir as imagens (mais rápido) |
| `scripts/dev.sh --logs` | apenas segue os logs do stack já em execução |
| `scripts/dev.sh --down` | para o stack (mantém os dados do banco) |
| `scripts/dev.sh --reset` | para o stack e **apaga** o volume do banco |
| `scripts/dev.sh -h` | ajuda |

No primeiro start, o entrypoint do backend aguarda o PostgreSQL, aplica migrações (`migrate`),
carrega dados de teste (53 objetos: colaboradores, máquinas, software, 19 relatórios) e cria o
superusuário de desenvolvimento.

**Acessos:**

| Serviço | URL | Login |
|---------|-----|-------|
| Frontend | `http://localhost:8080` | admin / admin123 |
| Backend API | `http://localhost:8000/api/` | Bearer token via login |
| Django Admin | `http://localhost:8000/admin/` | admin / admin123 |
| PostgreSQL | `localhost:5432` | DB: relatoriojapao |

> **Nota:** As credenciais `admin / admin123` são apenas para desenvolvimento local. Em produção
> (`DEBUG=False`), `SECRET_KEY` e `DB_PASSWORD` são obrigatórios via `.env` — o servidor não inicia sem eles.

### Alternativa: Docker manual

Equivale ao `scripts/dev.sh`, mas sem os healthchecks e a criação automática do `.env`:

```bash
cp .env.example .env
docker compose up --build
```

### Alternativa: Sem Docker

**Backend:**

```bash
cd packages/backend
python -m venv venv && source venv/bin/activate  # Linux/Mac
pip install -r requirements.txt
python manage.py migrate
python manage.py loaddata fixtures/sample_data.json
python manage.py createsuperuser  # ou: python manage.py shell -c "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'admin@jrc.com', 'admin123')"
python manage.py runserver
```

> Sem Docker, ajuste `DB_HOST=localhost` no `.env` (em vez de `db`).

**Frontend:**

```bash
cd packages/frontend
npm install
npm run dev
```

Acesse: `http://localhost:8080` — Login: admin / admin123

### MSW (mocks) é opt-in — backend real por padrão

Por padrão o frontend fala com o **backend real** (Django + PostgreSQL): os mocks do MSW
ficam **desligados**. Os handlers do MSW guardam dados apenas em memória, que somem ao
recarregar a página e **não persistem no banco** — por isso o MSW só liga quando pedido
explicitamente. Para desenvolver a UI sem backend, habilite o mock:

```bash
# No arquivo packages/frontend/.env:
VITE_ENABLE_MSW=true
```

> No Docker, o `docker-compose.yml` já define `VITE_ENABLE_MSW=false` no serviço `frontend`.

## Domínio de Negócio

O sistema gerencia 3 entidades principais e 11 dependentes:

- **Collaborator** — funcionários da JRC (nome, domínio, status, permissões)
- **Machine** — computadores e notebooks (modelo, service tag, IP, MAC, criptografia)
- **Software** — licenças (nome, chave, tipo, uso)

A partir desses cadastros, são gerados **relatórios de auditoria** cobrindo: contatos internos, computadores, usuários de domínio, acesso a servidor/internet/ERP, licenças, criptografia, celulares, destruição de dados, emails, pendrives, antivírus, atualizações de segurança, WiFi e backup.

## Documentação

| Documento | Descrição |
|-----------|-----------|
| [ANALISE.md](ANALISE.md) | Análise das 2 versões originais (Node.js + Django) |
| [PLANO_IMPLEMENTACAO.md](PLANO_IMPLEMENTACAO.md) | 7 fases de implementação com checklists |
| [docs/BACKEND.md](docs/BACKEND.md) | Referência completa do backend Django/DRF |
| [docs/FRONTEND.md](docs/FRONTEND.md) | Referência completa do frontend React |
| [docs/INFRA.md](docs/INFRA.md) | Docker, deploy e troubleshooting |
| [ROADMAP.md](ROADMAP.md) | Estado atual, fases do projeto e como usar |

## Contexto

Este projeto parte de duas implementações parciais pré-existentes (uma em Node.js/Express e outra em Django com templates) que estão sendo unificadas em uma arquitetura moderna de API REST + SPA. A análise completa das versões originais está em [ANALISE.md](ANALISE.md).
