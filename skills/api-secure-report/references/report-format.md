# Report format

Three contracts: what a subagent returns, how severity is decided, and the shape
of the final document.

## 1. Subagent return contract

A subagent returns zero or more blocks and nothing else — no preamble, no
summary, no reassurance that it looked carefully. One block per finding:

```
--- FINDING
scope: route | global
method: GET                      # route scope only
route: /orders/:id               # route scope only
component: bootstrap (main.ts)   # global scope only — what the finding is about
location: src/orders/orders.controller.ts:31
ref: A01.Q2                      # an id that exists in the secure-coding files
severity: critical | high | medium | low
what: <one or two sentences — the defect, stated plainly>
exploit: <concrete steps an attacker takes, with the request that does it>
fix: <what to change, in this project's idiom, pointing at the correct pattern>
--- END
```

Rules the consolidation step enforces, so state them in the subagent prompt:

- **No `location`, no finding.** A defect the agent did not open a file to
  confirm does not go in the report.
- **`ref` must exist.** `A01.Q1`–`A01.Q11`, `A02.Q1`–`A02.Q8`, `A03.Q1`–`A03.Q7`,
  `A04.Q1`–`A04.Q8`, `A05.Q1`–`A05.Q9`, `A06.Q1`–`A06.Q9`, `A07.Q1`–`A07.Q9`,
  `A08.Q1`–`A08.Q7`, `A09.Q1`–`A09.Q7`, `A10.Q1`–`A10.Q8`, plus `NEST.1`–`NEST.17`,
  `LAR.1`–`LAR.12`, `SPR.1`–`SPR.12`. If nothing fits, the gap belongs in the
  `secure-coding` skill as a new review question — not invented here.
- **`exploit` is concrete.** "An attacker could gain unauthorized access" is not
  an exploit. "Authenticate as any user, call `GET /orders/9001` with an id
  belonging to another tenant, receive the full order including the customer's
  address" is.
- **`fix` is actionable and idiomatic.** Name the construct this stack uses —
  `where: { id, tenantId }`, a policy plus a global scope, a `Specification`
  carrying the tenant predicate — not "add proper authorization".
- Write in **English**. Translation happens once, at consolidation.

## 2. Severity

One line each, so that agents working on different modules land in the same
place:

| Severity | Definition |
|---|---|
| **critical** | Reachable unauthenticated, or grants privilege escalation / arbitrary code / mass data access. No preconditions worth mentioning. |
| **high** | Any authenticated caller reaches data or actions belonging to another user or tenant, or a secret is exposed. Preconditions are trivially met. |
| **medium** | Real impact behind a precondition — a specific role, a race, a particular configuration — or an information leak that enables another attack. |
| **low** | Defense in depth, hardening, or a defect whose impact is bounded and non-sensitive. |

When two severities are arguable, take the higher one and say why in `what`.

## 3. Report template

Below is the `pt-BR` rendering, which is the default. For another language,
translate labels and prose and keep the structure, the ids, the paths and the
code exactly as they are.

```markdown
# Relatório de segurança da API — <projeto>

**Stack:** <detectada, ou "nenhuma detectada — core agnóstico">
**Escopo:** <raiz do repositório, ou o caminho passado>
**Data:** <YYYY-MM-DD>
**Rotas varridas:** <n> · **Com achado:** <n> · **Limpas:** <n>

## Resumo

| Severidade | Qtd |
|---|---|
| Crítica | 0 |
| Alta | 3 |
| Média | 4 |
| Baixa | 2 |

| Categoria OWASP | Achados |
|---|---|
| A01:2025 — Broken Access Control | 4 |
| A05:2025 — Injection | 2 |

## Inventário de rotas

Toda rota do projeto, com achado ou sem.

| Método | Rota | Arquivo | Guard | Status |
|---|---|---|---|---|
| GET | /orders/:id | src/orders/orders.controller.ts:31 | JwtGuard | ⚠ A01.Q2, A04.Q1 |
| POST | /orders | src/orders/orders.controller.ts:45 | JwtGuard | OK |
| GET | /health | src/health/health.controller.ts:12 | @Public() | OK |

## Achados

### 1. GET /orders/:id — Alta — `A01.Q2`

- **Rota vulnerável:** `GET /orders/:id` (`src/orders/orders.controller.ts:31`)
- **A vulnerabilidade:** <o defeito, em uma ou duas frases>
- **Como um atacante pode explorar:** <passos concretos, com a requisição>
- **Mitigação:** <o que mudar, no idioma da stack>

### 2. …

## Achados globais

Não pertencem a uma rota específica — mesma estrutura, com **Componente** no
lugar de **Rota vulnerável**.

### 8. Bootstrap da aplicação — Alta — `NEST.1`

- **Componente:** `src/main.ts:14`
- **A vulnerabilidade:** …
- **Como um atacante pode explorar:** …
- **Mitigação:** …

## Riscos já aceitos

De `SECURITY-NOTES.md` — não são achados novos.

| ID | Ref | Risco | Revisar quando |
|---|---|---|---|
| R-1 | `A08.Q1` | … | … |

## Limites desta varredura

- <o que não foi enumerado ou lido, e por quê>
- <rotas dinâmicas, gateway externo, código gerado, diretórios fora do escopo>
- Rotas efetivamente lidas: <n> de <n>.
- Ausência de achado não é prova de ausência de vulnerabilidade. As regras são as
  do skill `secure-coding`; um achado citando `A01.Q2` é resolvível contra
  `owasp/A01-broken-access-control.md`.
```

The **Limits** section is not optional and is never empty — at minimum it states
the coverage numbers and the last line. A report that hides what it did not look
at is worse than no report.
