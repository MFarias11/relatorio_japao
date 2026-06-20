# Frontend - React SPA

> Referencia profunda para trabalho no frontend. Para visao geral, ver [../CLAUDE.md](../CLAUDE.md).
> Para design tokens, spacing, tipografia e padroes visuais, ver [../.interface-design/system.md](../.interface-design/system.md).

## Stack

| Pacote | Versao | Uso |
|--------|--------|-----|
| react | ^18.3.1 | UI library |
| react-dom | ^18.3.1 | DOM rendering |
| typescript | ^5.8.3 | Tipagem estatica |
| vite | ^5.4.19 | Build tool e dev server |
| @vitejs/plugin-react-swc | ^3.11.0 | Plugin React para Vite (SWC) |
| react-router-dom | ^6.30.1 | Roteamento SPA |
| @tanstack/react-query | ^5.83.0 | Data fetching e caching |
| axios | ^1.13.6 | HTTP client com interceptors JWT |
| tailwindcss | ^3.4.17 | Utility-first CSS framework |
| tailwindcss-animate | ^1.0.7 | Animacoes Tailwind |
| @tailwindcss/typography | ^0.5.16 | Plugin de tipografia |
| Radix UI (multiplos pacotes) | ^1.x / ^2.x | Primitivos acessiveis (shadcn/ui) |
| class-variance-authority | ^0.7.1 | Variantes de classe para componentes |
| clsx | ^2.1.1 | Utilitario de className condicional |
| tailwind-merge | ^2.6.0 | Merge seguro de classes Tailwind |
| lucide-react | ^0.462.0 | Icones SVG |
| @fontsource/ibm-plex-sans | ^5.2.8 | Fonte IBM Plex Sans |
| react-hook-form | ^7.61.1 | Gerenciamento de formularios CRUD (create/edit) |
| @hookform/resolvers | ^3.10.0 | Resolver zod para react-hook-form |
| zod | ^3.25.76 | Validacao client-side com campos condicionais |
| recharts | ^2.15.4 | Graficos e visualizacoes |
| sonner | ^1.7.4 | Notificacoes toast (alternativo) |
| date-fns | ^3.6.0 | Manipulacao de datas |
| msw | ^2.12.11 | Mock Service Worker (dev apenas) |
| vitest | ^3.2.4 | Testes unitarios |
| @testing-library/react | ^16.0.0 | Testes de componentes React |
| @testing-library/jest-dom | ^6.6.0 | Matchers DOM para testes |
| @playwright/test | ^1.57.0 | Testes end-to-end |

## Estrutura de src/

```text
packages/frontend/src/
├── main.tsx              (entry point, MSW bootstrap condicional)
├── App.tsx               (layout, rotas, QueryClient, AuthProvider)
├── index.css             (variaveis CSS de tema, import Tailwind)
├── api/
│   └── client.ts         (Axios instance + interceptors JWT)
├── auth/
│   ├── AuthContext.tsx    (context provider, login/logout JWT)
│   └── ProtectedRoute.tsx (wrapper para rotas autenticadas)
├── types/
│   ├── api.ts            (PaginatedResponse, TokenPair)
│   └── entities.ts       (Collaborator, Machine, Software, Report, User, DashboardStats)
├── hooks/
│   ├── useCrudPage.ts      (hook genérico de orquestração CRUD para páginas)
│   ├── useCollaborators.ts (list + detail + create/update/delete mutations)
│   ├── useMachines.ts      (list + detail + create/update/delete mutations)
│   ├── useSoftware.ts      (list + detail + create/update/delete mutations)
│   ├── useReports.ts
│   ├── useDashboardStats.ts
│   ├── use-mobile.tsx
│   └── use-toast.ts
├── mocks/
│   ├── browser.ts        (MSW worker setup)
│   ├── handlers.ts       (barrel export)
│   ├── data/
│   │   └── fixtures.ts   (dados mock no formato API snake_case)
│   └── handlers/
│       ├── auth.ts
│       ├── collaborators.ts
│       ├── machines.ts
│       ├── software.ts
│       ├── reports.ts
│       └── dashboard.ts
├── components/
│   ├── AppLayout.tsx
│   ├── AppSidebar.tsx
│   ├── NavLink.tsx
│   ├── PageHeader.tsx
│   ├── StatusBadge.tsx
│   ├── SearchInput.tsx         (campo de busca reutilizável com debounce 400ms)
│   ├── DeleteConfirmDialog.tsx (diálogo de confirmação de exclusão, soft delete)
│   ├── CollaboratorForm.tsx    (formulário Dialog create/edit com zod)
│   ├── MachineForm.tsx         (formulário Sheet create/edit com zod, 18 campos)
│   ├── SoftwareForm.tsx        (formulário Dialog create/edit com zod)
│   └── ui/              (60+ componentes shadcn/ui)
├── pages/
│   ├── Login.tsx
│   ├── Dashboard.tsx
│   ├── Collaborators.tsx
│   ├── Machines.tsx
│   ├── SoftwarePage.tsx
│   ├── Reports.tsx
│   └── NotFound.tsx
└── lib/
    └── utils.ts          (cn() helper)
```

