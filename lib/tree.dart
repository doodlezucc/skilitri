import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_sound/android_encoder.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/ios_quality.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skilitri/theme.dart';
import 'package:video_player/video_player.dart';

import 'achievements.dart';
import 'main.dart';

class AchievementNode extends Node {
  static const String _TYPENAME = "achievement";
  List<MediaItem> _mediaItems = [];

  @override
  String _getType() {
    return _TYPENAME;
  }

  bool get hasItems => _mediaItems.length > 0;

  List<MediaItem> copyItems() => _mediaItems.toList(growable: false);

  void addItem(MediaItem mi) {
    mi._onDeletion = () {
      _mediaItems.remove(mi);
    };
    _mediaItems.add(mi);
  }

  AchievementNode(String title, SkillTree tree)
      : super(title: title, tree: tree);

  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({
      "media": _mediaItems.map((mi) => mi.toJson()).toList(growable: false)
    });

  AchievementNode.fromJson(Map<String, dynamic> json, SkillTree tree)
      : _mediaItems = List.from(json["media"])
            .map((m) => MediaItem._decipher(m))
            .toList(),
        super.fromJson(json, tree);

  ListTile render(BuildContext context) {
    return ListTile(
      title: Column(
        children: <Widget>[
          Text(
            SkillTree.dateToBeautiful(creationDate),
            style: TextStyle(color: Colors.black38),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      onTap: () => {
        Navigator.push(context,
                MaterialPageRoute(builder: (ctx) => EditAchievement(this)))
            .then((res) => {if (res != null) {}})
      },
    );
  }

  @override
  bool _canHaveChildren() {
    return false;
  }
}

class SkillTree {
  Set<Node> nodes = {};
  Map<Node, List<int>> _childMap;
  Map<int, Child> _ids = Map();

  List<AchievementNode> getAchievements() =>
      List.from(nodes.where((test) => test is AchievementNode),
          growable: false);

  List<AchievementNode> getSortedAchievements() {
    return getAchievements()
      ..sort((a, b) =>
          b.creationDate.millisecondsSinceEpoch -
          a.creationDate.millisecondsSinceEpoch);
  }

  SkillTree();

  Future<AchievementNode> addAchievementThroughUser(
      BuildContext context) async {
    AchievementNode ach = AchievementNode("", this);
    dynamic result = await Navigator.push(
        context, MaterialPageRoute(builder: (context) => EditAchievement(ach)));
    if (result == null) {
      nodes.add(ach);
      return ach;
    } else {
      return null;
    }
  }

  SkillNode addSkillNode(String title, Offset position) {
    SkillNode n = SkillNode(title: title, position: position, tree: this);
    nodes.add(n);
    return n;
  }

  SkillTree.fromJson(Map<String, dynamic> json) {
    _childMap = {};
    nodes = (json["nodes"] as List<dynamic>)
        .map((j) => Node.decipher(j, this))
        .toSet();

    _childMap.forEach((ch, childrenIDs) {
      childrenIDs.forEach((i) => {ch.addChild(_ids[i])});
    });
  }

  void _rearrangeIds() {
    int _counter = 0;
    _ids = Map();
    _ids.addEntries(nodes.map((n) => MapEntry(_counter++, n)));
  }

  Map<String, dynamic> toJson() {
    _rearrangeIds();
    return {
      "nodes": nodes.map((f) => f.toJson()).toList(growable: false),
    };
  }

  static String getWeekdayName(int wekd) {
    switch (wekd) {
      case 1:
        return "Monday";
      case 2:
        return "Tuesday";
      case 3:
        return "Wednesday";
      case 4:
        return "Thursday";
      case 5:
        return "Friday";
      case 6:
        return "Saturday";
      case 7:
        return "Sunday";
    }
    return "Pizza time ($wekd)";
  }

  static String _betterify(dynamic d) {
    return d.toString().padLeft(2, "0");
  }

  static String dateToBeautiful(DateTime dt) {
    return "${getWeekdayName(dt.weekday)}, ${_betterify(dt.day)}.${_betterify(dt.month)}.${dt.year}, ${_betterify(dt.hour)}:${_betterify(dt.minute)}";
  }
}

enum SelectionType { None, Selected, Focused, Dragged }

class TreeNeeder {
  SkillTree tree;
  DateTime creationDate;

  TreeNeeder(this.tree) {
    creationDate = DateTime.now();
  }

  Duration getStudyDuration() {
    return DateTime.now().difference(creationDate);
  }

  int _getIdAsChild() {
    return tree._ids.entries
        // ignore: unrelated_type_equality_checks
        .firstWhere((entry) => entry.value == this)
        .key;
  }

  TreeNeeder.fromJson(Map<String, dynamic> json, this.tree)
      : creationDate = DateTime.fromMillisecondsSinceEpoch(json["created"]) {
    tree._ids.putIfAbsent(json["id"], () => this as Child);
  }

  Map<String, dynamic> toJson() => {
        "id": _getIdAsChild(),
        "created": creationDate.millisecondsSinceEpoch,
      };
}

abstract class Parent extends TreeNeeder {
  Set<Child> children = {};

  Parent(SkillTree tree, [this.children]) : super(tree) {
    if (_canHaveChildren()) {
      if (children == null) {
        children = {};
      } else {
        if (tree != null) {
          tree.nodes.addAll(children.where((ch) => ch is Node));
        }
        for (Node n in children) {
          n._parents.add(this);
        }
      }
      this.children = children;
    }
  }

  bool _canHaveChildren();

  void addChild(Child n) {
    if (!_canHaveChildren()) return;
    n._parents.add(this);
    children.add(n);
  }

  Set<Child> getDescendants() {
    if (!_canHaveChildren()) return children; // which is {}
    Set<Child> out = Set();
    if (children.length > 0) {
      for (Child c in children) {
        if (c is Parent && (c as Parent)._canHaveChildren()) {
          out.addAll((c as Parent).getDescendants());
        }
        out.add(c);
      }
    }
    return out;
  }

  void unlinkChild(Child n) {
    if (!_canHaveChildren()) return;
    children.remove(n);
    n._parents.remove(this);
  }

  Map<String, dynamic> toJson() {
    if (_canHaveChildren()) {
      return super.toJson()
        ..addAll({
          "children": children
              .map((f) => (f as TreeNeeder)._getIdAsChild())
              .toList(growable: false)
        });
    }
    return super.toJson();
  }

  Parent.fromJson(Map<String, dynamic> json, SkillTree tree)
      : super.fromJson(json, tree) {
    if (_canHaveChildren()) {
      tree._childMap.putIfAbsent(this, () => List<int>.from(json["children"]));
    }
  }
}

class Child {
  // possible child of multiple things
  Set<Parent> _parents = {};

  Parent getFirstParent() => _parents.first;

  bool hasParent(Parent p) => _parents.contains(p);

  int get numParents => _parents.length;

  Set<Parent> getAscendants() {
    Set<Parent> out = Set();
    if (_parents.length > 0) {
      for (Node n in _parents) {
        out.addAll(n.getAscendants());
        out.add(n);
      }
    }
    return out;
  }

  void clearParents() {
    for (Parent p in _parents) {
      p.children.remove(this);
    }
    _parents.clear();
  }

  void addParent(Parent n) {
    n.addChild(this);
  }

  void unlinkParent(Parent n) {
    _parents.remove(n);
    n.children.remove(this);
  }
}

abstract class Node extends Parent with Child {
  String title;

  Node({@required String title, @required SkillTree tree, Set<Node> children})
      : super(tree, children) {
    this.title = clearEnd(title);
    creationDate = DateTime.now();
  }

  static Node decipher(Map<String, dynamic> json, SkillTree tree) {
    switch (json["type"]) {
      case SkillNode._TYPENAME:
        return SkillNode.fromJson(json, tree);
      case AchievementNode._TYPENAME:
        return AchievementNode.fromJson(json, tree);
    }
    print("oh well, unknown node type ${json["type"]}");
    return null;
  }

  Node.fromJson(Map<String, dynamic> json, SkillTree tree)
      : title = json["title"],
        super.fromJson(json, tree);

  Map<String, dynamic> toJson() {
    return super.toJson()
      ..addAll({
        "type": _getType(),
        "title": title,
      });
  }

  String _getType();

  void displayInfo(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute(builder: (ctx) => NodeInfo(node: this)));
  }

  @override
  String toString() {
    return "Node($title)";
  }

  void remove(bool keepChildren) {
    if (_canHaveChildren()) {
      if (keepChildren) {
        for (Child c in children.toSet()) {
          for (Node p in _parents) {
            p.addChild(c);
          }
        }
      } else {
        for (Child c in children.toSet()) {
          if (c is Node) {
            c.remove(false);
          }
        }
      }
      for (Child c in children.toSet()) {
        c._parents.remove(this);
      }
      children = {};
    }
    for (Node p in _parents) {
      p.children.remove(this);
    }
    tree.nodes.remove(this);
    _parents = null;
  }

  Widget getChildrenInfo(BuildContext context, ValueNotifier notifier) {
    List<AchievementNode> data =
        List.from(getDescendants().where((a) => a is AchievementNode));
    if (data.length == 0) {
      return Text("No connected achievements yet");
    }
    data.sort((a, b) =>
        b.creationDate.millisecondsSinceEpoch -
        a.creationDate.millisecondsSinceEpoch);
    return Column(
      children: data
          .map((d) => ListTile(
                title: Container(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: d._mediaItems
                        .map((mi) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2.0),
                              child: mi.getInfoPreview(context, notifier),
                            ))
                        .toList(),
                  ),
                ),
                onTap: () => {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (ctx) => EditAchievement(d)))
                },
                leading: Container(
                    width: 100,
                    child: Text(
                      d.title,
                      overflow: TextOverflow.fade,
                    )),
              ))
          .toList(),
    );
  }
}

