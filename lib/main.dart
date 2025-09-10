import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

/// -------------------- MODELS --------------------

enum BlockType { general, drink, challange }

class BlockModel {
  final String id;
  String label;
  String? taskText;
  BlockType type;
  BlockModel({
    required this.id,
    required this.label,
    this.taskText,
    this.type = BlockType.general,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'taskText': taskText,
    'type': type.name,
  };
  factory BlockModel.fromJson(Map<String, dynamic> j) => BlockModel(
    id: j['id'] as String,
    label: j['label'] as String,
    taskText: j['taskText'] as String?,
    type: BlockType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => BlockType.general,
    ),
  );
}

class BoardModel {
  final String id;
  String name;
  List<BlockModel> blocks;
  BoardModel({required this.id, required this.name, required this.blocks});
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };
  factory BoardModel.fromJson(Map<String, dynamic> j) => BoardModel(
    id: j['id'] as String,
    name: j['name'] as String,
    blocks: (j['blocks'] as List<dynamic>)
        .map((b) => BlockModel.fromJson(b as Map<String, dynamic>))
        .toList(),
  );
}

class PlayerModel {
  final String id;
  String name;
  Color color;
  int position;
  PlayerModel({
    required this.id,
    required this.name,
    required this.color,
    this.position = 0,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.value,
    'position': position,
  };
  factory PlayerModel.fromJson(Map<String, dynamic> j) => PlayerModel(
    id: j['id'] as String,
    name: j['name'] as String,
    color: Color(j['color'] as int),
    position: j['position'] as int,
  );
}

/// -------------------- UTIL --------------------
String _newId([String prefix = 'id']) =>
    '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
int clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

/// -------------------- STORAGE --------------------
class BoardStorage {
  static const String _key = 'boards_v1';
  static Future<List<BoardModel>> loadBoards() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map<BoardModel>((e) => BoardModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveBoards(List<BoardModel> boards) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(boards.map((b) => b.toJson()).toList());
    await sp.setString(_key, raw);
  }
}

/// -------------------- APP --------------------
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cigány ház',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainMenuPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// -------------------- MAIN MENU --------------------
class MainMenuPage extends StatefulWidget {
  @override
  _MainMenuPageState createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  List<BoardModel> boards = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await BoardStorage.loadBoards();
    setState(() => boards = loaded);
  }

