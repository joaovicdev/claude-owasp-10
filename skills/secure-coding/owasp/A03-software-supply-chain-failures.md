# A03:2025 — Software Supply Chain Failures

**ID:** `A03:2025` · **2021:** A06:2021 "Vulnerable and Outdated Components", renamed and widened · **Applies to:** any

OWASP traces this entry back to "A9 – Using Components with Known Vulnerabilities"
in the 2013 Top 10 and states that the risk "has grown in scope to include all
supply chain failures, not just ones involving known vulnerabilities." A vulnerable
dependency is now one failure mode in this category, not the whole of it.

## Rule

1. Adding a dependency is a trust decision, not a convenience. Check what it is,
   who maintains it, how recently, and what it pulls in transitively.
2. Every build resolves from a committed lockfile. A build that can silently
   resolve a different artifact than the last one is not reproducible.
3. Install and build hooks execute arbitrary code with the developer's and CI's
   privileges. Treat `postinstall`, plugins, and build scripts as code you ran.
4. CI credentials are supply chain. A workflow triggered by untrusted input must
   not have publish, deploy, or write tokens in scope.

## How it shows up in a backend API

- A single-purpose helper is pulled in for one function. It arrives with a
  transitive tree nobody has looked at, and now every one of those maintainers
  can run code in the build.
- Version ranges plus an ignored or missing lockfile mean the artifact in
  production was never the artifact that was tested.
- Typosquatting and namespace confusion: a package whose name differs by one
  character, or an internal package name that also resolves publicly, so the
  public one wins.
- A maintainer transfers or loses an account and a new release ships a payload.
  The dependency never changed in the manifest — only upstream did.
- CI pulls unpinned actions/images by mutable tag, so `@v3` or `:latest` is a
  standing remote-code-execution channel into the pipeline.
- Vulnerable versions stay because the audit output is noisy and nobody triages
  it, and because "we don't call that function" was asserted, not verified.
- Build containers and base images are dependencies too, and they are the least
  frequently reviewed ones.

## Anti-pattern

```
add_dependency("left-padd", version: "^2")     # typo'd name, floating range
lockfile: not committed
ci: uses action@latest with a publish token available to fork-triggered runs
```

## Correct

```
before adding:  who maintains it · last release · open critical issues
                · transitive count · does it need install hooks
add_dependency("left-pad", version: "2.1.0")   # exact
commit lockfile
ci: pin actions/images by digest
    build job runs with read-only credentials
    publish job is a separate, protected job
audit on a schedule, with triage recorded
```

For an internal package name, claim the public name or use a scoped registry —
name confusion is resolved by the resolver, not by intent.

## Idiom by stack

| Stack | Lockfile / pinning | Audit |
|---|---|---|
| Node / NestJS | `package-lock.json`, `npm ci`, `--ignore-scripts` where feasible | `npm audit`, `osv-scanner` |
| PHP / Laravel | `composer.lock`, `composer install` (never `update` in CI) | `composer audit` |
| Java / Spring | `pom.xml` exact versions or a BOM; Gradle lockfiles | `dependency-check`, `gradle dependencies` |
| Containers | pin base images by digest, not tag | image scanning in CI |

→ `stacks/nestjs.md (NEST.15)` · `stacks/laravel.md (LAR.10)` · `stacks/spring-boot.md (SPR.10)`

## Review questions

- **A03.Q1** — For each added dependency: is it maintained, is the name exactly
  right, and was the transitive footprint considered?
- **A03.Q2** — Is the lockfile committed and updated in the same change, and does
  CI install from it rather than re-resolving?
- **A03.Q3** — Does the new package run install/build hooks, and is that
  acceptable in CI and on developer machines?
- **A03.Q4** — Are CI actions, plugins, and base images pinned immutably
  (digest/exact version) rather than by mutable tag?
- **A03.Q5** — Can a workflow triggered by untrusted input reach publish, deploy,
  or repository-write credentials?
- **A03.Q6** — Does this change pull a package whose functionality already exists
  in the standard library or an existing dependency?
- **A03.Q7** — Are known-vulnerable versions present, and is any accepted risk
  recorded with its reason rather than silently ignored?

## Grep signals

```bash
rg '"(dependencies|devDependencies)"' -A 40 package.json | rg '\^|~|\*|latest'
rg -n 'postinstall|preinstall|prepare|prepublish' package.json
rg -n 'uses:\s*[^@]+@(v?\d+|main|master|latest)' .github/workflows/ 2>/dev/null
rg -n '^FROM .*:(latest|\d+)\s*$' Dockerfile* 2>/dev/null
rg -n '<version>\s*(LATEST|RELEASE|\$\{)' pom.xml 2>/dev/null
```
