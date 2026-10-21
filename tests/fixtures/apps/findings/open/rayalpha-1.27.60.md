# rayalpha: revisión con raylang 1.27.60 (1 Oct 2026)

Cómo se midió: fixture.

| # | estado | evidencia |
|---:|---|---|


### 3. [B] El canal pierde mensajes en nativo
**App:** rayalpha (raylang 1.27.60, net 0.10.1)
**Afecta a:** raylang

Un canal acotado pierde el último mensaje al cerrarse.

### 4. ✅ [D] llms.txt no menciona select_timeout
**App:** rayalpha (raylang 1.27.60)

Falta en la tabla de concurrencia.

### 5. [E/D] ray-button no tiene tamaño grande
**App:** rayalpha (raylang 1.27.60, elements 0.5.2)
**Afecta a:** ray-elements
**Issue:** ray-elements#12

Pide un tamaño grande y redondo.
