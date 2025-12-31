#  Sistema Inteligente para Prescrição de Treinos de Corrida (TCC)

> **SISTEMA INTELIGENTE PARA PRESCRIÇÃO AUTOMATIZADA DE TREINOS DE CORRIDA VOLTADO A CORREDORES AMADORES COM BASE EM INTELIGÊNCIA ARTIFICIAL ADAPTATIVA**

![Status](https://img.shields.io/badge/Status-Em_Desenvolvimento-yellow)
![Ruby](https://img.shields.io/badge/Ruby-3.x-red)
![Rails](https://img.shields.io/badge/Rails-7.x-red)
![AI](https://img.shields.io/badge/AI-Google_Gemini-blue)

## Sobre o Projeto

Este projeto foi desenvolvido como parte do Trabalho de Conclusão de Curso (TCC) do curso de **Sistemas de informação**.

O objetivo principal é democratizar o acesso a treinos de corrida personalizados. Muitos corredores amadores treinam sem orientação ou seguem planilhas estáticas que não respeitam sua evolução ou fadiga.

Este sistema resolve esse problema utilizando **Inteligência Artificial Generativa (LLM)** para atuar como um treinador virtual. O sistema analisa o histórico real do atleta e gera planos de treino adaptativos, considerando o volume semanal, pace atual e dias disponíveis.

## Funcionalidades Principais

-   **Importação de Dados Reais:** Upload e processamento de arquivos `.fit` (padrão Strava) para extração de métricas (distância, duração, pace, data).
-   **Dashboard do Atleta:** Visualização do histórico de corridas e estatísticas recentes.
-   **Geração de Treino via IA:** Integração com a **Google Gemini API** para criar periodizações de treino baseadas no histórico do usuário.
-   **Personalização:** Definição de objetivos (ex: "Correr 5km", "Melhorar Pace") e disponibilidade semanal.
-   **Feedback Adaptativo:** O sistema reavalia o plano com base na execução dos treinos anteriores.

## Tecnologias Utilizadas

### Backend & Frontend
-   **Ruby on Rails:** Framework principal para estrutura MVC, garantindo desenvolvimento ágil e robusto.
-   **PostgreSQL:** Banco de dados relacional para armazenar perfis, atividades e planos.
-   **Tailwind CSS** Estilização da interface.

### Inteligência Artificial & Serviços
-   **Google Gemini API:** Modelo de linguagem (LLM) utilizado para a lógica de raciocínio do treinador, análise de dados não estruturados e geração do JSON do plano de treino.
    -   *Modelos testados:* `gemini-1.5-flash`, `gemini-2.5-flash`.

### Bibliotecas Chave (Gems)
-   `google-generative-ai`: Interação com a API do Gemini.
-   `fit-parser`: Leitura e decodificação de arquivos binários de atividades físicas (.fit).
-   `devise`: Autenticação de usuários.

## Como Executar o Projeto

### Pré-requisitos
-   Ruby instalado (versão 3.0 ou superior)
-   Bundler
-   Chave de API do Google Gemini (Google AI Studio)

### Passo a Passo

2.  **Instale as dependências:**
    ```bash
    bundle install
    ```

3.  **Configuração de Variáveis de Ambiente:**
    Crie um arquivo `.env` na raiz do projeto e adicione sua chave da API:
    ```env
    GEMINI_API_KEY=sua_chave_aqui_faca_no_google_ai_studio
    ```

4.  **Configuração do Banco de Dados:**
    ```bash
    rails db:create
    rails db:migrate
    ```

5.  **Inicie o Servidor:**
    ```bash
    rails server
    ou
    foreman start -f Procfile.dev
    ```
    Acesse `http://localhost:3000` ou `http://localhost:5000` no seu navegador.

## Como a IA Funciona no Projeto

O diferencial deste Sistema é o uso de **Engenharia de Prompt** avançada. O sistema não pede apenas "um treino de corrida". O fluxo é:

1.  O sistema busca as últimas 10 atividades do banco de dados.
2.  Formata esses dados em um resumo textual (Data, Distância, Pace).
3.  Envia um prompt estruturado para o **Gemini**, contendo:
    -   O Perfil do Atleta (Objetivo).
    -   O Histórico Recente (Contexto).
    -   As restrições (Dias da semana disponíveis).
    -   Uma instrução estrita para retornar a resposta em formato **JSON**.
4.  O sistema recebe o JSON, valida a estrutura e salva no banco de dados, transformando a resposta da IA em uma interface de calendário interativo.

## Autor

---
*Este projeto é para fins acadêmicos e educacionais. Consulte sempre um profissional de educação física antes de iniciar atividades intensas.*
