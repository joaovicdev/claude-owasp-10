# Spring Boot — stack idiom

**ID prefix:** `SPR` · **Status: unverified against a real codebase.** Written
from framework documentation and the core rules, not from production Spring code
— unlike `nestjs.md`. Treat the specifics as a starting point and tighten them on
first contact with a real project.

### SPR.1 — Method security must be enabled to exist → A01

`@PreAuthorize` is inert unless method security is switched on. An annotation
that silently does nothing is worse than no annotation, because the code reads as
protected.

```java
@Configuration @EnableMethodSecurity   // without this, @PreAuthorize is decoration
class SecurityConfig { }
```

Verify with a test that an unauthorized principal actually receives 403.

### SPR.2 — `SecurityFilterChain` matchers are ordered and specific → A01

Rules are evaluated in order, so a broad `permitAll()` placed early shadows the
stricter matchers below it. End the chain with `anyRequest().authenticated()`,
and keep `permitAll()` to exact paths — a prefix like `/api/**` for one public
endpoint opens everything under it.

### SPR.3 — Authorize the instance, scope the query → A01

`@PreAuthorize("hasRole('USER')")` proves a role, not ownership. Repository
methods must carry the tenant/owner predicate.

```java
// wrong                                     // right
orderRepository.findById(id)                 orderRepository.findByIdAndTenantId(id, caller.tenantId())
                                             // or a Specification carrying the predicate
```

`@PostAuthorize` runs after the object is loaded and after any side effect in the
method — prefer `@PreAuthorize` plus a scoped query.

### SPR.4 — `@Query` is never concatenated → A05

```java
// wrong: @Query("SELECT o FROM Order o WHERE o.name LIKE '%" + name + "%'")
@Query("SELECT o FROM Order o WHERE o.name LIKE %:name%")
List<Order> search(@Param("name") String name);
```

The same applies to `EntityManager.createNativeQuery` and any `Sort`/`Pageable`
field arriving from the request — `Sort.by(userInput)` is an identifier, so it
needs an allowlist.

### SPR.5 — Bind a DTO, return a DTO → A01, A04

Binding a request directly onto a JPA entity is mass assignment: any exposed
setter becomes writable, including `id`, `role`, and audit columns. Use a request
DTO with `@Valid` and Bean Validation constraints, and a response DTO so lazy
associations and secret columns cannot serialize by accident.

### SPR.6 — Actuator, errors and CORS → A02, A10

Actuator endpoints expose configuration, environment, mappings, and heap dumps.
Expose only what is needed (`management.endpoints.web.exposure.include=health`),
put management on a separate port, and secure it.

```properties
server.error.include-stacktrace=never
server.error.include-message=never
spring.jpa.show-sql=false
```

`@CrossOrigin("*")` on a controller silently widens whatever the security config
established — configure CORS centrally with exact origins, and never combine a
wildcard origin with credentials.

### SPR.7 — Deserialization → A08

Do not enable Jackson polymorphic/default typing (`activateDefaultTyping`) on any
mapper that sees request data; it lets the payload name the class to instantiate,
which is the classic gadget-chain entry point. Avoid Java native deserialization
of untrusted bytes entirely. Prefer `@JsonCreator` with declared fields, and set
`FAIL_ON_UNKNOWN_PROPERTIES` so unexpected fields are rejected rather than
ignored.

Also watch YAML: `SnakeYAML`'s default constructor instantiates arbitrary types —
use `SafeConstructor`.

### SPR.8 — Authentication → A07

Use `DelegatingPasswordEncoder` (`{bcrypt}`/`{argon2}`) so the hash carries its
algorithm and can be upgraded. When validating JWTs, pin the algorithm, issuer,
and audience on the decoder rather than trusting the token header. Rate limit
login and reset endpoints — Spring Security does not do this for you. Rotate the
session on authentication and invalidate it on logout.

### SPR.9 — Logging → A09

Do not log DTOs or entities wholesale — a `toString()` generated over all fields
will print secrets the day someone adds one. Keep `spring.jpa.show-sql` off in
production (it prints bound parameters at debug level), and configure the
scrubber on any APM/error SDK.

### SPR.10 — Supply chain → A03

Pin exact versions or inherit a managed BOM; avoid `LATEST`/`RELEASE` and
version ranges. Commit Gradle dependency locks. Run a dependency vulnerability
check in CI and triage the output rather than muting it. Spring Boot's starters
pull large transitive trees — the parent version is the single most important
thing to keep current.

### SPR.11 — Outbound requests take an allowlist → A01

`RestTemplate` and `WebClient` will resolve and connect anywhere, which turns a
URL field into a reach into the private network. Validate the **resolved address**
against an allowlist, not the hostname, and stop redirect following — the default
client follows them.

```java
InetAddress addr = InetAddress.getByName(URI.create(url).getHost());
if (addr.isLoopbackAddress() || addr.isSiteLocalAddress() || addr.isLinkLocalAddress())
    throw new IllegalArgumentException();
```

`isLinkLocalAddress()` is what excludes the cloud metadata endpoint. Set connect
and read timeouts on the client; neither has a useful default.

### SPR.12 — CSRF and Thymeleaf escaping → A01, A05

Spring Security enables CSRF protection by default, and `http.csrf(csrf -> csrf.disable())`
is the line that removes it — legitimate for a stateless bearer-token API, a
finding for anything holding a session cookie. If it is disabled, the diff should
say which of the two it is.

Thymeleaf escapes with `th:text`; `th:utext` is the sink and belongs only over
sanitizer output. The same applies to building a URL attribute from user input.

## Grep signals

```bash
rg -n 'EnableMethodSecurity|EnableGlobalMethodSecurity' src/
rg -n 'permitAll|anyRequest|requestMatchers|antMatchers' src/
rg -n '@Query\s*\(.*\+|createNativeQuery|Sort\.by\(' src/
rg -n 'findById\(|getOne\(|getReferenceById\(' src/
rg -n 'activateDefaultTyping|enableDefaultTyping|readObject|new Yaml\(' src/
rg -n 'CrossOrigin' src/
rg -n 'include-stacktrace|include-message|show-sql|exposure.include' src/main/resources/
rg -n '<version>\s*(LATEST|RELEASE)' pom.xml
rg -n 'RestTemplate|WebClient|HttpClient|URI\.create' src/
rg -n 'csrf\(\)?\.disable|csrf\s*->\s*csrf\.disable|th:utext' src/
```
