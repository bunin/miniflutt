import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../common/tools.dart';
import '../models/data.dart';
import '../models/entry.dart';
import '../models/entry_style.dart';
import '../models/nav.dart';
import 'home.dart';

class MyEntryHeader extends StatelessWidget {
  MyEntryHeader({Key? key, required this.entry}) : super(key: key);
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.title!,
            textScaleFactor: 1.25,
            style: TextStyle(
              color: Theme.of(context).textTheme.titleLarge!.color,
              fontWeight: Theme.of(context).textTheme.titleLarge!.fontWeight,
            ),
          ),
          Divider(
            thickness: 1.0,
            color: Theme.of(context).textTheme.titleLarge!.color,
          ),
          RichText(
            textScaleFactor: 0.75,
            text: TextSpan(
              style: TextStyle(
                  color: Theme.of(context).textTheme.titleSmall!.color),
              children: <TextSpan>[
                TextSpan(text: 'by '),
                TextSpan(
                    text: entry.author,
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: ', ' + Uri.parse(entry.url!).host)
              ],
            ),
          ),
          Text(
            DateFormat('yyy-MM-dd HH:mm')
                .format(DateTime.parse(entry.publishedAt!)),
            textScaleFactor: 0.75,
          ),
        ],
      ),
    );
  }
}

class MyEntryBody extends StatelessWidget {
  MyEntryBody({Key? key, required this.entry}) : super(key: key);
  final Entry entry;

  Future<void> _handleURL(String? url, BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        // The dialogContext allows using a SnackBar without the 'Scaffold.of()
        // called with a context that does not contain a Scaffold.' error.
        final String fileName = url!.split('/').last;
        return AlertDialog(
          content: SingleChildScrollView(
            child:
                Text('Save on device or open in browser?\n\nFile: $fileName'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Save'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Downloading file...'),
                  duration: Duration(seconds: 60),
                ));
                final String filePath = await downloadURL(url);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('File saved in $filePath')));
              },
            ),
            TextButton(
              child: Text('Open'),
              onPressed: () {
                launchURL(url);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entryStyle = Provider.of<EntryStyle>(context, listen: false);
    return GestureDetector(
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            MyEntryHeader(entry: entry),
            Html(
              // Workaround since http images are not displayed
              data: entry.content!.replaceAll("http://", "https://"),
              style: {
                'html': Style(
                  fontSize: entryStyle.fontSize,
                ),
              },
              onLinkTap: (url, renderContext, attributes, element) async {
                // Suggest to download most common files
                final re = RegExp(r'\.('
                    r'7z|apk|avi|csv|doc|docx|flv|gif|h264|jpeg|jpg|mkv|mov|'
                    r'mp3|mp4|mpeg|mpg|odp|ods|odt|ogg|pdf|png|pps|ppt|pptx|'
                    r'psd|rtf|svg|tex|txt|webm|webp|xls|xlsx|zip'
                    r')$');
                if (re.hasMatch(url!.toLowerCase())) {
                  return _handleURL(url, context);
                } else {
                  launchURL(url);
                }
              },
              onImageTap: (url, renderContext, attributes, element) async {
                // Suggest to download images
                return _handleURL(url, context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MyEntryBottom extends StatelessWidget {
  MyEntryBottom({Key? key, required this.entry}) : super(key: key);
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: CircularNotchedRectangle(),
      child: Row(
        children: <Widget>[
          Spacer(),
          IconButton(
              icon: Icon(Icons.share),
              onPressed: () {
                // The box is necessary for iPads
                final RenderBox box = context.findRenderObject() as RenderBox;
                Share.share(entry.url!,
                    subject: entry.title,
                    sharePositionOrigin:
                        box.localToGlobal(Offset.zero) & box.size);
              }),
          Consumer<Data>(
            builder: (context, data, child) {
              return IconButton(
                icon: entry.starred!
                    ? Icon(
                        Icons.star,
                        color: Colors.amber,
                      )
                    : Icon(Icons.star_border),
                onPressed: () => data.toggleStar(entry.id),
              );
            },
          ),
          Consumer<Data>(
            builder: (context, data, child) {
              return IconButton(
                icon: Icon(entry.status == 'read'
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () => data.toggleRead(entry.id),
              );
            },
          ),
          if (entry.commentsUrl != null && entry.commentsUrl != "")
            Consumer<Data>(
              builder: (context, data, child) {
                return IconButton(
                  icon: Icon(Icons.comment),
                  onPressed: () => launchURL(entry.commentsUrl!),
                );
              },
            ),
          Spacer(),
        ],
      ),
    );
  }
}

class MyEntry extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Entry? entry = ModalRoute.of(context)!.settings.arguments as Entry?;
    final data = Provider.of<Data>(context, listen: false);
    final nav = Provider.of<Nav>(context, listen: false);
    final entries = filterEntries(data, nav);
    final PageController controller = PageController(
      initialPage: entries.indexOf(entry),
    );
    return PageView.builder(
      controller: controller,
      itemBuilder: (context, index) {
        final entry = entries[index]!;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              entry.feed!.title!,
            ),
          ),
          body: MyEntryBody(entry: entry),
          bottomNavigationBar: MyEntryBottom(entry: entry),
          floatingActionButton: FloatingActionButton(
            child: Icon(Icons.open_in_browser),
            onPressed: () => launchURL(entry.url!),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        );
      },
      itemCount: entries.length,
      onPageChanged: (index) {
        final entry = entries[index]!;
        data.read([entry.id]);
      },
    );
  }
}
