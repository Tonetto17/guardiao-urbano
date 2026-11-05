from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException
from jose import jwt
from pydantic import BaseModel
from pwdlib import PasswordHash

from database.connection import get_connection

router = APIRouter(prefix="/auth")
password_hash = PasswordHash.recommended()

SECRET_KEY = "guardiao-urbano-chave-secreta"
ALGORITHM = "HS256"
TOKEN_EXPIRE_MINUTES = 60


class CadastroRequest(BaseModel):
    nome: str
    email: str
    senha: str


class LoginRequest(BaseModel):
    email: str
    senha: str


@router.post("/register")
def register(dados: CadastroRequest):
    senha_hash = password_hash.hash(dados.senha)

    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute(
        "INSERT INTO usuarios (id, nome, email, senha, tipo) VALUES (gen_random_uuid(), %s, %s, %s, %s)",
        (dados.nome, dados.email, senha_hash, "CIDADAO")
    )

    connection.commit()
    cursor.close()
    connection.close()

    return {"message": "Usuário cadastrado"}

@router.post("/login")
def login(dados: LoginRequest):
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute(
        "SELECT id, nome, senha, tipo FROM usuarios WHERE email = %s",
        (dados.email,)
    )

    usuario = cursor.fetchone()

    cursor.close()
    connection.close()

    if not usuario:
        raise HTTPException(status_code=401, detail="Email ou senha inválidos")

    if not password_hash.verify(dados.senha, usuario[2]):
        raise HTTPException(status_code=401, detail="Email ou senha inválidos")

    payload = {
        "sub": str(usuario[0]),
        "tipo": usuario[3],
        "exp": datetime.now(timezone.utc) + timedelta(minutes=TOKEN_EXPIRE_MINUTES)
    }

    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

    return {
        "message": "Login realizado",
        "access_token": token,
        "token_type": "bearer",
        "usuario": {
            "id": str(usuario[0]),
            "nome": usuario[1],
            "email": dados.email,
            "tipo": usuario[3]
        }
    }
