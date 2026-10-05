CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE usuarios (
    id UUID PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    senha VARCHAR(255) NOT NULL,
    tipo VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE categorias (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL
);

CREATE TABLE ocorrencias (
    id UUID PRIMARY KEY,
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    categoria_id INTEGER NOT NULL REFERENCES categorias(id),
    descricao TEXT NOT NULL,
    status VARCHAR(30) NOT NULL,
    latitude DECIMAL(10, 7) NOT NULL,
    longitude DECIMAL(10, 7) NOT NULL,
    localizacao GEOMETRY(Point, 4326) NOT NULL,
    foto_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE historico_ocorrencias (
    id UUID PRIMARY KEY,
    ocorrencia_id UUID NOT NULL REFERENCES ocorrencias(id),
    status_anterior VARCHAR(30),
    status_novo VARCHAR(30) NOT NULL,
    alterado_por UUID NOT NULL REFERENCES usuarios(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);