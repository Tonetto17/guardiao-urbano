# GuardiãoUrbano

Aplicativo mobile colaborativo para denúncia e acompanhamento de problemas ambientais urbanos.

## 📱 Sobre o projeto

O GuardiãoUrbano é um aplicativo desenvolvido como parte das Atividades Práticas Supervisionadas (APS) da disciplina de Desenvolvimento de Sistemas Distribuídos.

O objetivo do aplicativo é permitir que usuários registrem problemas ambientais encontrados em áreas urbanas, utilizando fotografia, localização e informações sobre a ocorrência.

As informações são enviadas para uma infraestrutura de backend, onde as ocorrências podem ser armazenadas, processadas e analisadas por um administrador.

## 🎯 Objetivo

Facilitar o registro e acompanhamento de problemas ambientais urbanos por meio de uma aplicação mobile integrada a uma arquitetura distribuída.

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

1. Usuário encontra um problema ambiental.
2. Usuário registra uma foto.
3. O aplicativo obtém a localização.
4. Usuário seleciona a categoria.
5. Usuário adiciona uma descrição.
6. A ocorrência é enviada para o servidor.
7. O sistema processa e armazena a ocorrência.
8. O administrador analisa a ocorrência.
9. O status da ocorrência é atualizado.
10. O usuário acompanha o andamento da denúncia.

## 🏗️ Tecnologias

### Aplicativo Mobile

- **Flutter**
- **Dart**
- **Android Studio**
- **Android**

### Backend

- **Node.js**
- **TypeScript**

### Banco de Dados

- **PostgreSQL**
- **PostGIS**

O PostGIS será utilizado para trabalhar com informações relacionadas à localização das ocorrências.

### Mensageria

- **RabbitMQ**

O RabbitMQ será utilizado para a comunicação assíncrona entre partes do sistema.

### Infraestrutura

- **Docker**

O Docker será utilizado para executar os serviços necessários para o backend e banco de dados.

### Armazenamento local

- **SQLite**

Será utilizado para permitir o armazenamento local de informações necessárias ao funcionamento offline da aplicação.

## 📚 Bibliotecas

As bibliotecas e dependências serão adicionadas ao projeto conforme cada funcionalidade for implementada.

As versões utilizadas serão registradas nos arquivos de configuração do projeto.

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