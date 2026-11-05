# GuardiãoUrbano

Aplicativo mobile colaborativo para denúncia e acompanhamento de problemas ambientais urbanos.

## 📱 Sobre o projeto

O GuardiãoUrbano é um aplicativo desenvolvido como parte das Atividades Práticas Supervisionadas (APS) da disciplina de Desenvolvimento de Sistemas Distribuídos.

O aplicativo permite que usuários registrem problemas ambientais encontrados em áreas urbanas, utilizando fotografia, localização e informações sobre a ocorrência.

As ocorrências são enviadas para o servidor, onde podem ser armazenadas, processadas e analisadas por um administrador.

## 🎯 Objetivo

Facilitar o registro e acompanhamento de problemas ambientais urbanos por meio de uma aplicação mobile integrada a uma arquitetura de sistemas distribuídos.

## 🌱 Tipos de ocorrências

O aplicativo poderá registrar ocorrências como:

- Lixo irregular
- Descarte de entulho
- Queimada
- Árvore caída
- Desmatamento
- Esgoto irregular
- Poluição de rios
- Terrenos abandonados

## 🔄 Funcionamento

O fluxo principal da aplicação será:

1. O usuário encontra um problema ambiental.
2. Registra uma fotografia.
3. O aplicativo obtém a localização.
4. Seleciona a categoria do problema.
5. Adiciona uma descrição.
6. Envia a ocorrência.
7. O servidor recebe e processa os dados.
8. A ocorrência é armazenada.
9. O administrador analisa a ocorrência.
10. O status é atualizado.
11. O usuário acompanha o andamento da ocorrência.

## 🏗️ Tecnologias

### Aplicativo Mobile

- Flutter
- Dart
- Android Studio
- Android

### Backend

- Node.js
- TypeScript

### Banco de Dados

- PostgreSQL
- PostGIS

O PostGIS será utilizado para trabalhar com as informações geográficas das ocorrências.

### Mensageria

- RabbitMQ

O RabbitMQ será utilizado para comunicação assíncrona entre os componentes do sistema.

### Infraestrutura

- Docker

O Docker será utilizado para executar os serviços necessários para o sistema.

### Banco remoto e armazenamento local

- Neon PostgreSQL + PostGIS para persistir usuarios e ocorrencias no backend.
- O app Flutter nao mantem banco local; precisa de conexao com a API para enviar e consultar ocorrencias.
- Veja [backend/NEON.md](backend/NEON.md) para configurar o banco e criar o schema.

## 🧩 Arquitetura

A comunicação principal do sistema será organizada da seguinte forma:

```text
Aplicativo Flutter
       │
       ▼
    API Backend
       │
       ▼
    RabbitMQ
       │
       ▼
 Processamento
       │
       ▼
PostgreSQL + PostGIS