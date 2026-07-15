# Mini marketplace B2B

Aplicación web que permite a una tienda comprar productos de distintos proveedores. Al confirmar la compra se genera una orden que agrupa los productos en subórdenes: una por cada proveedor involucrado.

## Stack

- Ruby 3.3.4 (fijado en `.ruby-version`)
- Rails 8.0.5
- SQLite (adapter `sqlite3`)
- Vistas ERB server-side, sin JS ni frameworks de frontend

## Instalación y ejecución

​```bash
bundle install        # dependencias
bin/rails db:create   # crear la BD
bin/rails db:migrate  # migraciones
bin/rails db:seed     # sembrar datos
bin/rails server      # levantar en http://localhost:3000
​```

Atajo para preparar la BD completa: `bin/rails db:create db:migrate db:seed`.

### Tests

​```bash
bin/rails test
​```

Suite: 43 tests, 174 aserciones, 0 fallos.

- **Checkout** (`test/services/checkout_test.rb`, 18 tests): agrupación por proveedor (dos proveedores → dos subórdenes; uno → una), cálculo de subtotal y total, congelado de precio, rollback transaccional, carrito vacío y cantidad ≤ 0, que un error que no es de cantidad no se reporte como tal, el snapshot del descuento (editar o borrar el descuento no altera la orden ya creada) y la validación de monto mínimo post-descuento.
- **Carrito** (`test/controllers/cart_controller_test.rb`, 14 tests): agregar (con acumulación), actualizar, actualizar a cero (quita), quitar, carrito vacío, persistencia entre requests, manejo sin error 500 de cantidad inválida y producto inexistente, el precio con descuento en la vista y el bloqueo por monto mínimo.
- **Descuentos y precios** (`test/models/discount_test.rb` y `test/services/pricing_test.rb`, 11 tests): validaciones del descuento (porcentaje 1–100, `ends_at` posterior a `starts_at`, productos del propio proveedor), vigencia por ventana con bordes exactos, solape resuelto por el mayor porcentaje, y el redondeo al peso del precio con descuento.

## Flujo

Catálogo (raíz) → agregar productos al carrito → carrito agrupado por proveedor con subtotales y total → confirmar → orden con sus subórdenes.

## Datos iniciales

Los seeds crean 1 tienda (Tienda Central), 2 proveedores (Distribuidora Norte, Distribuidora Sur) y 6 productos (3 por proveedor), con precios en CLP como enteros y stock variado. También configuran un monto mínimo de compra por proveedor (`min_amount`; 0 = sin mínimo) y descuentos (vigentes y uno fuera de ventana, ya expirado) para poder probar ambos casos. Son idempotentes: correr `db:seed` varias veces no duplica datos.

---

## Decisiones de diseño más importantes

**Snapshot de precio.** Cada `OrderItem` guarda su propio `unit_price`, copiado desde `product.price` en el momento de confirmar la compra. Desde ahí la orden es autosuficiente y nunca vuelve a leer el precio del catálogo. Si el precio del producto cambia después, la orden conserva el precio con que se compró. Es la regla central del enunciado.

**Creación transaccional en un service object.** La orden se crea en `Checkout` (un PORO en `app/services/`), envuelto en una única transacción y usando `create!` (con bang). Si cualquier paso falla, la excepción escapa del bloque `transaction`, ActiveRecord hace rollback, y no queda ninguna orden, subórden ni item creado a medias. Los `rescue` están fuera del bloque a propósito: la excepción tiene que escapar para que el rollback ocurra, y recién después se convierte en un resultado de error.

**Totales calculados, no persistidos.** `subtotal` y `total` se calculan sumando los items, no se guardan en columnas. Como el `unit_price` ya está congelado, recalcular siempre da el mismo valor histórico: no hay riesgo de desincronización y hay una fuente menos de inconsistencia. El tradeoff es que la suma ocurre en Ruby; para el volumen de este ejercicio es correcto y más simple.

**Carrito en sesión, con la lógica fuera de la sesión.** El carrito vive en `session` como un hash `{ product_id => quantity }`. La clase `Cart` (un PORO) envuelve ese hash y ofrece una API limpia sin conocer HTTP ni sesión; el controlador traduce entre ambos. El `Checkout` recibe una lista plana de items, no la sesión ni el carrito, de modo que es testeable sin la capa web y define su propia frontera de consistencia.

**Pricing como fuente única del precio.** Un solo lugar responde "cuánto vale este producto en este instante": el PORO `Pricing` (`app/services/pricing.rb`), construido con `(product, at:)`. Lo usan tanto el carrito (para mostrar el precio vivo) como el `Checkout` (para congelarlo), así que la aritmética del descuento no se repite en ninguna vista ni modelo. El precio con descuento se calcula como `(list_price * (100 - percentage) / 100.0).round`: la multiplicación se hace en enteros primero para no perder precisión, la división es por `100.0` (float, no entero) para no truncar, y el `.round` cierra al peso. El dinero es entero (CLP) y el redondeo vive solo acá; con división entera, `8990` al 15% daría `7641` en vez de `7642`.

**Instante único de valuación.** El `Checkout` captura un solo `at = Time.current` al inicio de `call` y lo usa para todos los items y para validar los mínimos. Si cada item consultara `Time.current` por su cuenta, una compra que cruce el borde de una ventana de descuento podría congelar unos items con descuento y otros sin él; con un único instante, toda la orden se valúa de forma consistente.

