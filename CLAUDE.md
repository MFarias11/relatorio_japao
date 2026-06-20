# Relatorio JRC Brasil

Sistema de compliance de TI para a JRC Brasil - gera e gerencia 19 relatorios de auditoria de seguranca da informacao exigidos pela matriz japonesa. Trabalho universitario (Lab. Desenvolvimento de Software).

## Visão Geral

<IMPORTANTE>
No desenvolvimento do projeto, é crucial seguir as melhores práticas de design e arquitetura para garantir escalabilidade, manutenibilidade e facilidade de uso. As seguintes regras e convenções devem ser rigorosamente seguidas por todos os desenvolvedores envolvidos no projeto.

1. Respeitar a Lei de Demeter, para desacoplamento
2. Tell, Don't Ask
3. Evitar Acoplamento Temporal
4. Clean Code
5. SOLID
6. DRY
7. KISS (Keep It Simple, Stupid)

Nunca refatore código a menos que explicitamente solicitado.
</IMPORTANTE>

### 1. Lei de Demeter

**Regra: Cada unidade de codigo deve conversar apenas com seus vizinhos diretos. Nao acesse objetos atraves de cadeias de chamadas (evite "mais de um ponto").**

CORRETO — Controller chama apenas o Service, Service chama apenas o Repository:

```python
# controllers.py
class CollaboratorController(ModelViewSet):
    """Controller REST para o recurso Collaborator."""

    def perform_create(self, serializer):
        """Delega criacao ao service sem acessar camadas internas."""
        self.service.create(serializer.validated_data)
```

```python
# services.py
class CollaboratorService(BaseService):
    """Servico de logica de negocio para colaboradores."""

    def create(self, data):
        """Cria colaborador via repository."""
        return self.repository.create(data)
```

ERRADO — Controller atravessa camadas, acessando o Repository e o Model diretamente:

```python
# controllers.py — VIOLACAO
class CollaboratorController(ModelViewSet):
    def perform_create(self, serializer):
        # Pula o service e acessa o repository diretamente
        repo = CollaboratorRepository()
        collaborator = repo.create(serializer.validated_data)
        # Acessa o model atraves do repository (cadeia de chamadas)
        collaborator.email_set.filter(active=True).first().address
```

**Frontend:** Componentes React devem chamar funcoes de callback recebidas via props, nao acessar estado interno de componentes filhos via refs encadeadas.

CORRETO:

```javascript
/** Pagina de cadastro que delega acao ao callback. */
function CadastroPage({ onSave }) {
  const handleSubmit = (data) => onSave(data);
}
```

ERRADO:

```javascript
/** VIOLACAO — acessa estado interno do filho via ref encadeada. */
function CadastroPage() {
  const tableRef = useRef();
  const value = tableRef.current.state.selectedRow.id;
}
```

### 2. Tell, Don't Ask

**Regra: Ordene objetos a executar acoes em vez de consultar seu estado para decidir por eles. Quem possui o dado deve conter a logica que opera sobre ele.**

CORRETO — Controller ordena o service a executar; Model encapsula sua propria logica:

```python
# controllers.py
class CollaboratorController(ModelViewSet):
    def perform_destroy(self, instance):
        """Ordena o service a remover o colaborador."""
        self.service.remove(instance)
```

```python
# models.py — BaseModel encapsula soft delete
class BaseModel(models.Model):
    def soft_delete(self):
        """O proprio modelo sabe como se auto-deletar."""
        self.deleted_at = timezone.now()
        self.save(update_fields=['deleted_at'])
```

ERRADO — Controller consulta estado do modelo e toma decisao por ele:

```python
# controllers.py — VIOLACAO
class CollaboratorController(ModelViewSet):
    def perform_destroy(self, instance):
        # Pergunta ao modelo e decide externamente
        if instance.deleted_at is None:
            instance.deleted_at = timezone.now()
            instance.save()
```

**Frontend:** Componentes devem receber callbacks (`onDelete`, `onSave`) e executa-los, nao consultar estado externo para decidir.

CORRETO:

```javascript
/** Botao que ordena a acao via callback. */
function DeleteButton({ onDelete }) {
  return <button onClick={onDelete}>Excluir</button>;
}
```

ERRADO:

