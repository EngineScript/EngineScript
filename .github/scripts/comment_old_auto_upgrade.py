import os
import re
from datetime import datetime

FILES = [
    'scripts/functions/auto-upgrade/normal-auto-upgrade.sh',
    'scripts/functions/auto-upgrade/emergency-auto-upgrade.sh',
]
THRESHOLD_DAYS = 7
TODAY = datetime.utcnow().date()

changes_made = False

for file in FILES:
    if not os.path.exists(file):
        continue
    with open(file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    out_lines = []
    in_section = False
    last_update_date = None
    for i, line in enumerate(lines):
        # Detect section start
        if re.match(r'^# Start (Normal|Emergency) Automatic Upgrade', line):
            in_section = True
            out_lines.append(line)
            continue
        # Detect last updated date comment
        m = re.match(r'^# Last updated: (\d{4}-\d{2}-\d{2})', line)
        if in_section and m:
            last_update_date = datetime.strptime(m.group(1), '%Y-%m-%d').date()
            out_lines.append(line)
            continue
        # If in section, process uncommented commands
        if in_section and not line.lstrip().startswith('#') and line.strip() != '':
            # If no last update date, add one for today
            if not last_update_date:
                last_update_date = TODAY
                out_lines.append(f'# Last updated: {TODAY.isoformat()}\n')
            days_old = (TODAY - last_update_date).days
            if days_old >= THRESHOLD_DAYS:
                out_lines.append(f'# Commented out on {TODAY.isoformat()}\n')
                out_lines.append(f'# {line.lstrip()}')
                changes_made = True
            else:
                out_lines.append(line)
        else:
            out_lines.append(line)
        # End section if we hit a blank line or another section
        if in_section and (line.strip() == '' or (line.startswith('#') and not line.startswith('# Last updated:'))):
            in_section = False
            last_update_date = None
    with open(file, 'w', encoding='utf-8') as f:
        f.writelines(out_lines)
# Set output for labeling
if changes_made:
    print('::set-output name=auto_upgrade_changed::true')
else:
    print('::set-output name=auto_upgrade_changed::false')
