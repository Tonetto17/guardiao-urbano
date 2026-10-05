from fastapi import APIRouter, WebSocket

router = APIRouter()

conexoes = []

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    conexoes.append(websocket)

    print("WebSocket conectado")
    print(f"Conexões ativas: {len(conexoes)}")

    try:
        while True:
            await websocket.receive_text()
    except:
        if websocket in conexoes:
            conexoes.remove(websocket)

        print("WebSocket desconectado")
        print(f"Conexões ativas: {len(conexoes)}")

async def enviar_atualizacao(mensagem):
    print("Enviando atualização WebSocket")
    print(f"Conexões ativas: {len(conexoes)}")
    print(mensagem)

    conexoes_ativas = []

    for websocket in conexoes:
        try:
            await websocket.send_json(mensagem)
            conexoes_ativas.append(websocket)
            print("Atualização enviada")
        except Exception as erro:
            print(f"Erro ao enviar WebSocket: {erro}")

    conexoes.clear()
    conexoes.extend(conexoes_ativas)