**Se congela el resultado, no la receta.** El descuento sigue la misma regla que ya regía el precio. `OrderItem` guarda `list_price` (catálogo del momento) y `unit_price` (lo efectivamente pagado, ya con descuento), ambos calculados al confirmar; la orden nunca recalcula el descuento ni vuelve a leer `discounts`, así que editar o borrar un descuento después no altera órdenes históricas. Por eso **no** se guarda `discount_id` en `OrderItem`: acoplaría la orden a una tabla mutable e invitaría a recalcular, y el ahorro ya queda implícito como `list_price − unit_price`.

## Supuestos

- La tienda "autenticada" se simula usando la primera tienda de la BD (`Store.first`). La autenticación está fuera de alcance según el enunciado.
- El stock **no se valida ni se descuenta** en ningún flujo. La columna existe solo para poblar los seeds con datos variados.
- El dinero se representa como enteros (pesos chilenos, sin decimales ni centavos). Un helper `clp` lo formatea a `$8.990` solo en las vistas; el valor calculado siempre es entero.
- Los descuentos son solo porcentuales y se crean por seeds o consola: no hay UI de administración (fuera de alcance).
- Solape de descuentos permitido: si varios aplican al mismo producto en el mismo instante, gana el de mayor porcentaje.
- Ventana de vigencia `[starts_at, ends_at)`: inicio inclusivo, fin exclusivo.
- La condición de vigencia se expresa dos veces a propósito —el scope SQL `active_at` y `active_at?` en memoria— para permitir `includes(:discounts)` y evitar N+1. El tradeoff es mantener dos expresiones de la misma regla.
- El monto mínimo se evalúa **post-descuento** y por proveedor (cada subórden contra el `min_amount` de su proveedor), con `>=` (igualar el mínimo alcanza) y todo-o-nada: si un proveedor no llega, falla la orden completa.
- `min_amount` nulo o 0 significa sin mínimo.

## Casos borde

**Cubiertos:** carrito vacío al confirmar; cantidad ≤ 0 o no entera (validada en dos capas — el `Cart` para feedback inmediato en la UI, y el `Checkout` como frontera que no confía en su llamador); fallo a mitad de la creación de la orden (rollback completo); precio del catálogo que cambia después de la compra (la orden no se altera); sesión corrupta o malformada (se descartan las entradas basura en vez de romper la app). En descuentos y mínimo: un descuento puede hacer que el subtotal de un proveedor caiga **por debajo de su mínimo** y bloquear una compra que sin descuento sí procedería —es contraintuitivo, pero es la regla pedida: el mínimo se evalúa post-descuento—; los bordes exactos de la ventana de vigencia (en `starts_at` aplica, en `ends_at` ya no); el redondeo de un descuento cuyo resultado no da entero exacto; y una compra con dos proveedores donde uno alcanza su mínimo y el otro no, tras la cual no queda nada creado.

**Fuera:** concurrencia entre compras simultáneas (no aplica sin validación de stock); la validación de cantidad es redundante entre capas y da mensajes de texto distintos según dónde se dispare (decisión consciente: cada capa protege su propia frontera).

## Qué cambiaría para producción

- **PostgreSQL** en lugar de SQLite, por la concurrencia de escritura real de un marketplace (varias tiendas confirmando órdenes a la vez).
- **Autenticación y asociación real de tienda**, en lugar de `Store.first`.
- **Locale `:es`** configurado para que todos los mensajes salgan en español.
- Revisión de **N+1** en las vistas agrupadas e índices donde corresponda; eventualmente, persistir totales si el volumen de lectura lo justificara.

## Qué implementaría con más tiempo

- Validación y descuento de stock, con su manejo de concurrencia.
- UI de administración de descuentos para el proveedor (crear, editar, expirar), hoy solo por seeds o consola.
- Histórico de órdenes de la tienda y sus vistas.
- Tests de integración de las vistas y el flujo end-to-end (hoy los tests se concentran en el service y el carrito, que es donde está la lógica central).

## Uso de inteligencia artificial

Usé Claude Code de forma incremental: cada parte (modelo de datos, carrito, checkout, tests, vistas) se generó, revisó y commiteó por separado, en vez de generar todo de una vez. El objetivo fue entender y poder defender cada pieza, no acumular código.

Algunos episodios concretos de verificación:

- **Verificación aparente vs. real en el modelo de datos.** La IA reportó un total "verificado". Al pedirle trazar el cálculo con datos reales, su propia verificación usaba tres productos del mismo proveedor, así que nunca ejercitó la agrupación por proveedor —el corazón del dominio— pese a decir que estaba verificado. Ese hueco se cerró después con un test explícito de dos proveedores distintos, que además aserta qué items caen en qué subórden, no solo el conteo.

- **Mensaje de error que asumía la causa.** El `Checkout` reportaba cualquier fallo de un `OrderItem` como "cantidad inválida", aunque el error fuera de otro campo. Lo detecté en revisión y se corrigió para derivar el mensaje del error real del registro.

- **Propuestas no pedidas.** Varias veces la IA se adelantó agregando tests o funcionalidad fuera del incremento en curso. Algunos los descarté para mantener los commits enfocados; otros los conservé cuando resolvían un problema real (los tests del carrito surgieron al toparse con CSRF en pruebas manuales, y son evidencia más sólida que probar con curl). El criterio fue distinguir cuándo el extra aporta y cuándo es ruido.

En todos los casos verifiqué los resultados —trazando los cálculos a mano, leyendo el código generado y corriendo la suite— antes de dar cada parte por buena.

## Checklist

- [x] La aplicación puede ejecutarse siguiendo el README.
- [x] Existen datos iniciales suficientes para probar el flujo.
- [x] Se puede crear una orden con productos de varios proveedores.
- [x] La orden genera una subórden por proveedor.
- [x] Los totales se muestran correctamente.
- [x] Los tests pueden ejecutarse siguiendo el README.
- [x] Los supuestos, pendientes y uso de IA están documentados.