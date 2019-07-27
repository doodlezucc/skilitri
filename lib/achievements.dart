import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:skilitri/theme.dart';
import 'package:skilitri/tree.dart';

import 'main.dart';

class EditAchievement extends StatefulWidget {
  final Achievement achievement;

  EditAchievement(this.achievement);

  @override
  _EditAchievementState createState() => _EditAchievementState();
}

class _EditAchievementState extends State<EditAchievement> {
  TextEditingController _comment;

  @override
  initState() {
    super.initState();
    _comment = TextEditingController(text: widget.achievement.comment)..addListener(() => {

    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        if (widget.achievement.comment == "" && widget.achievement.mediaItems.length == 0) {
          print("deleting because of no comment");
          widget.achievement.remove();
          Navigator.pop(context, true);
        } else {
          Navigator.pop(context);
        }
        return Future<bool>.value(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Edit achievement"),
        ),
        body: Container(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: <Widget>[
                  TextField(
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    controller: _comment,
                    onChanged: (s) => {
                      widget.achievement.comment = s
                    },
                  ),
                  Divider(),
                  buildMediaCol(),
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      IconButton(
                        onPressed: () => {
                          ImageItem.throughUser(context, whenDone: (ii) => {
                            if (ii != null) {
                              widget.achievement.mediaItems.add(ii),
                              setState(() => {})
                            },
                          })
                        },
                        icon: Icon(Icons.image),
                      ),
                      IconButton(
                        onPressed: () => {
                          //widget.achievement.mediaItems.add(VideoItem.throughUser(context))
                        },
                        icon: Icon(Icons.videocam),
                      ),
                      IconButton(
                        onPressed: () => {
                          //widget.achievement.mediaItems.add(VideoItem.throughUser(context))
                        },
                        icon: Icon(Icons.mic),
                      ),
                      IconButton(
                        onPressed: () => {
                          //widget.achievement.mediaItems.add(VideoItem.throughUser(context))
                        },
                        icon: Icon(Icons.insert_drive_file),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
        persistentFooterButtons: <Widget>[
          FlatButton(
            shape: StadiumBorder(),
            child: Text("Delete", style: TextStyle(color: invalid)),
            onPressed: () => {
              widget.achievement.remove(),
              Navigator.pop(context, true)
            },
          ),
          FlatButton(
            shape: StadiumBorder(),
            child: Row(
              children: <Widget>[
                Icon(Icons.link),
                Text("${widget.achievement.getAscendants().length} (${widget.achievement.numParents}) connections")
              ],
            ),
            onPressed: () => {
              Navigator.push(context, MaterialPageRoute(
                  builder: (ctx) => LinkAchievement(achievement: widget.achievement)
              ))
            },
          ),
        ],
//      floatingActionButton: FloatingActionButton.extended(
//        label: Text("${widget.achievement.getAscendants().length} (${widget.achievement.numParents}) connections"),
//
//        onPressed: () => {
//          Navigator.push(context, MaterialPageRoute(
//              builder: (ctx) => LinkAchievement(achievement: widget.achievement, skilitri: widget.skilitri)
//          )).then((result) => {
//
//          })
//        },
//        icon: Icon(Icons.link),
//      ),
      ),
    );
  }

  Widget buildMediaCol() {
    if (widget.achievement.mediaItems.length == 0) {
      return Text("No media");
    }
    return Column(
      children: widget.achievement.mediaItems.map((mi) => Padding(
        padding: const EdgeInsets.all(4.0),
        child: mi.getPostPreview(context, null),
      )).toList(),
    );
  }
}

class LinkAchievement extends StatefulWidget {
  final Achievement achievement;

  const LinkAchievement({Key key, this.achievement}) : super(key: key);

  @override
  _LinkAchievementState createState() => _LinkAchievementState();
}

class _LinkAchievementState extends State<LinkAchievement> {
  List<ValueNotifier> notifs = [];
  Set<Parent> asc;

  void computeAsc() {
    asc = widget.achievement.getAscendants();
  }

  @override
  Widget build(BuildContext context) {
    computeAsc();

    return Scaffold(
      appBar: AppBar(
        title: Text("Select connections"),
      ),
      body: SkilitriState.instance.buildViewport(
              (n) =>
          {
            if (widget.achievement.hasParent(n)) {
              n.unlinkChild(widget.achievement)
            } else
              {
                n.addChild(widget.achievement)
              },
            computeAsc(),
            notifs[0].value++
          },
          null,
          getSelectionType,
              (n, child) {
            if (asc.contains(child)) {
              return Colors.white;
            }
            return Colors.black38;
          },
          arr: notifs
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => {
          Navigator.pop(context, true)
        },
        child: Icon(Icons.done),
      ),
    );
  }

  SelectionType getSelectionType(Node n) {
    if (widget.achievement.hasParent(n)) {
      return SelectionType.Focused;
    } else if (asc.contains(n)) {
      return SelectionType.Selected;
    }
    return SelectionType.None;
  }
}