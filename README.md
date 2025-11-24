# RESUMO
Uma solução Mobile + AR para operações de campo em contexto empresarial. O colaborador aponta a câmara ao Artigo e a aplicação mostra as informações do mesmo no ecrã. Os dados são mostrados em tempo real a partir do ERP da empresa via API REST, com cache offline para zonas sem rede.

# APLICAÇÃO
Uma aplicação móvel de Realidade Aumentada (AR) que apoia técnicos e colaboradores em contextos industriais, logísticos e de manutenção, integrando-se diretamente com o sistema de informação empresarial (ERP).
Através da câmara do telemóvel, o utilizador pode identificar equipamentos, visualizar instruções de manutenção, consultar dados técnicos e registar intervenções no sistema, tudo em tempo real e de forma intuitiva.
O objetivo é melhorar a eficiência operacional e reduzir o erro humano, tornando o processo mais rápido e visual.

# EXECUTAR
# Verificar se tem emulador instalado
flutter emulators

# Se aparecer algum, executar:
flutter emulators --launch <nome_emulador>

# Depois correr a app:
flutter run




# ESTRUTURA
lib:
Ficheiros de código da aplicação.

main.dart:
    localizado diretamente dentro da pasta lib, é o ponto de entrada da aplicação. É o primeiro ficheiro a ser executado quando a app é iniciada. Nele são definidas as configurações principais, o tema visual e as rotas iniciais. Também é onde a aplicação chama o ecrã principal, geralmente o HomeScreen.

lib/screens:
    Diferentes ecrãs que o utilizador pode ver e utilizar. Por exemplo, o ficheiro login_screen.dart contém o código da página de login, onde o utilizador introduz as credenciais. O ficheiro scanner_screen.dart contém a parte responsável por usar a câmara do telemóvel para ler códigos QR ou códigos de barras. O ficheiro home_screen.dart representa a página principal da aplicação, onde o utilizador tem acesso às opções do sistema.

lib/services: 
    Ficheiros responsáveis pela comunicação com o servidor e pela lógica de rede. O ficheiro api_service.dart serve para centralizar as chamadas à API, permitindo que a aplicação peça dados ou envie informação para o servidor através de ligações HTTP.

lib/models: 
    Ficheiros que representam as estruturas de dados da aplicação. Por exemplo, o ficheiro artigo_model.dart define como é construído um objeto "Artigo", com campos como nome, código, stock e preço. Estes modelos ajudam a organizar e validar os dados recebidos da API.

lib/widgets:
    Componentes reutilizáveis da interface. O ficheiro botao_principal.dart contém o código de um botão personalizado que pode ser usado em vários ecrãs. Os widgets permitem reaproveitar elementos visuais sem precisar de repetir o mesmo código em diferentes partes da aplicação.