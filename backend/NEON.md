# Neon (PostgreSQL)

A API conecta ao Neon usando a variável `DATABASE_URL`. Copie `backend/api/.env.example` para `backend/api/.env` e preencha a URL exibida no Neon Console. Mantenha o segredo somente no ambiente do backend; não coloque essa URL no app Flutter nem no repositório.

Antes de iniciar a API, execute `backend/init.sql` no SQL Editor do Neon para criar o PostGIS e as tabelas. A aplicação grava localização em `geometry(Point, 4326)`, portanto habilite `postgis` no projeto Neon escolhido.

Com a URL configurada, inicie os serviços auxiliares com `docker compose up -d` em `backend`. No PowerShell, prepare as dependências e inicie a API assim:

```powershell
cd backend/api
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m uvicorn main:app --reload
```

O Docker Compose mantém RabbitMQ e Redis locais; o PostgreSQL local foi removido.

O app não usa mais SQLite. Ocorrências só são enviadas quando há conexão com a API; envio offline e cache local de categorias foram removidos.
