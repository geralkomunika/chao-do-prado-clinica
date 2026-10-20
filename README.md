# Chão do Prado — Gestão Clínica (Next.js + Supabase + Vercel)

Projeto inicial para **testes com dados fictícios**. Inclui logótipo, login, perfis, agenda diária/semanal/mensal, marcações, cancelamento, pacientes, convite de colaboradores, políticas RLS e bloqueio de sobreposição de consultas na base de dados.

**NÃO USAR COM DADOS REAIS DE PACIENTES** sem revisão de segurança, conformidade RGPD, testes de penetração, backups/recuperação e procedimentos operacionais. Não é um software clínico certificado. A agenda administrativa pode conter dados de saúde inferíveis.

## 1. Criar Supabase

1. Cria um projeto em https://supabase.com/dashboard numa região da UE, verifica condições de tratamento de dados e planos de backups.
2. Abre **SQL Editor** e executa `supabase/migrations/001_initial.sql` integralmente num projeto vazio.
3. Em **Authentication > Providers**, mantém Email ativo. Configura URL do site e URLs de redirecionamento para o domínio Vercel. Configura SMTP próprio para convites em produção.
4. Em **Authentication > Users**, cria manualmente o primeiro utilizador administrador. Copia o UUID.
5. No SQL Editor executa, substituindo pelo UUID real:
   ```sql
   update public.profiles set name='Administrador', role='admin', active=true where id='UUID_DO_UTILIZADOR';
   ```
6. Em **Project Settings > API**, copia URL, `anon`/publishable key e `service_role`/secret key. **A service role é segredo exclusivo do servidor**.
7. Para atualizações automáticas, adiciona `appointments` e `patients` à publicação `supabase_realtime` nas definições de Realtime/Replication; confirma se as políticas RLS permitem acesso ao utilizador. Sem isto, basta recarregar para obter alterações.

## 2. GitHub

Carrega os ficheiros deste projeto para `geralkomunika/chao-do-prado-clinica` (descompacta primeiro). Não carregues `.env.local` nem dados de pacientes. É preferível repositório privado. Não coloques segredos no GitHub.

## 3. Vercel

1. Em https://vercel.com/new importa o repositório GitHub.
2. Framework: Next.js. Adiciona **Environment Variables**:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY` (segredo, **não** com prefixo NEXT_PUBLIC)
3. Deploy. Depois configura o URL Vercel em Supabase Authentication > URL Configuration.
4. Para domínio próprio, configura `agenda.seu-dominio.pt` na Vercel e cria o registo DNS indicado no painel. HTTPS é gerido pela Vercel.

## 4. Desenvolvimento local

Requer Node.js 20+:

```bash
npm install
cp .env.example .env.local
# editar .env.local com as chaves do projeto de TESTES
npm run dev
```

Abre http://localhost:3000/login.

## Permissões implementadas

- Administrador: vê agenda e pacientes, cria marcações, envia convites, consulta equipa.
- Rececionista: vê e gere agenda e pacientes.
- Médico: vê apenas as suas consultas e pacientes associados a essas consultas; não altera marcações.
- Utilizador novo: fica `pending` e inativo até atribuição autorizada.
- Alterações de perfis não são permitidas diretamente pelo cliente. A API de convites confirma o JWT do utilizador e o perfil `admin` antes de usar a chave de serviço.
- A base de dados impede horários sobrepostos para o mesmo médico, inclusive em pedidos concorrentes.

## Limitações e tarefas obrigatórias antes de produção

- Rever e testar RLS, incluindo acessos diretos à API, alterações de perfis e tentativas de escalada de privilégios.
- Ativar MFA e políticas de acesso adequadas; reforçar o fluxo de convite, suspensão/revogação de contas e rotação de sessões.
- Implementar validação de pedidos, limitação de taxa, monitorização, gestão de erros e registos de auditoria de **leituras** sensíveis. O audit_log atual regista apenas escritas e não constitui auditoria completa.
- Garantir backups automáticos e externos cifrados e **testar restauros**. O plano Supabase pode não incluir os backups necessários.
- Rever contratos DPA, localização e transferências de dados, minimização, retenção, direitos dos titulares e eventual AIPD; consultar profissional de RGPD e segurança.
- Confirmar acessibilidade, testes funcionais e integração entre fusos horários. Os horários são apresentados no fuso do navegador, devendo ser normalizados para Europe/Lisbon antes de produção.
- O limite de 2000 consultas carregadas deve ser substituído por paginação e consultas por intervalo para uso real.
- Implementar edição de pacientes, desativação de contas e confirmação de operações sensíveis.
- Configurar cabeçalhos de segurança, proteção de endpoints, testes automatizados e processo de deploy seguro.

## Observação

O projeto **não** foi publicado na Vercel, não foi ligado a um Supabase real e não foram realizados testes end-to-end. É uma base de implementação, não uma instalação em produção.
