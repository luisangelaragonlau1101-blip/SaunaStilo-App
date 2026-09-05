'use strict';
const fs = require('node:fs');
for (const file of ['lib/screens/operations_shell.dart','lib/screens/project_workspace_screen.dart','lib/screens/online_smart_screen.dart','lib/widgets/jornada_compacta.dart','lib/widgets/personal_message_overlay.dart','lib/services/team_contact_service.dart','functions/team-operations.js']) {
  if (!fs.existsSync(file)) throw new Error(`Missing release file: ${file}`);
}
console.log('Operations source inventory complete. This does not certify backend deployment or phone delivery.');
