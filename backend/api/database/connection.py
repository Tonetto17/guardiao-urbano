import psycopg

def get_connection():
    return psycopg.connect(
        host="127.0.0.1",
        port=5432,
        dbname="guardiao_urbano",
        user="guardiao",
        password="guardiao"
    )