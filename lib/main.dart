import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
//import 'package:fluttery_audio/fluttery_audio.dart';
import 'package:skilitri/tree.dart';
import 'package:matrix_gesture_detector/matrix_gesture_detector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'skilitri',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        primaryColorLight: Color(0xff90ffa0),
        primaryColor: Color(0xff60dcaf),
        primaryColorDark: Color(0xffd0e0e0),
        backgroundColor: Color(0xffa0a0a0),
      ),
      home: Skilitri()
    );
  }
}

class Skilitri extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return SkilitriState();
  }
}

class SkilitriState extends State<Skilitri> {
  bool check = false;
  Tree tree;
  Matrix4 matrix = Matrix4.identity();
  ValueNotifier<int> notifier = ValueNotifier(0);
  bool inSelectionMode = false;
  Set<Node> selection = {};
  Node active;
  Node dragged;

  void resetTree() {
    tree = Tree(
        {
          Node(
              title: "Node",
              position: Offset(0, 0),
              body: DemoBody(),
              children: {
                Node(
                    title: "Score Node #1",
                    position: Offset(0, -100),
                    body: ScoreBody(score: 100),
                    children: {
                      Node(
                        title: "Score Node #2",
                        position: Offset(-300, -200),
                        body: ScoreBody(score: 5),
                      ),
                      Node(
                        title: "Score Node #3",
                        position: Offset(300, -200),
                        body: ScoreBody(score: 63),
                      )
                    }
                )
              }
          )
        }
    );
  }

  Widget buildNode(Node n) {
    Matrix4 ma = matrix.clone();
    ma.translate(n.position.dx, -n.position.dy);

    return Transform(
        transform: ma,
        child: GestureDetector(
            onTapUp: (details) =>
            {
              //print("onTapUp on " + n.toString()),
              if (inSelectionMode) {
                if (selection.contains(n)) {
                  if (selection.length == 1) {
                    exitSelectionMode()
                  } else
                    {
                      selection.remove(n),
                      if (active == n) {
                        active = null
                      }
                    }
                } else
                  {
                    select(n, false)
                  },
                notifier.value++
              } else {
                n.displayInfo(context)
              },
              onDragStop()
            },
            onLongPressStart: (details) =>
            {
              Feedback.forLongPress(context),
              select(n, true)
            },
            child: MatrixGestureDetector(
                shouldRotate: false,
                shouldScale: false,
                onMatrixUpdate: (m, tm, sm, rm) {
                  n.isDragged = true;
                  dragged = n;

                  Matrix4 change = tm;
                  //print(MatrixGestureDetector.decomposeToValues(matrix));
                  double sc = MatrixGestureDetector
                      .decomposeToValues(matrix)
                      .scale;
                  //change.multiplyTranspose(matrix);
                  n.position += Offset(change
                      .getTranslation()
                      .x / sc, -change
                      .getTranslation()
                      .y / sc);
                  notifier.value++;
                },
                child: Center(
                  child: n.render(context, notifier, getSelectionType(n)),
                )
            )
        )
    );
  }

  SelectionType getSelectionType(Node n) {
    if (active == n) {
      return SelectionType.Focused;
    } else if (selection.contains(n)) {
      return SelectionType.Selected;
    } else {
      return SelectionType.None;
    }
  }

  Offset screenToView(BuildContext ctx, Offset sc) {
    Matrix4 m = matrix.clone();
    var zoom = MatrixGestureDetector.decomposeToValues(m).scale;
    m.translate(-sc.dx / zoom, (150 - sc.dy) / zoom, 0);
    return Offset(-m.getTranslation().x / zoom - 180, m.getTranslation().y / zoom + 220);
  }

  void select(Node n, bool deselectOthers) {
    setState(() =>
    {
      if (deselectOthers) {
        selection = {}
      },
      selection.add(n),
      inSelectionMode = true,
      active = n
    });
  }