## Rotas

| Rota | Componente | Auth | Descricao |
|------|-----------|------|-----------|
| `/login` ou `/` | Login | Nao | Formulario de login |
| `/dashboard` | Dashboard | Sim | KPIs e status de relatorios |
| `/collaborators` | Collaborators | Sim | Tabela paginada de colaboradores |
| `/machines` | Machines | Sim | Tabela paginada de maquinas |
| `/software` | SoftwarePage | Sim | Tabela paginada de software |
| `/reports` | Reports | Sim | 19 relatorios com geracao e download |
| `*` | NotFound | Nao | Pagina 404 |

### Definicao de rotas (App.tsx)

```typescript
const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <AuthProvider>
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/" element={<Login />} />
            <Route path="/dashboard" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
            <Route path="/collaborators" element={<ProtectedRoute><Collaborators /></ProtectedRoute>} />
            <Route path="/machines" element={<ProtectedRoute><Machines /></ProtectedRoute>} />
            <Route path="/software" element={<ProtectedRoute><SoftwarePage /></ProtectedRoute>} />
            <Route path="/reports" element={<ProtectedRoute><Reports /></ProtectedRoute>} />
            <Route path="*" element={<NotFound />} />
          </Routes>
        </AuthProvider>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
)
```

## AuthContext

O `AuthContext` gerencia tokens JWT em localStorage e expoe funcoes `login`/`logout` para toda a aplicacao. A interface `AuthContextType` define o contrato do contexto.

```typescript
// auth/AuthContext.tsx
interface AuthContextType {
  user: User | null
  loading: boolean
  login: (username: string, password: string) => Promise<void>
  logout: () => void
}

const AuthContext = createContext<AuthContextType | null>(null)

/**
 * Provider de autenticação JWT para a aplicação.
 *
 * Verifica token existente no mount e expõe funções login/logout.
 *
 * @param props.children - Componentes filhos que terão acesso ao contexto.
 * @returns Provider com estado de autenticação.
 */
export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const token = localStorage.getItem('access_token')
    if (token) {
      api.get('/auth/me/')
        .then(res => {
          setUser({
            id: res.data.id,
            username: res.data.username,
            email: res.data.email,
            isStaff: res.data.is_staff,
          })
        })
        .catch(() => {
          localStorage.removeItem('access_token')
          localStorage.removeItem('refresh_token')
        })
        .finally(() => setLoading(false))
    } else {
      setLoading(false)
    }
  }, [])

  /**
   * Autentica usuário com credenciais e armazena tokens JWT.
   *
   * @param username - Nome de usuário.
   * @param password - Senha do usuário.
   * @throws Error se credenciais forem inválidas.
   */
  const login = async (username: string, password: string) => {
    const res = await api.post('/auth/login/', { username, password })
    localStorage.setItem('access_token', res.data.access)
    localStorage.setItem('refresh_token', res.data.refresh)
    const userRes = await api.get('/auth/me/')
    setUser({
      id: userRes.data.id,
      username: userRes.data.username,
      email: userRes.data.email,
      isStaff: userRes.data.is_staff,
    })
  }

  /** Encerra sessão, invalida refresh token e limpa localStorage. */
  const logout = () => {
    const refresh = localStorage.getItem('refresh_token')
    api.post('/auth/logout/', { refresh }).catch(() => {})
    localStorage.removeItem('access_token')
    localStorage.removeItem('refresh_token')
    setUser(null)
  }

  return (
    <AuthContext.Provider value={{ user, login, logout, loading }}>
      {children}
    </AuthContext.Provider>
  )
}

/**
 * Hook para acessar o contexto de autenticação.
 *
 * @returns Objeto com user, loading, login e logout.
 * @throws Error se usado fora de AuthProvider.
 */
export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth deve ser usado dentro de AuthProvider')
  }
  return context
}
```

