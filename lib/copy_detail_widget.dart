import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ClipboardButton extends StatelessWidget {
  final String textToCopy;

  ClipboardButton({required this.textToCopy});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      child: Icon(CupertinoIcons.doc_on_clipboard),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: textToCopy));
        Fluttertoast.showToast(
            msg: "Copied to clipboard!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: CupertinoColors.systemGrey,
            textColor: CupertinoColors.white,
            fontSize: 16.0
        );
      },
    );
  }
}