  Future<void> _createDefaultBoardAndOpenEditor() async {
    final board = BoardModel(
      id: _newId('board'),
      name: 'Új pálya',
      blocks: [
        BlockModel(id: _newId('blk'), label: 'Start'),
        BlockModel(id: _newId('blk'), label: 'Everyone drinks'),
        BlockModel(id: _newId('blk'), label: 'Group selfie!'),
        BlockModel(id: _newId('blk'), label: 'Cél'),
      ],
    );
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => EditorPage(board: board)))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modular Board Game')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Új pálya létrehozása'),
              onPressed: _createDefaultBoardAndOpenEditor,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: boards.isEmpty
                  ? const Center(
                      child: Text('Nincs mentett pálya. Hozz létre újat!'),
                    )
                  : ListView.builder(
                      itemCount: boards.length,
                      itemBuilder: (_, i) {
                        final b = boards[i];
                        return Card(
                          child: ListTile(
                            title: Text(b.name),
                            subtitle: Text('${b.blocks.length} blokk'),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => LobbyPage(board: b),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    Navigator.of(context)
                                        .push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                EditorPage(board: b),
                                          ),
                                        )
                                        .then((_) => _load());
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    final ok =
                                        await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Törlés?'),
                                            content: Text(
                                              'Tényleg törlöd a "${b.name}" pályát?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Mégse'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('Törlés'),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;
                                    if (ok) {
                                      boards.removeAt(i);
                                      await BoardStorage.saveBoards(boards);
                                      setState(() {});
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------- EDITOR PAGE --------------------
String typeToLabel(BlockType t) {
  switch (t) {
    case BlockType.general:
      return "Általános";
    case BlockType.drink:
      return "Fix ivás";
    case BlockType.challange:
      return "Kihívás";
  }
}

Color typeToColor(BlockType t) {
  switch (t) {
    case BlockType.general:
      return Colors.grey;
    case BlockType.drink:
      return Colors.red;
    case BlockType.challange:
      return Colors.blue;
  }
}

class EditorPage extends StatefulWidget {
  final BoardModel board;
  EditorPage({required this.board});
  @override
  _EditorPageState createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late BoardModel board;
  final TextEditingController _boardNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    board = BoardModel(
      id: widget.board.id,
      name: widget.board.name,
      blocks: widget.board.blocks
          .map<BlockModel>(
            (b) => BlockModel(id: b.id, label: b.label, taskText: b.taskText),
          )
          .toList(),
    );
    _boardNameCtrl.text = board.name;
  }

  @override
  void dispose() {
    _boardNameCtrl.dispose();
    super.dispose();
  }

  void _addBlock() {
    final newBlock = BlockModel(id: _newId('blk'), label: "Új feladat");
    setState(() => board.blocks.add(newBlock));
  }

  Future<void> _saveAndExit() async {
    board.name = _boardNameCtrl.text.trim().isEmpty
        ? 'Pálya'
        : _boardNameCtrl.text.trim();
    final exist = await BoardStorage.loadBoards();
    final idx = exist.indexWhere((b) => b.id == board.id);
    if (idx >= 0) {
      exist[idx] = board;
    } else {
      exist.add(board);
    }
    await BoardStorage.saveBoards(exist);
    Navigator.of(context).pop();
  }

  void _editBlockDialog(BlockModel b) {
    final labelCtrl = TextEditingController(text: b.label);
    BlockType selectedType = b.type; // <-- ITT tároljuk a típus kezdeti értékét

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // kell, hogy tudjunk setState-et hívni
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Blokk szerkesztése"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: "Feladat szövege",
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<BlockType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: "Blokk típusa",
                    ),
                    items: BlockType.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(typeToLabel(t)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(
                          () => selectedType = val,
                        ); // <-- frissítjük a típust
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Mégse"),
                ),
                ElevatedButton(
                  onPressed: () {
                    b.label = labelCtrl.text.trim();
                    b.type =
                        selectedType; // <-- itt mentjük el a típust a blokkba
                    Navigator.of(context).pop();
                  },
                  child: const Text("Mentés"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pályaszerkesztő'),
        actions: [
          TextButton.icon(
            onPressed: _saveAndExit,
            icon: const Icon(
              Icons.save,
              color: Color.fromARGB(255, 25, 25, 25),
            ),
            label: const Text('Mentés', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _boardNameCtrl,
              decoration: const InputDecoration(labelText: 'Pálya neve'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Blokk hozzáadása'),
                  onPressed: _addBlock,
                ),
                const SizedBox(width: 8),
                const Text('Húzd őket a sorrendhez'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: board.blocks.length,
                onReorder: (int oldIndex, int newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final BlockModel item = board.blocks.removeAt(oldIndex);
                    board.blocks.insert(newIndex, item);
                  });
                },
                itemBuilder: (BuildContext context, int index) {
                  final b = board.blocks[index];
                  return Card(
                    key: ValueKey<String>(b.id),
                    child: ListTile(
                      title: Text(b.label),
                      subtitle: Text(b.taskText ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          _editBlockDialog(b);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------- LOBBY PAGE --------------------
class LobbyPage extends StatefulWidget {
  final BoardModel board;
  LobbyPage({required this.board});
  @override
  _LobbyPageState createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  final List<PlayerModel> players = [];
  final TextEditingController _nameCtrl = TextEditingController();
  final List<Color> palette = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.brown,
    Colors.pink,
    Colors.amber,
  ];
  int selectedColorIndex = 0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _addPlayer() {
    final name = _nameCtrl.text.trim().isEmpty
        ? 'Játékos ${players.length + 1}'
        : _nameCtrl.text.trim();
    final p = PlayerModel(
      id: _newId('player'),
      name: name,
      color: palette[selectedColorIndex],
      position: 0,
    );
    setState(() {
      players.add(p);
      _nameCtrl.clear();
      selectedColorIndex = (selectedColorIndex + 1) % palette.length;
    });
  }

  void _startGame() {
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adj hozzá legalább egy játékost')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GamePage(board: widget.board, players: players),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lobby: ${widget.board.name}')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Flexible(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Név'),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: selectedColorIndex,
                  items: List<DropdownMenuItem<int>>.generate(
                    palette.length,
                    (i) => DropdownMenuItem<int>(
                      value: i,
                      child: Row(
                        children: [
                          Container(width: 24, height: 24, color: palette[i]),
                          const SizedBox(width: 8),
                          Text(palette[i].toString().split('.').last),
                        ],
                      ),
                    ),
                  ),
                  onChanged: (int? v) {
                    if (v == null) return;
                    setState(() => selectedColorIndex = v);
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addPlayer,
                  child: const Text('Hozzáadás'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Játékosok (${players.length})'),
            Expanded(
              child: ListView.builder(
                itemCount: players.length,
                itemBuilder: (_, i) {
                  final p = players[i];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: p.color),
                    title: Text(p.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => setState(() => players.removeAt(i)),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Játék indítása'),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------- GAME PAGE --------------------
class GamePage extends StatefulWidget {
  final BoardModel board;
  final List<PlayerModel> players;
  GamePage({required this.board, required List<PlayerModel> players})
    : players = players
          .map<PlayerModel>(
            (p) => PlayerModel(
              id: p.id,
              name: p.name,
              color: p.color,
              position: 0,
            ),
          )
          .toList();

  @override
  _GamePageState createState() => _GamePageState();
}

enum Phase { AwaitRoll, MovedShowTask, AwaitNextPlayer, Finished }

class _GamePageState extends State<GamePage> {
  late List<PlayerModel> players;
  late BoardModel board;
  int currentPlayerIndex = 0;
  Phase phase = Phase.AwaitRoll;
  int lastRoll = 0;
  String? shownTask;
  String? winnerId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    board = widget.board;
    players = widget.players;
  }

  int _rollDice() {
    final r = Random();
    final val = r.nextInt(10) - 1; // -1..8
    setState(() => lastRoll = val);
    return val;
  }

  void _applyRollToCurrent(int roll) {
    if (phase != Phase.AwaitRoll) return;
    final p = players[currentPlayerIndex];
    final oldPos = p.position;
    int newPos = oldPos + roll;
    if (roll == -1) newPos = max(0, oldPos - 1);
    newPos = clampInt(newPos, 0, max(0, board.blocks.length - 1));
    setState(() {
      p.position = newPos;
      shownTask = board.blocks[newPos].taskText;
      phase = (newPos == board.blocks.length - 1)
          ? Phase.Finished
          : Phase.MovedShowTask;
      if (phase == Phase.Finished) winnerId = p.id;
    });
    _scrollToCurrent();
  }

  void _nextPlayer() {
    if (phase != Phase.AwaitNextPlayer && phase != Phase.MovedShowTask) return;
    setState(() {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      phase = Phase.AwaitRoll;
      lastRoll = 0;
      shownTask = '';
    });
  }

  void _scrollToCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final idx = players[currentPlayerIndex].position;
      final offset = (idx * 80).toDouble();
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildPlayerList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: board.blocks.length,
      itemBuilder: (_, i) {
        final block = board.blocks[i];
        final playersHere = players.where((p) => p.position == i).toList();
        return Card(
          child: ListTile(
            title: Text(block.label),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: playersHere
                  .map(
                    (p) => Row(
                      children: [
                        Container(width: 16, height: 16, color: p.color),
                        const SizedBox(width: 4),
                        Text(p.name),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    if (phase == Phase.Finished) {
      final winner = players.firstWhere((p) => p.id == winnerId);
      return Column(
        children: [
          Text(
            '${winner.name} nyert!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vissza a lobbyhoz'),
          ),
        ],
      );
    }

    if (phase == Phase.AwaitRoll) {
      return Column(
        children: [
          Text(
            '${players[currentPlayerIndex].name} következik',
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _applyRollToCurrent(_rollDice()),
            child: const Text('Dobás'),
          ),
          const SizedBox(height: 12),
          Text('Utolsó dobás: $lastRoll'),
        ],
      );
    }

    if (phase == Phase.MovedShowTask) {
      return Column(
        children: [
          Text('Feladat: $shownTask', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _nextPlayer,
            child: const Text('Következő játékos'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Játék: ${board.name}')),
      body: Column(
        children: [
          Expanded(child: _buildPlayerList()),
          Padding(padding: const EdgeInsets.all(12), child: _buildControls()),
        ],
      ),
    );
  }
}