abstract class VisibleNode extends Node {
  Offset position;
  bool isDragged = false;

  VisibleNode(
      {@required String title,
      @required this.position,
      @required SkillTree tree,
      Set<Node> children})
      : super(title: title, tree: tree, children: children);

  VisibleNode.fromJson(Map<String, dynamic> json, SkillTree tree)
      : position = Offset(json["position"]["x"], json["position"]["y"]),
        super.fromJson(json, tree);

  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({
      "position": {"x": position.dx, "y": position.dy},
    });

  Widget render(
      BuildContext context, ValueNotifier notifier, SelectionType sel) {
    return Container(
      decoration: BoxDecoration(
          color: nodeColor.withOpacity(isDragged ? 1.0 : 0.75),
          border: Border.all(
              width: 5,
              color: sel == SelectionType.None
                  ? Color(0x0)
                  : (sel == SelectionType.Focused
                      ? nodeFocused
                      : nodeSelected)),
          boxShadow: [
            BoxShadow(blurRadius: 25, spreadRadius: 5, color: Colors.black26)
          ],
          borderRadius: BorderRadius.all(Radius.circular(10.0))),
      child: Center(
          widthFactor: 1.0,
          heightFactor: 1.0,
          child: Container(
            padding: EdgeInsets.all(32.0),
            child: Text(
              title,
              style: TextStyle(color: nodeTitle, fontSize: 20.0),
            ),
          )),
    );
  }
}

