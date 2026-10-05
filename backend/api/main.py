from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from auth.routes import router as auth_router
from ocorrencias.routes import router as ocorrencias_router
from admin.routes import router as admin_router
from categorias.routes import router as categorias_router
from websocket.routes import router as websocket_router

app = FastAPI()

app.mount(
    "/uploads",
    StaticFiles(directory="uploads"),
    name="uploads"
)

app.include_router(auth_router)
app.include_router(ocorrencias_router)
app.include_router(admin_router)
app.include_router(categorias_router)
app.include_router(websocket_router)


@app.get("/")
def root():
    return {"message": "GuardiãoUrbano API"}