  void onAddNode(Offset position) {
    var controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Create new node"),
          content: Column(
            children: <Widget>[
              TextField(
                decoration: InputDecoration(
                  hintText: "Enter node name..."
                ),
                controller: controller,
              ),
              Center(
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => {
                        addNode(controller.text, ScoreBody(), position),
                        Navigator.of(ctx).pop()
                      },
                      icon: Icon(Icons.score),
                    ),
                    IconButton(
                      onPressed: () => {
                        addNode(controller.text, MediaBody(), position),
                        Navigator.of(ctx).pop()
                      },
                      icon: Icon(Icons.image),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  void addNode(String title, NodeBody body, Offset position) {
    Node n = Node(
        title: title,
        position: position,
        body: body
    );
    tree.nodes.add(n);
    n.tree = tree;
    select(n, true);
  }

  @deprecated
  void createEmptyNode(Offset position) {
    Node n = Node(
        title: "NEW NODE",
        position: position,
        body: ScoreBody(score: 0)
    );
    tree.nodes.add(n);
    n.tree = tree;
    select(n, true);
    //notifier.value++;
  }

  // I/O STUFF

  _read() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      //final file = File('${directory.path}/tree.fwd');
      //final file = File('${directory.path}/baum.fwd');
      final file = File('${directory.path}/jetztnochbesser.fwd');
      String text = await file.readAsString();
      print(text);
      setState(() => {
        tree = Tree.fromJson(jsonDecode(text))
      });
    } on FileSystemException {
      print("Can't read file");
    }
  }

  _save() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/jetztnochbesser.fwd');
    final text = jsonEncode(tree.toJson());
    print(text);
    await file.writeAsString(text);
    print('saved');

    Fluttertoast.showToast(
      msg: "Saved",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Color(0x60000000),
      timeInSecForIos: 1,
    );
  }

  Future<bool> _onWillPop() {
    exitSelectionMode();
    return Future<bool>.value(false);
  }

  @override
  Widget build(BuildContext context) {
    if (tree == null) {
      resetTree();
    }

    return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
            appBar: AppBar(
              title: Text('skilitri'),
            ),
            body: Column(
                children: [
                  Container(
                    child: Row(
                      children: <Widget>[
                        MaterialButton(
                          onPressed: () =>
                          {
                            resetTree(),
                            exitSelectionMode(),
                          },
                          child: Text('Reset tree'),
                        ),
                        IconButton(
                          onPressed: () =>
                          {
                            _save()
                          },
                          icon: Icon(
                              Icons.save
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                          {
                            _read()
                          },
                          icon: Icon(
                              Icons.restore_page
                          ),
                        ),
                      ],
                    ),
                    height: 50,
                  ),
                  Expanded(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerUp: (lol) =>
                      {
                        onDragStop()
                      },
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          return MatrixGestureDetector(
                              onMatrixUpdate: (m, tm, sm, rm) {
                                matrix =
                                    MatrixGestureDetector.compose(
                                        matrix, tm, sm, null);
                                notifier.value++;
                              },
                              child: GestureDetector(
                                onLongPressStart: (details) =>
                                {
                                  Feedback.forLongPress(context),
                                  if (inSelectionMode) {
                                    exitSelectionMode()
                                  } else
                                    {
                                      onAddNode(
                                          screenToView(
                                              context, details.globalPosition))
                                    }
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    alignment: Alignment.topLeft,
                                    color: Theme
                                        .of(context)
                                        .backgroundColor,
                                    child: AnimatedBuilder(
                                        animation: notifier,
                                        builder: (ctx, child) {
                                          return Container(
                                              width: double.infinity,
                                              height: double.infinity,
                                              child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    buildCanvas(),
                                                    Stack(
                                                      children: tree
                                                          .nodes
                                                          .map((n) =>
                                                          buildNode(n)
                                                      ).toList(),
                                                    )
                                                  ]
                                              )
                                          );
                                        }
                                    )
                                ),
                              )
                          );
                        },
                      ),
                    ),
                  ),
                  // SELECTION MODE BAR
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.decelerate,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                              blurRadius: 10
                          )
                        ]
                    ),
                    child: Row(
                      children: <Widget>[
                        MaterialButton(
                          onPressed: () =>
                          {
                            setState(() =>
                            {
                              exitSelectionMode()
                            })
                          },
                          child: Text('Exit'),
                        ),
                        IconButton(
                          onPressed: () =>
                          {
                            setState(() =>
                            {
                              for (Node n in selection) {
                                n.remove(true)
                              },
                              exitSelectionMode()
                            })
                          },
                          icon: Icon(
                              Icons.delete
                          ),
                        ),
                        IconButton(
                          onPressed: selection.length != 1 ? () =>
                          {
                            setState(() =>
                            {
                              if (active != null) {
                                for (Node n in selection) {
                                  if (n != active) {
                                    if (!active.getAscendants().contains(n)) {
                                      active.addChild(n),
                                    } else
                                      {
                                        print('well bois we did it, overflow is no more')
                                      }
                                  }
                                },
                              },
                            })
                          } : null,
                          icon: Icon(
                              Icons.link
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                          {
                            setState(() =>
                            {
                              for (Node n in selection) {
                                for (Node c in n.children.toSet()) {
                                  if (selection.contains(c)) {
                                    c.unlinkParent(n)
                                  }
                                }
                              },
                            })
                          },
                          icon: Icon(
                              Icons.link_off
                          ),
                        ),
                        IconButton(
                          onPressed: selection.length == 1 ? () =>
                          {
                            setState(() =>
                            {
                              selection.first.displayInfo(context)
                            })
                          } : null,
                          icon: Icon(
                              Icons.info_outline
                          ),
                        ),
                      ],
                    ),
                    height: inSelectionMode ? 50 : 0,
                  ),
                ]
            )
        )
    );
  }

  void onDragStop() {
    if (dragged != null) {
      dragged.isDragged = false;
      notifier.value++;
    }
  }

  void exitSelectionMode() {
    setState(() {
      inSelectionMode = false;
      active = null;
      selection = {};
    });
  }

  Widget buildCenter() {
    return Transform(
        transform: matrix,
        child: Stack(
          children: <Widget>[
            // vertical line
            Center(
                child: Container(
                    width: 1,
                    height: 250,
                    decoration: BoxDecoration(color: Colors.white)
                )
            ),
            // horizontal line
            Center(
                child: Container(
                    width: 250,
                    height: 1,
                    decoration: BoxDecoration(color: Colors.white)
                )
            ),
          ],
        )
    );
  }

  Widget buildCanvas() {
    return Transform(
      transform: matrix,
      child: Center(
        child: CustomPaint(
          painter: ShapesPainter(tree),
        ),
      ),
    );
  }
}

class ShapesPainter extends CustomPainter {
  Tree root;

  ShapesPainter(Tree root) {
    this.root = root;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    paint.color = Colors.black.withOpacity(0.25);
    paint.strokeWidth = 5;

    for (Node n in root.nodes) {
      for (Node c in n.children) {
        Offset start = c.position.scale(1, -1);
        Offset end = n.position.scale(1, -1);
        canvas.drawLine(start, end, paint);
        canvas.drawCircle(Offset.lerp(start, end, 0.7), 25, paint);
      }
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}