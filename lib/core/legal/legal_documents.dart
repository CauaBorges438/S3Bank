/// Termos de uso e política de privacidade do S3 Bank.
///
/// Ao alterar qualquer texto abaixo, aumente a versão. Quem aceitou a versão
/// anterior precisa aceitar a nova.
class LegalDocuments {
  LegalDocuments._();

  static const termsVersion = '1.0';
  static const privacyVersion = '1.0';

  static const terms = <LegalSection>[
    LegalSection(
      'Sobre o aplicativo',
      r'''O S3 Bank é um aplicativo de conta digital desenvolvido como projeto acadêmico.
Ele não é uma instituição financeira e não está autorizado pelo Banco Central do Brasil.
Os valores exibidos são simulados, e as operações entre contas do próprio aplicativo
são registradas no banco de dados do projeto.''',
    ),
    LegalSection(
      'Cadastro e conta',
      r'''Para criar uma conta, você deve informar dados verdadeiros, como nome, CPF, e-mail
e celular. Você é responsável pela guarda da sua senha de acesso e do seu PIN de
transação, que são pessoais e intransferíveis.''',
    ),
    LegalSection(
      'Uso permitido',
      r'''O aplicativo não pode ser usado para fraudes, lavagem de dinheiro ou qualquer
atividade ilícita. Contas usadas dessa forma podem ser bloqueadas.''',
    ),
    LegalSection(
      'Operações e segurança',
      r'''Pix, transferências, boletos e pagamentos de fatura só são concluídos com a
confirmação do PIN de transação. Há limite diário de saídas de R$ 5.000,00 para
transferências para outro banco e boletos pagos.''',
    ),
    LegalSection(
      'Níveis e rendimento',
      r'''Os pontos de constância, os níveis e o rendimento das caixinhas são uma simulação
baseada em percentual do CDI. Não há garantia de rendimento.''',
    ),
    LegalSection(
      'Disponibilidade',
      r'''O aplicativo está em desenvolvimento e pode ficar indisponível ou apresentar
falhas. Não há garantia de disponibilidade contínua.''',
    ),
    LegalSection(
      'Alterações',
      r'''Estes termos podem ser alterados. Quando houver mudança, uma nova versão será
apresentada para aceite antes de você continuar usando o aplicativo.''',
    ),
  ];

  static const privacy = <LegalSection>[
    LegalSection(
      'Dados que coletamos',
      r'''Nome, CPF, e-mail e celular, para criar e identificar a conta. Data e versão do
aceite destes termos. Movimentações financeiras feitas no aplicativo. As preferências
de notificação ficam salvas no próprio aparelho.''',
    ),
    LegalSection(
      'Por que coletamos',
      r'''Para criar e manter a conta, autenticar você, registrar as operações, prevenir
fraudes e cumprir obrigações legais. O aceite dos termos é a base do tratamento para
criar a conta (Lei 13.709/2018, art. 7º, I e V).''',
    ),
    LegalSection(
      'Armazenamento e segurança',
      r'''Os dados ficam no Supabase. Senhas, PIN e códigos de recuperação são guardados
apenas como hash. O CVV do cartão não é guardado em texto. A sessão de acesso fica no
armazenamento seguro do aparelho.''',
    ),
    LegalSection(
      'Compartilhamento',
      r'''Compartilhamos dados apenas com prestadores que nos ajudam a operar o aplicativo:
Supabase (banco de dados e autenticação) e Resend (envio de e-mails). Não vendemos
dados pessoais.''',
    ),
    LegalSection(
      'Seus direitos',
      r'''Você pode pedir a confirmação do tratamento, o acesso, a correção, a portabilidade
e a eliminação dos seus dados, além de informações sobre o compartilhamento e a
revogação do consentimento (Lei 13.709/2018, art. 18). Os pedidos são feitos pelo
e-mail de atendimento indicado na Central de ajuda.''',
    ),
    LegalSection(
      'Por quanto tempo guardamos',
      r'''Enquanto a conta existir e pelo prazo exigido pela legislação para registros
financeiros.''',
    ),
    LegalSection(
      'Contato',
      r'''Dúvidas sobre privacidade podem ser enviadas pelo e-mail de atendimento indicado na
Central de ajuda do aplicativo.''',
    ),
  ];
}

class LegalSection {
  final String title;
  final String body;

  const LegalSection(this.title, this.body);
}
