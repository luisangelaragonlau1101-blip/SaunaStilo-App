import 'package:flutter/material.dart';

/// Product policy: internal conversations continue; report export and private-file handoff do not.
/// This is an application boundary, not DRM or protection against browser tools/cameras.
class ExternalTransfer {
 static const blockedMessage='Sauna Stilo mantiene sus archivos dentro de la aplicación. La exportación y el envío a otras aplicaciones están desactivados.';
 static Future<void> block(BuildContext context) async {
  if(!context.mounted)return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content:Text(blockedMessage)));
 }
}

/// Keep paste/select/editing accessibility; remove outbound clipboard/share menu actions.
Widget privacyTextMenu(BuildContext context,EditableTextState state)=>AdaptiveTextSelectionToolbar.buttonItems(
 anchors:state.contextMenuAnchors,
 buttonItems:state.contextMenuButtonItems.where((item)=>![ContextMenuButtonType.copy,ContextMenuButtonType.cut,ContextMenuButtonType.share,ContextMenuButtonType.searchWeb,ContextMenuButtonType.lookUp].contains(item.type)).toList(),
);
