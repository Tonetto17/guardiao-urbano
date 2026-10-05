from fastapi import APIRouter, Depends, HTTPException
from database.connection import get_connection
from auth.security import get_current_admin
from websocket.routes import enviar_atualizacao

router = APIRouter(prefix="/admin")


@router.get("/ocorrencias")
def listar_todas_ocorrencias(
    usuario: dict = Depends(get_current_admin)
):
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute(
        """
        SELECT
            o.id,
            u.nome,
            u.email,
            c.nome AS categoria,
            o.descricao,
            o.status,
            o.latitude,
            o.longitude,
            o.foto_url,
            o.created_at
        FROM ocorrencias o
        JOIN usuarios u ON u.id = o.usuario_id
        JOIN categorias c ON c.id = o.categoria_id
        ORDER BY o.created_at DESC
        """
    )

    ocorrencias = cursor.fetchall()

    cursor.close()
    connection.close()

    return [
        {
            "id": str(ocorrencia[0]),
            "usuario": ocorrencia[1],
            "email": ocorrencia[2],
            "categoria": ocorrencia[3],
            "descricao": ocorrencia[4],
            "status": ocorrencia[5],
            "latitude": float(ocorrencia[6]),
            "longitude": float(ocorrencia[7]),
            "foto_url": ocorrencia[8],
            "created_at": ocorrencia[9]
        }
        for ocorrencia in ocorrencias
    ]


@router.get("/ocorrencias/{ocorrencia_id}/historico")
def listar_historico(
    ocorrencia_id: str,
    usuario: dict = Depends(get_current_admin)
):
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute(
        """
        SELECT
            h.id,
            h.status_anterior,
            h.status_novo,
            u.nome,
            h.created_at
        FROM historico_ocorrencias h
        JOIN usuarios u ON u.id = h.alterado_por
        WHERE h.ocorrencia_id = %s
        ORDER BY h.created_at ASC
        """,
        (ocorrencia_id,)
    )

    historico = cursor.fetchall()

    cursor.close()
    connection.close()

    return [
        {
            "id": str(item[0]),
            "status_anterior": item[1],
            "status_novo": item[2],
            "alterado_por": item[3],
            "created_at": item[4]
        }
        for item in historico
    ]


@router.put("/ocorrencias/{ocorrencia_id}/status")
async def alterar_status(
    ocorrencia_id: str,
    novo_status: str,
    usuario: dict = Depends(get_current_admin)
):
    status_validos = [
        "ABERTA",
        "EM_ANALISE",
        "EM_ATENDIMENTO",
        "CONCLUIDA"
    ]

    if novo_status not in status_validos:
        raise HTTPException(
            status_code=400,
            detail="Status inválido"
        )

    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute(
        """
        SELECT status
        FROM ocorrencias
        WHERE id = %s
        """,
        (ocorrencia_id,)
    )

    ocorrencia = cursor.fetchone()

    if not ocorrencia:
        cursor.close()
        connection.close()

        raise HTTPException(
            status_code=404,
            detail="Ocorrência não encontrada"
        )

    status_anterior = ocorrencia[0]

    cursor.execute(
        """
        UPDATE ocorrencias
        SET status = %s,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = %s
        """,
        (novo_status, ocorrencia_id)
    )

    cursor.execute(
        """
        INSERT INTO historico_ocorrencias (
            id,
            ocorrencia_id,
            status_anterior,
            status_novo,
            alterado_por
        )
        VALUES (
            gen_random_uuid(),
            %s,
            %s,
            %s,
            %s
        )
        """,
        (
            ocorrencia_id,
            status_anterior,
            novo_status,
            usuario["sub"]
        )
    )

    connection.commit()

    cursor.close()
    connection.close()

    await enviar_atualizacao({
        "tipo": "STATUS_ATUALIZADO",
        "ocorrencia_id": ocorrencia_id,
        "status_anterior": status_anterior,
        "status_novo": novo_status
    })

    return {
        "message": "Status atualizado",
        "status_anterior": status_anterior,
        "status_novo": novo_status
    }