## ProtectedRoute

Componente de guarda que redireciona para `/login` se o usuario nao esta autenticado. Exibe spinner durante verificacao de token no mount.

```typescript
// auth/ProtectedRoute.tsx
export default function ProtectedRoute({ children }: { children: ReactNode }) {
  const { user, loading } = useAuth()

  if (loading) {
    return (
      <div role="status" aria-live="polite" className="flex items-center justify-center min-h-screen">
        <div className="animate-spin h-8 w-8 border-4 border-accent border-t-transparent rounded-full" />
        <span className="sr-only">Carregando…</span>
      </div>
    )
  }

  if (!user) {
    return <Navigate to="/login" />
  }

  return <>{children}</>
}
```

## Axios Client (com interceptors JWT)

O cliente HTTP usa `import.meta.env.VITE_API_URL` (variavel de ambiente Vite) como base URL. Dois interceptors garantem autenticacao automatica e renovacao de token.

```typescript
// api/client.ts
import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:8000/api',
})

/**
 * Interceptor de request: adiciona Authorization header
 * com token Bearer armazenado em localStorage.
 */
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('access_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

/**
 * Interceptor de response: renova access token automaticamente
 * quando recebe 401, usando o refresh token. Em caso de falha
 * no refresh, limpa tokens e redireciona para /login.
 *
 * A flag _retry evita loop infinito de refresh (acoplamento temporal controlado).
 */
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config

    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true

      try {
        const refresh = localStorage.getItem('refresh_token')
        if (!refresh) {
          throw new Error('No refresh token')
        }

        const res = await axios.post(
          `${api.defaults.baseURL}/auth/refresh/`,
          { refresh }
        )
        localStorage.setItem('access_token', res.data.access)
        originalRequest.headers.Authorization = `Bearer ${res.data.access}`
        return api(originalRequest)
      } catch {
        localStorage.removeItem('access_token')
        localStorage.removeItem('refresh_token')
        window.location.href = '/login'
      }
    }

    return Promise.reject(error)
  }
)

export default api
```

## Tipos TypeScript

### Tipos de API (`types/api.ts`)

```typescript
/** Resposta paginada padrão do DRF (PageNumberPagination). */
export interface PaginatedResponse<T> {
  count: number
  next: string | null
  previous: string | null
  results: T[]
}

/** Par de tokens JWT retornado pelo endpoint de login. */
export interface TokenPair {
  access: string
  refresh: string
}
```

### Entidades do dominio (`types/entities.ts`)

Todas as interfaces usam **camelCase** no frontend. A transformacao de `snake_case` (API) para `camelCase` acontece nos hooks de React Query.

Alem das interfaces de listagem, o arquivo contem:

- **FormData types** — interfaces camelCase para react-hook-form (`CollaboratorFormData`, `MachineFormData`, `SoftwareFormData`)
- **Zod schemas** — validacao client-side com campos condicionais (`collaboratorSchema`, `machineSchema`, `softwareSchema`)
- **Mapping helpers** — funcoes de conversao camelCase↔snake_case (`toCollaboratorPayload`/`toCollaboratorFormData`, etc.) com coerce segura via helpers `str()`, `bool()`, `num()`

