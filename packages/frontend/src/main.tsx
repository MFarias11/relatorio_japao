/**
 * Entry point da aplicação React.
 *
 * O MSW (Mock Service Worker) é opt-in: só é inicializado quando explicitamente
 * solicitado via `VITE_ENABLE_MSW=true` em desenvolvimento. Por padrão (e em
 * produção) a aplicação fala com o backend real, evitando que os mocks
 * interceptem silenciosamente os writes e mascarem a persistência no banco.
 */
import { createRoot } from "react-dom/client"
import App from "./App.tsx"
import "./index.css"

/**
 * Ativa o MSW apenas quando explicitamente habilitado (opt-in).
 *
 * O mock só liga em modo desenvolvimento E com `VITE_ENABLE_MSW=true`. Como os
 * handlers do MSW guardam dados em memória (que somem a cada reload), deixá-lo
 * ligado por engano contra o backend real faz parecer que os dados não
 * persistem — por isso o default é desligado.
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
