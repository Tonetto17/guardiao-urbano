import json
import pika

def get_rabbitmq_connection():
    credentials = pika.PlainCredentials("guest", "guest")

    parameters = pika.ConnectionParameters(
        host="localhost",
        port=5672,
        credentials=credentials
    )

    return pika.BlockingConnection(parameters)

def criar_fila_ocorrencias():
    connection = get_rabbitmq_connection()
    channel = connection.channel()

    channel.queue_declare(
        queue="ocorrencias",
        durable=True
    )

    connection.close()

def criar_filas_resiliencia():
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

    connection.close()

def publicar_ocorrencia(ocorrencia):
    connection = get_rabbitmq_connection()
    channel = connection.channel()

    channel.queue_declare(
        queue="ocorrencias",
        durable=True
    )

    mensagem = json.dumps(ocorrencia)

    channel.basic_publish(
        exchange="",
        routing_key="ocorrencias",
        body=mensagem,
        properties=pika.BasicProperties(
            delivery_mode=2
        )
    )

    connection.close()