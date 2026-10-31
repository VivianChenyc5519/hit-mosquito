Hit That Moustique !

by Vivian chen and Lou-Ann Coquard-Morel

Hit That Moustique ! is a 2-player 2D game built in Godot 4.7. One player is the Human, who hunts with an electric racket and a flashlight. The other is the Mosquito, who tries to bite the Human before the timer runs out. The Human wins by zapping the mosquito once. The Mosquito wins by draining all 4 of the Human’s HP, or by surviving until the 120-second timer ends.

The Human walks at 220 px/s with WASD or the arrow keys, and the mouse aims the racket and the flashlight. Both the racket head and the beam turn toward the mouse, and you can aim while walking. A left click swings the racket. A swing that misses plays the woosh sound and the swing animation. A swing that touches the mosquito plays the zap sound and the hit animation, and it kills the mosquito instantly. After each swing there is a 0.5 s cooldown, and you can’t swing while stunned.

The Mosquito walks at 280 px/s, aims with the mouse, and left-clicks to bite. A bite only counts if the mosquito’s bite area overlaps the human’s body area. A bite that hits does four things:

It costs the human 1 HP.
It stuns the human for 1.5 s.
It gives the mosquito a speed boost to 400 px/s for 1.5 s.
It starts an 8 s bite cooldown.

A bite that misses only starts a 1 s cooldown, so you can’t spam clicks. The mosquito has 1 life.

Collisions. The racket and the mosquito never collide with each other. The mosquito can fly over the human, and the human can swing the racket “behind” the mosquito. Only the overlap areas decide a hit or a miss. Both characters collide with the walls.

Vision.

The Human sees almost nothing: the map is nearly black, and only the flashlight beam reveals the floor. The mosquito is visible only while it is inside the beam. The beam is about 136 px long with a half-angle of about 12.5°.
The Mosquito sees the whole map, a bit darkened, and can see where the human’s flashlight is pointing. The human appears as a flickering red dot on top of the racket.

Sound.

Every UI button plays the click sound, automatically.
A miss plays the woosh and a hit plays the zap.
A bite plays a short bite sound that I synthesized.
The mosquito buzz loops all the time. It is positioned on the mosquito and heard from the human’s side, so it gets louder and shifts left or right as the mosquito gets closer. This is how the human can track it in the dark.
The background music is very quiet and loops. The M key or the Music button turns it on and off, in the lobby and in the game.

Camera and map. The screen is 800×384 logical pixels. The left 640 px are the arena, and the right 160 px are the side panel. The camera is zoomed 2× and follows the character you control. It stops at the map edges, so in a corner the character keeps walking to the edge. Your brown tiles are the floor. Every empty cell of the tilemap, and everything outside it, is drawn as dark stone wall and is solid. This is built automatically from your map, so if you redraw the tiles, the walls follow.

Side panel. It shows the timer, then “YOUR STATS” and “ENEMY STATS”. Each has a heart with HP (or life for the mosquito), a cooldown bar (slap or bite), and a status (STUNNED, SPEED BOOST, SQUASHED). At the end, a window shows Victory or Defeat with the reason. A Credits window opens from the lobby.

How the online part works :

The online part uses Godot’s built-in high-level multiplayer: an ENetMultiplayerPeer (a UDP-based network library), RPCs, and multiplayer authority. It is a host-and-client model. Nothing external, such as a server program or a website, is needed.

Roles. The host is always the Human (peer id 1). The one client who joins is always the Mosquito. The server is created with max_clients = 1, so a third connection is refused.

Starting. The host presses “Host (Human)” in the lobby. The Play button stays disabled until a second player connects. When the host presses Play, it sends a reliable RPC and both players load the game scene together.

Who decides what. The host is the referee. It runs the rules (game_manager.gd): HP, cooldowns, stun, boost, win and lose. The client only sends requests.

When the mosquito clicks, the client sends “I tried to bite” to the host.
The host checks whether the areas overlap and applies the result.
It then broadcasts the outcome to both players: a bite hit or miss, the new HP, a stun, a boost, a slap hit or miss, and the end of the match.

Both players then play the same animations and sounds from that same message.

What is sent. Each player continuously sends its own position (and the aim angle) with an unreliable RPC, since a lost packet is not a problem. Everything that must not be lost (bites, slaps, HP, stun, boost, the match ending) goes through reliable RPCs.

If someone leaves, the other player gets a “The other player left the game” window with a button back to the lobby.

Solo debug mode runs the same game with OfflineMultiplayerPeer, so there is no network. You play one character with one keyboard, TAB swaps the character, and R restarts. It uses the same code, which is why it behaves like the online game.

How to connect

The host

Open the game and click “Host (Human)”. The game listens on UDP port 9999.
Give the other player your IP address.
On the same Wi-Fi or network, your local IP is the one from hostname -I in a terminal (for example 192.168.1.20).
Over the internet, use a VPN-style tool, which is the easiest option. Both players join the same virtual network (for example Tailscale, ZeroTier or Radmin VPN), and the host gives their virtual IP. The alternative is to forward UDP port 9999 on your router to your computer, then give the client your public IP.
Make sure your firewall allows UDP 9999.

The client

Type the host’s IP in the box (127.0.0.1 only works on the same computer) and click “Join (Mosquito)”.
Wait for “Connected”, then wait for the host to press Play.

You can test both sides on one computer: run two copies of the game, host in one and join 127.0.0.1 in the other.

What each script does

Game flow and network

network.gd (autoload “Network”): creates the host and the client, tracks the number of players, knows who is the mosquito, starts the game scene for both, handles disconnections, and holds the debug-mode state. It is always loaded.
lobby.gd: builds the main page in code: title, how-to-play window, connection window, solo test buttons, Music and Credits buttons. It enables Play only when two players are connected.
game.gd: the controller of a match. It builds the walls and collision from the tilemap, sets up the camera, sets each player’s role and view (darkness, flashlight, sounds), and moves the camera. It receives bite and slap requests and sends the results to both players. It also drives the side panel and the end screen, and handles the debug keys (TAB, R, M).
game_manager.gd: the rulebook (start/finish a match, timer, HP, cooldowns, stun, boost, who wins). Its tunable numbers, such as match length, HP and cooldowns, are at the top of the file. It runs only on the host (or in solo mode).

Characters

human.gd: the racket character. It handles walking, aiming, rotating the racket head and the flashlight, the slap request, the swing and hit animations, the hurt flash, the HP heart, the slap cooldown ring, and the “is this point inside my beam?” check.
mosquito.gd: handles walking, speed boost, aiming and rotating, the bite request, the lunge animation, the dying animation, the always-on buzz sound, and the bite cooldown ring.
cooldown_ring.gd: draws the small circular cooldown indicator over a character, in code.
human_sensor.gd: draws the flickering red dot that shows the human to the mosquito player.
map_walls.gd: draws the dark stone walls in all empty cells of the map.

Interface and sound

game_ui.gd: builds all the in-game interface in code: side panel with timer and stat windows, the “BITTEN!” / “ZAP!” messages, the damage flash, and the end window.
ui_theme.gd: the one place that defines the look: the PixelifySans font, the racket-inspired color palette, and the style of windows, buttons, text fields and bars.
audio_manager.gd (autoload “Sfx”): loads and plays all the sounds, automatically adds the click sound to every button, and controls the background music and its on/off toggle. It also creates the mosquito’s buzz player.
