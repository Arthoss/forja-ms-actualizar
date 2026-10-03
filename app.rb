require "sinatra"
require "pg"
require "json"

set :bind, "0.0.0.0"
set :port, ENV.fetch("PORT", 4567).to_i
set :host_authorization, { permitted_hosts: [] }
set :show_exceptions, false

def con_db
  conn = PG.connect(ENV.fetch("DATABASE_URL"))
  yield conn
ensure
  conn&.close
end

def json_ok(datos, codigo = 200)
  status codigo
  content_type :json
  datos.to_json
end

get "/" do
  json_ok({ status: "ok", servicio: "forja-ms-actualizar (Ruby)" })
end

# Respaldo de lectura (resiliencia): mismo formato que el microservicio Flask
# Respaldo de lectura (resiliencia): mismo formato que el microservicio Flask
get "/api/tip" do
  tip = con_db do |db|
    db.exec("SELECT id, texto, categoria FROM tips ORDER BY random() LIMIT 1").first
  end
  if tip
    json_ok({ id: tip["id"].to_i, texto: tip["texto"], categoria: tip["categoria"] })
  else
    json_ok({ error: "No hay tips" }, 404)
  end
end

# Actualizar un tip
put "/tips/:id" do
  begin
    cuerpo = JSON.parse(request.body.read)
    raise JSON::ParserError unless cuerpo.is_a?(Hash)
  rescue JSON::ParserError
    return json_ok({ error: "Cuerpo JSON inválido" }, 400)
  end

  if cuerpo["texto"].nil? && cuerpo["categoria"].nil?
    return json_ok({ error: "Envía texto y/o categoria" }, 400)
  end

  fila = con_db do |db|
    db.exec_params(
      "UPDATE tips SET texto = COALESCE($1, texto), categoria = COALESCE($2, categoria) " \
      "WHERE id = $3 RETURNING id, created_at, texto, categoria",
      [cuerpo["texto"], cuerpo["categoria"], params[:id].to_i]
    ).first
  end

  if fila
    json_ok({ mensaje: "Tip actualizado", tip: fila })
  else
    json_ok({ error: "Tip no encontrado" }, 404)
  end
end

error do
  json_ok({ error: env["sinatra.error"].message }, 500)
end

# ---- Swagger ----
get "/openapi.json" do
  json_ok({
    openapi: "3.0.0",
    info: { title: "FORJA Microservicio - Actualizar Tips (Ruby)", version: "1.0.0" },
    paths: {
      "/tips/{id}" => {
        put: {
          summary: "Actualiza un tip por su ID",
          parameters: [{ name: "id", in: "path", required: true, schema: { type: "integer" } }],
          requestBody: {
            required: true,
            content: { "application/json" => { schema: {
              type: "object",
              properties: { texto: { type: "string" }, categoria: { type: "string" } }
            } } }
          },
          responses: {
            "200" => { description: "Tip actualizado correctamente" },
            "400" => { description: "Cuerpo inválido" },
            "404" => { description: "Tip no encontrado" }
          }
        }
      },
      "/api/tip" => {
        get: {
          summary: "Devuelve un tip aleatorio (respaldo de lectura)",
          responses: {
            "200" => { description: "Tip aleatorio" },
            "404" => { description: "No hay tips" }
          }
        }
      }
    }
  })
end

get "/api-docs" do
  content_type :html
  <<~HTML
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>FORJA - Actualizar Tips (Ruby)</title>
      <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
      <script>SwaggerUIBundle({ url: "/openapi.json", dom_id: "#swagger-ui" });</script>
    </body>
    </html>
  HTML
end