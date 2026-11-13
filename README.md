# Guardião Urbano

Aplicativo mobile colaborativo para denúncia e acompanhamento de problemas ambientais urbanos.

## 📱 Sobre o projeto

O Guardião Urbano é um aplicativo desenvolvido como parte das Atividades Práticas Supervisionadas (APS) da disciplina de Desenvolvimento de Sistemas Distribuídos.

O aplicativo permite que os usuários registrem problemas ambientais encontrados em áreas urbanas, utilizando fotografias, localização geográfica, categorias e descrições para documentar cada ocorrência.

As informações podem ser armazenadas localmente no dispositivo e enviadas ao servidor por meio de uma API, permitindo o gerenciamento e acompanhamento das ocorrências.

## 🎯 Objetivo

Facilitar o registro e o acompanhamento de problemas ambientais urbanos por meio de uma aplicação mobile integrada a uma arquitetura de sistemas distribuídos.

## 🌱 Tipos de ocorrências

O aplicativo contempla o registro de problemas ambientais, como:

- Lixo irregular;
- Descarte de entulho;
- Queimadas;
- Árvores caídas;
- Desmatamento;
- Esgoto irregular;
- Poluição de rios;
- Terrenos abandonados.

## 🔄 Funcionamento

O fluxo principal da aplicação é organizado da seguinte maneira:

1. O usuário identifica um problema ambiental.
2. Realiza o registro de uma fotografia.
3. O aplicativo obtém as coordenadas geográficas da ocorrência.
4. O usuário seleciona a categoria correspondente.
5. Adiciona uma descrição do problema.
6. O aplicativo organiza e armazena os dados da ocorrência.
7. Os dados são enviados ao backend por meio de uma requisição à API.
8. O servidor recebe e processa as informações.
9. As ocorrências são armazenadas no banco de dados remoto.
10. O administrador pode analisar e atualizar o andamento das ocorrências.
11. O usuário pode acompanhar o status dos registros.

## 🏗️ Tecnologias

### Aplicativo Mobile

- **Flutter:** framework utilizado para o desenvolvimento da aplicação mobile.
- **Dart:** linguagem de programação utilizada no aplicativo.
- **Android Studio:** ambiente de desenvolvimento.
- **Android:** plataforma de execução do aplicativo.

### Backend

- **Node.js:** ambiente de execução do servidor.
- **TypeScript:** linguagem utilizada para desenvolvimento do backend.

### Banco de Dados

- **PostgreSQL:** banco de dados relacional utilizado para armazenar as informações.
- **PostGIS:** extensão do PostgreSQL utilizada para trabalhar com dados geográficos.
- **Neon PostgreSQL:** serviço utilizado para disponibilização do banco de dados remoto.

### Armazenamento Local

- **SQLite:** banco de dados local utilizado para armazenar informações no dispositivo.
- **DatabaseHelper:** classe responsável pela inicialização do banco, criação das tabelas e operações de inserção, consulta e atualização.

As principais tabelas locais são:

- `ocorrencias_offline`: armazena descrição, categoria, coordenadas geográficas, caminho da fotografia e data de criação das ocorrências.
- `categorias_offline`: armazena as informações utilizadas para identificar e classificar os tipos de ocorrência.

### Mensageria

- **RabbitMQ:** ferramenta de mensageria utilizada na arquitetura para permitir a comunicação assíncrona entre componentes do sistema.

### Infraestrutura

- **Docker:** utilizado para facilitar a configuração e execução dos serviços necessários ao ambiente de desenvolvimento.

## 🧩 Arquitetura do Sistema

A aplicação utiliza uma arquitetura distribuída, separando as responsabilidades entre o aplicativo mobile, o backend, os serviços de mensageria e o banco de dados.

O fluxo de comunicação é organizado da seguinte forma:

```text
Aplicativo Flutter
       |
       v
Armazenamento Local (SQLite)
       |
       v
API Backend
(Node.js / TypeScript)
       |
       v
RabbitMQ
       |
       v
Processamento das Ocorrências
       |
       v
PostgreSQL + PostGIS
       |
       v
Banco de Dados Remoto
```

### Comunicação entre os componentes

O aplicativo Flutter é responsável pela interface e pela interação com o usuário, permitindo registrar ocorrências e organizar as informações coletadas.

O SQLite possibilita o armazenamento local dos dados, enquanto a API realiza a comunicação entre o aplicativo e o servidor.

O backend concentra o processamento das informações e a integração com o banco de dados remoto. O RabbitMQ permite a comunicação assíncrona entre os componentes, contribuindo para a organização do processamento das ocorrências.

O PostgreSQL, integrado ao PostGIS, permite armazenar e consultar os registros, incluindo suas informações geográficas.

## 💾 Persistência e Gerenciamento de Dados

O sistema trabalha com armazenamento local e remoto.

No dispositivo mobile, o SQLite é utilizado para manter os registros locais das ocorrências. As operações são centralizadas na classe `DatabaseHelper`, responsável pelo gerenciamento das tabelas e dos dados.

No ambiente remoto, o PostgreSQL com PostGIS é responsável pela persistência das informações recebidas pelo backend.

Essa organização permite separar o armazenamento realizado no dispositivo do gerenciamento centralizado no servidor.

## 🐳 Infraestrutura com Docker

O Docker é utilizado para facilitar a configuração do ambiente de desenvolvimento e a execução dos serviços que compõem a infraestrutura do sistema.

A utilização de contêineres contribui para manter os serviços organizados e facilitar sua execução em diferentes ambientes.

## 📌 Considerações Finais

O Guardião Urbano busca aplicar conceitos de desenvolvimento mobile, persistência de dados, comunicação entre serviços e arquitetura distribuída.

A integração entre Flutter, backend, banco de dados e mensageria permite organizar as diferentes responsabilidades da aplicação, oferecendo uma solução para o registro e acompanhamento de problemas ambientais urbanos.