class SkillNode extends VisibleNode {
  static const String _TYPENAME = "skill";

  SkillNode(
      {@required String title,
      @required Offset position,
      @required SkillTree tree,
      Set<Node> children})
      : super(title: title, position: position, tree: tree, children: children);

  SkillNode.fromJson(Map<String, dynamic> json, SkillTree tree)
      : super.fromJson(json, tree);

  @override
  String _getType() {
    return _TYPENAME;
  }

  @override
  bool _canHaveChildren() {
    return true;
  }
}

abstract class MediaItem {
  void Function() _onDeletion;

  MediaItem();

  Map<String, dynamic> _addSpecifics();

  Widget getPostPreview(BuildContext context, ValueNotifier notif);

  Widget getInfoPreview(BuildContext context, ValueNotifier notif);

  String _getType();

  DateTime getLastModified();

  void _del();

  void delete({ValueNotifier notif}) {
    _del();
    _onDeletion();
    notif?.value++;
  }

  static MediaItem _decipher(Map<String, dynamic> json) {
    switch (json["type"]) {
      case ImageItem._TYPENAME:
        return ImageItem.fromJson(json);
      case AudioItem._TYPENAME:
        return AudioItem.fromJson(json);
    }
    print("error? no media item created from json");
    return null;
  }

  Map<String, dynamic> toJson() => {
        "type": _getType(),
      }..addAll(_addSpecifics());
}

