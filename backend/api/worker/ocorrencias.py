import json
import os
import sys
import pika

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from messaging.rabbitmq import get_rabbitmq_connection

MAX_TENTATIVAS = 2

def publicar_retry(body, tentativas):
    connection = get_rabbitmq_connection()
    channel = connection.channel()

    channel.basic_publish(
        exchange="",
        routing_key="ocorrencias_retry",
        body=body,
        properties=pika.BasicProperties(
            delivery_mode=2,
            headers={
                "x-retry-count": tentativas
            }
        )
    )

    connection.close()

def publicar_dlq(body):
    connection = get_rabbitmq_connection()
    channel = connection.channel()

    channel.basic_publish(
        exchange="",
        routing_key="ocorrencias_dlq",
        body=body,
        properties=pika.BasicProperties(
            delivery_mode=2
        )
    )

    connection.close()

def obter_tentativas(headers):
    if not headers:
        return 0

    return headers.get("x-retry-count", 0)

def processar_ocorrencia(ch, method, properties, body):
    try:
        ocorrencia = json.loads(body)

        campos_obrigatorios = [
            "id",
            "usuario_id",
            "categoria_id",
            "descricao",
            "status",
            "latitude",
            "longitude"
        ]

        for campo in campos_obrigatorios:
            if campo not in ocorrencia:
                raise ValueError(f"Campo obrigatório ausente: {campo}")

        print("Ocorrência recebida:")
        print(ocorrencia)

        ch.basic_ack(delivery_tag=method.delivery_tag)

    except Exception as erro:
        tentativas = obter_tentativas(properties.headers)

        print("Erro ao processar ocorrência:")
        print(erro)
        print(f"Tentativa: {tentativas + 1}")

        if tentativas >= MAX_TENTATIVAS:
            publicar_dlq(body)
            ch.basic_ack(delivery_tag=method.delivery_tag)
            print("Mensagem enviada para DLQ")
        else:
            publicar_retry(body, tentativas + 1)
            ch.basic_ack(delivery_tag=method.delivery_tag)
            print("Mensagem enviada para retry")

connection = get_rabbitmq_connection()
channel = connection.channel()

channel.queue_declare(
    queue="ocorrencias",
    durable=True
)

channel.queue_declare(
    queue="ocorrencias_retry",
    durable=True,
    arguments={
        "x-message-ttl": 5000,
        "x-dead-letter-exchange": "",
        "x-dead-letter-routing-key": "ocorrencias"
    }
)

channel.queue_declare(
    queue="ocorrencias_dlq",
    durable=True
)

channel.basic_qos(prefetch_count=1)

channel.basic_consume(
    queue="ocorrencias",
    on_message_callback=processar_ocorrencia
)

print("Worker de ocorrências iniciado")

channel.start_consuming()