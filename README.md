# raymcp

Los hallazgos de las ray-apps (`findings/`) como servidor
[MCP](https://modelcontextprotocol.io), y un agente de línea de órdenes que los usa a través de
ese servidor, escrito en [raylang](https://github.com/ray-language/raylang). Un asistente (Claude
Code, Claude Desktop, cualquier cliente MCP) puede buscar, leer y crear hallazgos; `raymcp ask`
hace lo mismo con un modelo de Anthropic o con cualquier endpoint compatible con OpenAI.

```
$ raymcp ask "¿qué hay abierto sobre ptr?"
raymcp: 4 tools from the findings server; model claude-opus-5-5; autonomy ask
  → mcp__raymcp__search_findings {"query":"ptr","status":"open"} (read)
  ← 1 match: ⏎ #214 [B] abierto · rayffi (raylang 1.27.65) · afecta a raylang — Un struct con un ptr…
  … step 2
  → mcp__raymcp__get_finding {"number":214} (read)
  ← open/rayffi-1.27.65.md, abierto ⏎ ### 214. [B] …
  … step 3
El #214 (rayffi, abierto): en nativo, un struct con un ptr enviado por un canal compila y luego…
  [done, 3 step(s), …]
```

```
raymcp serve [--root DIR] [--http HOST:PORT]   el servidor MCP (stdio por defecto)
raymcp tools [--root DIR]                      conectarse como cliente y listar lo que ofrece
raymcp call TOOL [JSON] [--root DIR]           llamar a una herramienta a través de MCP
raymcp ask [PROMPT] [opciones]                 el agente: un turno, o una conversación sin PROMPT
raymcp fake-model SCRIPT [--port N]            un modelo con guion, compatible con OpenAI
```

`--root` es el directorio de las ray-apps, el que tiene `findings/`. Por defecto es
`$RAYMCP_ROOT`, y si no, el directorio actual si tiene `findings/`, y si no, su padre.

## El servidor

| Herramienta | Qué hace |
|---|---|
| `search_findings` (solo lectura) | palabras que deben aparecer todas, y filtros por tipo, app, a quién afecta y estado; los más nuevos primero |
| `get_finding` (solo lectura) | el texto completo de uno, con su archivo y estado |
| `findings_summary` (solo lectura) | cuántos hay, y los abiertos por tipo, componente y app |
| `add_finding` | uno nuevo, con el siguiente número global, en el archivo de campaña de su app y versión. Regenera `INDEX.md` con `tools/findings.py` si está |

Recursos: `findings://index` (`INDEX.md`) y `findings://convention` (`findings/README.md`). Las
instrucciones del servidor piden buscar antes de crear. `add_finding` aplica las reglas de
`tools/findings.py`:
- quien encuentra no es el dueño;
- el componente afectado tiene que ser uno conocido o una app;
- el tipo es B, D, E o una combinación;
- la versión es X.Y.Z.

Además, rechaza un título repetido. Cada llamada vuelve a leer los archivos, así que lo que otro
haya escrito ya está.

Para usarlo desde Claude Code:

```sh
make build
claude mcp add raymcp -- /ruta/a/raymcp/raymcp serve --root /ruta/a/ray-apps
```

## El agente

`raymcp ask` usa los paquetes `agent` y `llm`, y se conecta a su propio servidor como a cualquier
otro: lanza `raymcp serve` como proceso hijo y habla MCP por stdio.

| Opción | |
|---|---|
| `--model M` | por defecto `claude-opus-5-5`, con la clave en `ANTHROPIC_API_KEY` |
| `--endpoint URL` | un servidor compatible con OpenAI (Ollama: `http://127.0.0.1:11434/v1`) |
| `--key-env VAR` | de qué variable sale la clave |
| `--fake SCRIPT` | el modelo con guion de `SCRIPT`, sin clave (ver abajo) |
| `--autonomy` | `ask` (por defecto), `edits` o `auto` |
| `--yes` / `--no` | responder siempre así a las aprobaciones; por defecto se pregunta en la terminal |
| `--stream` | el texto según llega |
| `--steps N` | llamadas al modelo por turno (20) |

`add_finding` no es de solo lectura, así que en `ask` y en `edits` pregunta antes de escribir
(#220). Ctrl-C cancela el turno en curso; dos seguidos salen.

### El modelo con guion

No hace falta una clave para ver el bucle entero. `src/fakemodel.ray` es un servidor HTTP con el
dialecto de Chat Completions de OpenAI, con y sin streaming. A cada petición contesta el siguiente
paso de un guion JSON:

```json
[
  {"text": "Let me look.", "tools": [{"name": "mcp__raymcp__search_findings", "arguments": {"query": "ptr"}}]},
  {"text": "It is #214."},
  {"status": 429, "retry_after": 1},
  {"delay_ms": 3000, "text": "too late"}
]
```

Guarda cada petición que recibe, y así los tests comprueban qué herramientas se ofrecieron y qué
resultado volvió del servidor. La posición en el guion la lleva una fibra actor, porque cada
handler recibe una copia de lo que captura. `make demo` lo usa con `examples/demo.json`.

## Cómo

```
src/findings.ray    los archivos de hallazgos como datos: leer, buscar, resumir, añadir
src/server.ray      el proveedor MCP (mcp/serve): herramientas, recursos, instrucciones
src/ask.ray         el agente (agent + llm) conectado al servidor (mcp)
src/fakemodel.ray   el modelo con guion (net/webserver y una fibra actor)
src/main.ray        la línea de órdenes
```

## Lo que se probó del protocolo

Con un servidor de prueba aparte y `call_timeout_ms = 1000`, todo se comportó como dicen las doc
de `mcp`:

| La herramienta… | El cliente recibe | El servidor |
|---|---|---|
| hace `panic` | `Err(the tool failed: kaboom)` | sigue vivo |
| se sale de un array | `Err(… index 5 out of range …)` | sigue vivo |
| escribe basura en stdout | `Ok`; la línea se ignora | sigue vivo |
| tarda 3 s | `Err(no reply after 1000ms; the server was killed)` a los 1008 ms | se relanza en la siguiente llamada (60 ms) |
| hace `exit(3)` | `Err(the server exited (exit 3) before answering)` | se relanza (32 ms) |

Matar `raymcp ask` con SIGTERM a mitad de turno no deja huérfano al `raymcp serve` hijo: se va al
cerrarse su entrada.

## Uso

```bash
make build         # ./raymcp, binario nativo
make test          # 17 tests en la VM
make test-native   # los mismos, compilados
make tools         # lo que ofrece el servidor sobre los hallazgos reales, por MCP
make demo          # un turno del agente con el modelo con guion
```

## Estado

| Qué | Estado |
|---|---|
| Hallazgos, servidor, cliente, agente | **17 tests** en VM y nativo (raylang 1.27.65; agent, llm y mcp 0.2.0; net 0.10.1) |
| De punta a punta | modelo con guion → agente → cliente MCP → `raymcp serve` en otro proceso → archivos: búsqueda, aprobación sí y no, `auto`, streaming, reintentos (500, 429), cancelación y el límite de pasos |
| Sobre los hallazgos reales | `tools`, `call` y `ask --fake` sobre los 221 hallazgos; el resumen coincide con `INDEX.md` |
| Windows x86_64 nativo | los tests del agente se saltan: el modelo con guion es un servidor HTTP, y allí `accept` bloquea el hilo de su worker (#222, encontrado en raystat) |
| Un modelo de verdad | **sin probar**: en esta máquina no hay clave de Anthropic ni modelo local |
| Claude Code como cliente | sin probar (el comando para registrarlo está arriba) |

Pendiente: probar con un modelo real, el transporte HTTP (`--http`) con un cliente, y una
herramienta para cerrar hallazgos (poner la marca ✅ al volver a medir).

## Hallazgos de dogfood

En `findings/open/raymcp-1.27.65.md` del directorio de las apps:

1. **#217 [D]** Bajo `ray test --native`, `launch_mode()` dice `"native"` y `self_command()` da el
   binario de test, así que el servidor se lanzaba mal. La doc dice `"test"`. raymcp mira
   `RAY_TEST`.
2. **#218 [B]** Un `Option` de una tupla de 4 elementos no compila en nativo, con errores de rustc
   que `ray check` no anticipa. Con 2 y 3 elementos sí compila.
3. **#219 [E]** `llm` y `mcp` 0.2.0 fijan `net` en v0.5.0 por git. Añadir `net ^0.10.1` lo sustituye
   para todos, sin aviso.
4. **#220 [E]** Por MCP no se puede declarar una herramienta que escribe sin destruir, y `agent` la
   trata como `EXEC`: en `edits` también pregunta.
5. **#221 [D]** `ray doc` muestra `-> Config` sin su módulo, y `llm/llm` no lo reexporta.

Lo que salió bien:

- los tres paquetes juntos a la primera: `mcp/serve` con `handle` puro para los tests, el cliente
  con relanzamiento y plazos, y `agent` con aprobación, eventos, streaming, cancelación y límite de
  pasos;
- `for_endpoint` contra un servidor propio;
- los reintentos con `retry-after`;
- el mismo comportamiento en VM y nativo, salvo los dos hallazgos de arriba.