```typescript
/** Funcionário da JRC Brasil com dados de domínio e permissões. */
export interface Collaborator {
  id: number
  name: string
  domainUser: string
  department: string
  status: boolean
  fired: boolean
  hasServerAccess: boolean
  hasErpAccess: boolean
  hasInternetAccess: boolean
  hasCellphone: boolean
  email: string
}

/** Computador ou notebook registrado no inventário da JRC. */
export interface Machine {
  id: number
  hostname: string
  model: string
  serviceTag: string
  ip: string
  macAddress: string
  operationalSystem: string
  encrypted: boolean
  antivirus: boolean
  collaboratorId: number | null
  collaboratorName: string
  machineType: "desktop" | "notebook"
}

/** Licença de software gerenciada pela JRC. */
export interface Software {
  id: number
  softwareName: string
  licenseKey: string
  licenseType: "perpetual" | "subscription" | "oem"
  quantity: number
  inUse: number
  expiresAt: string | null
}

/** Relatório de auditoria exigido pela matriz japonesa. */
export interface Report {
  id: number
  number: string
  name: string
  nameJp: string
  category: string
  lastGenerated: string | null
  status: "pending" | "generated" | "sent"
}

/** Usuário autenticado do sistema. */
export interface User {
  id: number
  username: string
  email: string
  isStaff: boolean
}

/** Estatísticas consolidadas para o dashboard. */
export interface DashboardStats {
  activeCollaborators: number
  totalCollaborators: number
  totalMachines: number
  totalSoftware: number
  pendingReports: number
  totalReports: number
  machinesWithoutEncryption: string[]
}
```

## React Query

### Configuracao global (App.tsx)

O `QueryClient` e criado no `App.tsx` com defaults para todas as queries:

```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,   // 5 minutos — dados considerados frescos
      gcTime:    1000 * 60 * 10,  // 10 minutos — cache mantido apos desmount
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
})
```

### Leitura de dados — `useQuery` com transformacao snake_case para camelCase

Todos os hooks de leitura usam `useQuery` e transformam campos `snake_case` da API Django para `camelCase` do frontend TypeScript. Essa transformacao acontece exclusivamente no `queryFn`.

Cada entidade (Collaborators, Machines, Software) expoe 5 hooks:

| Hook | Tipo | Descricao |
|------|------|-----------|
| `useCollaborators(page, search)` | `useQuery` | Lista paginada com busca server-side |
| `useCollaborator(id)` | `useQuery` | Detalhe para edicao (enabled quando id != null) |
| `useCreateCollaborator()` | `useMutation` | POST com conversao camelCase→snake_case |
| `useUpdateCollaborator()` | `useMutation` | PUT com conversao camelCase→snake_case |
| `useDeleteCollaborator()` | `useMutation` | DELETE (soft delete no backend) |

Todas as mutations invalidam `queryClient` apos sucesso (`['collaborators']` e `['dashboard-stats']`).

### Hook generico de CRUD — `useCrudPage`

O hook `useCrudPage<TFormData>` centraliza a orquestracao CRUD reutilizada pelas 3 paginas de entidades. Recebe as mutations e um `entityLabel` para mensagens de toast, e retorna estado + handlers prontos:

```typescript
const crud = useCrudPage<CollaboratorFormData>({
  createMutation,
  updateMutation,
  deleteMutation,
  entityLabel: "Colaborador",
})
// crud.page, crud.search, crud.formOpen, crud.editingId, crud.deletingEntity
// crud.handleCreate, crud.handleEdit, crud.handleSave, crud.handleDelete
// crud.handleSearchChange, crud.handleFormClose, crud.setDeletingEntity
// crud.isSaving, crud.isDeleting, crud.serverErrors
```

### Escrita de dados — `useMutation`

Mutations invalidam queries relacionadas apos sucesso via `queryClient.invalidateQueries`.

```typescript
// hooks/useReports.ts (trecho)
import { useMutation, useQueryClient } from '@tanstack/react-query'
import api from '../api/client'

/** Mutation para gerar um relatório, invalidando a lista após sucesso. */
function useGenerateReport() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (reportNumber: string) =>
      api.post(`/reports/${reportNumber}/generate/`).then(r => r.data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reports'] })
    },
  })
}
```

### staleTime por dominio

Dominios com dados que mudam raramente podem ter `staleTime` maior definido diretamente na query:

```typescript
// hooks/useReports.ts (trecho)
function useReportsList() {
  return useQuery({
    queryKey: ['reports'],
    queryFn: async (): Promise<PaginatedResponse<Report>> => {
      const res = await api.get('/reports/')
      // ... transformacao snake_case -> camelCase ...
      return { count, next, previous, results }
    },
    staleTime: 1000 * 60 * 15, // 15 minutos para lista de relatórios
  })
}
```

### Download de relatorio via blob