abstract class FileMediaItem extends MediaItem {
  File file;

  FileMediaItem(this.file) : super();

  FileMediaItem.fromJson(Map<String, dynamic> json)
      : file = File(json["path"]),
        super();

  @override
  DateTime getLastModified() {
    return file.lastModifiedSync();
  }

  @override
  void _del() {
    _onFileDelete();
    if (file.path.contains("skilitri")) {
      print("Deleting source file");
      file.deleteSync();
    } else {
      print("Kept source");
    }
  }

  void _onFileDelete();

  @override
  Map<String, dynamic> _addSpecifics() => {"path": file.path};
}

class VideoItem extends FileMediaItem {
  static const String TYPENAME = "video";

  VideoItem(File file) : super(file);

  VideoItem.throughUser(ImageSource source, BuildContext context)
      : super(null) {
    recVideo(source, context, null);
  }

  @override
  String _getType() {
    return TYPENAME;
  }

  Future recVideo(
      ImageSource source, BuildContext context, ValueNotifier notif) async {
    var video = await ImagePicker.pickVideo(source: source);
    Navigator.pop(context);
    if (video != null) {
      file = video;
      if (notif != null) {
        notif.value++;
      }
    }
  }

  VideoPlayerController controller;

  @override
  Widget getInfoPreview(BuildContext context, ValueNotifier notif) {
    return null;
  }

  @override
  Widget getPostPreview(BuildContext context, ValueNotifier notif) {
    if (controller == null) {
      controller = VideoPlayerController.file(file)
        ..initialize().then((_) => notif.value++);
    }

    return controller.value.initialized
        ? AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller))
        : Container();
  }

  @override
  void _onFileDelete() {}
}

class AudioItem extends FileMediaItem {
  static const String _TYPENAME = "audio";
  static FlutterSound flutterSound = FlutterSound();
  static double currentPosition;
  bool isPlaying = false;
  double _seekbarProgress;
  double duration;
  ValueNotifier _notif;

  static void maybeShutUp() {
    if (flutterSound.isPlaying) {
      flutterSound.stopPlayer();
    }
  }

  AudioItem(File file) : super(file);

  AudioItem.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  static Future<AudioItem> throughUser(BuildContext context) async {
    final directory = await getApplicationDocumentsDirectory();
    print(directory);

    String path = await flutterSound.startRecorder(
        "${directory.path}/${DateTime.now().millisecondsSinceEpoch}.aac",
        androidEncoder: AndroidEncoder.AAC_ELD,
        bitRate: 128000,
        iosQuality: IosQuality.HIGH);

    return await showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text("Recording audio..."),
            content: FlatButton(
                onPressed: () => {
                      flutterSound.stopRecorder().then(
                          (s) => {Navigator.pop(ctx, AudioItem(File(path)))})
                    },
                child: Text("Stop")),
          );
        });
  }

  @override
  String _getType() {
    return _TYPENAME;
  }

  @override
  Widget getInfoPreview(BuildContext context, ValueNotifier notif) {
    if (ModalRoute.of(context).isCurrent) {
      _notif = notif;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: ShapeDecoration(
        shape: CircleBorder(),
        color: Theme.of(context).primaryColor,
      ),
      child: IconButton(
        onPressed: () => {
          _togglePlaying(),
        },
        icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow,
            color: Colors.white),
      ),
    );
  }

  void _togglePlaying() async {
    if (isPlaying) {
      await flutterSound.stopPlayer();
      isPlaying = false;
      _notif.value++;
    } else {
      if (flutterSound.isPlaying) {
        await flutterSound.stopPlayer();
      }
      await flutterSound.startPlayer(file.uri.toString());
      isPlaying = true;

      flutterSound.onPlayerStateChanged.listen((status) {
        if (status != null) {
          duration = status.duration;
          currentPosition = status.currentPosition;
          //print("$currentPosition / $duration");
        }
        _notif.value++;
      }, onDone: () => {isPlaying = false, _notif.value++});
    }
  }

  @override
  Widget getPostPreview(BuildContext context, ValueNotifier notif) {
    if (ModalRoute.of(context).isCurrent) {
      _notif = notif;
    }
    Duration d = isPlaying
        ? (_seekbarProgress == null
            ? Duration(milliseconds: currentPosition.toInt())
            : Duration(milliseconds: (duration * _seekbarProgress).toInt()))
        : Duration.zero;

    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => {
            _togglePlaying(),
          },
          icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
        ),
        Expanded(
          child: isPlaying
              ? Slider.adaptive(
                  onChangeStart: (v) => {flutterSound.pausePlayer()},
                  onChanged: (v) => {_seekbarProgress = v},
                  onChangeEnd: (v) => {
                    currentPosition = duration * _seekbarProgress,
                    _seekbarProgress = null,
                    flutterSound.seekToPlayer((duration * v).toInt()),
                    flutterSound.resumePlayer()
                  },
                  value: _seekbarProgress ?? currentPosition / duration,
                )
              : Slider.adaptive(
                  onChanged: null,
                  value: 0,
                ),
        ),
        Text("${d.inMinutes % Duration.minutesPerHour}:"
            "${(d.inSeconds % Duration.secondsPerMinute).toString().padLeft(2, "0")}")
      ],
    );
  }

  @override
  void _onFileDelete() {
    if (isPlaying) {
      flutterSound.stopPlayer();
    }
  }
}

