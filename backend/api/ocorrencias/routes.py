import os
import shutil
import uuid

from fastapi import APIRouter, Depends, File, Form, UploadFile
from database.connection import get_connection
from auth.security import get_current_user
from messaging.rabbitmq import publicar_ocorrencia

router = APIRouter(prefix="/ocorrencias")

PASTA_FOTOS = "uploads/ocorrencias"
os.makedirs(PASTA_FOTOS, exist_ok=True)


@router.post("/")
def criar_ocorrencia(
    categoria_id: int = Form(...),
    descricao: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    foto: UploadFile | None = File(None),
    usuario: dict = Depends(get_current_user)
):
    foto_url = None

    if foto:
        extensao = os.path.splitext(foto.filename or "")[1].lower()
        nome_arquivo = f"{uuid.uuid4()}{extensao}"
        caminho_foto = os.path.join(PASTA_FOTOS, nome_arquivo)

        with open(caminho_foto, "wb") as arquivo:
            shutil.copyfileobj(foto.file, arquivo)

        foto_url = f"/uploads/ocorrencias/{nome_arquivo}"

    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute(
        """
        INSERT INTO ocorrencias (
            id,
            usuario_id,
            categoria_id,
            descricao,
            status,
            latitude,
            longitude,
            localizacao,
            foto_url
        )
        VALUES (
            gen_random_uuid(),
            %s,
            %s,
            %s,
            'ABERTA',
            %s,
            %s,
            ST_SetSRID(ST_MakePoint(%s, %s), 4326),
            %s
        )
        RETURNING id
        """,
        (
            usuario["sub"],
            categoria_id,
            descricao,
            latitude,
            longitude,
            longitude,
            latitude,
            foto_url
        )
    )

    ocorrencia_id = cursor.fetchone()[0]

    connection.commit()

    cursor.close()
    connection.close()

    publicar_ocorrencia({
        "id": str(ocorrencia_id),
        "usuario_id": usuario["sub"],
        "categoria_id": categoria_id,
        "descricao": descricao,
        "status": "ABERTA",
        "latitude": latitude,
        "longitude": longitude,
        "foto_url": foto_url
    })

    return {
        "message": "Ocorrência criada",
        "id": str(ocorrencia_id),
        "foto_url": foto_url
    }


@router.get("/")
def listar_ocorrencias(usuario: dict = Depends(get_current_user)):
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute(
        """
        SELECT
            o.id,
            c.nome AS categoria,
            o.descricao,
            o.status,
            o.latitude,
            o.longitude,
            o.foto_url,
            o.created_at
        FROM ocorrencias o
        JOIN categorias c ON c.id = o.categoria_id
        WHERE o.usuario_id = %s
        ORDER BY o.created_at DESC
        """,
        (usuario["sub"],)
    )

    ocorrencias = cursor.fetchall()

    cursor.close()
    connection.close()

    return [
        {
            "id": str(ocorrencia[0]),
            "categoria": ocorrencia[1],
            "descricao": ocorrencia[2],
            "status": ocorrencia[3],
            "latitude": float(ocorrencia[4]),
            "longitude": float(ocorrencia[5]),
            "foto_url": ocorrencia[6],
            "created_at": ocorrencia[7]
        }
        for ocorrencia in ocorrencias
    ]


@router.get("/{ocorrencia_id}")
def buscar_ocorrencia(
    ocorrencia_id: str,
    usuario: dict = Depends(get_current_user)
):
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute(
        """
        SELECT
            o.id,
            c.nome AS categoria,
            o.descricao,
            o.status,
            o.latitude,
            o.longitude,
            o.foto_url,
            o.created_at,
            o.updated_at
        FROM ocorrencias o
        JOIN categorias c ON c.id = o.categoria_id
        WHERE o.id = %s
        AND o.usuario_id = %s
        """,
        (ocorrencia_id, usuario["sub"])
    )

    ocorrencia = cursor.fetchone()

    cursor.close()
    connection.close()

    if not ocorrencia:
        return {"message": "Ocorrência não encontrada"}

    return {
        "id": str(ocorrencia[0]),
        "categoria": ocorrencia[1],
        "descricao": ocorrencia[2],
        "status": ocorrencia[3],
        "latitude": float(ocorrencia[4]),
        "longitude": float(ocorrencia[5]),
        "foto_url": ocorrencia[6],
        "created_at": ocorrencia[7],
        "updated_at": ocorrencia[8]
    }