```javascript
/** VIOLACAO — consulta estado externo para decidir o que fazer. */
function DeleteButton({ item, setItems, items }) {
  const handleClick = () => {
    if (item.deletedAt === null) {
      setItems(items.filter(i => i.id !== item.id));
    }
  };
}
```

### 3. Evitar Acoplamento Temporal

**Regra: Nao dependa de ordem implicita de chamadas. Torne dependencias de sequencia explicitas via transacoes, parametros obrigatorios ou orquestracao no service.**

CORRETO — `@transaction.atomic` garante que operacoes dependentes executam juntas:

```python
# services.py
class CollaboratorService(BaseService):
    @transaction.atomic
    def create(self, data):
        """Cria colaborador e emails em uma unica transacao.

        Se a criacao de email falhar, o colaborador tambem e revertido.
        """
        emails_data = data.pop('emails', [])
        collaborator = self.repository.create(data)
        for email_data in emails_data:
            email_data['collaborator'] = collaborator
            self.email_repository.create(email_data)
        return collaborator
```

ERRADO — Passos dependentes sem transacao; falha parcial deixa dados inconsistentes:

```python
# services.py — VIOLACAO
class CollaboratorService(BaseService):
    def create(self, data):
        emails_data = data.pop('emails', [])
        collaborator = self.repository.create(data)
        # Se falhar aqui, colaborador existe sem emails — dado inconsistente
        for email_data in emails_data:
            email_data['collaborator'] = collaborator
            self.email_repository.create(email_data)
        return collaborator
```

**Frontend:** Use `AbortController` para evitar race conditions em chamadas assincronas, e flags de controle (`_retry`) no interceptor JWT para evitar loops infinitos de refresh.

CORRETO:

```javascript
/** Hook que cancela requisicao anterior ao receber nova chamada. */
useEffect(() => {
  const controller = new AbortController();
  api.get('/api/collaborators/', { signal: controller.signal });
  return () => controller.abort();
}, [filters]);
```

**Red flags de acoplamento temporal:** metodos que precisam ser chamados "na ordem certa", inicializacao em dois passos sem validacao, estado compartilhado mutavel entre chamadas independentes.

### 4. Clean Code

**Regra: Nomes descritivos, funcoes pequenas com responsabilidade unica, sem magic numbers. O codigo deve comunicar intencao sem necessidade de comentarios explicativos.**

**Nomenclatura do projeto:**

| Contexto | Convencao | Exemplo |
|----------|-----------|---------|
| Modelos Django | PascalCase, singular, ingles | `Collaborator`, `ServerAccess` |
| Campos de modelo | snake_case, ingles | `domain_user`, `service_tag` |
| URLs da API | kebab-case, plural, ingles | `/api/server-access/`, `/api/pen-drives/` |
| Componentes React | PascalCase | `DataTable`, `CadastroPage` |
| Variaveis JS | camelCase | `pageSize`, `handleSubmit` |

CORRETO — Nomes descritivos, constantes nomeadas:

```python
# repositories.py
class CollaboratorRepository(BaseRepository):
    DEFAULT_PAGE_SIZE = 20

    def get_active(self):
        """Retorna colaboradores ativos e nao demitidos."""
        return self.model.objects.filter(status=True, fired=False)
```

ERRADO — Nomes genericos, magic numbers:

```python
# repositories.py — VIOLACAO
class CollaboratorRepository(BaseRepository):
    def get(self):
        return self.model.objects.filter(status=True, fired=False)[:20]  # magic number
```