class ImageItem extends FileMediaItem {
  static const String _TYPENAME = "image";

  ImageItem(File file) : super(file);

  static Future<ImageItem> throughUser(BuildContext context) async {
    return await showDialog(
        context: context,
        builder: (ctx) {
          return SimpleDialog(
            title: Text("Add photo"),
            children: <Widget>[
              IconButton(
                onPressed: () => {
                  getImage(ImageSource.camera, context)
                      .then((ii) => Navigator.pop(ctx, ii)),
                },
                icon: Icon(Icons.camera_alt),
              ),
              IconButton(
                onPressed: () => {
                  getImage(ImageSource.gallery, context)
                      .then((ii) => Navigator.pop(ctx, ii)),
                },
                icon: Icon(Icons.photo_library),
              )
            ],
          );
        });
  }

  ImageItem.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  String _getType() {
    return _TYPENAME;
  }

  static Future<ImageItem> getImage(
      ImageSource source, BuildContext context) async {
    var image = await ImagePicker.pickImage(source: source);
    if (image != null) {
      return ImageItem(image);
    }
    return null;
  }

  @override
  Widget getPostPreview(BuildContext context, ValueNotifier notif) {
    return Container(
        decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.0),
            borderRadius: BorderRadius.circular(5.0)),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Image.file(file, height: 200),
        ));
  }

  @override
  Widget getInfoPreview(BuildContext context, ValueNotifier notif) {
    return Image.file(file, height: 50);
  }

  @override
  void _onFileDelete() {}
}

class NodeInfo extends StatefulWidget {
  final Node node;
  final ValueNotifier<int> notif = ValueNotifier(0);

  NodeInfo({Key key, @required this.node}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return NodeInfoState();
  }
}

class NodeInfoState extends State<NodeInfo> {
  TextEditingController cTitle;

  @override
  void initState() {
    cTitle = TextEditingController(text: widget.node.title);
    super.initState();
  }

  @override
  void dispose() {
    AudioItem.maybeShutUp();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Node information"),
        ),
        body: AnimatedBuilder(
            animation: widget.notif,
            builder: (ctx, constraints) => Container(
                    child: SingleChildScrollView(
                  padding: EdgeInsets.all(10.0),
                  child: Column(
                      children: <Widget>[
                    TextField(
                        decoration:
                            InputDecoration(hintText: "Enter node name..."),
                        onChanged: (s) => {widget.node.title = clearEnd(s)},
                        onEditingComplete: () => {
                              cTitle.text = clearEnd(cTitle.text),
                              FocusScope.of(context).unfocus()
                            },
                        controller: cTitle),
                    Divider(
                      height: 30.0,
                    )
                  ]..add(widget.node.getChildrenInfo(context, widget.notif))),
                ))));
  }
}