Funcao utilitaria para download de relatorio em PDF ou Excel, usando `responseType: 'blob'` para receber o arquivo binario e criar um link temporario de download.

```typescript
// hooks/useReports.ts (trecho)

/**
 * Faz download de relatório em PDF ou Excel via blob.
 *
 * @param reportNumber - Número do relatório (ex: "08").
 * @param format - Formato do download ("pdf" ou "xlsx").
 */
async function downloadReport(reportNumber: string, format: 'pdf' | 'xlsx') {
  const res = await api.get(`/reports/${reportNumber}/?format=${format}`, {
    responseType: 'blob',
  })
  const url = window.URL.createObjectURL(new Blob([res.data]))
  const link = document.createElement('a')
  link.href = url
  link.download = `relatorio_${reportNumber}.${format}`
  link.click()
  window.URL.revokeObjectURL(url)
}
```

## MSW (Mock Service Worker)

O MSW intercepta requisicoes de rede em desenvolvimento, permitindo desenvolvimento frontend independente do backend. A ativacao e **opt-in**: liga apenas em `import.meta.env.DEV` **E** com `VITE_ENABLE_MSW === 'true'`.

> **Importante:** os handlers do MSW guardam dados **apenas em memoria** (resetam a cada reload da pagina) e **nao persistem no banco**. Por isso o default e DESLIGADO — deixar o mock ligado por engano contra o backend real faz parecer que as insercoes/edicoes nao persistem.

### Bootstrap condicional (main.tsx)

```typescript
// main.tsx
import { createRoot } from "react-dom/client"
import App from "./App.tsx"
import "./index.css"

/**
 * Ativa o MSW apenas quando explicitamente habilitado (opt-in).
 *
 * @returns Promise que resolve quando o worker está pronto (mock ligado) ou imediatamente.
 */
async function enableMocking() {
  if (import.meta.env.DEV && import.meta.env.VITE_ENABLE_MSW === 'true') {
    const { worker } = await import("./mocks/browser")
    return worker.start({ onUnhandledRequest: "bypass" })
  }
}

enableMocking().then(() => {
  createRoot(document.getElementById("root")!).render(<App />)
})
```

### Worker setup (mocks/browser.ts)

```typescript
// mocks/browser.ts
import { setupWorker } from 'msw/browser'
import { handlers } from './handlers'

export const worker = setupWorker(...handlers)
```

### Barrel export de handlers (mocks/handlers.ts)

```typescript
// mocks/handlers.ts
import { authHandlers } from './handlers/auth'
import { collaboratorsHandlers } from './handlers/collaborators'
import { machinesHandlers } from './handlers/machines'
import { softwareHandlers } from './handlers/software'
import { reportsHandlers } from './handlers/reports'
import { dashboardHandlers } from './handlers/dashboard'

export const handlers = [
  ...authHandlers,
  ...collaboratorsHandlers,
  ...machinesHandlers,
  ...softwareHandlers,
  ...reportsHandlers,
  ...dashboardHandlers,
]
```

### Padrao de handler (exemplo: colaboradores)

Cada handler simula CRUD completo no formato DRF `PageNumberPagination`, com dados mutaveis em memoria e soft-delete via `deletedIds` Set. Os dados iniciais vem de `mocks/data/fixtures.ts` (formato `snake_case`, como a API real).

Operacoes suportadas por entidade (collaborators, machines, software):

| Verbo | Rota | Descricao |
|-------|------|-----------|
| GET | `/collaborators/` | Lista paginada com busca (`?search=`) |
| GET | `/collaborators/:id/` | Detalhe (campos do modelo, sem aliases) |
| POST | `/collaborators/` | Criacao com validacao de duplicatas |
| PUT | `/collaborators/:id/` | Atualizacao |
| DELETE | `/collaborators/:id/` | Soft delete (marca ID como deletado, filtra em GET) |

## shadcn/ui

shadcn/ui fornece componentes acessiveis construidos sobre Radix UI e estilizados com Tailwind CSS. Os componentes sao copiados para `src/components/ui/` (60+ componentes) e customizados localmente — nao sao importados de um pacote externo.

### Configuracao

A configuracao inicial foi feita com `npx shadcn@latest init`, que gerou:

- `src/components/ui/` — diretorio com componentes
- `src/lib/utils.ts` — helper `cn()`
- Variaveis CSS de tema em `src/index.css`

Para adicionar novos componentes:

```bash
npx shadcn@latest add button
npx shadcn@latest add card
npx shadcn@latest add dialog
npx shadcn@latest add table
npx shadcn@latest add toast
```

### Helper `cn()`

Combina classes CSS condicionalmente, resolvendo conflitos entre classes Tailwind.

```typescript
// lib/utils.ts
import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

### Uso com Tailwind

```typescript
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

/**
 * Botao de acao primaria com variante destrutiva opcional.
 *
 * @param props.destructive - Aplica estilo destrutivo ao botao.
 * @param props.onClick - Callback de clique.
 * @param props.children - Conteudo do botao.
 * @returns Botao renderizado.
 */
function ActionButton({ destructive = false, onClick, children }: {
  destructive?: boolean
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <Button
      variant={destructive ? 'destructive' : 'default'}
      className={cn('w-full sm:w-auto', destructive && 'mt-2')}
      onClick={onClick}
    >
      {children}
    </Button>
  )
}
```

### Regras de uso

- **Nunca** sobrescrever estilos shadcn/ui com CSS modulo — usar apenas classes Tailwind.
- **Nao** reimplementar comportamentos ARIA que Radix UI ja fornece (focus trap, `aria-expanded`, etc.).
- Customizacoes de tema vao em `src/index.css` via variaveis CSS (`--primary`, `--background`, etc.).
- Usar o alias `@/` para importar componentes: `import { Button } from '@/components/ui/button'`.

## Path Aliases

O projeto usa o alias `@/` configurado no `vite.config.ts` para resolver para `src/`:

```typescript
// vite.config.ts (trecho)
resolve: {
  alias: {
    "@": path.resolve(__dirname, "./src"),
  },
},
```

Isso permite imports como:

```typescript
import { Button } from '@/components/ui/button'
import { useAuth } from '@/auth/AuthContext'
import api from '@/api/client'
```

## Variaveis de Ambiente

Arquivo `.env` na raiz de `packages/frontend/`:

```text
VITE_API_URL=http://localhost:8000/api
```

Variaveis Vite devem comecar com `VITE_` para serem expostas ao codigo client-side. Acessadas via `import.meta.env.VITE_API_URL`.

> Em producao com nginx, a URL da API pode ser relativa (`/api`) se o nginx faz proxy reverso.

## Comandos

```bash
cd packages/frontend

# Instalar dependencias
npm install

# Dev server (Vite, porta 8080) — backend real; MSW so com VITE_ENABLE_MSW=true
npm run dev

# Build de producao
npm run build

# Build de desenvolvimento (com source maps)
npm run build:dev

# Preview do build de producao
npm run preview

# Testes unitarios (Vitest, execucao unica)
npm run test

# Testes unitarios (Vitest, modo watch)
npm run test:watch

# Linting (ESLint)
npm run lint
```

### Testes

O projeto usa tres niveis de teste:

| Ferramenta | Tipo | Uso |
|-----------|------|-----|
| Vitest | Unitario/Integracao | Hooks, utilitarios, logica isolada |
| @testing-library/react | Componentes | Renderizacao e interacao de componentes |
| Playwright | E2E | Fluxos completos no navegador |

Exemplo de teste com `@testing-library/react`:

```typescript
import { render, screen, waitFor } from '@testing-library/react'
import { BrowserRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { AuthProvider } from '../auth/AuthContext'
import Login from '../pages/Login'

/** Renderiza componente com todos os providers necessarios. */
function renderWithProviders(component: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <AuthProvider>
          {component}
        </AuthProvider>
      </BrowserRouter>
    </QueryClientProvider>
  )
}

/** Verifica que o formulario de login renderiza os campos esperados. */
test('renderiza formulario de login', () => {
  renderWithProviders(<Login />)
  expect(screen.getByLabelText(/usuario/i)).toBeInTheDocument()
  expect(screen.getByLabelText(/senha/i)).toBeInTheDocument()
  expect(screen.getByRole('button', { name: /entrar/i })).toBeInTheDocument()
})
```

## Fonte

O projeto usa a fonte **IBM Plex Sans** via `@fontsource/ibm-plex-sans`, importada no CSS global.