Para regras de docstrings obrigatorias em PT-BR, ver secao [Docstrings](#docstrings).

### 5. SOLID

#### S — Single Responsibility (Responsabilidade Unica)

Cada camada tem uma unica responsabilidade. Nao misture responsabilidades entre camadas.

| Camada | Responsabilidade unica | O que NAO faz |
|--------|----------------------|---------------|
| Controller | Receber HTTP, validar permissoes, retornar Response | Logica de negocio, queries ao banco |
| Service | Logica de negocio, orquestracao | Acessar request/response HTTP, queries diretas |
| Repository | Acesso a dados (ORM queries) | Logica de negocio, formatacao de resposta |
| Serializer | Validacao de input, formatacao de output | Logica de negocio, acesso a dados |
| Model | Definicao de campos, comportamento da entidade | Orquestracao, HTTP |

#### O — Open/Closed (Aberto para extensao, fechado para modificacao)

`BaseRepository` fornece operacoes padrao. Repositories especificos estendem sem modificar a base:

```python
# repositories.py
class CollaboratorRepository(BaseRepository):
    """Estende BaseRepository com queries especificas de colaborador."""

    def get_with_emails(self):
        """Retorna colaboradores com emails pre-carregados."""
        return self.model.objects.prefetch_related('emails')
```

#### L — Liskov Substitution (Substituicao de Liskov)

Todo repository que herda de `BaseRepository` deve preservar o contrato dos metodos herdados (`create`, `update`, `soft_delete`, `get_all`). Nenhum herdeiro deve alterar o comportamento esperado desses metodos.

#### I — Interface Segregation (Segregacao de Interface)

Use serializers especificos por acao em vez de um unico serializer sobrecarregado:

```python
# serializers.py
class CollaboratorListSerializer(serializers.ModelSerializer):
    """Serializer enxuto para listagem (sem relacoes aninhadas)."""
    class Meta:
        model = Collaborator
        fields = ['id', 'name', 'status']

class CollaboratorDetailSerializer(serializers.ModelSerializer):
    """Serializer completo para detalhe (com emails aninhados)."""
    emails = EmailSerializer(many=True, read_only=True)
    class Meta:
        model = Collaborator
        fields = '__all__'
```

#### D — Dependency Inversion (Inversao de Dependencia)

Controller depende do Service (abstracao de negocio), nao do Model/Repository (detalhe de dados):

```python
# controllers.py
class CollaboratorController(ModelViewSet):
    """Depende de CollaboratorService, nao de Collaborator ou CollaboratorRepository."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.service = CollaboratorService()
```

### 6. DRY (Don't Repeat Yourself)

**Regra: Centralize logica comum em classes base. Nao duplique codigo entre entidades que compartilham comportamento.**

**Centralizacao no projeto:**

| Classe base | Herdeiros | O que centraliza |
|-------------|-----------|-----------------|
| `BaseModel` | 14 modelos (Collaborator, Machine, Software, etc.) | `created_at`, `updated_at`, `deleted_at`, `soft_delete()`, `SoftDeleteManager` |
| `BaseRepository` | 12 repositories | `create()`, `update()`, `soft_delete()`, `get_all()`, `get_by_id()` |
| `BaseService` | 12 services | Orquestracao padrao entre repository e validacao |
| `ModelViewSet` (DRF) | 12 controllers | CRUD HTTP completo (list, create, retrieve, update, destroy) |

**Fronteira do DRY:** Nao force abstracao prematura. Se dois trechos de codigo sao parecidos mas pertencem a dominios diferentes, duplicacao e aceitavel. Tres ou mais repeticoes justificam extracao.

### 7. KISS (Keep It Simple, Stupid)

**Regra: Prefira a solucao mais simples que resolve o problema. Evite complexidade desnecessaria, abstrações prematuramente e configuracao excessiva.**

CORRETO — `DefaultRouter` registra CRUD completo em uma linha:

```python
# urls.py
router = DefaultRouter()
router.register(r'collaborators', CollaboratorController)
# Uma linha = 5 endpoints (list, create, retrieve, update, destroy)
```

CORRETO — Repository minimo, sem metodos que ninguem usa:

```python
# repositories.py
class WifiRepository(BaseRepository):
    """Repositorio de Wifi. Herda CRUD padrao de BaseRepository."""
    model = Wifi
```

CORRETO — Componente React simples, sem estado desnecessario:

```javascript
/**
 * Card de informacao para o dashboard.
 *
 * @param {Object} props
 * @param {string} props.title - Titulo do card.
 * @param {number} props.value - Valor numerico exibido.
 * @returns {JSX.Element} Card renderizado.
 */
function InfoCard({ title, value }) {
  return (
    <div className="card">
      <h5>{title}</h5>
      <p>{value}</p>
    </div>
  );
}
```

Para a lista completa de anti-patterns a evitar, ver secao [Anti-patterns (NAO FACA)](#anti-patterns-nao-faca).

## Documentacao de Referencia

- [ANALISE.md](ANALISE.md) - Analise das 2 versoes originais (Node.js + Django), modelos, relatorios
- [PLANO_IMPLEMENTACAO.md](PLANO_IMPLEMENTACAO.md) - 7 fases de implementacao, endpoints, checklists
- [docs/BACKEND.md](docs/BACKEND.md) - Referencia profunda Django/DRF
- [docs/FRONTEND.md](docs/FRONTEND.md) - Referencia profunda React SPA
- [docs/INFRA.md](docs/INFRA.md) - Docker, deploy, troubleshooting

## Arquitetura

```
React SPA (:8080)  <-->  Django REST API (:8000)  <-->  PostgreSQL (:5432)
```

**Backend em camadas:**

```
Request → urls.py (Route) → Controller → Service → Repository → Model/DB
                                |
                           Serializer (validacao/formatacao)
```

| Camada | Arquivo | Responsabilidade |
|--------|---------|-----------------|
| Route | `urls.py` | Mapeamento URL → Controller |
| Controller | `controllers.py` | HTTP request/response, permissoes, chama service |
| Service | `services.py` | Logica de negocio, orquestracao entre repositories |
| Repository | `repositories.py` | Acesso a dados (ORM), soft delete, queries |
| Entity/Model | `models.py` | Definicao de campos, BaseModel |
| Serializer | `serializers.py` | Validacao de input, formatacao de output |

- **Backend:** Django 4.2 + DRF + PostgreSQL
- **Frontend:** React 18 + React Router + Axios + Tailwind CSS + shadcn/ui + React Query (ver [docs/FRONTEND.md](docs/FRONTEND.md))
- **Auth:** JWT via djangorestframework-simplejwt
- **Deploy:** Docker Compose (3 containers: db, backend, frontend)

## Frontend Stack

### Tailwind CSS

- Usar classes utilitarias em vez de CSS customizado.
- Seguir abordagem mobile-first; breakpoints por prefixo (`sm:`, `md:`, `lg:`).
- Extrair componentes reutilizaveis quando um conjunto de classes se repetir em 3 ou mais lugares.

### shadcn/ui

- Componentes base para UI (`Button`, `Card`, `Dialog`, `Select`, `Toast`, etc.).
- Customizacao feita exclusivamente via Tailwind CSS (sem CSS modulo adicional).
- Acessibilidade built-in via Radix UI — nao reimplementar ARIA manualmente onde shadcn/ui ja fornece.

### React Query

- Usar `useQuery` para todas as operacoes de leitura (GET); nunca buscar dados diretamente em `useEffect` sem cache.
- Usar `useMutation` para operacoes de escrita (POST, PUT, PATCH, DELETE).
- Definir `staleTime` e `gcTime` (`cacheTime`) por dominio no `QueryClient` global.
- Invalidar queries relacionadas apos mutacoes bem-sucedidas via `queryClient.invalidateQueries`.

### MSW (Mock Service Worker)

- **Opt-in, DESLIGADO por padrão.** Só liga em desenvolvimento E com `VITE_ENABLE_MSW=true`.
- Os handlers guardam dados **apenas em memória** (somem ao recarregar); deixá-lo ligado por
  engano contra o backend real faz parecer que os dados não persistem no banco.
- Usado para desenvolver a UI sem backend (simula a API Django).
- Handlers em `packages/frontend/src/mocks/handlers/`.
- Bootstrap condicional em `main.tsx` (`import.meta.env.DEV && VITE_ENABLE_MSW === 'true'`) — zero impacto no build de produção.

Para detalhes completos de implementacao, consultar [docs/FRONTEND.md](docs/FRONTEND.md).
Para design tokens, espacamento, tipografia e padroes visuais de componentes, consultar [.interface-design/system.md](.interface-design/system.md).

## Estrutura do Monorepo

```
relatorio_japao/
├── CLAUDE.md
├── ANALISE.md
├── PLANO_IMPLEMENTACAO.md
├── README.md
├── docker-compose.yml
├── .env
├── docs/
│   ├── BACKEND.md
│   ├── FRONTEND.md
│   └── INFRA.md
└── packages/
    ├── backend/
    │   ├── Dockerfile
    │   ├── requirements.txt
    │   ├── manage.py
    │   ├── config/          (settings, urls, wsgi, asgi)
    │   ├── accounts/        (auth JWT: controllers, services)
    │   ├── core/            (14 modelos + controllers/services/repositories)
    │   └── reports/         (19 relatorios: controllers/services/repositories/exporters)
    └── frontend/
        ├── vite.config.ts
        ├── package.json
        ├── public/
        └── src/
            ├── api/         (Axios client + JWT interceptors)
            ├── auth/        (AuthContext, ProtectedRoute)
            ├── types/       (TypeScript interfaces)
            ├── hooks/       (React Query hooks por domínio)
            ├── mocks/       (MSW handlers para desenvolvimento)
            ├── components/  (AppSidebar, PageHeader, StatusBadge, ui/)
            ├── pages/       (Login, Dashboard, Collaborators, Machines, Software, Reports)
            └── lib/         (utils)
```

## Comandos Rapidos

```bash
# Docker - subir tudo
docker-compose up --build

# Backend (sem Docker)
cd packages/backend
python -m venv venv && source venv/bin/activate  # Linux/Mac
pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver

# Frontend (sem Docker)
cd packages/frontend
npm install
npm run dev

# Testes
cd packages/backend && pytest
cd packages/frontend && npm run test

# Banco
python manage.py makemigrations
python manage.py migrate
python manage.py loaddata fixtures/sample_data.json
python manage.py shell
```

## Convencoes

| Aspecto | Convencao |
|---------|-----------|
| Codigo (variaveis, classes, funcoes) | Ingles (EN) |
| Interface do usuario (labels, mensagens) | Portugues (PT-BR) |
| Documentacao | Portugues (PT-BR) |
| Commits | Ingles (EN) |
| Nomes de modelos Django | PascalCase, singular, ingles |
| Nomes de campos | snake_case, ingles |
| URLs da API | kebab-case, plural, ingles |
| Componentes React | PascalCase |
| Controllers | `XxxController` (PascalCase), arquivo `controllers.py` |
| Services | `XxxService` (PascalCase), arquivo `services.py` |
| Repositories | `XxxRepository` (PascalCase), arquivo `repositories.py` |

## Padrao Critico: Soft Delete

Todos os modelos herdam de `BaseModel` que implementa soft delete:

```python
class BaseModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    objects = SoftDeleteManager()  # Filtra deleted_at=None por padrao
    all_objects = models.Manager()  # Inclui deletados

    class Meta:
        abstract = True

    def soft_delete(self):
        self.deleted_at = timezone.now()
        self.save(update_fields=['deleted_at'])
```

**NUNCA use `.delete()` fisico. Sempre use `.soft_delete()`.**

Soft delete deve ser feito via repository:

```python
class BaseRepository:
    def soft_delete(self, instance):
        instance.soft_delete()
```

## Autenticacao JWT

| Endpoint | Metodo | Descricao | View |
|----------|--------|-----------|------|
| `/api/auth/login/` | POST | Gera access + refresh token | simplejwt `TokenObtainPairView` |
| `/api/auth/refresh/` | POST | Renova access token | simplejwt `TokenRefreshView` |
| `/api/auth/register/` | POST | Cria novo usuario (staff only) | Custom `RegisterView` (IsAdminUser) |
| `/api/auth/me/` | GET | Dados do usuario logado | Custom `UserView` |
| `/api/auth/logout/` | POST | Invalida refresh token (blacklist) | simplejwt `TokenBlacklistView` (retorna 200) |

- Access token: 30 min / Refresh token: 1 dia
- `ROTATE_REFRESH_TOKENS: True` — cada refresh gera novo refresh token
- `BLACKLIST_AFTER_ROTATION: True` — refresh antigo e invalidado automaticamente
- Requer `rest_framework_simplejwt.token_blacklist` em INSTALLED_APPS
- Frontend armazena tokens em localStorage
- Axios interceptor adiciona `Bearer <token>` automaticamente

## API REST

- **Base URL:** `/api/`
- **CRUD endpoints:** `/api/collaborators/`, `/api/machines/`, `/api/software/`, `/api/emails/`, `/api/cellphones/`, `/api/wifi/`, `/api/antivirus/`, `/api/servers/`, `/api/server-access/`, `/api/erp-access/`, `/api/data-destroyed/`, `/api/pen-drives/`
- **Dashboard:** `GET /api/dashboard/stats/` (contagens agregadas: colaboradores, maquinas, software, relatorios, maquinas sem criptografia)
- **Relatorios:** `GET /api/reports/` (lista 19 relatorios), `POST /api/reports/{numero}/generate/` (marca como gerado), `GET /api/reports/{numero}/?format=pdf|xlsx` (exportacao — spec 003)
- **Paginacao:** PageNumberPagination, 20 itens/pagina
- **Filtros:** django-filter por campos, SearchFilter, OrderingFilter
- **Exportacao:** `?format=pdf` ou `?format=xlsx` (implementacao completa na spec 003)

## Anti-patterns (NAO FACA)

- **Raw SQL** - Use Django ORM (QuerySets). Nunca `cursor.execute()`.
- **Delete fisico** - Use `soft_delete()`. Nunca `Model.objects.delete()`.
- **URLs hardcoded no frontend** - Use variavel de ambiente `VITE_API_URL`.
- **Sem CORS** - Sempre configure `django-cors-headers`.
- **Token em cookie** - Use localStorage + Axios interceptor.
- **Controllers sem autenticacao** - Todos os controllers precisam de `IsAuthenticated` (exceto login/register).
- **Queries N+1** - Use `select_related()` e `prefetch_related()`. Exemplo critico: MachineController deve usar `prefetch_related('collaborator_machines__collaborator', 'antivirus_records')` para campos computed (collaborator_name, antivirus).
- **Logica de negocio em controllers ou repositories** - Mantenha controllers finos, logica nos services.
- **Controllers chamando ORM diretamente** - Use repositories para todo acesso a dados.
- **Services retornando Response** - Services retornam dados puros (QuerySets, dicts), nunca objetos HTTP.
- **Imports relativos entre apps** - Cada app Django importa apenas do proprio app ou de `core`.
- **Migracoes manuais** - Sempre use `makemigrations`, nunca edite migracoes manualmente.
- **SECRET_KEY exposta** - Use `python-decouple` para ler do `.env`.
- **DEBUG=True em producao** - Sempre `False` em prod.

## Dominio de Negocio (Resumo)

**3 Entidades Principais:**

- **Collaborator** - Funcionario da JRC (nome, dominio, status, permissoes)
- **Machine** - Computador/notebook (hostname, model, service_tag, IP, MAC, criptografia)
- **Software** - Licenca de software (nome, chave, tipo licenca, uso)

**11 Entidades Dependentes:**

- Email, Cellphone, Wifi, AntiVirus, Server, ServerAccess, ServerErpAccess, DataDestroyed, PenDrive, CollaboratorSoftware (N:N), CollaboratorMachine (N:N)

## Docstrings

<CRITICAL>
Todo codigo novo ou modificado DEVE conter docstrings em **portugues do Brasil (PT-BR)**.
Isso inclui classes, metodos, funcoes publicas, callbacks de teste e interfaces publicas.
Nunca considerar uma tarefa como concluida se houver funcao ou classe sem docstring em PT-BR.
</CRITICAL>

### Objetivo

Docstrings servem dois propositos: clareza para desenvolvedores e **contexto explicito para LLMs**.
Um modelo de IA nao infere contexto implicito — cada docstring deve ser auto-suficiente.

### Python — Backend (Google Style)

Usar formato **Google Style** (`"""..."""`) em todo o backend Django.

**Model:**

```python
class Collaborator(BaseModel):
    """Funcionario da JRC Brasil.

    Representa um colaborador com dados de dominio, status
    e permissoes. Suporta soft delete via BaseModel.

    Attributes:
        name: Nome completo do colaborador.
        domain_user: Usuario de dominio Windows.
        status: Se o colaborador esta ativo.
        fired: Se o colaborador foi demitido.
    """
```

**Repository:**

```python
class CollaboratorRepository(BaseRepository):
    """Repositorio de acesso a dados de colaboradores.

    Encapsula todas as queries ao modelo Collaborator,
    incluindo filtros por status e prefetch de relacoes.

    Attributes:
        model: Modelo Django gerenciado por este repositorio.
    """

    def get_active(self):
        """Retorna colaboradores ativos e nao demitidos.

        Returns:
            QuerySet[Collaborator]: Colaboradores com status=True e fired=False.
        """
```

**Service:**

```python
class CollaboratorService(BaseService):
    """Servico de logica de negocio para colaboradores.

    Orquestra operacoes entre CollaboratorRepository e EmailRepository.
    Responsavel por nested creation e regras de negocio.
    """

    def create(self, data):
        """Cria colaborador com emails associados em uma transacao.

        Args:
            data: Dicionario com campos do colaborador.
                Pode incluir chave 'emails' com lista de dicts de email.

        Returns:
            Collaborator: Instancia criada com emails associados.

        Raises:
            ValidationError: Se dados obrigatorios estiverem ausentes.
        """
```

**Controller:**

```python
class CollaboratorController(ModelViewSet):
    """Controller REST para o recurso Collaborator.

    Endpoint: /api/collaborators/
    Permissoes: IsAuthenticated (todas as acoes).
    Delega logica de negocio para CollaboratorService.
    """
```

**Serializer:**

```python
class CollaboratorSerializer(serializers.ModelSerializer):
    """Serializer de entrada e saida para Collaborator.

    Valida campos obrigatorios e formata dados para a API.
    Suporta nested creation de emails via campo 'emails'.
    """
```

### JavaScript/React — Frontend (JSDoc)

Usar formato **JSDoc** (`/** ... */`) em todo o frontend React.

**Componente React:**

```javascript
/**
 * Tabela generica com paginacao e ordenacao.
 *
 * Exibe dados tabulares vindos da API com suporte a
 * paginacao server-side e ordenacao por coluna.
 *
 * @param {Object} props
 * @param {Array<Object>} props.columns - Definicao das colunas (key, label, sortable).
 * @param {string} props.endpoint - URL da API para buscar dados.
 * @param {number} [props.pageSize=20] - Itens por pagina.
 * @returns {JSX.Element} Tabela renderizada com controles de paginacao.
 */
function DataTable({ columns, endpoint, pageSize = 20 }) {
```

**Hook/Context:**

```javascript
/**
 * Context de autenticacao JWT.
 *
 * Gerencia tokens (access/refresh) em localStorage e fornece
 * estado de usuario logado para toda a aplicacao.
 *
 * @returns {{ user: Object|null, login: Function, logout: Function, loading: boolean }}
 */
function useAuth() {
```

**Funcao utilitaria:**

```javascript
/**
 * Formata data ISO para exibicao em PT-BR (dd/mm/aaaa).
 *
 * @param {string} isoDate - Data no formato ISO 8601.
 * @returns {string} Data formatada (ex: "07/03/2026").
 */
function formatDateBR(isoDate) {
```

### Regras AI-Friendly

| Regra | Descricao |
|-------|-----------|
| **Contexto explicito** | Cada docstring deve ser auto-suficiente. Nao assumir que o leitor (humano ou IA) conhece o contexto. |
| **Terminologia consistente** | Usar sempre os mesmos termos do dominio (ex: "colaborador", nunca alternar com "funcionario"). |
| **Estrutura previsivel** | Mesmo formato em todo o projeto — Google Style (Python), JSDoc (JS). |
| **Relacoes entre camadas** | Documentar qual service um controller chama, qual repository um service usa. |
| **Dominio de negocio** | Mencionar conceitos do dominio nas docstrings (ex: "relatorio de compliance", "soft delete"). |

### Escopo

| Contexto | Docstring obrigatoria? |
|----------|----------------------|
| Classes publicas, metodos publicos, funcoes exportadas | **Sim** |
| Funcoes de teste (`test()`, `it()`, `describe()`) | **Sim** |
| Hooks, handlers, componentes React | **Sim** |
| Metodos privados triviais ou one-liners obvios (ex: getter simples) | Nao |
| Arquivos `__init__.py` vazios | Nao |

## Regras de Markdown

- **OBRIGATÓRIO**: Todo bloco de código cercado (fenced code block) deve ter o identificador de linguagem após os três backticks de abertura. Exemplo: ` ```typescript `, ` ```json `, ` ```text `. Nunca usar ` ``` ` sem especificar a linguagem — isso viola a regra MD040 (fenced-code-language) do markdown-lint.

## Manutenção de Documentação

**OBRIGATÓRIO**: Toda mudança de código deve ser acompanhada por atualização de documentação relevante.

- Docstrings em português em todo código novo ou modificado.
- Ao final de cada tarefa: revisar se toda documentação está sincronizada.

**19 Relatorios de Auditoria:**
Cobrem: contatos internos, computadores, usuarios de dominio, acesso a servidor/internet/ERP, licencas de software, criptografia de notebooks, celulares corporativos, destruicao de dados, emails, pendrives, antivirus, atualizacoes de seguranca, WiFi, backup de servidores.

> Ver tabela completa em [ANALISE.md](ANALISE.md#19-relatorios-implementados) e [docs/BACKEND.md](docs/BACKEND.md).
