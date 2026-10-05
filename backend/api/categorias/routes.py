import json

from fastapi import APIRouter
from database.connection import get_connection
from cache.redis import get_redis_connection

router = APIRouter(prefix="/categorias")

@router.get("/")
def listar_categorias():
    redis = get_redis_connection()

    categorias_cache = redis.get("categorias")

    if categorias_cache:
        return json.loads(categorias_cache)

    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute(
        """
        SELECT id, nome
        FROM categorias
        ORDER BY nome
        """
    )

    categorias = cursor.fetchall()

    cursor.close()
    connection.close()

    resultado = [
        {
            "id": categoria[0],
            "nome": categoria[1]
        }
        for categoria in categorias
    ]

    redis.set(
        "categorias",
        json.dumps(resultado),
        ex=300
    )

    return resultado