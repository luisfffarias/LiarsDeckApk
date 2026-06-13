#  Liar's Jokenpo (Liars)

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Socket.io](https://img.shields.io/badge/Socket.io-black?style=for-the-badge&logo=socket.io&badgeColor=010101)

Um jogo de cartas multiplayer eletrizante focado em blefe e intuição, inspirado na dinâmica do *Liar's Bar* com mecânicas de Jokenpô (Pedra, Papel e Tesoura). Desenvolvido para mobile com interface imersiva de taverna.


---

## Como Jogar

O jogo é uma batalha mental onde os jogadores devem se livrar de todas as suas cartas. 
A mesa exigirá uma carta específica (Pedra, Papel ou Tesoura). Você pode jogar as cartas verdadeiras ou **blefar**. 

* **Duvidar:** Se um oponente desconfiar da sua jogada e apertar o botão de *Duvidar*, suas cartas são reveladas.
* **Jokenpô da Morte:** Quem for pego na mentira (ou quem acusar falsamente) sofrerá uma penalidade e terá que jogar uma rodada de "Roleta Russa" no Jokenpô contra o servidor.
* **Moedas e Ranking:** Sobreviva, elimine seus adversários por W.O. ou blefes, fature moedas (coins) e suba no ranking dos *Liar's Kings*!

## Tecnologias Utilizadas

O projeto foi construído utilizando uma arquitetura moderna dividida entre Front-end e Back-end:

### Front-end (Este repositório)
* **Flutter:** Framework principal para a construção da interface mobile.
* **Dart:** Linguagem de programação.
* **Dio:** Para requisições HTTP REST (Autenticação e Perfis).
* **Socket.io Client:** Para comunicação em tempo real bidirecional com a mesa.
* **Audioplayers:** Efeitos sonoros e música ambiente (Game Feel).
* **Flutter Secure Storage:** Armazenamento seguro do JWT Token.

### Back-end (API e Game Server)
* **NestJS:** Framework Node.js para o servidor.
* **Socket.io:** Gerenciamento das salas, turnos, temporizadores de AFK e broadcast de eventos.
* **Prisma ORM & PostgreSQL:** Persistência de dados (usuários, moedas, vitórias e taxa de vitórias).

---

## Como Rodar o Projeto (Desenvolvimento)

Caso queira rodar o projeto localmente na sua máquina ou no [FlutLab](https://flutlab.io):

**Pré-requisitos:**
- Flutter SDK instalado.
- Back-end do jogo rodando localmente ou em nuvem (atualize a `ApiConstants.baseUrl` no código).

**Passos:**
1.  Clone este repositório:
   ```bash
   git clone [https://github.com/seu-usuario/liars.git](https://github.com/seu-usuario/liars.git)

2.  Acesse a pasta do projeto:

Bash
cd liars
3.  Instale as dependências do Flutter:

Bash
flutter pub get
4.  Execute o aplicativo:

Bash
flutter run
```
---
### Desenvolvido por:
Luis Fernando França Farias

Ryan Pereira da Mota

Guilherme Pim

---

-Projeto desenvolvido para fins acadêmicos e aprimoramento em desenvolvimento mobile Multiplataforma e comunicação em tempo real.
