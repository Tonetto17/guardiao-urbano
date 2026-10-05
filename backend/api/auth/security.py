from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

security = HTTPBearer()

SECRET_KEY = "guardiao-urbano-chave-secreta"
ALGORITHM = "HS256"

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        payload = jwt.decode(
            credentials.credentials,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Token inválido")

def get_current_admin(usuario: dict = Depends(get_current_user)):
    if usuario["tipo"] != "ADMIN":
        raise HTTPException(
            status_code=403,
            detail="Acesso permitido apenas para administradores"
        )

    return usuario